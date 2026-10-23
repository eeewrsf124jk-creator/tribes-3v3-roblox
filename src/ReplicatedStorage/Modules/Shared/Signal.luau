--!strict
-- Minimal typed in-process signal used for service-to-service events (kill -> POTG, etc.).

export type Connection = {
	Connected: boolean,
	Disconnect: (self: Connection) -> (),
}

export type Signal<T...> = {
	Connect: (self: Signal<T...>, fn: (T...) -> ()) -> Connection,
	Once: (self: Signal<T...>, fn: (T...) -> ()) -> Connection,
	Fire: (self: Signal<T...>, T...) -> (),
	Wait: (self: Signal<T...>) -> T...,
	DisconnectAll: (self: Signal<T...>) -> (),
	Destroy: (self: Signal<T...>) -> (),
	_handlers: { [Connection]: (T...) -> () },
}

local Signal = {}
Signal.__index = Signal

local ConnectionImpl = {}
ConnectionImpl.__index = ConnectionImpl

function ConnectionImpl.Disconnect(self: any)
	if not self.Connected then
		return
	end
	self.Connected = false
	self._signal._handlers[self] = nil
end

function Signal.new<T...>(): Signal<T...>
	local self = setmetatable({ _handlers = {} }, Signal)
	return (self :: any) :: Signal<T...>
end

function Signal.Connect(self: any, fn: (...any) -> ()): Connection
	local conn = setmetatable({ Connected = true, _signal = self }, ConnectionImpl)
	self._handlers[conn] = fn
	return (conn :: any) :: Connection
end

function Signal.Once(self: any, fn: (...any) -> ()): Connection
	local conn: Connection
	conn = Signal.Connect(self, function(...)
		conn:Disconnect()
		fn(...)
	end)
	return conn
end

function Signal.Fire(self: any, ...: any)
	for conn, fn in self._handlers do
		if (conn :: any).Connected then
			task.spawn(fn, ...)
		end
	end
end

function Signal.Wait(self: any): ...any
	local co = coroutine.running()
	Signal.Once(self, function(...)
		task.spawn(co, ...)
	end)
	return coroutine.yield()
end

function Signal.DisconnectAll(self: any)
	for conn in self._handlers do
		(conn :: any).Connected = false
	end
	table.clear(self._handlers)
end

function Signal.Destroy(self: any)
	Signal.DisconnectAll(self)
end

return Signal
