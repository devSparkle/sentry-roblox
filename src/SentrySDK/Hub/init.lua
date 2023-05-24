--!nocheck
--[=[
	The hub consists of a stack of clients and scopes.
	
	The SDK maintains two variables: The main hub (a global variable) and the current
	hub (a variable local to the current thread or execution context, also sometimes
	known as async local or context local).
]=]
--// Initialization

local Defaults = require(script.Parent:WaitForChild("Defaults"))

local ClientClass = require(script:WaitForChild("Client"))
local ScopeClass = require(script:WaitForChild("Scope"))

local Module = {}

--// Functions

function Module.new(Client: ClientClass.Client?, Scope: ScopeClass.Scope?)
	return setmetatable({Client = Client or ClientClass.new(), Scope = Scope or ScopeClass.new()}, {__index = Module})
end

function Module:Clone()
	return Module.new(self.Client, self.Scope:Clone())
end

function Module:GetCurrentHub()
	return self
end

function Module:CaptureEvent(Event: Defaults.Event, Hint)
	return self.Client:CaptureEvent(Event, Hint, self.Scope)
end

function Module:CaptureMessage(Message: string, Level: Defaults.Level? )
	return self:CaptureEvent({
		level = Level or "info",
		message = {
			formatted = Message, --// TODO: Remove PII (player names, user IDs)
			message = Message,
		}
	})
end

function Module:CaptureException(ErrorMessage: string?)
	if ErrorMessage == nil then
		return function(...)
			return self:CaptureException(...)
		end
	end
	
	local Thread = coroutine.running()
	local Event = {
		exception = {
			type = ErrorMessage,
			thread_id = string.gsub(tostring(Thread), "thread: ", ""),
		},
	}
	
	local EnvTrace = {}
	local EnvCount = 1
	
	while pcall(function() table.insert(EnvTrace, EnvCount, getfenv(EnvCount)) end) do
		EnvCount += 1
	end
	
	local OriginEnv = EnvTrace[1]
	
	if OriginEnv then
		if OriginEnv.script then
			Event.exception.module = tostring(OriginEnv.script)
			Event.exception.thread_id = Event.exception.thread_id
		end
	end
	
	return self:CaptureEvent(Event, {
		message = ErrorMessage,
		traceback = debug.traceback(),
		environments = EnvTrace,
		
		thread = Thread,
		thread_id = Event.exception.thread_id,
	})
end


function Module:PushScope()
	local OldScope = self.Scope
	local NewScope = setmetatable(Defaults:DeepCopy(OldScope), {__index = OldScope})
	
	self.Scope = NewScope
	
	return self, function()
		self.Scope = OldScope
	end
end

function Module:WithScope()
	
end

function Module:PopScope()
	self.Scope = getmetatable(self.Scope).__index
	
	return self
end

function Module:ConfigureScope(Callback: (ScopeClass.Scope) -> ())
	self.Scope:ConfigureScope(Callback)
	
	return self
end


function Module:GetClient()
	return self.Client
end

function Module:BindClient(Client: any?)
	self.Client = Client
end

function Module:UnbindClient()
	return Module:BindClient(nil)
end

return Module