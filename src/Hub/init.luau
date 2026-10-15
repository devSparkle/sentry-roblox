--!nocheck
--// Initialization

local Defaults = require(script.Parent:WaitForChild("Defaults"))

local ClientClass = require(script:WaitForChild("Client"))
local ScopeClass = require(script:WaitForChild("Scope"))

local RunService = game:GetService("RunService")
local Utils = require(script.Parent.Utils)

--[=[
	@class Hub
	
	The hub consists of a stack of clients and scopes.
	
	The SDK maintains two variables: The main hub (a global variable) and the current
	hub (a variable local to the current thread or execution context, also sometimes
	known as async local or context local).
]=]
local Hub = {}
local Logger = {}

--// Functions

--[=[
	@param Client Client
	@param Scope Scope
]=]
function Hub.new(Client: ClientClass.Client?, Scope: ScopeClass.Scope?)
	local MainTab = setmetatable({Client = Client or ClientClass.new(), Scope = Scope or ScopeClass.new()}, {__index = Hub})
	MainTab.Logger = setmetatable({Hub=MainTab}, {__index = Logger})
	return MainTab
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
  @param body string or Logger.fmt content
  @param attribute any key/value (string, number, or bool)
]=]
function Logger:Debug(Body: string | Defaults.LogParamFormat, Attribute: {[string]: any}?)
	return self:CaptureLog(Body, "debug", Attribute);
end

--[=[
  @param body string or Logger.fmt content
  @param attribute any key/value (string, number, or bool)
]=]
function Logger:Info(Body: string | Defaults.LogParamFormat, Attribute: {[string]: any}?)
	return self:CaptureLog(Body, "info", Attribute);
end

--[=[
  @param body string or Logger.fmt content
  @param attribute any key/value (string, number, or bool)
]=]
function Logger:Warn(Body: string | Defaults.LogParamFormat, Attribute: {[string]: any}?)
	return self:CaptureLog(Body, "warn", Attribute);
end

--[=[
  @param body string or Logger.fmt content
  @param attribute any key/value (string, number, or bool)
]=]
function Logger:Error(Body: string | Defaults.LogParamFormat, Attribute: {[string]: any}?)
	return self:CaptureLog(Body, "error", Attribute);
end

--[=[
	@param template 'string.format' text template
	@param ... 'string.format' parameters to complete the template
]=]
function Logger:fmt(Template: string, ...: string): Defaults.LogParamFormat
	local content = {}
	content.template = Template
	content.params = {...}
	return content;
end

--[=[
  @param body string or Logger.fmt content
  @param attributes custom log metadata (key/value)
  @param level level
]=]
function Logger:CaptureLog(Body: string | Defaults.LogParamFormat, Level: Defaults.Level, Attributes: {[string]: any}?)
	if not Body then return; end
	-- Byapss for client since it doesn't have init options
	if not (self.Hub.Options and self.Hub.Options.EnableLogs) and not RunService:IsClient() then return; end
	local LogPayload = {
		timestamp = DateTime.now().UnixTimestamp;
		level = Level or "info"; -- set default level if needed
		body = Body;
		attributes = {
			["sentry.environment"] = self.Hub.Options and self.Hub.Options.Environment;
			["sentry.release"] = self.Hub.Options and self.Hub.Options.Release;
		};
	}

	-- Convert Formatted body to payload
	if typeof(LogPayload.body) == "table" then
		LogPayload.body = string.format(Body.template, table.unpack(Body.params));
		LogPayload.attributes["sentry.message.template"] = Utils.ValToAttrVal(Body.template)
		for i,v in ipairs(Body.params) do
			LogPayload.attributes["sentry.message.parameter."..i-1] = Utils.ValToAttrVal(v)
		end
	end

	-- Copy over attribute table
	if Attributes then
		for k,v in pairs(Attributes) do
			LogPayload.attributes[k] = Utils.ValToAttrVal(v)
		end
	end

	-- Copy over user attributes
	if self.Hub.Scope.user then
		local userObj = Utils.FlattenTable(self.Hub.Scope.user, "user")
		for k,v in pairs(userObj) do
			LogPayload.attributes[k] = Utils.ValToAttrVal(v);
		end
	end

	-- Server/Client ctx
	if self.Hub.Scope.Logger then
		LogPayload.attributes.Logger = Utils.ValToAttrVal(self.Hub.Scope.Logger);
	end

	-- Copy over Scope Attributes
	if(self.Hub.Scope.attributes) then
		for k,v in pairs(self.Hub.Scope.attributes) do
			LogPayload.attributes[k] = Utils.ValToAttrVal(v)
		end
	end

	self.Hub:_CaptureLog(LogPayload)
end

--[=[
	This is internal method. Please use the Hub.Logger table to send sentry formatted log
	or customize LogServiceMessageOut integration instead 
]=]
function Hub:_CaptureLog(payload)
	if self.Options and self.Options.BeforeSendLog then
		local newPayload = self.Options.BeforeSendLog(payload);
		if newPayload == nil then return; end
		return self.Client:CaptureLog(newPayload, self.Scope)
	end
	return self.Client:CaptureLog(payload, self.Scope)
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
		exception = {{
			type = ErrorMessage,
			thread_id = string.gsub(tostring(Thread), "thread: ", ""),
		}},
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
			Event.exception[1].module = tostring(OriginEnv.script)
			Event.exception[1].thread_id = Event.exception[1].thread_id
		end
	end
	
	return self:CaptureEvent(Event, {
		message = ErrorMessage,
		traceback = debug.traceback(),
		environments = EnvTrace,
		memory_category = debug.getmemorycategory(),
		
		thread = Thread,
		thread_id = Event.exception[1].thread_id,
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