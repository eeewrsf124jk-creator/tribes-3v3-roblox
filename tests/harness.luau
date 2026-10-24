-- Minimal Roblox-style module loader for Lune: maps `script.Parent.X` paths onto the source
-- tree so pure modules (config, validator, ballistics, scaling math) can run outside Studio.

local fs = require("@lune/fs")
local luau = require("@lune/luau")
local roblox = require("@lune/roblox")

local Harness = {}

-- Seeded RNG with the Random API the shared modules use.
local RandomShim = {}
RandomShim.__index = RandomShim

function RandomShim.new(seed: number?)
	local self = setmetatable({}, RandomShim)
	self.state = math.floor(seed or os.clock() * 1e6) % 2147483647
	if self.state <= 0 then
		self.state += 2147483646
	end
	return self
end

function RandomShim:NextNumber(min: number?, max: number?): number
	self.state = (self.state * 48271) % 2147483647
	local u = self.state / 2147483647
	local lo, hi = min or 0, max or 1
	return lo + (hi - lo) * u
end

function RandomShim:NextInteger(min: number, max: number): number
	return math.floor(self:NextNumber(min, max + 1))
end

local cache: { [string]: any } = {}
local nodes: { [string]: any } = {}

-- fs calls yield, which is not allowed inside metamethods, so index the tree up front.
local exists: { [string]: boolean } = {}
local function index(dir: string)
	exists[dir] = true
	for _, name in fs.readDir(dir) do
		local full = dir .. "/" .. name
		if fs.isDir(full) then
			index(full)
		else
			exists[full] = true
		end
	end
end
index("src")

local function node(path: string): any
	if nodes[path] then
		return nodes[path]
	end
	local self: any = { __path = path }
	local methods = {}
	function methods.FindFirstChild(_, name: string)
		local dir = path:gsub("%.luau$", "")
		for _, candidate in { dir .. "/" .. name .. ".luau", dir .. "/" .. name } do
			if exists[candidate] then
				return node(candidate)
			end
		end
		return nil
	end
	function methods.WaitForChild(s, name: string)
		local child = methods.FindFirstChild(s, name)
		assert(child, "no child " .. name .. " under " .. path)
		return child
	end
	setmetatable(self, {
		__index = function(_, key: string)
			if methods[key] then
				return methods[key]
			end
			if key == "Parent" then
				local parent = path:match("^(.*)/[^/]+$")
				return if parent then node(parent) else nil
			end
			if key == "Name" then
				return (path:match("([^/]+)$") :: string):gsub("%.luau$", "")
			end
			local child = methods.FindFirstChild(self, key)
			assert(child, "no child " .. key .. " under " .. path)
			return child
		end,
	})
	nodes[path] = self
	return self
end

local workspaceAttributes: { [string]: any } = {}
local workspaceShim = {
	Gravity = 196.2,
	GetAttribute = function(_, name: string)
		return workspaceAttributes[name]
	end,
	SetAttribute = function(_, name: string, value: any)
		workspaceAttributes[name] = value
	end,
}

local function load(path: string): any
	if cache[path] ~= nil then
		return cache[path]
	end
	assert(exists[path], "module not found: " .. path)
	local env: { [string]: any } = {
		script = node(path),
		require = function(target: any)
			return load(target.__path)
		end,
		workspace = workspaceShim,
		Random = RandomShim,
		Vector3 = roblox.Vector3,
		CFrame = roblox.CFrame,
		Color3 = roblox.Color3,
		Enum = roblox.Enum,
	}
	local chunk = luau.load(fs.readFile(path), { debugName = path, environment = env })
	local result = chunk()
	cache[path] = result
	return result
end

Harness.Load = load
Harness.Random = RandomShim
Harness.Workspace = workspaceShim

-- Tiny test runner -----------------------------------------------------------------------
local passed, failed = 0, 0
local failures: { string } = {}

function Harness.Test(name: string, fn: () -> ())
	local ok, err = pcall(fn)
	if ok then
		passed += 1
		print("  ok   " .. name)
	else
		failed += 1
		table.insert(failures, name .. ": " .. tostring(err))
		print("  FAIL " .. name .. "\n       " .. tostring(err))
	end
end

function Harness.Eq(actual: any, expected: any, label: string?)
	if actual ~= expected then
		error(string.format("%s: expected %s, got %s", label or "value", tostring(expected), tostring(actual)), 2)
	end
end

function Harness.Near(actual: number, expected: number, eps: number, label: string?)
	if math.abs(actual - expected) > eps then
		error(string.format("%s: expected %.4f±%.4f, got %.4f", label or "value", expected, eps, actual), 2)
	end
end

function Harness.True(cond: any, label: string)
	if not cond then
		error(label, 2)
	end
end

function Harness.Summary(): boolean
	print(string.format("\n%d passed, %d failed", passed, failed))
	return failed == 0
end

return Harness
