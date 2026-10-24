--!strict
-- POTGRecorderAndScorer: 20 Hz timeline recorder and 6 s sliding-window highlight scorer.
--   Per frame and actor: {t, x, y, z, yaw, pitch, flags}   (flags: 1 alive, 2 blocking,
--   4 sliding, 8 drawing). Events: Shot / Swing / Hit / Kill / Equip.
--   Window score for a killer = sum over their kills in the window of
--     100 (kill) + 50 (HEADSHOT) + 90 (LONG SHOT >= 80 studs) + 80 (WINNING BLOW: last kill of
--     the round), multiplied by 1.5 (2 kills) / 2.5 (3+ kills), plus 500 for a TEAM WIPE
--     (every enemy of that round killed by the same player inside the window).
--   Each round's best window is cut out at round end; the match POTG is the best of them.

local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Modules = game:GetService("ReplicatedStorage"):WaitForChild("Modules")
local Types = require(Modules.Shared.Types)
local GameConfig = require(Modules.Config.GameConfig)

local Registry = require(script.Parent.Combat.CombatantRegistry)
local DamageModel = require(script.Parent.Combat.DamageModel)
local Combat = require(script.Parent.LagCompensatedCombatService)

type Combatant = Registry.Combatant

local Recorder = {}

type KillRecord = {
	T: number,
	KillerId: string,
	VictimId: string,
	VictimTeam: Types.TeamName,
	Headshot: boolean,
	Distance: number,
	WinningBlow: boolean,
}

type ActorInfo = { Name: string, Team: Types.TeamName, UserId: number }

type Session = {
	Context: string,
	Round: number,
	RoundStart: number,
	Recording: boolean,
	Frames: { [string]: { { number } } },
	Events: { Types.POTGEvent },
	Kills: { KillRecord },
	Actors: { [string]: ActorInfo },
	TeamSizes: { Alpha: number, Bravo: number },
	Best: Types.POTGPacket?,
}

local sessions: { [string]: Session } = {}
local W = GameConfig.POTG.Weights

local function now(): number
	return Workspace:GetServerTimeNow()
end

function Recorder.Begin(context: string, actors: { Combatant })
	local s: Session = {
		Context = context,
		Round = 0,
		RoundStart = now(),
		Recording = false,
		Frames = {},
		Events = {},
		Kills = {},
		Actors = {},
		TeamSizes = { Alpha = 0, Bravo = 0 },
		Best = nil,
	}
	for _, c in actors do
		s.Actors[c.Id] = { Name = c.Name, Team = c.Team, UserId = c.UserId }
	end
	sessions[context] = s
end

function Recorder.AddActor(context: string, c: Combatant)
	local s = sessions[context]
	if s then
		s.Actors[c.Id] = { Name = c.Name, Team = c.Team, UserId = c.UserId }
	end
end

function Recorder.StartRound(context: string, round: number)
	local s = sessions[context]
	if s == nil then
		return
	end
	s.Round = round
	s.RoundStart = now()
	s.Recording = true
	s.Frames = {}
	s.Events = {}
	s.Kills = {}
	local alpha, bravo = 0, 0
	for _, c in Registry.InContext(context) do
		if c.Alive then
			if c.Team == "Alpha" then
				alpha += 1
			elseif c.Team == "Bravo" then
				bravo += 1
			end
			local character = c.Character
			local equipped = if character then character:GetAttribute("EquippedItem") else nil
			if type(equipped) == "string" then
				table.insert(s.Events, { T = 0, Kind = "Equip", ActorId = c.Id, WeaponId = equipped })
			end
		end
	end
	s.TeamSizes = { Alpha = alpha, Bravo = bravo }
end

local function event(context: string, e: Types.POTGEvent)
	local s = sessions[context]
	if s and s.Recording then
		e.T = now() - s.RoundStart
		table.insert(s.Events, e)
	end
end

local function recordFrames()
	local t = now()
	for context, s in sessions do
		if s.Recording then
			local rel = t - s.RoundStart
			for _, c in Registry.InContext(context) do
				local root = c.Root
				if root and s.Actors[c.Id] then
					local frames = s.Frames[c.Id]
					if frames == nil then
						frames = {}
						s.Frames[c.Id] = frames
					end
					local look = root.CFrame.LookVector
					local yaw = math.atan2(-look.X, -look.Z)
					local flags = 0
					if c.Alive then
						flags += 1
					end
					if c.Blocking then
						flags += 2
					end
					if c.Sliding then
						flags += 4
					end
					local character = c.Character
					local draw = if character then character:GetAttribute("DrawRatio") else nil
					if type(draw) == "number" and draw > 0 then
						flags += 8
					end
					local p = root.Position
					table.insert(frames, { rel, p.X, p.Y, p.Z, yaw, c.Pitch, flags })
				end
			end
		end
	end
end

-- Score every 6 s window that ends just after one of the killer's kills.
local function bestWindow(s: Session): (number, number, string?, { string })
	local bestScore, bestEnd, bestKiller = 0, 0, nil :: string?
	local bestTags: { string } = {}
	for _, anchor in s.Kills do
		local killer = anchor.KillerId
		local windowEnd = anchor.T + 1
		local windowStart = windowEnd - GameConfig.POTG.WindowSeconds
		local score = 0
		local count = 0
		local headshot, longShot, winning = false, false, false
		local victimsByTeam: { [string]: { [string]: boolean } } = {}
		for _, k in s.Kills do
			if k.KillerId == killer and k.T >= windowStart and k.T <= anchor.T then
				count += 1
				local ks = W.Kill
				if k.Headshot then
					ks += W.Headshot
					headshot = true
				end
				if k.Distance >= GameConfig.Combat.LongShotDistance then
					ks += W.LongShot
					longShot = true
				end
				if k.WinningBlow then
					ks += W.WinningBlow
					winning = true
				end
				score += ks
				local bucket = victimsByTeam[k.VictimTeam]
				if bucket == nil then
					bucket = {}
					victimsByTeam[k.VictimTeam] = bucket
				end
				bucket[k.VictimId] = true
			end
		end
		local tags: { string } = {}
		if count >= 3 then
			score *= W.MultiKill3
			table.insert(tags, "TRIPLE KILL")
		elseif count == 2 then
			score *= W.MultiKill2
			table.insert(tags, "DOUBLE KILL")
		end
		local wipe = false
		for team, victims in victimsByTeam do
			local size = if team == "Alpha" then s.TeamSizes.Alpha elseif team == "Bravo" then s.TeamSizes.Bravo else 0
			local n = 0
			for _ in victims do
				n += 1
			end
			if size >= 2 and n >= size then
				wipe = true
			end
		end
		if wipe then
			score += W.TeamWipe
			table.insert(tags, "TEAM WIPE")
		end
		if headshot then
			table.insert(tags, "HEADSHOT")
		end
		if longShot then
			table.insert(tags, "LONG SHOT")
		end
		if winning then
			table.insert(tags, "WINNING BLOW")
		end
		if score > bestScore then
			bestScore, bestEnd, bestKiller, bestTags = score, windowEnd, killer, tags
		end
	end
	return bestScore, bestEnd, bestKiller, bestTags
end

local function slice(s: Session, startT: number, endT: number, killerId: string, score: number, tags: { string }): Types.POTGPacket
	local frames: { [string]: { Types.POTGActorFrame } } = {}
	for id, list in s.Frames do
		local out: { Types.POTGActorFrame } = {}
		for _, f in list do
			if f[1] >= startT - 0.1 and f[1] <= endT + 0.1 then
				table.insert(out, { f[1] - startT, f[2], f[3], f[4], f[5], f[6], f[7] })
			end
		end
		frames[id] = out
	end
	local events: { Types.POTGEvent } = {}
	-- equipment state at the window start: last Equip event per actor before startT
	local lastEquip: { [string]: Types.POTGEvent } = {}
	for _, e in s.Events do
		if e.Kind == "Equip" and e.T <= startT then
			lastEquip[e.ActorId] = e
		end
	end
	for _, e in lastEquip do
		table.insert(events, { T = 0, Kind = "Equip", ActorId = e.ActorId, WeaponId = e.WeaponId })
	end
	for _, e in s.Events do
		if e.T >= startT and e.T <= endT then
			table.insert(events, {
				T = e.T - startT,
				Kind = e.Kind,
				ActorId = e.ActorId,
				TargetId = e.TargetId,
				Origin = e.Origin,
				Velocity = e.Velocity,
				Gravity = e.Gravity,
				WeaponId = e.WeaponId,
				Position = e.Position,
			})
		end
	end
	local actor = s.Actors[killerId]
	return {
		PlayerName = if actor then actor.Name else "Unknown",
		ActorId = killerId,
		Tags = tags,
		Score = score,
		Duration = endT - startT,
		FrameRate = GameConfig.POTG.FrameRate,
		Actors = s.Actors,
		Frames = frames,
		Events = events,
	}
end

-- Called when a round ends; cuts that round's best window and keeps it if it beats the match best.
function Recorder.FinishRound(context: string)
	local s = sessions[context]
	if s == nil or not s.Recording then
		return
	end
	s.Recording = false
	if #s.Kills > 0 then
		s.Kills[#s.Kills].WinningBlow = true
	end
	local score, windowEnd, killer, tags = bestWindow(s)
	if killer and score > 0 then
		local roundLength = now() - s.RoundStart
		local endT = math.min(windowEnd, roundLength)
		local startT = math.max(0, endT - GameConfig.POTG.WindowSeconds)
		if s.Best == nil or score > (s.Best :: Types.POTGPacket).Score then
			s.Best = slice(s, startT, endT, killer, score, tags)
		end
	end
	s.Frames = {}
	s.Events = {}
end

function Recorder.Best(context: string): Types.POTGPacket?
	local s = sessions[context]
	return if s then s.Best else nil
end

function Recorder.End(context: string)
	sessions[context] = nil
end

function Recorder.Start()
	DamageModel.Killed:Connect(function(victim: Combatant, attacker: Combatant?, report: Types.DamageReport)
		local s = sessions[victim.Context]
		if s == nil or not s.Recording then
			return
		end
		local t = now() - s.RoundStart
		local distance = 0
		if attacker and attacker.Root and victim.Root then
			distance = ((attacker.Root :: BasePart).Position - (victim.Root :: BasePart).Position).Magnitude
		end
		if attacker then
			table.insert(s.Kills, {
				T = t,
				KillerId = attacker.Id,
				VictimId = victim.Id,
				VictimTeam = victim.Team,
				Headshot = report.Headshot,
				Distance = distance,
				WinningBlow = false,
			})
		end
		event(victim.Context, {
			T = t,
			Kind = "Kill",
			ActorId = if attacker then attacker.Id else victim.Id,
			TargetId = victim.Id,
			Position = report.Position,
			WeaponId = report.WeaponId,
		})
	end)
	DamageModel.Damaged:Connect(function(victim: Combatant, attacker: Combatant?, report: Types.DamageReport)
		if attacker and (report.Amount > 0 or report.ArmorAmount > 0) then
			event(victim.Context, {
				T = 0,
				Kind = "Hit",
				ActorId = attacker.Id,
				TargetId = victim.Id,
				Position = report.Position,
				WeaponId = report.WeaponId,
			})
		end
	end)
	Combat.Shot:Connect(function(c: Combatant, itemId: string, origin: Vector3, velocity: Vector3, gravityScale: number)
		event(c.Context, {
			T = 0,
			Kind = "Shot",
			ActorId = c.Id,
			Origin = origin,
			Velocity = velocity,
			Gravity = gravityScale,
			WeaponId = itemId,
		})
	end)
	Combat.Swing:Connect(function(c: Combatant, itemId: string)
		event(c.Context, { T = 0, Kind = "Swing", ActorId = c.Id, WeaponId = itemId })
	end)
	Combat.Equipped:Connect(function(c: Combatant, itemId: string)
		event(c.Context, { T = 0, Kind = "Equip", ActorId = c.Id, WeaponId = itemId })
	end)

	local accum = 0
	local interval = 1 / GameConfig.POTG.FrameRate
	RunService.Heartbeat:Connect(function(dt)
		accum += dt
		if accum >= interval then
			accum -= interval
			if accum > interval then
				accum = 0
			end
			recordFrames()
		end
	end)
end

return Recorder
