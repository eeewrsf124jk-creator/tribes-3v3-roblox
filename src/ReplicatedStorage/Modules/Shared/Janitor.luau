--!strict
-- Janitor: owns runtime objects (Instances, connections, tweens, threads, callbacks, nested
-- janitors) and destroys them all at once. Round transitions call Cleanup() so nothing from a
-- previous round survives into the next.

export type Janitor = {
	Add: <T>(self: Janitor, item: T, key: string?) -> T,
	Remove: (self: Janitor, key: string) -> (),
	Get: (self: Janitor, key: string) -> any,
	Cleanup: (self: Janitor) -> (),
	Destroy: (self: Janitor) -> (),
	LinkToInstance: (self: Janitor, instance: Instance) -> RBXScriptConnection,
	_items: { any },
	_keyed: { [string]: any },
}

local Janitor = {}
Janitor.__index = Janitor

local function dispose(item: any)
	local kind = typeof(item)
	if kind == "Instance" then
		if (item :: Instance):IsA("Tween") then
			(item :: Tween):Cancel()
		end
		(item :: Instance):Destroy()
	elseif kind == "RBXScriptConnection" then
		(item :: RBXScriptConnection):Disconnect()
	elseif kind == "function" then
		task.spawn(item)
	elseif kind == "thread" then
		local co = item :: thread
		if coroutine.status(co) ~= "dead" then
			pcall(task.cancel, co)
		end
	elseif kind == "table" then
		local t = item :: any
		if type(t.Destroy) == "function" then
			t:Destroy()
		elseif type(t.Disconnect) == "function" then
			t:Disconnect()
		end
	end
end

function Janitor.new(): Janitor
	local self = setmetatable({
		_items = {},
		_keyed = {},
	}, Janitor)
	return (self :: any) :: Janitor
end

function Janitor.Add<T>(self: Janitor, item: T, key: string?): T
	if key ~= nil then
		local existing = self._keyed[key]
		if existing ~= nil then
			dispose(existing)
		end
		self._keyed[key] = item
	else
		table.insert(self._items, item)
	end
	return item
end

function Janitor.Remove(self: Janitor, key: string)
	local existing = self._keyed[key]
	if existing ~= nil then
		self._keyed[key] = nil
		dispose(existing)
	end
end

function Janitor.Get(self: Janitor, key: string): any
	return self._keyed[key]
end

function Janitor.Cleanup(self: Janitor)
	local items = self._items
	self._items = {}
	for i = #items, 1, -1 do
		dispose(items[i])
	end
	local keyed = self._keyed
	self._keyed = {}
	for _, item in keyed do
		dispose(item)
	end
end

function Janitor.Destroy(self: Janitor)
	self:Cleanup()
end

function Janitor.LinkToInstance(self: Janitor, instance: Instance): RBXScriptConnection
	return instance.Destroying:Connect(function()
		self:Cleanup()
	end)
end

return Janitor
