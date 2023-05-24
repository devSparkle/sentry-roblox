--!nocheck
--// Initialization

local Defaults = require(script.Parent:WaitForChild("Defaults"))

local ClientClass = require(script:WaitForChild("Client"))
local ScopeClass = require(script:WaitForChild("Scope"))

--[=[
	@class Hub
	
	The hub consists of a stack of clients and scopes.
	
	The SDK maintains two variables: The main hub (a global variable) and the current
	hub (a variable local to the current thread or execution context, also sometimes
	known as async local or context local).
]=]
local Hub = {}

--// Functions

--[=[
	@param Client Client
	@param Scope Scope
]=]
function Hub.new(Client: ClientClass.Client?, Scope: ScopeClass.Scope?)
	return setmetatable({Client = Client or ClientClass.new(), Scope = Scope or ScopeClass.new()}, {__index = Hub})
end


--[=[
]=]
function Hub:Clone()
	return Hub.new(self.Client, self.Scope:Clone())
end

--[=[
]=]
function Hub:GetCurrentHub()
	return self
end

--[=[
	@param Event Event
	@param Hint Hint
]=]
function Hub:CaptureEvent(Event: Defaults.Event, Hint)
	if self.Options then
		if self.Options.SampleRate == 0 then return end
		if math.random() > self.Options.SampleRate then
			return
		end
	end
	
	return self.Client:CaptureEvent(Event, Hint, self.Scope)
end

--[=[
	@param Level Level
]=]
function Hub:CaptureMessage(Message: string, Level: Defaults.Level? )
	return self:CaptureEvent({
		level = Level or "info",
		message = {
			formatted = Message, --// TODO: Remove PII (player names, user IDs)
			message = Message,
		}
	})
end

--[=[
]=]
function Hub:CaptureException(ErrorMessage: string?)
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
	
	if self.Options and self.Options.IncludeLocalVariables then
		while pcall(function() table.insert(EnvTrace, EnvCount, getfenv(EnvCount)) end) do
			EnvCount += 1
		end
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
		memory_category = debug.getmemorycategory(),
		
		thread = Thread,
		thread_id = Event.exception.thread_id,
	})
end


--[=[
]=]
function Hub:PushScope()
	local OldScope = self.Scope
	local NewScope = setmetatable(Defaults:DeepCopy(OldScope), {__index = OldScope})
	
	self.Scope = NewScope
	
	return self, function()
		self.Scope = OldScope
	end
end

--[=[
	@unreleased
]=]
function Hub:WithScope()
	
end

--[=[
	@unreleased
]=]
function Hub:PopScope()
	self.Scope = getmetatable(self.Scope).__index
	
	return self
end

--[=[
]=]
function Hub:ConfigureScope(Callback: (ScopeClass.Scope) -> ())
	self.Scope:ConfigureScope(Callback)
	
	return self
end


--[=[
]=]
function Hub:GetClient()
	return self.Client
end

--[=[
	@param Client Client
]=]
function Hub:BindClient(Client: any?)
	self.Client = Client
end

--[=[
]=]
function Hub:UnbindClient()
	return self:BindClient(nil)
end

--[=[
]=]
function Hub:StartSession()
	local CurrentTime = DateTime.now()
	
	return self.Options.Transport:CaptureEnvelope({
		sid = self.Scope.user.sid,
		did = tostring(self.Scope.user.id),
		seq = CurrentTime.UnixTimestampMillis,
		timestamp = CurrentTime:ToIsoDate(),
		started = self.Scope.user.started:ToIsoDate(),
		init = true,
		
		status = "ok",
		
		attrs = {
			release = self.Scope.release,
			environment = self.Scope.environment,
		}
	})
end

--[=[
]=]
function Hub:EndSession()
	local CurrentTime = DateTime.now()
	
	return self.Options.Transport:CaptureEnvelope({
		sid = self.Scope.user.sid,
		did = tostring(self.Scope.user.id),
		seq = CurrentTime.UnixTimestampMillis,
		timestamp = CurrentTime:ToIsoDate(),
		started = self.Scope.user.started:ToIsoDate(),
		
		status = "exited",
		
		attrs = {
			release = self.Scope.release,
			environment = self.Scope.environment,
		}
	})
end

return Hub