--!strict
-- Sound mapping. Defaults use sound files that ship inside every Roblox client
-- (rbxasset://sounds/..., the same files the default character sounds use), pitched to fit each
-- cue, so the game is audible with zero uploads. Replace any Id with "rbxassetid://<number>"
-- from your own uploaded or Creator Store audio to upgrade a cue.

export type Cue = { Id: string, Volume: number, Pitch: number }

local JUMP = "rbxasset://sounds/action_jump.mp3"
local LAND = "rbxasset://sounds/action_jump_land.mp3"
local GETUP = "rbxasset://sounds/action_get_up.mp3"
local FALL = "rbxasset://sounds/action_falling.ogg"
local STEP = "rbxasset://sounds/action_footsteps_plastic.mp3"
local SWIM = "rbxasset://sounds/action_swim.mp3"
local SPLASH = "rbxasset://sounds/impact_water.mp3"
local OOF = "rbxasset://sounds/uuhhh.mp3"

local Cues: { [string]: Cue } = {
	BowRelease = { Id = GETUP, Volume = 0.6, Pitch = 1.8 },
	BowDraw = { Id = FALL, Volume = 0.25, Pitch = 2.2 },
	CrossbowFire = { Id = LAND, Volume = 0.8, Pitch = 1.9 },
	GunFire = { Id = LAND, Volume = 1.2, Pitch = 0.75 },
	BlunderbussFire = { Id = LAND, Volume = 1.4, Pitch = 0.55 },
	Throw = { Id = GETUP, Volume = 0.5, Pitch = 1.5 },
	SwingLight = { Id = GETUP, Volume = 0.5, Pitch = 2.1 },
	SwingHeavy = { Id = GETUP, Volume = 0.7, Pitch = 1.2 },
	HitFlesh = { Id = LAND, Volume = 0.7, Pitch = 1.4 },
	HitHeadshot = { Id = LAND, Volume = 1.0, Pitch = 2.2 },
	HitArmor = { Id = STEP, Volume = 0.9, Pitch = 2.4 },
	ArmorBreak = { Id = SPLASH, Volume = 0.9, Pitch = 2.0 },
	Block = { Id = STEP, Volume = 1.0, Pitch = 3.0 },
	Hitmarker = { Id = STEP, Volume = 0.5, Pitch = 3.2 },
	Kill = { Id = JUMP, Volume = 0.9, Pitch = 1.6 },
	Death = { Id = OOF, Volume = 0.8, Pitch = 1.0 },
	Splash = { Id = SPLASH, Volume = 0.7, Pitch = 1.0 },
	WaterWade = { Id = SWIM, Volume = 0.5, Pitch = 1.0 },
	Slide = { Id = FALL, Volume = 0.4, Pitch = 1.3 },
	TrapSnap = { Id = LAND, Volume = 1.2, Pitch = 2.6 },
	SmokePop = { Id = SPLASH, Volume = 0.8, Pitch = 0.6 },
	WarHorn = { Id = FALL, Volume = 1.0, Pitch = 0.35 },
	FireballWhoosh = { Id = FALL, Volume = 0.8, Pitch = 0.7 },
	Explosion = { Id = LAND, Volume = 1.4, Pitch = 0.4 },
	Heal = { Id = SWIM, Volume = 0.5, Pitch = 1.6 },
	UIClick = { Id = STEP, Volume = 0.4, Pitch = 2.8 },
	UIConfirm = { Id = JUMP, Volume = 0.5, Pitch = 2.0 },
	Countdown = { Id = STEP, Volume = 0.8, Pitch = 2.0 },
	Fight = { Id = JUMP, Volume = 1.0, Pitch = 0.9 },
	ChestShake = { Id = LAND, Volume = 0.6, Pitch = 1.1 },
	ChestOpen = { Id = SPLASH, Volume = 0.8, Pitch = 1.5 },
	CardFlip = { Id = GETUP, Volume = 0.5, Pitch = 2.4 },
	RingTick = { Id = FALL, Volume = 0.35, Pitch = 0.5 },
	Fountain = { Id = SWIM, Volume = 0.25, Pitch = 0.8 },
}

local SoundCatalog = { Cues = Cues }

function SoundCatalog.Get(name: string): Cue
	return Cues[name] or Cues.UIClick
end

-- Play a one-shot cue at a world position (or 2D when no position is given).
function SoundCatalog.Play(name: string, parent: Instance?, pitchJitter: number?): Sound
	local cue = SoundCatalog.Get(name)
	local s = Instance.new("Sound")
	s.Name = name
	s.SoundId = cue.Id
	s.Volume = cue.Volume
	local jitter = pitchJitter or 0.05
	s.PlaybackSpeed = cue.Pitch * (1 + (math.random() * 2 - 1) * jitter)
	s.RollOffMaxDistance = 260
	s.RollOffMinDistance = 10
	s.Parent = parent or game:GetService("SoundService")
	s.Ended:Once(function()
		s:Destroy()
	end)
	s:Play()
	task.delay(8, function()
		if s.Parent then
			s:Destroy()
		end
	end)
	return s
end

return SoundCatalog
