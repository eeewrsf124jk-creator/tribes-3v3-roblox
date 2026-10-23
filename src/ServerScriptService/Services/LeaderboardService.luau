--!strict
-- LeaderboardService: the three 3D boards in the lobby plus the elimination statues.
--   Board_TopTribes        weekly tribe Glory (TribeService ordered store)
--   Board_MostEliminations OrderedDataStore LB_Eliminations_v1 (lifetime kills)
--   Board_LongestStreaks   OrderedDataStore LB_LongestStreak_v1 (best win streak)
-- Online players' stats are written every refresh; top 3 eliminators get avatar statues.

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local CollectionService = game:GetService("CollectionService")

local Modules = game:GetService("ReplicatedStorage"):WaitForChild("Modules")
local GameConfig = require(Modules.Config.GameConfig)

local PlayerData = require(script.Parent.PlayerDataService)
local Tribes = require(script.Parent.TribeService)

local Leaderboards = {}

type Row = { Rank: number, Name: string, Value: number, UserId: number }

local killsStore: OrderedDataStore? = nil
local streakStore: OrderedDataStore? = nil
local nameCache: { [number]: string } = {}
local statueOwners: { [number]: number } = {}

local function nameFor(userId: number): string
	local cached = nameCache[userId]
	if cached then
		return cached
	end
	local player = Players:GetPlayerByUserId(userId)
	if player then
		nameCache[userId] = player.DisplayName
		return player.DisplayName
	end
	local ok, name = pcall(function()
		return Players:GetNameFromUserIdAsync(userId)
	end)
	local result = if ok and type(name) == "string" then name else ("User " .. userId)
	nameCache[userId] = result
	return result
end

local function topFrom(store: OrderedDataStore?, count: number, fallback: (Player) -> number): { Row }
	local rows: { Row } = {}
	if store then
		local ok, pages = pcall(function()
			return (store :: OrderedDataStore):GetSortedAsync(false, count)
		end)
		if ok and pages then
			for i, entry in (pages :: DataStorePages):GetCurrentPage() do
				local uid = tonumber(string.match(entry.key, "%d+")) or 0
				table.insert(rows, { Rank = i, Name = nameFor(uid), Value = entry.value, UserId = uid })
			end
			return rows
		end
	end
	-- no DataStore access (Studio): rank the players in this server
	local list: { Row } = {}
	for _, p in Players:GetPlayers() do
		table.insert(list, { Rank = 0, Name = p.DisplayName, Value = fallback(p), UserId = p.UserId })
	end
	table.sort(list, function(a, b)
		return a.Value > b.Value
	end)
	for i, r in list do
		r.Rank = i
		if i <= count then
			table.insert(rows, r)
		end
	end
	return rows
end

local function panel(name: string): Instance?
	for _, p in CollectionService:GetTagged("LeaderboardPanel") do
		if p:GetAttribute("Leaderboard") == name then
			return p
		end
	end
	return nil
end

local function fill(boardName: string, rows: { Row }, suffix: string)
	local p = panel(boardName)
	if p == nil then
		return
	end
	local list = p:FindFirstChild("Rows", true)
	if list == nil then
		return
	end
	for _, child in list:GetChildren() do
		if child:IsA("TextLabel") then
			child:Destroy()
		end
	end
	for _, r in rows do
		local label = Instance.new("TextLabel")
		label.Name = "Row" .. r.Rank
		label.LayoutOrder = r.Rank
		label.Size = UDim2.new(1, -8, 0, 34)
		label.BackgroundTransparency = if r.Rank % 2 == 0 then 0.85 else 0.7
		label.BackgroundColor3 = Color3.fromRGB(10, 10, 14)
		label.BorderSizePixel = 0
		label.Font = Enum.Font.GothamBold
		label.TextScaled = true
		label.TextXAlignment = Enum.TextXAlignment.Left
		label.TextColor3 = if r.Rank == 1 then Color3.fromRGB(255, 205, 60) elseif r.Rank <= 3 then Color3.fromRGB(230, 230, 240) else Color3.fromRGB(190, 192, 205)
		label.Text = string.format("  #%d   %s   —   %s %s", r.Rank, r.Name, tostring(math.floor(r.Value)), suffix)
		label.Parent = list
	end
end

local function placeStatue(rank: number, userId: number)
	if statueOwners[rank] == userId then
		return
	end
	local pedestal: BasePart? = nil
	for _, p in CollectionService:GetTagged("StatuePedestal") do
		if p:IsA("BasePart") and p:GetAttribute("StatueRank") == rank then
			pedestal = p
		end
	end
	if pedestal == nil or userId <= 0 then
		return
	end
	local ok, model = pcall(function()
		return Players:CreateHumanoidModelFromUserIdAsync(userId)
	end)
	if not ok or model == nil then
		return
	end
	local old = pedestal:FindFirstChild("Statue")
	if old then
		old:Destroy()
	end
	statueOwners[rank] = userId
	local statue = model :: Model
	statue.Name = "Statue"
	for _, d in statue:GetDescendants() do
		if d:IsA("BasePart") then
			d.Anchored = true
			d.CanCollide = false
			d.Material = Enum.Material.Marble
			d.Color = (pedestal :: BasePart).Color
		elseif d:IsA("BaseScript") or d:IsA("Sound") then
			d:Destroy()
		elseif d:IsA("Decal") then
			d.Transparency = 0.6
		end
	end
	local humanoid = statue:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	end
	local _, size = statue:GetBoundingBox()
	local top = (pedestal :: BasePart).Position + Vector3.new(0, (pedestal :: BasePart).Size.Y / 2 + size.Y / 2, 0)
	-- statues face +Z, toward the plaza (characters face -Z by default)
	statue:PivotTo(CFrame.new(top) * CFrame.Angles(0, math.pi, 0))
	statue.Parent = pedestal
end

local function writeStats()
	for _, p in Players:GetPlayers() do
		local profile = PlayerData.Get(p)
		if profile then
			local key = "u_" .. p.UserId
			if killsStore then
				pcall(function()
					(killsStore :: OrderedDataStore):SetAsync(key, profile.Kills)
				end)
			end
			if streakStore then
				pcall(function()
					(streakStore :: OrderedDataStore):SetAsync(key, profile.BestStreak)
				end)
			end
		end
	end
end

function Leaderboards.Refresh()
	local size = math.min(GameConfig.Lobby.LeaderboardSize, 25)
	local kills = topFrom(killsStore, size, function(p: Player): number
		local profile = PlayerData.Get(p)
		return if profile then profile.Kills else 0
	end)
	local streaks = topFrom(streakStore, size, function(p: Player): number
		local profile = PlayerData.Get(p)
		return if profile then profile.BestStreak else 0
	end)
	fill("Board_MostEliminations", kills, "KOs")
	fill("Board_LongestStreaks", streaks, "wins")
	local tribeRows: { Row } = {}
	for i, t in Tribes.TopWeekly(size) do
		table.insert(tribeRows, { Rank = i, Name = string.format("[%s] %s", t.Tag, t.Name), Value = t.WeeklyGlory, UserId = 0 })
	end
	fill("Board_TopTribes", tribeRows, "Glory")
	for rank = 1, 3 do
		local r = kills[rank]
		if r and r.Value > 0 then
			task.spawn(placeStatue, rank, r.UserId)
		end
	end
end

function Leaderboards.Start()
	local ok1, k = pcall(function()
		return DataStoreService:GetOrderedDataStore("LB_Eliminations_v1")
	end)
	local ok2, s = pcall(function()
		return DataStoreService:GetOrderedDataStore("LB_LongestStreak_v1")
	end)
	killsStore = if ok1 then k else nil
	streakStore = if ok2 then s else nil
	-- verify access once (Studio without API access throws)
	if killsStore then
		local probe = pcall(function()
			(killsStore :: OrderedDataStore):GetSortedAsync(false, 1)
		end)
		if not probe then
			killsStore = nil
			streakStore = nil
		end
	end
	Players.PlayerRemoving:Connect(function(player)
		local profile = PlayerData.Get(player)
		if profile and killsStore and streakStore then
			pcall(function()
				(killsStore :: OrderedDataStore):SetAsync("u_" .. player.UserId, profile.Kills);
				(streakStore :: OrderedDataStore):SetAsync("u_" .. player.UserId, profile.BestStreak)
			end)
		end
	end)
	task.spawn(function()
		task.wait(5)
		while true do
			writeStats()
			Leaderboards.Refresh()
			task.wait(GameConfig.Lobby.LeaderboardRefresh)
		end
	end)
end

return Leaderboards
