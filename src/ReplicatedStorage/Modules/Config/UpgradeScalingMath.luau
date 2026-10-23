--!strict
-- Shard upgrade economy and per-level stat scaling.
--   Shards to go from level L to L+1: 10 * 2^(L-1)  (10 -> 20 -> 40 -> 80 -> ... -> 2560)
--   Stat multiplier at level L:       1.04^(L-1)    (compound +4% per level; Lv10 = 1.423x)
--   A linear mode (1 + 0.04*(L-1)) is exposed for comparison / tuning.

local UpgradeScalingMath = {}

UpgradeScalingMath.MaxLevel = 10
UpgradeScalingMath.BaseShardCost = 10
UpgradeScalingMath.PerLevelBonus = 0.04

export type ScalingMode = "Compound" | "Linear"

UpgradeScalingMath.Mode = "Compound" :: ScalingMode

function UpgradeScalingMath.ShardsForNextLevel(level: number): number?
	if level < 1 then
		return nil
	end
	if level >= UpgradeScalingMath.MaxLevel then
		return nil
	end
	return UpgradeScalingMath.BaseShardCost * 2 ^ (level - 1)
end

function UpgradeScalingMath.TotalShardsToReach(level: number): number
	local total = 0
	for l = 1, math.min(level, UpgradeScalingMath.MaxLevel) - 1 do
		total += UpgradeScalingMath.BaseShardCost * 2 ^ (l - 1)
	end
	return total
end

function UpgradeScalingMath.StatMultiplier(level: number, mode: ScalingMode?): number
	local l = math.clamp(math.floor(level), 1, UpgradeScalingMath.MaxLevel)
	local m = mode or UpgradeScalingMath.Mode
	if m == "Linear" then
		return 1 + UpgradeScalingMath.PerLevelBonus * (l - 1)
	end
	return (1 + UpgradeScalingMath.PerLevelBonus) ^ (l - 1)
end

function UpgradeScalingMath.ScaleDamage(baseDamage: number, level: number): number
	return baseDamage * UpgradeScalingMath.StatMultiplier(level)
end

function UpgradeScalingMath.ScaleHealth(baseHealth: number, level: number): number
	return baseHealth * UpgradeScalingMath.StatMultiplier(level)
end

function UpgradeScalingMath.CanUpgrade(level: number, shards: number): boolean
	local need = UpgradeScalingMath.ShardsForNextLevel(level)
	return need ~= nil and shards >= need
end

-- Account XP curve: XP needed to go from account level L to L+1.
function UpgradeScalingMath.XPForLevel(level: number): number
	return math.floor(250 * math.max(level, 1) ^ 1.2)
end

return UpgradeScalingMath
