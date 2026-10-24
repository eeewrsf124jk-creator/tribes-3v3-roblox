-- Opens the Rojo-built place files and checks the DataModel Studio will load:
--   lune run tests/place.luau build/Lobby.rbxl build/Arena.rbxl
-- Every script must compile, the entry points must have the right classes and locations,
-- and each place must carry its role attribute.

local fs = require("@lune/fs")
local luau = require("@lune/luau")
local process = require("@lune/process")
local roblox = require("@lune/roblox")

local failures = 0
local function check(cond: any, message: string)
	if cond then
		print("  ok   " .. message)
	else
		failures += 1
		print("  FAIL " .. message)
	end
end

local function find(root: any, path: string): any
	local node = root
	for name in path:gmatch("[^/]+") do
		node = if node then node:FindFirstChild(name) else nil
	end
	return node
end

local function verify(file: string, role: string)
	print(string.format("%s (%s)", file, role))
	local game = roblox.deserializePlace(fs.readFile(file))

	local scripts, compiled = 0, 0
	for _, inst in game:GetDescendants() do
		if inst:IsA("LuaSourceContainer") then
			scripts += 1
			local ok, err = pcall(luau.compile, inst.Source)
			if ok then
				compiled += 1
			else
				print("       compile error in " .. inst:GetFullName() .. ": " .. tostring(err))
			end
			local firstLine = (inst.Source :: string):match("^[^\n]*")
			check(firstLine == "--!strict", inst:GetFullName() .. " is --!strict")
		end
	end
	check(scripts >= 60 and compiled == scripts, string.format("%d/%d scripts compile", compiled, scripts))

	local workspace = game:GetService("Workspace")
	check(workspace:GetAttribute("PlaceRole") == role, "Workspace.PlaceRole = " .. role)

	local server = find(game, "ServerScriptService/ServerMain")
	check(server and server.ClassName == "Script", "ServerMain is a Script in ServerScriptService")
	local client = find(game, "StarterPlayer/StarterPlayerScripts/ClientMain")
	check(client and client.ClassName == "LocalScript", "ClientMain is a LocalScript in StarterPlayerScripts")

	for _, name in {
		"MovementController",
		"CameraAndViewmodelController",
		"WeaponAndProjectileController",
		"CombatFeedbackAndHUDController",
		"POTGAndVictorySequenceController",
		"LobbyUIController",
		"InputAndKeybindController",
	} do
		local m = find(game, "StarterPlayer/StarterPlayerScripts/Controllers/" .. name)
		check(m and m.ClassName == "ModuleScript", "controller " .. name)
	end
	for _, path in {
		"ReplicatedStorage/Modules/Config/EquipmentDatabase",
		"ReplicatedStorage/Modules/Shared/Net",
		"ReplicatedStorage/BuilderModules/StudioBuilderPipeline",
		"ServerScriptService/Services/RoundStateMachineService",
		"ServerScriptService/Services/LagCompensatedCombatService",
	} do
		local m = find(game, path)
		check(m and m.ClassName == "ModuleScript", path)
	end
	-- every Net.Reliable("X") / Net.Unreliable("X") must name a declared remote; an unknown name
	-- would make WaitForChild yield forever at runtime
	local net = find(game, "ReplicatedStorage/Modules/Shared/Net")
	if net then
		local declared: { [string]: { [string]: boolean } } = { Reliable = {}, Unreliable = {} }
		for kind, set in declared do
			local block = (net.Source :: string):match("Net%." .. kind .. "Names = (%b{})")
			for name in (block or ""):gmatch('"([%w_]+)"') do
				set[name] = true
			end
		end
		local used, unknown = 0, {}
		for _, inst in game:GetDescendants() do
			if inst:IsA("LuaSourceContainer") then
				for kind, name in (inst.Source :: string):gmatch('Net%.(%a+)%("([%w_]+)"%)') do
					local set = declared[kind]
					if set then
						used += 1
						if not set[name] then
							table.insert(unknown, kind .. ":" .. name .. " in " .. inst:GetFullName())
						end
					end
				end
			end
		end
		check(used > 0 and #unknown == 0, string.format("%d remote lookups name declared remotes%s", used, if #unknown > 0 then " (unknown: " .. table.concat(unknown, ", ") .. ")" else ""))
	end
	-- only the two entry points may be Scripts / LocalScripts
	local entry = 0
	for _, inst in game:GetDescendants() do
		if inst.ClassName == "Script" or inst.ClassName == "LocalScript" then
			entry += 1
		end
	end
	check(entry == 2, "single-entry architecture (" .. entry .. " runnable scripts)")
end

local args = process.args
verify(args[1] or "build/Lobby.rbxl", "Lobby")
verify(args[2] or "build/Arena.rbxl", "Arena")

print(if failures == 0 then "\nplace checks passed" else string.format("\n%d place checks failed", failures))
process.exit(if failures == 0 then 0 else 1)
