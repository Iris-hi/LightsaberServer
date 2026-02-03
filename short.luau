--!strict

local runservice = game:GetService("RunService")

export type config = {
	debug: boolean,
	AStart: boolean,
}

export type controller = {
	init: (self: controller, config: config?) -> (),
	start: (self: controller) -> (),
	stop: (self: controller) -> (),
	running: (self: controller) -> boolean,
}

local dfig: config = table.freeze({
	debug = false,
	AStart = false,
})

local impl = {}
impl.__index = impl

local function new(): controller
	return setmetatable({
		_initialized = false,
		_running = false,
		_config = dfig,
		_connection = nil,
	}, impl)
end

function impl:init(config: config?)
	if self._initialized then
		return
	end

	self._config = config or dfig
	self._initialized = true
end

function impl:start()
	if not self._initialized or self._running then
		return
	end

	self._running = true

	self._connection = runservice.Heartbeat:Connect(function()
		if not self._running then
			return
		end
	end)
end

function impl:stop()
	if not self._running then
		return
	end

	if not self._config.AStart then
		return
	end

	self._running = false

	if self._connection then
		self._connection:Disconnect()
		self._connection = nil
	end
end

function impl:running(): boolean
	return self._running
end

return new()
