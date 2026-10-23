--!strict
-- TribeService: player clans ("Tribes") stored in DataStores.
--   Tribes3v3_Tribes_v1      tribe_<id> -> TribeRecord, tag_<TAG> -> id
--   Tribes3v3_TribeGlory_W<n> (OrderedDataStore) weekly Glory per tribe for the TOP TRIBES board
-- Founding costs the TribeCreation Developer Product when it is configured, otherwise it is free.
-- Members earn weekly Glory for their tribe from ranked wins.

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local TextService = game:GetService("TextService")
local HttpService = game:GetService("HttpService")

local Modules = game:GetService("ReplicatedStorage"):WaitForChild("Modules")
local Net = require(Modules.Shared.Net)
local MonetizationCatalog = require(Modules.Config.MonetizationCatalog)

local PlayerData = require(script.Parent.PlayerDataService)
local Economy = require(script.Parent.EconomyAndMonetizationService)

local Tribes = {}

export type TribeRecord = {
	Id: string,
	Name: string,
	Tag: string,
	Leader: number,
	Members: { [string]: string }, -- userId -> display name
	WeeklyGlory: number,
	Week: number,
	TotalGlory: number,
	Created: number,
}

export type TribeView = {
	Id: string,
	Name: string,
	Tag: string,
	Leader: number,
	MemberCount: number,
	Members: { { UserId: number, Name: string } },
	WeeklyGlory: number,
	TotalGlory: number,
}

local MAX_MEMBERS = 20
local store: DataStore? = nil
local memory: { [string]: any } = {} -- fallback when DataStores are unavailable (Studio)
local memoryGlory: { [string]: number } = {}
local pendingCreate: { [Player]: { Name: string, Tag: string } } = {}

function Tribes.Week(): number
	-- weeks since the Unix epoch, rolling over on Thursday 00:00 UTC
	return math.floor(os.time() / 604800)
end

local function gloryStore(): OrderedDataStore?
	local ok, result = pcall(function()
		return DataStoreService:GetOrderedDataStore("Tribes3v3_TribeGlory_W" .. Tribes.Week())
	end)
	return if ok then result else nil
end

local function get(key: string): any
	local ds = store
	if ds == nil then
		return memory[key]
	end
	local ok, value = pcall(function()
		return ds:GetAsync(key)
	end)
	return if ok then value else nil
end

local function update(key: string, fn: (any) -> any): any
	local ds = store
	if ds == nil then
		local nextValue = fn(memory[key])
		if nextValue ~= nil then
			memory[key] = nextValue
		end
		return memory[key]
	end
	local result: any = nil
	local ok, err = pcall(function()
		result = ds:UpdateAsync(key, function(old: any): any
			return fn(old)
		end)
	end)
	if not ok then
		warn("[Tribes] update failed", key, err)
	end
	return result
end

local function remove(key: string)
	local ds = store
	if ds == nil then
		memory[key] = nil
		return
	end
	pcall(function()
		ds:RemoveAsync(key)
	end)
end

local function view(r: TribeRecord): TribeView
	local members = {}
	local count = 0
	for uid, name in r.Members do
		count += 1
		table.insert(members, { UserId = tonumber(uid) or 0, Name = name })
	end
	return {
		Id = r.Id,
		Name = r.Name,
		Tag = r.Tag,
		Leader = r.Leader,
		MemberCount = count,
		Members = members,
		WeeklyGlory = if r.Week == Tribes.Week() then r.WeeklyGlory else 0,
		TotalGlory = r.TotalGlory,
	}
end

local function send(player: Player, kind: string, payload: any)
	Net.Reliable("TribeAction"):FireClient(player, kind, payload)
end

local function filterText(player: Player, text: string): string?
	local ok, result = pcall(function()
		local filtered = TextService:FilterStringAsync(text, player.UserId, Enum.TextFilterContext.PublicChat)
		return filtered:GetNonChatStringForBroadcastAsync()
	end)
	if not ok or result ~= text then
		return nil
	end
	return result
end

function Tribes.Get(id: string): TribeRecord?
	local r = get("tribe_" .. id)
	if type(r) == "table" then
		return r :: TribeRecord
	end
	return nil
end

local function syncMine(player: Player)
	local profile = PlayerData.Get(player)
	local record = if profile and profile.TribeId then Tribes.Get(profile.TribeId) else nil
	if profile and profile.TribeId and record == nil then
		profile.TribeId = nil
		PlayerData.MarkChanged(player)
	end
	player:SetAttribute("TribeTag", if record then record.Tag else nil)
	send(player, "Mine", if record then view(record) else nil)
end

local function create(player: Player, name: string, tag: string)
	local profile = PlayerData.Get(player)
	if profile == nil then
		return
	end
	if profile.TribeId then
		send(player, "Status", "Leave your tribe first")
		return
	end
	local id = string.sub(HttpService:GenerateGUID(false), 1, 10)
	local claimed = false
	update("tag_" .. tag, function(old: any): any
		if old ~= nil then
			return nil
		end
		claimed = true
		return id
	end)
	if not claimed then
		send(player, "Status", "Tag [" .. tag .. "] is taken")
		return
	end
	local record: TribeRecord = {
		Id = id,
		Name = name,
		Tag = tag,
		Leader = player.UserId,
		Members = { [tostring(player.UserId)] = player.DisplayName },
		WeeklyGlory = 0,
		Week = Tribes.Week(),
		TotalGlory = 0,
		Created = os.time(),
	}
	update("tribe_" .. id, function(): any
		return record
	end)
	profile.TribeId = id
	PlayerData.MarkChanged(player)
	send(player, "Status", "Tribe [" .. tag .. "] " .. name .. " founded!")
	syncMine(player)
end

local function join(player: Player, tag: string)
	local profile = PlayerData.Get(player)
	if profile == nil then
		return
	end
	if profile.TribeId then
		send(player, "Status", "Leave your tribe first")
		return
	end
	local id = get("tag_" .. tag)
	if type(id) ~= "string" then
		send(player, "Status", "No tribe with tag [" .. tag .. "]")
		return
	end
	local joined = false
	update("tribe_" .. id, function(old: any): any
		if type(old) ~= "table" then
			return nil
		end
		local count = 0
		for _ in old.Members do
			count += 1
		end
		if count >= MAX_MEMBERS then
			return nil
		end
		old.Members[tostring(player.UserId)] = player.DisplayName
		joined = true
		return old
	end)
	if joined then
		profile.TribeId = id
		PlayerData.MarkChanged(player)
		send(player, "Status", "Joined [" .. tag .. "]")
	else
		send(player, "Status", "That tribe is full")
	end
	syncMine(player)
end

local function leave(player: Player)
	local profile = PlayerData.Get(player)
	if profile == nil or profile.TribeId == nil then
		return
	end
	local id = profile.TribeId :: string
	local disbandTag: string? = nil
	update("tribe_" .. id, function(old: any): any
		if type(old) ~= "table" then
			return nil
		end
		old.Members[tostring(player.UserId)] = nil
		if next(old.Members) == nil then
			disbandTag = old.Tag
			return old
		end
		if old.Leader == player.UserId then
			for uid in old.Members do
				old.Leader = tonumber(uid) or old.Leader
				break
			end
		end
		return old
	end)
	if disbandTag then
		remove("tag_" .. disbandTag)
		remove("tribe_" .. id)
	end
	profile.TribeId = nil
	PlayerData.MarkChanged(player)
	send(player, "Status", "You left the tribe")
	syncMine(player)
end

function Tribes.TopWeekly(count: number): { TribeView }
	local results: { TribeView } = {}
	local ordered = gloryStore()
	if ordered == nil then
		local list: { { Id: string, Glory: number } } = {}
		for id, glory in memoryGlory do
			table.insert(list, { Id = id, Glory = glory })
		end
		table.sort(list, function(a, b)
			return a.Glory > b.Glory
		end)
		for i = 1, math.min(count, #list) do
			local r = Tribes.Get(list[i].Id)
			if r then
				table.insert(results, view(r))
			end
		end
		return results
	end
	local ok, pages = pcall(function()
		return (ordered :: OrderedDataStore):GetSortedAsync(false, math.clamp(count, 1, 100))
	end)
	if ok and pages then
		for _, entry in (pages :: DataStorePages):GetCurrentPage() do
			local r = Tribes.Get(entry.key)
			if r then
				local v = view(r)
				v.WeeklyGlory = entry.value
				table.insert(results, v)
			end
		end
	end
	return results
end

function Tribes.AddGlory(player: Player, amount: number)
	local profile = PlayerData.Get(player)
	if profile == nil or profile.TribeId == nil or amount <= 0 then
		return
	end
	local id = profile.TribeId :: string
	local week = Tribes.Week()
	local weekly = 0
	update("tribe_" .. id, function(old: any): any
		if type(old) ~= "table" then
			return nil
		end
		if old.Week ~= week then
			old.Week = week
			old.WeeklyGlory = 0
		end
		old.WeeklyGlory += amount
		old.TotalGlory = (old.TotalGlory or 0) + amount
		weekly = old.WeeklyGlory
		return old
	end)
	local ordered = gloryStore()
	if ordered then
		pcall(function()
			(ordered :: OrderedDataStore):SetAsync(id, math.floor(weekly))
		end)
	else
		memoryGlory[id] = weekly
	end
end

local function cleanName(raw: any, maxLen: number, pattern: string): string?
	if type(raw) ~= "string" then
		return nil
	end
	local s = string.gsub(raw, "^%s+", "")
	s = string.gsub(s, "%s+$", "")
	if #s < 2 or #s > maxLen or string.match(s, pattern) == nil then
		return nil
	end
	return s
end

local function onTribeAction(player: Player, action: any, a: any, b: any)
	if type(action) ~= "string" then
		return
	end
	if action == "Create" then
		local name = cleanName(a, 24, "^[%w %-']+$")
		local tagRaw = cleanName(b, 4, "^%w+$")
		if name == nil or tagRaw == nil then
			send(player, "Status", "Name: 2-24 letters/numbers. Tag: 2-4 letters/numbers")
			return
		end
		local tag = string.upper(tagRaw :: string)
		local filteredName = filterText(player, name :: string)
		local filteredTag = filterText(player, tag)
		if filteredName == nil or filteredTag == nil then
			send(player, "Status", "That name is not allowed")
			return
		end
		local product = MonetizationCatalog.ByKey("TribeCreation")
		if product and MonetizationCatalog.IsConfigured(product) then
			pendingCreate[player] = { Name = filteredName :: string, Tag = tag }
			game:GetService("MarketplaceService"):PromptProductPurchase(player, product.ProductId)
		else
			create(player, filteredName :: string, tag)
		end
	elseif action == "Join" then
		local tag = cleanName(a, 4, "^%w+$")
		if tag then
			join(player, string.upper(tag))
		end
	elseif action == "Leave" then
		leave(player)
	elseif action == "Search" then
		local tag = cleanName(a, 4, "^%w+$")
		local results: { TribeView } = {}
		if tag then
			local id = get("tag_" .. string.upper(tag))
			if type(id) == "string" then
				local r = Tribes.Get(id)
				if r then
					table.insert(results, view(r))
				end
			end
		end
		send(player, "Results", results)
	elseif action == "Browse" then
		send(player, "Results", Tribes.TopWeekly(20))
	elseif action == "Mine" then
		syncMine(player)
	end
end

function Tribes.Start()
	local ok, result = pcall(function()
		return DataStoreService:GetDataStore("Tribes3v3_Tribes_v1")
	end)
	if ok then
		store = result
		local probeOk = pcall(function()
			(result :: DataStore):GetAsync("__probe")
		end)
		if not probeOk then
			store = nil
			warn("[Tribes] DataStore unavailable, using in-memory tribes")
		end
	end
	Net.Reliable("TribeAction").OnServerEvent:Connect(onTribeAction)
	Economy.TribeCreationPurchased:Connect(function(player: Player)
		local pending = pendingCreate[player]
		pendingCreate[player] = nil
		if pending then
			create(player, pending.Name, pending.Tag)
		end
	end)
	Economy.GloryAwarded:Connect(function(player: Player, amount: number)
		task.spawn(Tribes.AddGlory, player, amount)
	end)
	PlayerData.ProfileLoaded:Connect(function(player: Player)
		task.spawn(syncMine, player)
	end)
	Players.PlayerRemoving:Connect(function(player)
		pendingCreate[player] = nil
	end)
end

return Tribes
