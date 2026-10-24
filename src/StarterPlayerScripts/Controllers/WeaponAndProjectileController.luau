--!strict
-- WeaponAndProjectileController: turns input into combat requests and draws their local side.
--   Bows (DrawTime) and charged throws (ChargeTime): hold LMB to draw, release to loose. The
--     arrow is spawned locally the instant the button is released and the packet is sent with
--     the draw ratio, a server timestamp and a seed; the server rewinds and re-simulates it.
--   Crossbow / firearms: click to fire, re-armed after ReloadTime. Blunderbuss pellets come
--     from the shared seed so the local spread matches the server's.
--   Melee: click (or hold) to swing at SwingRate with a Trail on the blade; BattleAxe holds to
--     charge an overhead; RMB holds a block on swords, the Shield raises on RMB or LMB.
--   Utilities: lobbed items show the predicted arc while LMB is held and throw on release;
--     SnapTrap / Palisade show a green (valid) or red hologram at the placement point.
--   Healing items start a cast (Q cancels). R toggles fire arrows, F catches a returning chakram.
-- Also replicates aim pitch (20 Hz) and draw ratio, and bends every visible bow string.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Modules = ReplicatedStorage:WaitForChild("Modules")
local Net = require(Modules.Shared.Net)
local Types = require(Modules.Shared.Types)
local Ballistics = require(Modules.Shared.BallisticsEngine)
local EquipmentRig = require(Modules.Shared.EquipmentRig)
local VFX = require(Modules.Shared.VFX)
local EquipmentDatabase = require(Modules.Config.EquipmentDatabase)
local SoundCatalog = require(Modules.Config.SoundCatalog)
local State = require(script.Parent.ClientState)
local Camera = require(script.Parent.CameraAndViewmodelController)
local Renderer = require(script.Parent.ProjectileRenderer)
local Poses = require(script.Parent.CharacterPoses)

local Weapon = {}

type Spec = Types.EquipmentSpec
type ChargeKind = "Bow" | "Throw" | "Heavy" | "Lob"
type Charge = { Slot: number, Start: number, Time: number, Kind: ChargeKind }

local PLACE_RANGE = 14
local THROW_INTERVAL = 0.6

local player = Players.LocalPlayer

local primaryHeld = false
local secondaryHeld = false
local blockSent = false
local charge: Charge? = nil
local lastUse: { [number]: number } = {}
local lastDrawSent = -1
local lastDrawSendAt = 0
local lastPitchSendAt = 0

local hologram: Model? = nil
local hologramItem: string? = nil
local hologramTarget: Vector3? = nil
local arcDots: { BasePart } = {}
local arcRing: BasePart? = nil

local trailOffAt: { [Trail]: number } = {}
local lastSwingSeen: { [Model]: number } = {}
local stringState: { [Attachment]: number } = {}

local function now(): number
	return Workspace:GetServerTimeNow()
end

---------------------------------------------------------------------------------------------
-- Helpers
---------------------------------------------------------------------------------------------
local function minInterval(spec: Spec): number
	if spec.SubType == "MELEE" then
		return spec.SwingRate or 0.5
	end
	if spec.ReloadTime then
		return spec.ReloadTime
	end
	if spec.Cooldown then
		return spec.Cooldown
	end
	if spec.Category == "UTILITY" or spec.Category == "HEALING" then
		return THROW_INTERVAL
	end
	if spec.SubType == "BOW" then
		return 0.25
	end
	return 0.35
end

-- Remaining cooldown and the full interval for a hotbar slot (HUD overlay).
function Weapon.SlotCooldown(slot: number): (number, number)
	local inv = State.Inventory
	local s = if inv then inv.Slots[slot] else nil
	local spec = if s then EquipmentDatabase.Get(s.ItemId) else nil
	if spec == nil then
		return 0, 1
	end
	local interval = minInterval(spec)
	local used = lastUse[slot]
	if used == nil then
		return 0, interval
	end
	return math.max(0, interval - (now() - used)), interval
end

local function ready(slot: number, spec: Spec): boolean
	local used = lastUse[slot]
	return used == nil or now() - used >= minInterval(spec) * 0.9
end

local function headPosition(): Vector3?
	local character = State.Character()
	local head = if character then character:FindFirstChild("Head") else nil
	if head and head:IsA("BasePart") then
		return head.Position
	end
	local root = State.Root()
	return if root then root.Position + Vector3.new(0, 1.5, 0) else nil
end

local function staggered(): boolean
	local character = State.Character()
	local until_ = if character then character:GetAttribute("StaggerUntil") else nil
	return type(until_) == "number" and until_ > now()
end

local function phaseAllowsCombat(): boolean
	local round = State.Round
	return round == nil or round.Phase == "ActiveCombat"
end

local function canAct(): boolean
	return State.InCombat()
		and State.Alive()
		and not State.InMenu()
		and not State.Cinematic
		and phaseAllowsCombat()
		and not staggered()
end

local function equipped(): (number, Types.InventorySlot?, Spec?)
	local inv = State.Inventory
	if inv == nil then
		return 0, nil, nil
	end
	local slot = inv.Slots[inv.Equipped]
	return inv.Equipped, slot, if slot then EquipmentDatabase.Get(slot.ItemId) else nil
end

local function isLobbed(itemId: string): boolean
	return itemId == "SmokeBomb" or itemId == "Fireball" or itemId == "HealingFlask"
end

local function isPlaced(itemId: string): boolean
	return itemId == "SnapTrap" or itemId == "Palisade"
end

-- World position of the held weapon's muzzle (viewmodel in first person).
local function muzzlePosition(): Vector3?
	local cam = Workspace.CurrentCamera
	local vm = if cam then cam:FindFirstChild("LocalViewmodel") else nil
	local weapon = if vm then vm:FindFirstChild("Weapon") else nil
	if weapon == nil then
		local character = State.Character()
		weapon = if character then character:FindFirstChild(EquipmentRig.HeldName) else nil
	end
	if weapon and weapon:IsA("Model") then
		local a = EquipmentRig.GetAttachment(weapon, "MuzzleAttachment")
		if a then
			return a.WorldPosition
		end
	end
	return headPosition()
end

local function pushInventoryLocally()
	State.InventoryChanged:Fire(State.Inventory)
end

local function hasAmmo(slot: Types.InventorySlot, spec: Spec): (boolean, boolean)
	local inv = State.Inventory
	if inv == nil then
		return false, false
	end
	if spec.SubType == "BOW" then
		if inv.UseFireArrows and inv.Ammo.FireArrows > 0 then
			return true, true
		end
		if inv.Ammo.Arrows > 0 then
			return true, false
		end
		return inv.Ammo.FireArrows > 0, inv.Ammo.FireArrows > 0
	elseif spec.SubType == "GUN" then
		return inv.Ammo.Bullets > 0, false
	end
	return slot.Count ~= 0, false
end

local function consumeLocally(slot: Types.InventorySlot, spec: Spec, fire: boolean)
	local inv = State.Inventory
	if inv == nil then
		return
	end
	if spec.SubType == "BOW" then
		if fire then
			inv.Ammo.FireArrows = math.max(0, inv.Ammo.FireArrows - 1)
		else
			inv.Ammo.Arrows = math.max(0, inv.Ammo.Arrows - 1)
		end
	elseif spec.SubType == "GUN" then
		inv.Ammo.Bullets = math.max(0, inv.Ammo.Bullets - 1)
	elseif slot.Count > 0 then
		slot.Count -= 1
	end
	pushInventoryLocally()
end

local function outOfAmmo()
	SoundCatalog.Play("UIClick", nil, 0)
	State.Notify:Fire("Out of ammo", "Error")
end

---------------------------------------------------------------------------------------------
-- Actions
---------------------------------------------------------------------------------------------
local function recoilFor(spec: Spec)
	local kick = 0.012
	if spec.Id == "Crossbow" then
		kick = 0.022
	elseif spec.Id == "Blunderbuss" then
		kick = 0.1
	elseif spec.Id == "Musket" then
		kick = 0.065
	elseif spec.SubType == "GUN" then
		kick = 0.05
	elseif spec.SubType == "THROWABLE" then
		kick = 0.008
	end
	State.Recoil:Fire(kick * 6, (math.random() - 0.5) * kick * 3)
	if spec.SubType == "GUN" then
		Camera.Shake(kick * 4)
	end
end

local function fireRanged(slotIndex: number, slot: Types.InventorySlot, spec: Spec, ratio: number)
	local head = headPosition()
	if head == nil or spec.ProjectileSpeed == nil then
		return
	end
	if slot.ItemId == "Chakram" then
		local character = State.Character()
		if character and character:GetAttribute("ChakramOut") == true then
			return
		end
	end
	local ok, fire = hasAmmo(slot, spec)
	if not ok then
		outOfAmmo()
		return
	end
	local aim = Camera.AimPoint()
	local dir = aim - head
	if dir.Magnitude < 0.1 then
		return
	end
	dir = dir.Unit
	local charged = spec.DrawTime ~= nil or spec.ChargeTime ~= nil
	local speedMult = if charged then (Ballistics.DrawScale(ratio)) else 1
	local speed = spec.ProjectileSpeed * speedMult
	local gravity = spec.GravityScale or 0
	local seed = math.random(1, 2147483646)
	local inv = State.Inventory :: Types.InventoryView
	Net.Reliable("FireProjectile"):FireServer({
		Slot = slotIndex,
		Origin = head,
		Direction = dir,
		Draw = ratio,
		ClientTime = now(),
		Seed = seed,
		UseFire = inv.UseFireArrows,
	})
	lastUse[slotIndex] = now()

	-- local prediction from the muzzle toward the same aim point
	local muzzle = muzzlePosition() or head
	local visualDir = (aim - muzzle)
	visualDir = if visualDir.Magnitude > 0.1 then visualDir.Unit else dir
	if spec.PelletCount then
		for _, d in Ballistics.PelletDirections(visualDir, spec.SpreadAngle or 8, spec.PelletCount, seed) do
			Renderer.Spawn({
				OwnerId = State.MyId(),
				ItemId = slot.ItemId,
				Body = "Bullet",
				Origin = muzzle,
				Velocity = d * speed,
				GravityScale = gravity,
				MaxAge = 0.6,
				Local = true,
			})
		end
	elseif slot.ItemId ~= "Chakram" then
		Renderer.SpawnLocal(slot.ItemId, muzzle, visualDir * speed, gravity, fire)
	end
	consumeLocally(slot, spec, fire)

	local root = State.Root()
	if spec.SubType == "BOW" then
		SoundCatalog.Play(if spec.Id == "Crossbow" then "CrossbowFire" else "BowRelease", root, 0.06)
	elseif spec.SubType == "GUN" then
		SoundCatalog.Play(if spec.PelletCount then "BlunderbussFire" else "GunFire", root, 0.05)
		VFX.Burst("BlockSpark", CFrame.lookAt(muzzle, muzzle + visualDir), 0.5)
	else
		SoundCatalog.Play("Throw", root, 0.1)
	end
	recoilFor(spec)
end

local function setTrail(model: Model?, seconds: number)
	if model == nil then
		return
	end
	local trail = model:FindFirstChild("SwingTrail", true)
	if trail and trail:IsA("Trail") then
		trail.Enabled = true
		trailOffAt[trail] = os.clock() + seconds
	end
end

local function swing(slotIndex: number, slot: Types.InventorySlot, spec: Spec, chargeRatio: number)
	local _, dir = Camera.AimRay()
	Net.Reliable("MeleeSwing"):FireServer({
		Slot = slotIndex,
		Direction = dir,
		ClientTime = now(),
		Charge = chargeRatio,
	})
	lastUse[slotIndex] = now()
	State.LocalSwing:Fire(slot.ItemId)
	local heavy = (spec.SwingRate or 0.5) >= 0.8
	SoundCatalog.Play(if heavy then "SwingHeavy" else "SwingLight", State.Root(), 0.1)
	local character = State.Character()
	local held = if character then character:FindFirstChild(EquipmentRig.HeldName) else nil
	setTrail(if held and held:IsA("Model") then held else nil, 0.3)
	local cam = Workspace.CurrentCamera
	local vm = if cam then cam:FindFirstChild("LocalViewmodel") else nil
	local vmWeapon = if vm then vm:FindFirstChild("Weapon") else nil
	setTrail(if vmWeapon and vmWeapon:IsA("Model") then vmWeapon else nil, 0.3)
	State.Recoil:Fire(if heavy then 0.05 else 0.02, (math.random() - 0.5) * 0.03)
end

local function throwUtility(slotIndex: number, slot: Types.InventorySlot)
	local head = headPosition()
	if head == nil or slot.Count == 0 then
		if slot.Count == 0 then
			outOfAmmo()
		end
		return
	end
	local _, dir = Camera.AimRay()
	Net.Reliable("UseUtility"):FireServer({
		Slot = slotIndex,
		Origin = head,
		Direction = dir,
		ClientTime = now(),
	})
	lastUse[slotIndex] = now()
	SoundCatalog.Play(if slot.ItemId == "Fireball" then "FireballWhoosh" else "Throw", State.Root(), 0.1)
	State.Recoil:Fire(0.03, 0)
end

local function placeUtility(slotIndex: number, slot: Types.InventorySlot)
	if hologramTarget == nil then
		State.Notify:Fire("Can't place that here", "Error")
		return
	end
	if slot.Count == 0 then
		outOfAmmo()
		return
	end
	Net.Reliable("UseUtility"):FireServer({ Slot = slotIndex, Target = hologramTarget, ClientTime = now() })
	lastUse[slotIndex] = now()
	SoundCatalog.Play("UIConfirm", State.Root(), 0.05)
end

local function cancelCharge()
	if charge then
		charge = nil
		State.Drawing = false
		State.DrawRatio = 0
		Net.Unreliable("ReplicateBowDrawRatio"):FireServer(0)
		lastDrawSent = 0
	end
end

local function setBlock(on: boolean)
	if blockSent ~= on then
		blockSent = on
		Net.Reliable("ToggleBlock"):FireServer(on)
	end
end

---------------------------------------------------------------------------------------------
-- Input entry points (called by InputAndKeybindController)
---------------------------------------------------------------------------------------------
function Weapon.PrimaryDown()
	primaryHeld = true
	if not canAct() then
		return
	end
	local slotIndex, slot, spec = equipped()
	if slot == nil or spec == nil then
		return
	end
	local itemId: string = slot.ItemId
	local castHeal = spec.Category == "HEALING" and not isLobbed(itemId)
	if castHeal then
		if slot.Count == 0 then
			outOfAmmo()
			return
		end
		Net.Reliable("StartHeal"):FireServer(slotIndex)
		return
	end
	if spec.SubType == "SHIELD" then
		setBlock(true)
		return
	end
	if not ready(slotIndex, spec) then
		return
	end
	if isPlaced(itemId) then
		placeUtility(slotIndex, slot)
	elseif itemId == "WarHorn" then
		Net.Reliable("UseUtility"):FireServer({ Slot = slotIndex, ClientTime = now() })
		lastUse[slotIndex] = now()
		SoundCatalog.Play("WarHorn", State.Root(), 0)
	elseif isLobbed(itemId) then
		charge = { Slot = slotIndex, Start = os.clock(), Time = 0, Kind = "Lob" }
	elseif spec.SubType == "MELEE" then
		if spec.ChargeTime then
			charge = { Slot = slotIndex, Start = os.clock(), Time = spec.ChargeTime, Kind = "Heavy" }
			State.Drawing = true
		else
			swing(slotIndex, slot, spec, 0)
		end
	elseif EquipmentDatabase.IsRanged(spec) then
		local chargeTime = spec.DrawTime or spec.ChargeTime
		if chargeTime then
			local ok = hasAmmo(slot, spec)
			if not ok then
				outOfAmmo()
				return
			end
			charge = { Slot = slotIndex, Start = os.clock(), Time = chargeTime, Kind = if spec.SubType == "BOW" then "Bow" else "Throw" }
			State.Drawing = true
			if spec.SubType == "BOW" then
				SoundCatalog.Play("BowDraw", State.Root(), 0.05)
			end
		else
			fireRanged(slotIndex, slot, spec, 1)
		end
	end
end

function Weapon.PrimaryUp()
	primaryHeld = false
	local _, _, spec = equipped()
	if spec and spec.SubType == "SHIELD" and not secondaryHeld then
		setBlock(false)
	end
	local c = charge
	if c == nil then
		return
	end
	local inv = State.Inventory
	local cSlot = if inv then inv.Slots[c.Slot] else nil
	local cSpec = if cSlot then EquipmentDatabase.Get(cSlot.ItemId) else nil
	local ratio = if c.Time > 0 then math.clamp((os.clock() - c.Start) / c.Time, 0, 1) else 1
	cancelCharge()
	if cSlot == nil or cSpec == nil or inv == nil or inv.Equipped ~= c.Slot or not canAct() then
		return
	end
	if c.Kind == "Lob" then
		throwUtility(c.Slot, cSlot)
	elseif c.Kind == "Heavy" then
		swing(c.Slot, cSlot, cSpec, ratio)
	elseif ratio >= 0.12 then
		fireRanged(c.Slot, cSlot, cSpec, ratio)
	end
end

function Weapon.SecondaryDown()
	secondaryHeld = true
	local _, _, spec = equipped()
	if spec == nil or not State.Alive() then
		return
	end
	if spec.CanBlock or spec.SubType == "SHIELD" then
		if canAct() then
			setBlock(true)
		end
	elseif EquipmentDatabase.IsRanged(spec) then
		State.Aiming = true
	end
end

function Weapon.SecondaryUp()
	secondaryHeld = false
	State.Aiming = false
	local _, _, spec = equipped()
	if not (primaryHeld and spec and spec.SubType == "SHIELD") then
		setBlock(false)
	end
end

function Weapon.Equip(index: number)
	local inv = State.Inventory
	if inv == nil or not State.Alive() or inv.Slots[index] == nil or inv.Equipped == index then
		return
	end
	cancelCharge()
	setBlock(false)
	State.Aiming = false
	inv.Equipped = index
	Net.Reliable("EquipSlot"):FireServer(index)
	pushInventoryLocally()
end

function Weapon.Cycle(direction: number)
	local inv = State.Inventory
	if inv == nil or #inv.Slots == 0 then
		return
	end
	local n = #inv.Slots
	local i = ((inv.Equipped - 1 + direction) % n) + 1
	Weapon.Equip(i)
end

function Weapon.ToggleFireArrows()
	local inv = State.Inventory
	if inv == nil then
		return
	end
	if inv.Ammo.FireArrows <= 0 and not inv.UseFireArrows then
		State.Notify:Fire("No fire arrows in this loadout", "Error")
		return
	end
	inv.UseFireArrows = not inv.UseFireArrows
	State.Notify:Fire(if inv.UseFireArrows then "Fire arrows ON" else "Fire arrows OFF", "Info")
	pushInventoryLocally()
end

function Weapon.CancelHeal()
	Net.Reliable("CancelHeal"):FireServer()
end

function Weapon.CatchChakram()
	Net.Reliable("CatchChakram"):FireServer()
end

function Weapon.CancelAll()
	primaryHeld = false
	secondaryHeld = false
	cancelCharge()
	setBlock(false)
	State.Aiming = false
end

---------------------------------------------------------------------------------------------
-- Previews: lob arc and placement hologram
---------------------------------------------------------------------------------------------
local function previewParent(): Instance
	return Workspace.CurrentCamera :: Camera
end

local function hideArc()
	for _, d in arcDots do
		d.Transparency = 1
	end
	if arcRing then
		arcRing.Transparency = 1
	end
end

local function ensureArc()
	if #arcDots > 0 and arcDots[1].Parent then
		return
	end
	table.clear(arcDots)
	for i = 1, 40 do
		local p = Instance.new("Part")
		p.Name = "ArcDot" .. i
		p.Shape = Enum.PartType.Ball
		p.Size = Vector3.new(0.22, 0.22, 0.22)
		p.Material = Enum.Material.Neon
		p.Color = Color3.fromRGB(255, 245, 210)
		p.Anchored = true
		p.CanCollide = false
		p.CanQuery = false
		p.CanTouch = false
		p.CastShadow = false
		p.Transparency = 1
		p.Parent = previewParent()
		table.insert(arcDots, p)
	end
	local ring = Instance.new("Part")
	ring.Name = "ArcLanding"
	ring.Shape = Enum.PartType.Cylinder
	ring.Size = Vector3.new(0.1, 4, 4)
	ring.Material = Enum.Material.Neon
	ring.Color = Color3.fromRGB(255, 200, 60)
	ring.Anchored = true
	ring.CanCollide = false
	ring.CanQuery = false
	ring.CanTouch = false
	ring.CastShadow = false
	ring.Transparency = 1
	ring.Parent = previewParent()
	arcRing = ring
end

local arcParams = RaycastParams.new()
arcParams.FilterType = Enum.RaycastFilterType.Exclude

local function updateArc(itemId: string)
	local spec = EquipmentDatabase.Get(itemId)
	local head = headPosition()
	if spec == nil or head == nil or spec.ProjectileSpeed == nil then
		hideArc()
		return
	end
	ensureArc()
	local _, dir = Camera.AimRay()
	local speed = spec.ProjectileSpeed
	-- same launch the server uses for lobbed utilities
	local velocity = dir * speed + Vector3.new(0, speed * 0.12, 0)
	local exclude: { Instance } = { previewParent() }
	local character = State.Character()
	if character then
		table.insert(exclude, character)
	end
	arcParams.FilterDescendantsInstances = exclude
	local points, hit = Ballistics.TraceArc(head, velocity, spec.GravityScale or 1, 3, 0.045, arcParams)
	for i, d in arcDots do
		local p = points[i + 1]
		if p then
			d.CFrame = CFrame.new(p)
			d.Transparency = 0.15 + 0.6 * (i / #arcDots)
		else
			d.Transparency = 1
		end
	end
	local ring = arcRing
	if ring then
		if hit then
			local radius = (spec.Radius or spec.SplashRadius or 6) * 2
			ring.Size = Vector3.new(0.1, radius, radius)
			ring.CFrame = CFrame.lookAt(hit.Position, hit.Position + hit.Normal) * CFrame.Angles(0, math.rad(90), 0)
			ring.Transparency = 0.55
			ring.Color = if itemId == "HealingFlask" then Color3.fromRGB(90, 230, 120) elseif itemId == "Fireball" then Color3.fromRGB(255, 120, 30) else Color3.fromRGB(200, 200, 210)
		else
			ring.Transparency = 1
		end
	end
end

local function destroyHologram()
	if hologram then
		hologram:Destroy()
	end
	hologram = nil
	hologramItem = nil
	hologramTarget = nil
end

local groundParams = RaycastParams.new()
groundParams.FilterType = Enum.RaycastFilterType.Exclude

local function updateHologram(itemId: string)
	local root = State.Root()
	if root == nil then
		destroyHologram()
		return
	end
	if hologram == nil or hologramItem ~= itemId then
		destroyHologram()
		local prefab = EquipmentRig.GetPrefab(itemId)
		if prefab == nil then
			return
		end
		local h = prefab:Clone()
		h.Name = "PlacementHologram"
		for _, d in h:GetDescendants() do
			if d:IsA("BasePart") then
				d.Anchored = true
				d.CanCollide = false
				d.CanQuery = false
				d.CanTouch = false
				d.CastShadow = false
				d.Material = Enum.Material.ForceField
				d.Transparency = 0
			elseif d:IsA("Decal") or d:IsA("Texture") or d:IsA("ParticleEmitter") or d:IsA("BaseScript") then
				d:Destroy()
			end
		end
		h.Parent = previewParent()
		hologram = h
		hologramItem = itemId
	end
	local aim = Camera.AimPoint()
	local offset = aim - root.Position
	local flatOffset = Vector3.new(offset.X, 0, offset.Z)
	if flatOffset.Magnitude > PLACE_RANGE then
		flatOffset = flatOffset.Unit * PLACE_RANGE
	end
	local exclude: { Instance } = { previewParent() }
	for _, p in Players:GetPlayers() do
		if p.Character then
			table.insert(exclude, p.Character)
		end
	end
	groundParams.FilterDescendantsInstances = exclude
	local probe = root.Position + flatOffset + Vector3.new(0, 4, 0)
	local hit = Workspace:Raycast(probe, Vector3.new(0, -14, 0), groundParams)
	local valid = hit ~= nil and hit.Normal.Y >= 0.7
	local look = Vector3.new(root.CFrame.LookVector.X, 0, root.CFrame.LookVector.Z)
	if look.Magnitude < 0.1 then
		look = Vector3.zAxis
	end
	local position = if hit then hit.Position else probe - Vector3.new(0, 4, 0)
	local h = hologram :: Model
	h:PivotTo(CFrame.lookAt(position, position + look.Unit) * CFrame.new(0, 0.08, 0))
	local color = if valid then Color3.fromRGB(70, 255, 120) else Color3.fromRGB(255, 60, 60)
	for _, d in h:GetDescendants() do
		if d:IsA("BasePart") then
			d.Color = color
		end
	end
	hologramTarget = if valid then root.Position + flatOffset else nil
end

---------------------------------------------------------------------------------------------
-- Per-frame
---------------------------------------------------------------------------------------------
local function updateStrings()
	-- bend the string of every visible bow from its owner's DrawRatio
	for _, model in Weapon.VisibleCharacters() do
		local held = model:FindFirstChild(EquipmentRig.HeldName)
		if held and held:IsA("Model") then
			local str = EquipmentRig.GetAttachment(held, "StringAttachment")
			local rest = if str then str:GetAttribute("RestZ") else nil
			local drawDistance = held:GetAttribute("DrawDistance")
			if str and type(rest) == "number" and type(drawDistance) == "number" then
				local ratioAttr = model:GetAttribute("DrawRatio")
				local ratio = if model == State.Character() then State.DrawRatio elseif type(ratioAttr) == "number" then ratioAttr else 0
				local last = stringState[str]
				if last == nil or math.abs(last - ratio) > 0.01 then
					stringState[str] = ratio
					local p = str.Position
					str.Position = Vector3.new(p.X, p.Y, rest + drawDistance * ratio)
				end
			end
		end
		-- swing trails for everyone else's swings (SwingAt changes)
		local swingAt = model:GetAttribute("SwingAt")
		if type(swingAt) == "number" and model ~= State.Character() and lastSwingSeen[model] ~= swingAt then
			lastSwingSeen[model] = swingAt
			if now() - swingAt < 0.5 then
				setTrail(if held and held:IsA("Model") then held else nil, 0.3)
			end
		end
	end
	local clock = os.clock()
	for trail, offAt in trailOffAt do
		if clock >= offAt or trail.Parent == nil then
			trail.Enabled = false
			trailOffAt[trail] = nil
		end
	end
	for str in stringState do
		if str.Parent == nil then
			stringState[str] = nil
		end
	end
	for model in lastSwingSeen do
		if model.Parent == nil then
			lastSwingSeen[model] = nil
		end
	end
end

local visibleCache: { Model } = {}
local visibleAt = 0

function Weapon.VisibleCharacters(): { Model }
	if os.clock() - visibleAt < 0.5 then
		return visibleCache
	end
	visibleAt = os.clock()
	local list: { Model } = {}
	for _, p in Players:GetPlayers() do
		if p.Character then
			table.insert(list, p.Character)
		end
	end
	local runtime = Workspace:FindFirstChild("Runtime_Dynamic_Containers")
	if runtime then
		for _, name in { "AliveCharacters_Alpha", "AliveCharacters_Bravo" } do
			local f = runtime:FindFirstChild(name)
			if f then
				for _, m in f:GetChildren() do
					if m:IsA("Model") and not table.find(list, m) then
						table.insert(list, m)
					end
				end
			end
		end
	end
	visibleCache = list
	return list
end

local function step(dt: number)
	Renderer.Step(dt)
	updateStrings()

	local slotIndex, slot, spec = equipped()
	local acting = canAct()

	-- charging / drawing
	local c = charge
	if c then
		if not acting or slotIndex ~= c.Slot then
			cancelCharge()
		else
			local ratio = if c.Time > 0 then math.clamp((os.clock() - c.Start) / c.Time, 0, 1) else 0
			if c.Kind ~= "Lob" then
				State.DrawRatio = ratio
				State.Drawing = true
				local t = os.clock()
				if math.abs(ratio - lastDrawSent) >= 0.1 and t - lastDrawSendAt > 0.1 then
					lastDrawSent = ratio
					lastDrawSendAt = t
					Net.Unreliable("ReplicateBowDrawRatio"):FireServer(ratio)
				end
			end
		end
	end

	-- held LMB repeats light melee swings and quick throws
	if primaryHeld and acting and charge == nil and slot and spec and ready(slotIndex, spec) then
		if (spec.SubType == "MELEE" and spec.ChargeTime == nil) then
			swing(slotIndex, slot, spec, 0)
		elseif slot.ItemId == "ThrowingKnives" or slot.ItemId == "Bolas" then
			fireRanged(slotIndex, slot, spec, 1)
		end
	end

	-- previews
	local showArc = acting and charge ~= nil and charge.Kind == "Lob" and slot ~= nil
	if showArc and slot then
		updateArc(slot.ItemId)
	else
		hideArc()
	end
	if acting and slot and isPlaced(slot.ItemId) then
		updateHologram(slot.ItemId)
	elseif hologram then
		destroyHologram()
	end

	-- blocking ends if the weapon changes or we can no longer act
	if blockSent and (not acting or spec == nil or not (spec.CanBlock or spec.SubType == "SHIELD")) then
		setBlock(false)
	end
	if State.Aiming and (spec == nil or not EquipmentDatabase.IsRanged(spec) or not State.Alive()) then
		State.Aiming = false
	end

	-- aim pitch replication
	if State.InCombat() and State.Alive() and os.clock() - lastPitchSendAt >= 0.05 then
		lastPitchSendAt = os.clock()
		Net.Unreliable("ReplicateCharacterState"):FireServer(Camera.Pitch())
	end
end

function Weapon.Init() end

function Weapon.Start()
	Renderer.Start()
	Poses.SetOwnPitchSource(Camera.Pitch)
	Poses.Start()
	State.InventoryChanged:Connect(function(view)
		if view == nil then
			Weapon.CancelAll()
			destroyHologram()
			hideArc()
			table.clear(lastUse)
		end
	end)
	State.MenuChanged:Connect(function(open: boolean)
		if open then
			Weapon.CancelAll()
		end
	end)
	player.CharacterAdded:Connect(function()
		Weapon.CancelAll()
		destroyHologram()
	end)
	RunService:BindToRenderStep("TribesWeapons", Enum.RenderPriority.Camera.Value + 2, step)
end

return Weapon
