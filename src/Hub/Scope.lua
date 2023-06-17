--!nocheck
--// Initialization

local RunService = game:GetService("RunService")
local PlayerService = game:GetService("Players")
local LocalizationService = game:GetService("LocalizationService")

local Defaults = require(script.Parent.Parent:WaitForChild("Defaults"))

--[=[
	@class Scope
	
	A scope holds data that should implicitly be sent with Sentry events.
	It can hold context data, extra parameters, level overrides, fingerprints etc.
	
	The user can modify the current scope (to set extra, tags, current user) through
	the global function configure_scope. configure_scope takes a callback function
	to which it passes the current scope.
]=]
local Scope = {}
Scope.__index = Scope

--// Functions

--[=[
	@private
	@param Function (Event, Hint) -> (Event)
]=]
function Scope._AddGlobalEventProcessor(Function)
	local BindableFunction = Instance.new("BindableFunction")
	
	BindableFunction:SetAttribute("RunContext", if RunService:IsClient() then Enum.RunContext.Client else Enum.RunContext.Server)
	BindableFunction.Name = "GlobalEventProcessor"
	BindableFunction.OnInvoke = Function
	BindableFunction.Parent = script
end

--[=[
]=]
function Scope.new()
	return setmetatable({
		extra = {},
		contexts = {},
		tags = {},
		
		_event_processors = {},
	}, Scope)
end

--[=[
	The reason for this callback-based API is efficiency. If the SDK is disabled, it
	should not invoke the callback, thus avoiding unnecessary work.
]=]
function Scope:ConfigureScope(Callback: (Scope) -> ())
	Callback(self)
end


--[=[
	Adds information of the given player to each event sent.
	Only one user may be associated with a Scope at any given time. Calling this method will override the current user.
	When no player is provided, any existing player information is removed.
	
	The `UserId`, `Name` and country-code of the player is sent.
]=]
function Scope:SetUser(Player: Player | number)
	if typeof(Player) == "Instance" then
		local IsLocal = (Player == PlayerService.LocalPlayer)
		local LocaleId = (if IsLocal then LocalizationService.SystemLocaleId else Player.LocaleId)
		local CountryCode = string.split(LocaleId, "-")[2]
		
		if CountryCode then
			CountryCode = string.upper(CountryCode)
		end
		
		self.user = {
			id = Player.UserId,
			username = Player.Name,
			data = {
				AccountAge = Player.AccountAge,
				Character = (Player.Character ~= nil),
				MembershipType = Player.MembershipType.Name,
				Team = if Player.Team then tostring(Player.Team) else nil,
			},
			
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


--[=[
]=]
function Scope:SetExtra(Key: string, Value: Defaults.ValidJSONValues)
	self.extra[Key] = Value
end

--[=[
]=]
function Scope:SetExtras(Dictionary: {[string]: Defaults.ValidJSONValues})
	for Key, Value in next, Dictionary do
		self.extra[Key] = Value
	end
end


--[=[
]=]
function Scope:SetTag(Key: string, Value: Defaults.ValidJSONValues)
	self.tags[Key] = Value
end

--[=[
]=]
function Scope:SetTags(Dictionary: {[string]: Defaults.ValidJSONValues})
	for Key, Value in next, Dictionary do
		self.tags[Key] = Value
	end
end


--[=[
]=]
function Scope:SetContext(Key: string, Value: Defaults.ValidJSONValues)
	self.contexts[Key] = Value
end

--[=[
]=]
function Scope:SetLevel(Level: Defaults.Level)
	self.level = Level
end

--[=[
]=]
function Scope:SetTranSaction(TransactionName: string)
	self.transaction = TransactionName
end

--[=[
]=]
function Scope:SetFingerprint(Fingerprint: {string})
	self.fingerprint = Fingerprint
end


--[=[
	@param Processor (Event, Hint) -> (Event)
]=]
function Scope:AddEventProcessor(Processor)
	table.insert(self._event_processors, Processor)
end


--[=[
]=]
function Scope:Clear()
	local EmptyScope = Scope.new()
	
	for Key, Value in next, self do
		rawset(self, Key, rawget(EmptyScope, Key))
	end
end

--[=[
]=]
function Scope:Clone()
	return setmetatable(table.clone(self), Scope)
end


--[=[
	@unreleased
	@param Breadcrumb Breadcrumb
]=]
function Scope:AddBreadcrumb(Breadcrumb)
	print([[WIP: The function "Scope:AddBreadcrumb" is not yet implemented.]])
end

--[=[
	@unreleased
]=]
function Scope:ClearBreadcrumbs()
	print([[WIP: The function "Scope:ClearBreadcrumbs" is not yet implemented.]])
end


--[=[
	@param Event Event
	@param Hint Hint
]=]
function Scope:ApplyToEvent(Event: Defaults.Event, Hint): Defaults.Event
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

export type Scope = typeof(Scope.new())

return table.freeze(Scope)