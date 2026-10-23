--!strict
-- EconomyAndMonetizationService: victory chest drops, shard unlocks/upgrades, match settlement
-- (XP, win streak, Glory RP) and Developer Product receipts.
--   GenerateVictoryDrop: 4 weighted item cards sharing 23-25 shards on a win (12-14 on a loss).
--   New players (< 10 matches) are steered toward the cheapest locked unlocks.
--   ProcessReceipt: 10 R$ Golden Drop (~60 shards + a guaranteed locked weapon unlock),
--   20/39/79 R$ Restore Streak (LastLostStreak -> WinStreak), 399/599/799 R$ Item Unlock,
--   299 R$ Tribe creation. Receipts are idempotent through Profile.ProcessedReceipts.

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local Modules = game:GetService("ReplicatedStorage"):WaitForChild("Modules")
local Types = require(Modules.Shared.Types)
local Net = require(Modules.Shared.Net)
local Signal = require(Modules.Shared.Signal)
local GameConfig = require(Modules.Config.GameConfig)
local EquipmentDatabase = require(Modules.Config.EquipmentDatabase)
local UpgradeScalingMath = require(Modules.Config.UpgradeScalingMath)
local MonetizationCatalog = require(Modules.Config.MonetizationCatalog)

local PlayerData = require(script.Parent.PlayerDataService)

type Profile = Types.Profile
type DropCard = Types.DropCard

local Economy = {}

Economy.TribeCreationPurchased = Signal.new() :: Signal.Signal<Player>
Economy.GloryAwarded = Signal.new() :: Signal.Signal<Player, number>

local pendingDrops: { [Player]: { Cards: { DropCard }, Total: number, Kind: string } } = {}
local pendingUnlock: { [Player]: string } = {}
local rng = Random.new()

local MAX_RECEIPTS = 100

---------------------------------------------------------------------------------------------
-- Shards, unlocks and upgrades
---------------------------------------------------------------------------------------------
local function isLockable(spec: Types.EquipmentSpec): boolean
	return spec.UnlockShards ~= nil and spec.RankedOnly ~= true
end

local function upgradeReady(profile: Profile, itemId: string): boolean
	local level = profile.UnlockedItems[itemId]
	if level == nil then
		return false
	end
	return UpgradeScalingMath.CanUpgrade(level, profile.Shards[itemId] or 0)
end

-- Add shards; auto-unlocks a locked item once its UnlockShards threshold is reached.
local function grantShards(profile: Profile, itemId: string, amount: number): DropCard
	local spec = EquipmentDatabase.Get(itemId)
	profile.Shards[itemId] = (profile.Shards[itemId] or 0) + amount
	local newUnlock = false
	if spec and isLockable(spec) and profile.UnlockedItems[itemId] == nil then
		local need = spec.UnlockShards :: number
		if (profile.Shards[itemId] or 0) >= need then
			profile.Shards[itemId] -= need
			profile.UnlockedItems[itemId] = 1
			newUnlock = true
		end
	end
	return {
		ItemId = itemId,
		Shards = amount,
		NewUnlock = newUnlock,
		UpgradeReady = upgradeReady(profile, itemId),
	}
end

local function pickWeighted(pool: { { Id: string, Weight: number } }, count: number): { string }
	local picked: { string } = {}
	local list = table.clone(pool)
	for _ = 1, count do
		local total = 0
		for _, e in list do
			total += e.Weight
		end
		if total <= 0 or #list == 0 then
			break
		end
		local r = rng:NextNumber() * total
		for i, e in list do
			r -= e.Weight
			if r <= 0 then
				table.insert(picked, e.Id)
				table.remove(list, i)
				break
			end
		end
	end
	return picked
end

local function dropPool(profile: Profile): { { Id: string, Weight: number } }
	local active = profile.Presets[profile.ActivePreset]
	local inActive: { [string]: boolean } = {}
	if active then
		for _, id in active.Slots do
			inActive[id] = true
		end
		if active.Armor then
			inActive[active.Armor] = true
		end
	end
	local newPlayer = profile.MatchesPlayed < 10
	local pool: { { Id: string, Weight: number } } = {}
	for _, id in EquipmentDatabase.Order do
		local spec = EquipmentDatabase.Items[id]
		if spec.RankedOnly ~= true then
			local level = profile.UnlockedItems[id]
			local weight = 0
			if level == nil then
				if isLockable(spec) then
					weight = 3
					if newPlayer then
						-- early unlocks first: cheaper unlocks are much more likely
						weight = 6 * (30 / math.max(10, spec.UnlockShards :: number))
					end
				end
			elseif level < UpgradeScalingMath.MaxLevel then
				weight = if inActive[id] then 3 else 1
			end
			if weight > 0 then
				table.insert(pool, { Id = id, Weight = weight })
			end
		end
	end
	return pool
end

-- Split `total` into `n` positive integer shares, largest first (flip order x3 -> x2 -> x1).
local function splitShares(total: number, n: number): { number }
	local weights: { number } = {}
	local sum = 0
	for i = 1, n do
		local w = rng:NextNumber(0.6, 1.4) * (n - i + 1)
		weights[i] = w
		sum += w
	end
	local shares: { number } = {}
	local assigned = 0
	for i = 1, n do
		local s = math.max(1, math.floor(total * weights[i] / sum))
		shares[i] = s
		assigned += s
	end
	shares[1] += total - assigned
	table.sort(shares, function(a, b)
		return a > b
	end)
	return shares
end

function Economy.GenerateVictoryDrop(player: Player, won: boolean): ({ DropCard }, number)
	local profile = PlayerData.Get(player)
	if profile == nil then
		return {}, 0
	end
	local R = GameConfig.Rewards
	local total = if won then rng:NextInteger(R.WinShardsMin, R.WinShardsMax) else rng:NextInteger(R.LossShardsMin, R.LossShardsMax)
	local items = pickWeighted(dropPool(profile), R.DropCards)
	if #items == 0 then
		return {}, 0
	end
	local shares = splitShares(total, #items)
	local cards: { DropCard } = {}
	for i, id in items do
		table.insert(cards, grantShards(profile, id, shares[i]))
	end
	pendingDrops[player] = { Cards = cards, Total = total, Kind = "Victory" }
	PlayerData.MarkChanged(player)
	return cards, total
end

function Economy.GoldenDrop(player: Player): ({ DropCard }, number)
	local profile = PlayerData.Get(player)
	if profile == nil then
		return {}, 0
	end
	local cards: { DropCard } = {}
	-- guaranteed unlock of a locked weapon
	local locked: { string } = {}
	for _, id in EquipmentDatabase.Order do
		local spec = EquipmentDatabase.Items[id]
		if spec.Category == "WEAPONS" and isLockable(spec) and profile.UnlockedItems[id] == nil then
			table.insert(locked, id)
		end
	end
	local total = MonetizationCatalog.GoldenDropShards
	if #locked > 0 then
		local id = locked[rng:NextInteger(1, #locked)]
		profile.UnlockedItems[id] = 1
		table.insert(cards, { ItemId = id, Shards = 0, NewUnlock = true, UpgradeReady = upgradeReady(profile, id) })
	end
	local items = pickWeighted(dropPool(profile), GameConfig.Rewards.DropCards - #cards)
	local shares = splitShares(total, math.max(1, #items))
	for i, id in items do
		table.insert(cards, grantShards(profile, id, shares[i]))
	end
	profile.GoldenDropPurchased = true
	pendingDrops[player] = { Cards = cards, Total = total, Kind = "Golden" }
	PlayerData.MarkChanged(player)
	return cards, total
end

function Economy.Upgrade(player: Player, itemId: string): (boolean, string)
	local profile = PlayerData.Get(player)
	local spec = EquipmentDatabase.Get(itemId)
	if profile == nil or spec == nil then
		return false, "Unknown item"
	end
	local level = profile.UnlockedItems[itemId]
	local shards = profile.Shards[itemId] or 0
	if level == nil then
		if not isLockable(spec) then
			return false, "Unlocked through Glory"
		end
		local need = spec.UnlockShards :: number
		if shards < need then
			return false, string.format("Need %d shards", need)
		end
		profile.Shards[itemId] = shards - need
		profile.UnlockedItems[itemId] = 1
		PlayerData.MarkChanged(player)
		return true, spec.DisplayName .. " unlocked!"
	end
	local need = UpgradeScalingMath.ShardsForNextLevel(level)
	if need == nil then
		return false, "Max level"
	end
	if shards < need then
		return false, string.format("Need %d shards", need)
	end
	profile.Shards[itemId] = shards - need
	profile.UnlockedItems[itemId] = level + 1
	PlayerData.MarkChanged(player)
	return true, string.format("%s upgraded to Lv %d", spec.DisplayName, level + 1)
end

---------------------------------------------------------------------------------------------
-- Match settlement
---------------------------------------------------------------------------------------------
export type SettleInput = {
	Won: boolean,
	Kills: number,
	Deaths: number,
	Assists: number,
	IsMvp: boolean,
	Ranked: boolean,
}

export type SettleResult = {
	XPBreakdown: { { Label: string, Amount: number } },
	LevelBefore: number,
	LevelAfter: number,
	XPBefore: number,
	XPAfter: number,
	XPNeeded: number,
	GloryDelta: number,
}

function Economy.Settle(player: Player, input: SettleInput): SettleResult?
	local profile = PlayerData.Get(player)
	if profile == nil then
		return nil
	end
	local R = GameConfig.Rewards
	local breakdown: { { Label: string, Amount: number } } = {}
	local function add(label: string, amount: number)
		if amount > 0 then
			table.insert(breakdown, { Label = label, Amount = amount })
		end
	end
	add(if input.Won then "Victory" else "Match played", if input.Won then R.XPWin else R.XPLoss)
	add(string.format("Eliminations x%d", input.Kills), input.Kills * R.XPPerKill)
	add(string.format("Assists x%d", input.Assists), input.Assists * R.XPPerAssist)
	if input.IsMvp then
		add("MVP", R.XPMvp)
	end

	-- streaks
	local gloryDelta = 0
	if input.Won then
		profile.WinStreak += 1
		profile.BestStreak = math.max(profile.BestStreak, profile.WinStreak)
		profile.Wins += 1
		add(string.format("Win streak x%d", profile.WinStreak), (profile.WinStreak - 1) * R.XPStreakBonus)
		if input.Ranked then
			gloryDelta = R.GloryWin + (profile.WinStreak - 1) * R.GloryStreakBonus
		end
	else
		if profile.WinStreak > 0 then
			profile.LastLostStreak = profile.WinStreak
		end
		profile.WinStreak = 0
		profile.Losses += 1
		if input.Ranked then
			gloryDelta = -R.GloryLoss
		end
	end
	profile.GloryRP = math.max(0, profile.GloryRP + gloryDelta)
	if gloryDelta > 0 then
		Economy.GloryAwarded:Fire(player, gloryDelta)
	end
	profile.Kills += input.Kills
	profile.Deaths += input.Deaths
	profile.MatchesPlayed += 1

	local total = 0
	for _, e in breakdown do
		total += e.Amount
	end
	local levelBefore, xpBefore = profile.Level, profile.XP
	profile.XP += total
	while profile.XP >= UpgradeScalingMath.XPForLevel(profile.Level) do
		profile.XP -= UpgradeScalingMath.XPForLevel(profile.Level)
		profile.Level += 1
	end
	player:SetAttribute("Level", profile.Level)
	player:SetAttribute("GloryRP", profile.GloryRP)
	PlayerData.MarkChanged(player)
	return {
		XPBreakdown = breakdown,
		LevelBefore = levelBefore,
		LevelAfter = profile.Level,
		XPBefore = xpBefore,
		XPAfter = profile.XP,
		XPNeeded = UpgradeScalingMath.XPForLevel(profile.Level),
		GloryDelta = gloryDelta,
	}
end

---------------------------------------------------------------------------------------------
-- Developer Products
---------------------------------------------------------------------------------------------
local function grant(player: Player, product: MonetizationCatalog.Product): boolean
	local profile = PlayerData.Get(player)
	if profile == nil then
		return false
	end
	if product.Kind == "GoldenDrop" then
		local cards, total = Economy.GoldenDrop(player)
		Net.Reliable("OpenVictoryChest"):FireClient(player, { Kind = "Golden", Cards = cards, Total = total })
	elseif product.Kind == "RestoreStreak" then
		if profile.LastLostStreak > 0 then
			profile.WinStreak = profile.LastLostStreak
			profile.BestStreak = math.max(profile.BestStreak, profile.WinStreak)
			profile.LastLostStreak = 0
			PlayerData.Notify(player, string.format("Win streak restored to %d!", profile.WinStreak), "Success")
		end
	elseif product.Kind == "ItemUnlock" then
		local itemId: string? = pendingUnlock[player]
		local spec = if itemId then EquipmentDatabase.Get(itemId) else nil
		if spec == nil or spec.RobuxCost ~= product.Tier or profile.UnlockedItems[itemId :: string] ~= nil then
			-- fall back to the cheapest locked item of this price tier
			itemId = nil
			for _, id in EquipmentDatabase.Order do
				local s = EquipmentDatabase.Items[id]
				if s.RobuxCost == product.Tier and isLockable(s) and profile.UnlockedItems[id] == nil then
					itemId = id
					break
				end
			end
		end
		if itemId then
			profile.UnlockedItems[itemId] = profile.UnlockedItems[itemId] or 1
			local s = EquipmentDatabase.Get(itemId)
			PlayerData.Notify(player, (if s then s.DisplayName else itemId) .. " unlocked!", "Success")
		else
			-- nothing left to unlock at this tier: convert to shards for owned items
			Economy.GoldenDrop(player)
		end
		pendingUnlock[player] = nil
	elseif product.Kind == "TribeCreation" then
		Economy.TribeCreationPurchased:Fire(player)
	end
	PlayerData.MarkChanged(player)
	return true
end

local function processReceipt(receipt: { [string]: any }): Enum.ProductPurchaseDecision
	local player = Players:GetPlayerByUserId(receipt.PlayerId)
	if player == nil then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	local profile = PlayerData.WaitFor(player, 10)
	if profile == nil then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	local purchaseId = tostring(receipt.PurchaseId)
	if table.find(profile.ProcessedReceipts, purchaseId) then
		return Enum.ProductPurchaseDecision.PurchaseGranted
	end
	local product = MonetizationCatalog.ByProductId(receipt.ProductId)
	if product == nil then
		warn("[Economy] receipt for unknown product", receipt.ProductId)
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	if not grant(player, product) then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	table.insert(profile.ProcessedReceipts, purchaseId)
	while #profile.ProcessedReceipts > MAX_RECEIPTS do
		table.remove(profile.ProcessedReceipts, 1)
	end
	if not PlayerData.Save(player) then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	return Enum.ProductPurchaseDecision.PurchaseGranted
end

local function onPurchaseRequest(player: Player, key: any, itemId: any)
	if type(key) ~= "string" then
		return
	end
	local profile = PlayerData.Get(player)
	if profile == nil then
		return
	end
	local product: MonetizationCatalog.Product? = nil
	if key == "RestoreStreak" then
		if profile.LastLostStreak <= 0 then
			PlayerData.Notify(player, "No lost streak to restore", "Error")
			return
		end
		product = MonetizationCatalog.RestoreTierFor(profile.LastLostStreak)
	elseif key == "ItemUnlock" then
		local spec = if type(itemId) == "string" then EquipmentDatabase.Get(itemId) else nil
		if spec == nil or spec.RobuxCost == nil or profile.UnlockedItems[spec.Id] ~= nil then
			return
		end
		product = MonetizationCatalog.UnlockProductFor(spec.RobuxCost)
		pendingUnlock[player] = spec.Id
	else
		product = MonetizationCatalog.ByKey(key)
	end
	if product == nil then
		return
	end
	if not MonetizationCatalog.IsConfigured(product) then
		if RunService:IsStudio() then
			-- Studio test path: product IDs are not created yet, grant directly
			grant(player, product)
			PlayerData.Notify(player, "[Studio] " .. product.DisplayName .. " granted (ProductId not configured)", "Info")
		else
			PlayerData.Notify(player, product.DisplayName .. " is not available yet", "Error")
		end
		return
	end
	MarketplaceService:PromptProductPurchase(player, product.ProductId)
end

local function onOpenChest(player: Player)
	local pending = pendingDrops[player]
	if pending then
		Net.Reliable("OpenVictoryChest"):FireClient(player, { Kind = pending.Kind, Cards = pending.Cards, Total = pending.Total })
	end
end

local function onUpgrade(player: Player, itemId: any)
	if type(itemId) ~= "string" then
		return
	end
	local ok, message = Economy.Upgrade(player, itemId)
	PlayerData.Notify(player, message, if ok then "Success" else "Error")
	Net.Reliable("UpgradeEquipment"):FireClient(player, ok, itemId)
end

function Economy.Start()
	MarketplaceService.ProcessReceipt = processReceipt
	Net.Reliable("PurchaseRequest").OnServerEvent:Connect(onPurchaseRequest)
	Net.Reliable("OpenVictoryChest").OnServerEvent:Connect(onOpenChest)
	Net.Reliable("UpgradeEquipment").OnServerEvent:Connect(onUpgrade)
	Players.PlayerRemoving:Connect(function(player)
		pendingDrops[player] = nil
		pendingUnlock[player] = nil
	end)
end

return Economy
