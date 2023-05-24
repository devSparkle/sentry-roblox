--!nocheck
--[=[
	A scope holds data that should implicitly be sent with Sentry events.
	It can hold context data, extra parameters, level overrides, fingerprints etc.
	
	The user can modify the current scope (to set extra, tags, current user) through
	the global function configure_scope. configure_scope takes a callback function
	to which it passes the current scope.
]=]
--// Initialization

local RunService = game:GetService("RunService")
local PlayerService = game:GetService("Players")
local LocalizationService = game:GetService("LocalizationService")

local Defaults = require(script.Parent.Parent:WaitForChild("Defaults"))

local Module = {}
Module.__index = Module

--// Functions

function Module._AddGlobalEventProcessor(Function)
	local BindableFunction = Instance.new("BindableFunction")
	
	BindableFunction:SetAttribute("RunContext", if RunService:IsClient() then Enum.RunContext.Client else Enum.RunContext.Server)
	BindableFunction.Name = "GlobalEventProcessor"
	BindableFunction.OnInvoke = Function
	BindableFunction.Parent = script
end

function Module.new()
	return setmetatable({
		extra = {},
		contexts = {},
		tags = {},
		
		_event_processors = {},
	}, Module)
end

--[=[
	The reason for this callback-based API is efficiency. If the SDK is disabled, it
	should not invoke the callback, thus avoiding unnecessary work.
]=]
function Module:ConfigureScope(Callback: (Scope) -> ())
	Callback(self)
end


function Module:SetUser(Player: Player | number)
	if typeof(Player) == "Instance" then
		local IsLocal = (Player == PlayerService.LocalPlayer)
		local LocaleId = (if IsLocal then LocalizationService.SystemLocaleId else Player.LocaleId)
		local CountryCode = string.split(LocaleId, "-")[2]
		
		if CountryCode then
			CountryCode = string.upper(CountryCode)
		end
		
		self.user = {
			id = Player.UserId,
			name = Player.Name,
			
			geo = {
				city = "Unknown",
				country_code = CountryCode,
				region = CountryCode,
			},
		}
	elseif typeof(Player) == "number" then
		self.user = {id = Player}
	else
		self.user = nil
	end
end


function Module:SetExtra(Key: string, Value: Defaults.ValidJSONValues)
	self.extra[Key] = Value
end

function Module:SetExtras(Dictionary: {[string]: Defaults.ValidJSONValues})
	for Key, Value in next, Dictionary do
		self.extra[Key] = Value
	end
end


function Module:SetTag(Key: string, Value: Defaults.ValidJSONValues)
	self.tags[Key] = Value
end

function Module:SetTags(Dictionary: {[string]: Defaults.ValidJSONValues})
	for Key, Value in next, Dictionary do
		self.tags[Key] = Value
	end
end


function Module:SetContext(Key: string, Value: Defaults.ValidJSONValues)
	self.contexts[Key] = Value
end

function Module:SetLevel(Level: Defaults.Level)
	self.level = Level
end

function Module:SetTranSaction(TransactionName: string)
	self.transaction = TransactionName
end

function Module:SetFingerprint(Fingerprint)
	self.fingerprint = Fingerprint
end


function Module:AddEventProcessor(Processor)
	table.insert(self._event_processors, Processor)
end


function Module:Clear()
	local EmptyScope = Module.new()
	
	for Key, Value in next, self do
		rawset(self, Key, rawget(EmptyScope, Key))
	end
end

function Module:Clone()
	return setmetatable(table.clone(self), Module)
end


function Module:AddBreadcrumb(Breadcrumb)
	print([[WIP: The function "Scope:AddBreadcrumb" is not yet implemented.]])
end

function Module:ClearBreadcrumbs()
	print([[WIP: The function "Scope:ClearBreadcrumbs" is not yet implemented.]])
end


function Module:ApplyToEvent(Event: Defaults.Event, Hint): Defaults.Event
	local Event = Defaults:AggregateDictionaries(self, Event)
	local EventProcessors = table.clone(Event._event_processors)
	Event._event_processors = nil
	
	if #Event.contexts then
		Event.contexts = nil
	end
	
	if #Event.extra then
		Event.extra = nil
	end
	
	for _, Processor in next, script:GetChildren() do
		if Processor.Name ~= "GlobalEventProcessor" then continue end
		if RunService:IsClient() and Processor:GetAttribute("RunContext") ~= Enum.RunContext.Client then continue end
		if RunService:IsServer() and Processor:GetAttribute("RunContext") ~= Enum.RunContext.Server then continue end
		
		table.insert(EventProcessors, 1, function(...)
			return Processor:Invoke(...)
		end)
	end
	
	for _, Processor in next, EventProcessors do
		local Success, Response = pcall(Processor, Event, Hint)
		
		if Success then
			Event = Response
			
			if not Event then
				break
			end
		else
			Event.errors = (Event.errors or {})
			table.insert(Event.errors, {
				type = "unknown_error",
				details = "Encountered error when calling an EventProcessor.",
				name = Response,
			})
		end
	end
	
	
	return Event
end

export type Scope = typeof(Module.new())

return table.freeze(Module)