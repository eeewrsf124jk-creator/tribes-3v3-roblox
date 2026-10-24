-- Regenerates docs/reference/*.md straight from the source tree and the built places, so the
-- reference never drifts from the code. Run from the repository root after building:
--
--   rojo build -o build/Lobby.rbxl && rojo build arena.project.json -o build/Arena.rbxl
--   lune run tools/gendocs.luau
--
-- The builder pipeline runs inside Lune (tests/harness.luau world mode), so the world, prefab
-- and ScreenGui inventories list exactly what Studio gets.

local fs = require("@lune/fs")
local process = require("@lune/process")
local H = require("../tests/harness")

local OUT = "docs/reference"
local MODULES = "src/ReplicatedStorage/Modules"
local HEADER = "<!-- 자동 생성 문서: tools/gendocs.luau 가 만듭니다. 직접 고치지 말고 다시 생성하세요. -->\n\n"

---------------------------------------------------------------------------------------------
-- helpers
---------------------------------------------------------------------------------------------
local function sortedKeys(t: { [any]: any }): { any }
	local keys = {}
	for k in t do
		table.insert(keys, k)
	end
	table.sort(keys, function(a, b)
		return tostring(a) < tostring(b)
	end)
	return keys
end

local function fmt(v: any): string
	local ty = typeof(v)
	if ty == "number" then
		if v == math.huge then
			return "무제한"
		end
		if v == math.floor(v) then
			return string.format("%d", v)
		end
		return (string.format("%.4f", v):gsub("0+$", ""):gsub("%.$", ""))
	elseif ty == "string" then
		return v
	elseif ty == "boolean" then
		return tostring(v)
	elseif ty == "Color3" then
		return string.format("RGB(%d, %d, %d)", math.round(v.R * 255), math.round(v.G * 255), math.round(v.B * 255))
	elseif ty == "Vector3" then
		return string.format("(%s, %s, %s)", fmt(v.X), fmt(v.Y), fmt(v.Z))
	elseif ty == "table" then
		local parts = {}
		if #v > 0 then
			for _, x in v do
				table.insert(parts, fmt(x))
			end
			return "{ " .. table.concat(parts, ", ") .. " }"
		end
		for _, k in sortedKeys(v) do
			table.insert(parts, tostring(k) .. " = " .. fmt(v[k]))
		end
		return "{ " .. table.concat(parts, ", ") .. " }"
	end
	return tostring(v)
end

local function cell(v: any): string
	if v == nil then
		return ""
	end
	return (fmt(v):gsub("|", "\\|"))
end

local function write(name: string, body: string)
	fs.writeFile(OUT .. "/" .. name, HEADER .. body)
	print("wrote " .. OUT .. "/" .. name)
end

local function listFiles(dir: string, out: { string })
	for _, name in fs.readDir(dir) do
		local full = dir .. "/" .. name
		if fs.isDir(full) then
			listFiles(full, out)
		elseif name:match("%.luau$") then
			table.insert(out, full)
		end
	end
	return out
end

local files = listFiles("src", {})
table.sort(files)
local sources: { [string]: string } = {}
for _, f in files do
	sources[f] = fs.readFile(f)
end

-- src path -> where Rojo puts it and as which class
local function robloxPath(path: string): (string, string)
	local rel = path:gsub("^src/", "")
	local class = "ModuleScript"
	if rel:match("%.server%.luau$") then
		class = "Script"
	elseif rel:match("%.client%.luau$") then
		class = "LocalScript"
	end
	rel = rel:gsub("%.server%.luau$", ""):gsub("%.client%.luau$", ""):gsub("%.luau$", "")
	rel = rel:gsub("^StarterPlayerScripts", "StarterPlayer/StarterPlayerScripts")
	return (rel:gsub("/", ".")), class
end

local function headerComment(src: string): string
	local lines = {}
	for line in src:gmatch("[^\n]*") do
		if line:match("^%-%-!") then
			continue
		end
		if line:match("^%-%-") then
			table.insert(lines, (line:gsub("^%-%- ?", "")))
		elseif #lines > 0 or line ~= "" then
			break
		end
	end
	return table.concat(lines, "\n")
end

---------------------------------------------------------------------------------------------
-- 1. equipment.md
---------------------------------------------------------------------------------------------
local DB = H.Load(MODULES .. "/Config/EquipmentDatabase.luau")
local Validator = H.Load(MODULES .. "/Shared/LoadoutBudgetValidator.luau")
local Scaling = H.Load(MODULES .. "/Config/UpgradeScalingMath.luau")

do
	local out = { "# 장비 레퍼런스 (전체 " .. #DB.Order .. "종)\n" }
	table.insert(out, "`src/ReplicatedStorage/Modules/Config/EquipmentDatabase.luau`의 모든 항목과 모든 필드입니다.\n")
	table.insert(out, "## 로드아웃 규칙\n")
	table.insert(out, "| 항목 | 값 |\n|---|---|")
	table.insert(out, "| 최대 포인트 | " .. DB.MaxPoints .. " |")
	table.insert(out, "| 최대 슬롯 (방어구 제외) | " .. DB.MaxSlots .. " |")
	table.insert(out, "| 방어구 | 1개 (전용 슬롯) |")
	table.insert(out, "| 저장 프리셋 수 | " .. #Validator.DefaultPresets() .. " |")
	table.insert(out, "| 백스탭 즉사 대미지 | " .. DB.BackstabDamage .. " |")
	table.insert(out, "\n## 탄약 묶음\n")
	table.insert(out, "| 종류 | 1묶음 발수 | 묶음당 포인트 | 최대 묶음 | 최대 발수 |\n|---|---|---|---|---|")
	for _, kind in { "Arrows", "FireArrows", "Bullets" } do
		table.insert(
			out,
			string.format(
				"| %s | %d | %d | %d | %d |",
				kind,
				DB.AmmoBundles[kind],
				DB.AmmoBundleCost[kind],
				DB.AmmoBundleMax[kind],
				DB.AmmoBundles[kind] * DB.AmmoBundleMax[kind]
			)
		)
	end
	table.insert(out, "\n## 랭크 전용 근접 무기 해금 조건 (Glory RP)\n")
	table.insert(out, "| 아이템 | 필요 Glory |\n|---|---|")
	for _, id in sortedKeys(DB.RankedUnlockGlory) do
		table.insert(out, string.format("| %s | %d |", id, DB.RankedUnlockGlory[id]))
	end

	-- summary tables per category
	local categories = { "WEAPONS", "UTILITY", "HEALING", "ARMOR" }
	local columns = {
		WEAPONS = { "SubType", "Cost", "BaseDmg", "HeadMult", "AmmoType", "MaxStack", "UnlockShards", "RobuxCost" },
		UTILITY = { "Cost", "MaxStack", "Cooldown", "Duration", "Radius", "Damage" },
		HEALING = { "Cost", "MaxStack", "HealAmount", "CastTime", "Duration", "SplashRadius" },
		ARMOR = { "Cost", "ArmorHP", "RangedDmgReduction", "MeleeDmgReduction", "SpeedPenalty", "KnockbackResist" },
	}
	for _, cat in categories do
		table.insert(out, "\n## " .. cat .. " 요약\n")
		local cols = columns[cat]
		table.insert(out, "| Id | 이름 | " .. table.concat(cols, " | ") .. " |")
		table.insert(out, "|---|---|" .. string.rep("---|", #cols))
		for _, id in DB.Order do
			local spec = DB.Items[id]
			if spec.Category == cat then
				local row = { id, spec.DisplayName }
				for _, c in cols do
					table.insert(row, cell(spec[c]))
				end
				table.insert(out, "| " .. table.concat(row, " | ") .. " |")
			end
		end
	end

	table.insert(out, "\n## 항목별 전체 필드\n")
	for _, id in DB.Order do
		local spec = DB.Items[id]
		table.insert(out, string.format("### %s (%s)\n", spec.DisplayName, id))
		table.insert(out, "> " .. (spec.Description or "") .. "\n")
		table.insert(out, "| 필드 | 값 |\n|---|---|")
		for _, k in sortedKeys(spec) do
			table.insert(out, string.format("| %s | %s |", k, cell(spec[k])))
		end
		local level10 = if spec.BaseDmg then Scaling.ScaleDamage(spec.BaseDmg, 10) else nil
		if level10 then
			table.insert(out, string.format("| (계산) Lv10 대미지 | %s |", fmt(level10)))
		end
		if spec.BaseDmg and spec.HeadMult then
			table.insert(out, string.format("| (계산) Lv1 헤드샷 | %s |", fmt(spec.BaseDmg * spec.HeadMult)))
		end
		table.insert(out, "")
	end

	table.insert(out, "## 기본 프리셋 5종\n")
	table.insert(out, "| # | 이름 | 슬롯 | 방어구 | 탄약 (묶음) | 포인트 |\n|---|---|---|---|---|---|")
	for i, p in Validator.DefaultPresets() do
		local r = Validator.Validate(p)
		table.insert(
			out,
			string.format(
				"| %d | %s | %s | %s | 화살 %d / 총알 %d / 불화살 %d | %d |",
				i,
				p.Name,
				table.concat(p.Slots, ", "),
				p.Armor or "-",
				p.Ammo.Arrows,
				p.Ammo.Bullets,
				p.Ammo.FireArrows,
				r.Points
			)
		)
	end
	write("equipment.md", table.concat(out, "\n") .. "\n")
end

---------------------------------------------------------------------------------------------
-- 2. config.md
---------------------------------------------------------------------------------------------
do
	local GameConfig = H.Load(MODULES .. "/Config/GameConfig.luau")
	local Monetization = H.Load(MODULES .. "/Config/MonetizationCatalog.luau")
	local out = { "# 설정값 레퍼런스\n" }

	table.insert(out, "## GameConfig\n")
	table.insert(out, "`src/ReplicatedStorage/Modules/Config/GameConfig.luau`\n")
	local function dump(prefix: string, t: { [any]: any })
		local scalars, nested = {}, {}
		for _, k in sortedKeys(t) do
			local v = t[k]
			if type(v) == "function" then
				continue
			end
			if type(v) == "table" and #v == 0 and next(v) ~= nil then
				table.insert(nested, k)
			else
				table.insert(scalars, k)
			end
		end
		if #scalars > 0 then
			table.insert(out, "### " .. prefix .. "\n")
			table.insert(out, "| 키 | 값 |\n|---|---|")
			for _, k in scalars do
				table.insert(out, string.format("| %s | %s |", tostring(k), cell(t[k])))
			end
			table.insert(out, "")
		end
		for _, k in nested do
			dump(prefix .. "." .. tostring(k), t[k])
		end
	end
	dump("GameConfig", GameConfig)

	table.insert(out, "## 유료 상품 (MonetizationCatalog)\n")
	table.insert(out, "ProductId가 0이면 \"미설정\"으로 표시되고 구매 창이 뜨지 않습니다.\n")
	table.insert(out, "| Key | 종류 | 가격 (R$) | 표시 이름 | Tier | ProductId |\n|---|---|---|---|---|---|")
	for _, p in Monetization.Products do
		table.insert(
			out,
			string.format(
				"| %s | %s | %d | %s | %s | %d |",
				p.Key,
				p.Kind,
				p.PriceRobux,
				p.DisplayName,
				cell(p.Tier),
				p.ProductId
			)
		)
	end

	table.insert(out, "\n## 업그레이드와 레벨 (UpgradeScalingMath)\n")
	table.insert(out, "| 레벨 | 다음 레벨까지 샤드 | 누적 샤드 | 능력치 배율 (복리) | 배율 (선형) | 계정 XP (다음 레벨) |\n|---|---|---|---|---|---|")
	for level = 1, Scaling.MaxLevel do
		table.insert(
			out,
			string.format(
				"| %d | %s | %d | %s | %s | %d |",
				level,
				cell(Scaling.ShardsForNextLevel(level) or "MAX"),
				Scaling.TotalShardsToReach(level),
				fmt(Scaling.StatMultiplier(level, "Compound")),
				fmt(Scaling.StatMultiplier(level, "Linear")),
				Scaling.XPForLevel(level)
			)
		)
	end

	-- SoundCatalog needs Instance at call time only; reading the table is safe
	local Sounds = H.Load(MODULES .. "/Config/SoundCatalog.luau")
	table.insert(out, "\n## 사운드 큐 (SoundCatalog)\n")
	table.insert(out, "| 큐 | 파일 | 볼륨 | 피치 |\n|---|---|---|---|")
	for _, name in sortedKeys(Sounds.Cues) do
		local c = Sounds.Cues[name]
		table.insert(out, string.format("| %s | `%s` | %s | %s |", name, c.Id, fmt(c.Volume), fmt(c.Pitch)))
	end
	write("config.md", table.concat(out, "\n") .. "\n")
end

---------------------------------------------------------------------------------------------
-- 3. remotes.md
---------------------------------------------------------------------------------------------
do
	-- Net.luau touches services at load time, so read the two name lists from its source
	local netSrc = sources[MODULES .. "/Shared/Net.luau"]
	local function names(listName: string): { string }
		local block = netSrc:match("Net%." .. listName .. " = (%b{})")
		local list = {}
		for name in block:gmatch('"([%w_]+)"') do
			table.insert(list, name)
		end
		return list
	end
	local Net = { ReliableNames = names("ReliableNames"), UnreliableNames = names("UnreliableNames") }
	local out = { "# 네트워크 채널 레퍼런스\n" }
	table.insert(out, "서버가 `ReplicatedStorage.RemoteNetwork_Events`에 만듭니다. 사용 위치는 `Net.Reliable(\"이름\")` / `Net.Unreliable(\"이름\")`를 부르는 모든 줄입니다.\n")
	local function usage(name: string, kind: string): { string }
		local rows = {}
		local needle = 'Net.' .. kind .. '("' .. name .. '")'
		local function roleOf(line: string): string?
			if line:find("OnServerEvent", 1, true) then
				return "서버 수신"
			elseif line:find("OnClientEvent", 1, true) then
				return "클라이언트 수신"
			elseif line:find("FireServer", 1, true) then
				return "클라이언트 → 서버"
			elseif line:find("FireAllClients", 1, true) then
				return "서버 → 전체"
			elseif line:find("FireClient", 1, true) then
				return "서버 → 클라이언트"
			end
			return nil
		end
		for _, f in files do
			local lines = {}
			for line in (sources[f] .. "\n"):gmatch("([^\n]*)\n") do
				table.insert(lines, line)
			end
			for n, line in lines do
				if line:find(needle, 1, true) then
					local role = roleOf(line)
					local var = line:match("local%s+([%w_]+)%s*[:=]")
					if role == nil and var then
						-- `local remote = Net.Reliable("X")`: report the calls made through the variable
						local found = false
						for m = n + 1, math.min(n + 40, #lines) do
							local l = lines[m]
							if l:find(var .. ":", 1, true) or l:find(var .. ".", 1, true) or l:find("(" .. var .. " ::", 1, true) then
								local r = roleOf(l)
								if r then
									table.insert(rows, string.format("| %s | `%s:%d` |", r, f, m))
									found = true
								end
							end
						end
						if not found then
							table.insert(rows, string.format("| 참조 | `%s:%d` |", f, n))
						end
					else
						table.insert(rows, string.format("| %s | `%s:%d` |", role or "참조", f, n))
					end
				end
			end
		end
		return rows
	end
	local function section(title: string, names: { string }, kind: string, class: string)
		table.insert(out, "## " .. title .. " (" .. class .. ", " .. #names .. "개)\n")
		for _, name in names do
			table.insert(out, "### " .. name .. "\n")
			local rows = usage(name, kind)
			if #rows == 0 then
				table.insert(out, "코드에서 이 이름으로 직접 부르는 곳이 없습니다 (변수에 담아 쓰는 경우 포함 안 됨).\n")
			else
				table.insert(out, "| 역할 | 위치 |\n|---|---|")
				for _, r in rows do
					table.insert(out, r)
				end
				table.insert(out, "")
			end
		end
	end
	section("Reliable", Net.ReliableNames, "Reliable", "RemoteEvent")
	section("Unreliable", Net.UnreliableNames, "Unreliable", "UnreliableRemoteEvent")
	write("remotes.md", table.concat(out, "\n") .. "\n")
end

---------------------------------------------------------------------------------------------
-- 4. modules.md
---------------------------------------------------------------------------------------------
do
	local out = { "# 스크립트와 모듈 전체 목록 (" .. #files .. "개)\n" }
	local total = 0
	for _, f in files do
		local _, count = sources[f]:gsub("\n", "\n")
		total += count
	end
	table.insert(out, string.format("총 %d줄. 모든 파일은 `--!strict`로 시작합니다.\n", total))
	table.insert(out, "| 파일 | Roblox 위치 | 종류 | 줄 수 |\n|---|---|---|---|")
	for _, f in files do
		local path, class = robloxPath(f)
		local _, count = sources[f]:gsub("\n", "\n")
		table.insert(out, string.format("| `%s` | %s | %s | %d |", f, path, class, count))
	end
	for _, f in files do
		local src = sources[f]
		local path, class = robloxPath(f)
		table.insert(out, "\n## " .. path .. "\n")
		table.insert(out, string.format("`%s` · %s\n", f, class))
		local header = headerComment(src)
		if header ~= "" then
			table.insert(out, "```text\n" .. header .. "\n```\n")
		end
		local deps = {}
		for target in src:gmatch("require%(([^%)]+)%)") do
			if not table.find(deps, target) then
				table.insert(deps, target)
			end
		end
		if #deps > 0 then
			table.insert(out, "**의존:** " .. table.concat(
				(function()
					local d = {}
					for _, x in deps do
						table.insert(d, "`" .. x .. "`")
					end
					return d
				end)(),
				", "
			) .. "\n")
		end
		local fns = {}
		for line in (src .. "\n"):gmatch("([^\n]*)\n") do
			local sig = line:match("^function ([%w_]+[%.:][%w_%.:]+%b())")
			if sig then
				local ret = line:match("%b()%s*:%s*(.+)$")
				table.insert(fns, "- `" .. sig .. (if ret then ": " .. ret else "") .. "`")
			end
		end
		if #fns > 0 then
			table.insert(out, "**공개 함수**\n")
			table.insert(out, table.concat(fns, "\n") .. "\n")
		end
		local types = {}
		for name in src:gmatch("\nexport type ([%w_]+)") do
			table.insert(types, "`" .. name .. "`")
		end
		if #types > 0 then
			table.insert(out, "**공개 타입:** " .. table.concat(types, ", ") .. "\n")
		end
	end
	write("modules.md", table.concat(out, "\n") .. "\n")
end

---------------------------------------------------------------------------------------------
-- 5. types.md
---------------------------------------------------------------------------------------------
do
	local src = sources[MODULES .. "/Shared/Types.luau"]
	local out = { "# 공유 타입 (Types.luau)\n" }
	table.insert(out, "서버 서비스와 클라이언트 컨트롤러가 함께 쓰는 데이터 계약입니다. 원본 그대로 옮겼습니다.\n")
	table.insert(out, "```lua\n" .. (src:gsub("^%-%-!strict\n", "")) .. "```")
	write("types.md", table.concat(out, "\n") .. "\n")
end

---------------------------------------------------------------------------------------------
-- 6/7. world.md and ui.md (builder pipeline executed in Lune)
---------------------------------------------------------------------------------------------
local function buildWorld(role: string): any
	local file = "build/" .. role .. ".rbxl"
	if not fs.isFile(file) then
		error(file .. " is missing: run `rojo build` first (see the header of this script)")
	end
	local w = H.UseWorld(file)
	local P = H.LoadInstance(w.DataModel:GetService("ReplicatedStorage").BuilderModules.StudioBuilderPipeline)
	P.RunAll({ Role = role })
	return w
end

local function partCount(inst: any): number
	local n = if inst:IsA("BasePart") then 1 else 0
	for _, d in inst:GetDescendants() do
		if d:IsA("BasePart") then
			n += 1
		end
	end
	return n
end

local function classCounts(inst: any): string
	local counts: { [string]: number } = {}
	for _, d in inst:GetDescendants() do
		counts[d.ClassName] = (counts[d.ClassName] or 0) + 1
	end
	local parts = {}
	for _, k in sortedKeys(counts) do
		table.insert(parts, k .. " " .. counts[k])
	end
	return table.concat(parts, ", ")
end

local lobby = buildWorld("Lobby")
local arena = buildWorld("Arena")

do
	local out = { "# 월드 인벤토리\n" }
	table.insert(out, "빌더 파이프라인(Step 1~4)을 실제로 실행해 만든 결과입니다. CSG 합치기는 엔진 밖에서는 동작하지 않아 용접된 Model로 대체된 상태로 셌습니다. Studio에서는 같은 자리에 Union 하나가 생기므로 파트 수가 이보다 적을 수 있습니다.\n")

	local CollisionGroups = H.LoadInstance(lobby.DataModel:GetService("ReplicatedStorage").Modules.Shared.CollisionGroups)
	table.insert(out, "## 충돌 그룹 매트릭스\n")
	table.insert(out, "| | " .. table.concat(CollisionGroups.Ordered, " | ") .. " |")
	table.insert(out, "|---|" .. string.rep("---|", #CollisionGroups.Ordered))
	for _, a in CollisionGroups.Ordered do
		local row = { a }
		for _, b in CollisionGroups.Ordered do
			table.insert(row, if CollisionGroups.ShouldCollide(a, b) then "충돌" else "-")
		end
		table.insert(out, "| " .. table.concat(row, " | ") .. " |")
	end

	-- siblings that only differ by a trailing number (TileRing1_1 .. TileRing1_22) are folded
	-- into one line so the tree stays readable; containers are expanded up to maxDepth
	local function tree(root: any, depth: number, maxDepth: number, lines: { string })
		local groups: { { key: string, name: string, class: string, items: { any } } } = {}
		local index: { [string]: number } = {}
		for _, c in root:GetChildren() do
			local base = c.Name:gsub("_?%d+$", "")
			local key = c.ClassName .. "|" .. base
			if index[key] == nil then
				table.insert(groups, { key = key, name = base, class = c.ClassName, items = {} })
				index[key] = #groups
			end
			table.insert(groups[index[key]].items, c)
		end
		for _, g in groups do
			local parts = 0
			for _, c in g.items do
				parts += partCount(c)
			end
			local label = if #g.items == 1 then g.items[1].Name else g.name .. "* ×" .. #g.items
			table.insert(lines, string.format("%s- **%s** (%s) · 파트 %d", string.rep("  ", depth), label, g.class, parts))
			if #g.items == 1 and depth + 1 < maxDepth and (g.class == "Folder" or g.class == "Model") then
				tree(g.items[1], depth + 1, maxDepth, lines)
			end
		end
	end

	table.insert(out, "\n## Workspace 런타임 폴더\n")
	local lines = {}
	tree(arena.DataModel:GetService("Workspace").Runtime_Dynamic_Containers, 0, 2, lines)
	table.insert(out, table.concat(lines, "\n"))

	table.insert(out, "\n## 로비 마을 (Lobby_50Player_World)\n")
	local lw = lobby.DataModel:GetService("Workspace").Lobby_50Player_World
	table.insert(out, string.format("전체 파트 %d개. 구성 요소별 개수: %s\n", partCount(lw), classCounts(lw)))
	lines = {}
	tree(lw, 0, 3, lines)
	table.insert(out, table.concat(lines, "\n"))

	table.insert(out, "\n## 아레나 맵 4종 (ServerStorage.ArenaMapStorage)\n")
	for _, map in arena.DataModel:GetService("ServerStorage").ArenaMapStorage:GetChildren() do
		table.insert(out, "\n### " .. map.Name .. "\n")
		local attrs = {}
		for k, v in map:GetAttributes() do
			table.insert(attrs, k .. " = " .. fmt(v))
		end
		table.sort(attrs)
		if #attrs > 0 then
			table.insert(out, "속성: " .. table.concat(attrs, ", ") .. "\n")
		end
		table.insert(out, string.format("전체 파트 %d개. 구성 요소별 개수: %s\n", partCount(map), classCounts(map)))
		lines = {}
		tree(map, 0, 2, lines)
		table.insert(out, table.concat(lines, "\n"))
	end

	table.insert(out, "\n## 장비 프리팹 (ReplicatedStorage.Procedural_3D_Weapon_And_Armor_Prefabs)\n")
	local prefabs = lobby.DataModel:GetService("ReplicatedStorage").Procedural_3D_Weapon_And_Armor_Prefabs
	for _, folder in prefabs:GetChildren() do
		table.insert(out, "\n### " .. folder.Name .. "\n")
		table.insert(out, "| 모델 | 파트 | 장착 부위 | Attachment |\n|---|---|---|---|")
		for _, model in folder:GetChildren() do
			local attachments = {}
			for _, d in model:GetDescendants() do
				if d:IsA("Attachment") and not table.find(attachments, d.Name) then
					table.insert(attachments, d.Name)
				end
			end
			table.sort(attachments)
			table.insert(
				out,
				string.format(
					"| %s | %d | %s | %s |",
					model.Name,
					partCount(model),
					cell(model:GetAttribute("AttachPart") or "-"),
					table.concat(attachments, ", ")
				)
			)
		end
	end

	table.insert(out, "\n## VFX 템플릿 (ReplicatedStorage.VFX_And_Particle_Templates)\n")
	local vfx = lobby.DataModel:GetService("ReplicatedStorage").VFX_And_Particle_Templates
	for _, folder in vfx:GetChildren() do
		table.insert(out, "\n### " .. folder.Name .. "\n")
		table.insert(out, "| 템플릿 | 종류 | 구성 |\n|---|---|---|")
		for _, t in folder:GetChildren() do
			table.insert(out, string.format("| %s | %s | %s |", t.Name, t.ClassName, classCounts(t)))
		end
	end
	write("world.md", table.concat(out, "\n") .. "\n")
end

do
	local out = { "# ScreenGui 전체 구조\n" }
	table.insert(out, "Step 4 빌더가 만드는 11개 화면의 모든 요소입니다. 이름은 클라이언트 컨트롤러가 찾는 계약이라 바꾸면 컨트롤러도 같이 바꿔야 합니다. 글자가 있는 요소는 기본 문구를 함께 적었습니다.\n")
	local starterGui = lobby.DataModel:GetService("StarterGui")
	local guis = starterGui:GetChildren()
	table.insert(out, "| ScreenGui | 요소 수 |\n|---|---|")
	for _, g in guis do
		table.insert(out, string.format("| %s | %d |", g.Name, #g:GetDescendants()))
	end
	local function walk(inst: any, depth: number, lines: { string })
		for _, c in inst:GetChildren() do
			if c:IsA("UICorner") or c:IsA("UIStroke") or c:IsA("UIGradient") or c:IsA("UIPadding") or c:IsA("UITextSizeConstraint") or c:IsA("UIAspectRatioConstraint") or c:IsA("UIListLayout") or c:IsA("UIGridLayout") then
				continue
			end
			local text = ""
			if (c:IsA("TextLabel") or c:IsA("TextButton") or c:IsA("TextBox")) and c.Text ~= "" then
				text = " — \"" .. (c.Text:gsub("\n", " "):sub(1, 60)) .. "\""
			end
			table.insert(lines, string.format("%s- %s `%s`%s", string.rep("  ", depth), c.Name, c.ClassName, text))
			walk(c, depth + 1, lines)
		end
	end
	for _, g in guis do
		table.insert(out, "\n## " .. g.Name .. "\n")
		table.insert(out, "꾸밈 요소 포함 구성: " .. classCounts(g) .. "\n")
		table.insert(out, "<details><summary>요소 트리 펼치기</summary>\n")
		local lines = {}
		walk(g, 0, lines)
		table.insert(out, table.concat(lines, "\n"))
		table.insert(out, "\n</details>")
	end
	write("ui.md", table.concat(out, "\n") .. "\n")
end

print("docs/reference regenerated")
process.exit(0)
