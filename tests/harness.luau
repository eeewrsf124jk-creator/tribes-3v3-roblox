-- Minimal Roblox-style module loader for Lune: maps `script.Parent.X` paths onto the source
-- tree so pure modules (config, validator, ballistics, scaling math) can run outside Studio.

local fs = require("@lune/fs")
local luau = require("@lune/luau")
local roblox = require("@lune/roblox")
local task = require("@lune/task")

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

-- World mode: modules see a real (Lune) DataModel so the builder steps can assemble actual
-- Instances. Engine-only services are replaced by stubs: RunService reports "server, not
-- running" (Studio edit mode), CSG calls fail so GeometryKit falls back to welded Models, and
-- PhysicsService only records collision groups.
local world: any = nil

local function stub(name: string): any
	return setmetatable({ Name = name }, {
		__index = function(_, _key)
			return function()
				return nil
			end
		end,
	})
end

local methodsInstalled = false

function Harness.UseWorld(placeFile: string?): any
	if not methodsInstalled then
		methodsInstalled = true
		Harness.InstallEngineMethods()
	end
	return Harness.NewWorld(placeFile)
end

function Harness.InstallEngineMethods()
	-- engine methods Lune's Instance does not implement
	roblox.implementMethod("Instance", "WaitForChild", function(self: any, name: string)
		local child = self:FindFirstChild(name)
		assert(child, "WaitForChild: no " .. name .. " under " .. self:GetFullName())
		return child
	end)
	roblox.implementMethod("BasePart", "GetJoints", function(self: any)
		-- joints live next to the parts they connect: scan the top-most Model holding this part
		local scope = self
		while scope.Parent and scope.Parent:IsA("Model") do
			scope = scope.Parent
		end
		local joints = {}
		for _, d in scope:GetDescendants() do
			if (d:IsA("JointInstance") or d:IsA("WeldConstraint")) and (d.Part0 == self or d.Part1 == self) then
				table.insert(joints, d)
			end
		end
		return joints
	end)
	local function pivotOf(self: any): any
		if self:IsA("BasePart") then
			return self.CFrame
		end
		if self.PrimaryPart then
			return self.PrimaryPart.CFrame
		end
		return self.WorldPivot
	end
	local function pivotTo(self: any, target: any)
		if self:IsA("BasePart") then
			self.CFrame = target
			return
		end
		local delta = target * pivotOf(self):Inverse()
		for _, d in self:GetDescendants() do
			if d:IsA("BasePart") then
				d.CFrame = delta * d.CFrame
			end
		end
		if self.PrimaryPart == nil then
			self.WorldPivot = target
		end
	end
	for _, class in { "Model", "BasePart" } do
		roblox.implementMethod(class, "GetPivot", pivotOf)
		roblox.implementMethod(class, "PivotTo", pivotTo)
	end
	roblox.implementMethod("ParticleEmitter", "Emit", function() end)
end

function Harness.NewWorld(placeFile: string?): any
	local dm = if placeFile
		then roblox.deserializePlace(fs.readFile(placeFile))
		else roblox.Instance.new("DataModel")
	local groups: { [string]: boolean } = {}
	local services: { [string]: any } = {
		RunService = {
			IsServer = function()
				return true
			end,
			IsClient = function()
				return false
			end,
			IsRunning = function()
				return false
			end,
			IsStudio = function()
				return true
			end,
		},
		GeometryService = {
			UnionAsync = function()
				error("CSG is unavailable outside the engine")
			end,
			SubtractAsync = function()
				error("CSG is unavailable outside the engine")
			end,
		},
		PhysicsService = setmetatable({
			RegisterCollisionGroup = function(_, name: string)
				groups[name] = true
			end,
			IsCollisionGroupRegistered = function(_, name: string)
				return groups[name] == true
			end,
			GetRegisteredCollisionGroups = function()
				local list = {}
				for name in groups do
					table.insert(list, { name = name })
				end
				return list
			end,
		}, {
			__index = function()
				return function() end
			end,
		}),
	}
	world = {
		DataModel = dm,
		CollisionGroups = groups,
		game = setmetatable({}, {
			__index = function(_, key: string)
				if key == "GetService" then
					return function(_, name: string)
						if services[name] then
							return services[name]
						end
						local ok, service = pcall(function()
							return dm:GetService(name)
						end)
						return if ok then service else stub(name)
					end
				end
				return (dm :: any)[key]
			end,
		}),
	}
	return world
end

local load: (string) -> any
local instanceCache: { [any]: any } = {}

-- Runs a ModuleScript that lives in the world DataModel (world mode).
local function loadInstance(module: any): any
	if instanceCache[module] ~= nil then
		return instanceCache[module]
	end
	local env: { [string]: any } = {}
	for k, v in Harness.WorldEnv() do
		env[k] = v
	end
	env.script = module
	local chunk = luau.load(module.Source, { debugName = module:GetFullName(), environment = env })
	local result = chunk()
	instanceCache[module] = result
	return result
end

local function requireAny(target: any): any
	if typeof(target) == "Instance" then
		return loadInstance(target)
	end
	return load(target.__path)
end

function Harness.WorldEnv(): { [string]: any }
	local env: { [string]: any } = {
		require = requireAny,
		Random = RandomShim,
		task = task,
		game = world.game,
		workspace = world.DataModel:GetService("Workspace"),
	}
	for _, name in {
		"Instance", "Vector3", "CFrame", "Color3", "Enum", "UDim", "UDim2", "Vector2", "BrickColor",
		"ColorSequence", "ColorSequenceKeypoint", "NumberSequence", "NumberSequenceKeypoint",
		"NumberRange", "PhysicalProperties", "Font", "Rect", "Ray", "Faces", "Axes", "Region3",
	} do
		env[name] = (roblox :: any)[name]
	end
	return env
end

Harness.LoadInstance = loadInstance

function load(path: string): any
	if cache[path] ~= nil then
		return cache[path]
	end
	assert(exists[path], "module not found: " .. path)
	local env: { [string]: any } = {
		script = node(path),
		require = requireAny,
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
