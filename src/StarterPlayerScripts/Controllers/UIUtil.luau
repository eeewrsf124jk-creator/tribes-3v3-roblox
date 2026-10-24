--!strict
-- UIUtil: typed lookups into the generated ScreenGuis plus the small helpers every controller
-- shares (item glyphs, rarity colours, tweens, template cloning, toasts, time formatting).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local UIKit = require(ReplicatedStorage:WaitForChild("BuilderModules"):WaitForChild("Kit"):WaitForChild("UIKit"))
local Types = require(ReplicatedStorage:WaitForChild("Modules").Shared.Types)
local SoundCatalog = require(ReplicatedStorage.Modules.Config.SoundCatalog)

local UIUtil = {}

UIUtil.Theme = UIKit.Theme

local player = Players.LocalPlayer

function UIUtil.Gui(name: string): ScreenGui
	local playerGui = player:WaitForChild("PlayerGui")
	local gui = playerGui:WaitForChild(name, 30)
	assert(gui and gui:IsA("ScreenGui"), "ScreenGui missing: " .. name)
	return gui
end

function UIUtil.Find(root: Instance, path: string): Instance?
	local node: Instance? = root
	for segment in string.gmatch(path, "[^/]+") do
		if node == nil then
			return nil
		end
		node = (node :: Instance):FindFirstChild(segment)
	end
	return node
end

function UIUtil.Get(root: Instance, path: string): Instance
	return UIKit.Get(root, path)
end

function UIUtil.Label(root: Instance, path: string): TextLabel
	local inst = UIKit.Get(root, path)
	assert(inst:IsA("TextLabel"), path .. " is not a TextLabel")
	return inst
end

function UIUtil.Button(root: Instance, path: string): TextButton
	local inst = UIKit.Get(root, path)
	assert(inst:IsA("TextButton"), path .. " is not a TextButton")
	return inst
end

function UIUtil.Box(root: Instance, path: string): TextBox
	local inst = UIKit.Get(root, path)
	assert(inst:IsA("TextBox"), path .. " is not a TextBox")
	return inst
end

function UIUtil.Frame(root: Instance, path: string): GuiObject
	local inst = UIKit.Get(root, path)
	assert(inst:IsA("GuiObject"), path .. " is not a GuiObject")
	return inst
end

function UIUtil.Tween(inst: Instance, time: number, props: { [string]: any }, style: Enum.EasingStyle?, direction: Enum.EasingDirection?): Tween
	local tween = TweenService:Create(inst, TweenInfo.new(time, style or Enum.EasingStyle.Quad, direction or Enum.EasingDirection.Out), props)
	tween:Play()
	return tween
end

-- Clone a hidden template next to itself; clones are tagged so ClearClones can remove them.
function UIUtil.CloneTemplate<T>(template: T & GuiObject, name: string?): T & GuiObject
	local clone = (template :: GuiObject):Clone() :: any
	clone.Name = name or (template :: GuiObject).Name .. "_Clone"
	clone.Visible = true
	clone:SetAttribute("UIClone", true)
	clone.Parent = (template :: GuiObject).Parent
	return clone
end

function UIUtil.ClearClones(container: Instance)
	for _, child in container:GetChildren() do
		if child:GetAttribute("UIClone") == true then
			child:Destroy()
		end
	end
end

function UIUtil.SetFill(fill: GuiObject, ratio: number, tweenTime: number?)
	local target = UDim2.fromScale(math.clamp(ratio, 0, 1), 1)
	if tweenTime and tweenTime > 0 then
		UIUtil.Tween(fill, tweenTime, { Size = target })
	else
		fill.Size = target
	end
end

function UIUtil.FormatTime(seconds: number): string
	local s = math.max(0, math.ceil(seconds))
	return string.format("%d:%02d", s // 60, s % 60)
end

function UIUtil.Click()
	SoundCatalog.Play("UIClick", nil, 0.02)
end

local GLYPHS: { [string]: string } = {
	WoodBow = "🏹",
	Crossbow = "🎯",
	Headhunter = "🦅",
	Flintlock = "🔫",
	Blunderbuss = "💥",
	Musket = "🎖",
	Sling = "🪨",
	ThrowingKnives = "🔪",
	Javelins = "🔱",
	Chakram = "⭕",
	Bolas = "🪢",
	Harpoon = "🪝",
	DiamondDagger = "🗡",
	IronSword = "⚔",
	Hammer = "🔨",
	BattleAxe = "🪓",
	Spear = "🦯",
	Shield = "🛡",
	Katana = "🗾",
	Scythe = "☠",
	Gauntlets = "🥊",
	TwinHatchets = "⚒",
	SmokeBomb = "💨",
	SnapTrap = "🪤",
	Palisade = "🧱",
	WarHorn = "📯",
	Fireball = "🔥",
	Bandage = "🩹",
	Apple = "🍎",
	HealingFlask = "🧪",
	GoldenApple = "🍏",
	LeatherArmor = "🦺",
	IronArmor = "🛡",
	DiamondArmor = "💎",
}

function UIUtil.Glyph(itemId: string): string
	return GLYPHS[itemId] or "◆"
end

-- Rarity colour by loadout cost; ranked melees are always red.
function UIUtil.RarityColor(spec: Types.EquipmentSpec?): Color3
	if spec == nil then
		return UIKit.Theme.Stroke
	end
	if spec.RankedOnly then
		return Color3.fromRGB(235, 60, 60)
	end
	if spec.Cost >= 5 then
		return Color3.fromRGB(255, 190, 40)
	elseif spec.Cost == 4 then
		return Color3.fromRGB(180, 90, 255)
	elseif spec.Cost == 3 then
		return Color3.fromRGB(70, 150, 255)
	elseif spec.Cost == 2 then
		return Color3.fromRGB(80, 210, 110)
	end
	return Color3.fromRGB(200, 200, 210)
end

function UIUtil.TeamColor(team: string): Color3
	if team == "Alpha" then
		return UIKit.Theme.Alpha
	elseif team == "Bravo" then
		return UIKit.Theme.Bravo
	end
	return UIKit.Theme.SubText
end

-- "Map_01_WinterTimberFort" -> "WINTER TIMBER FORT"
function UIUtil.PrettyMap(mapName: string): string
	local base = string.gsub(mapName, "^Map_%d+_", "")
	local spaced = string.gsub(base, "(%l)(%u)", "%1 %2")
	return string.upper(spaced)
end

local TOAST_COLORS: { [string]: Color3 } = {
	Info = UIKit.Theme.Gold,
	Success = UIKit.Theme.Good,
	Error = UIKit.Theme.Bad,
}

-- Toasts live in LobbyHUD/Toasts, which stays visible in every phase.
function UIUtil.Toast(text: string, kind: string?)
	local playerGui = player:FindFirstChildOfClass("PlayerGui")
	local hud = if playerGui then playerGui:FindFirstChild("LobbyHUD") else nil
	local template = if hud then UIUtil.Find(hud, "Toasts/ToastTemplate") else nil
	if template == nil or not template:IsA("Frame") then
		return
	end
	local toasts = template.Parent :: Instance
	local live = 0
	for _, child in toasts:GetChildren() do
		if child:GetAttribute("UIClone") == true then
			live += 1
		end
	end
	if live >= 4 then
		for _, child in toasts:GetChildren() do
			if child:GetAttribute("UIClone") == true then
				child:Destroy()
				break
			end
		end
	end
	local toast = UIUtil.CloneTemplate(template, "Toast")
	toast.LayoutOrder = math.floor(os.clock() * 100) % 1000000
	local message = toast:FindFirstChild("Message")
	if message and message:IsA("TextLabel") then
		message.Text = text
	end
	local stroke = toast:FindFirstChildOfClass("UIStroke")
	if stroke then
		stroke.Color = TOAST_COLORS[kind or "Info"] or UIKit.Theme.Gold
	end
	toast.BackgroundTransparency = 1
	UIUtil.Tween(toast, 0.2, { BackgroundTransparency = 0.15 })
	task.delay(3.2, function()
		if toast.Parent then
			UIUtil.Tween(toast, 0.35, { BackgroundTransparency = 1 })
			if message and message:IsA("TextLabel") then
				UIUtil.Tween(message, 0.35, { TextTransparency = 1 })
			end
			task.wait(0.4)
			toast:Destroy()
		end
	end)
end

return UIUtil
