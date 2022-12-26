--!nonstrict
--// Initialization

local Types = require(script.Parent.Parent:WaitForChild("Types"))

--[=[
	@class Scope
]=]
local Scope = {}
Scope.__index = Scope

--// Functions

--[=[
	Adds information of the given player to each event sent.
	Only one user may be associated with a Scope at any given time. Calling this method will override the current user.
	When no player is provided, any existing player information is removed.
	
	The `UserId`, `Name` and country-code of the player is sent.
]=]
function Scope:SetUser(Player: Player?)
	if Player then
		self.user = {
			id = Player.UserId,
			name = Player.Name,
			
			geo = {
				country_code = string.split(Player.LocaleId, "-")[2],
			},
		}
	else
		self.user = nil
	end
end

--[=[
]=]
function Scope:SetExtra(Key: string, Value: any)
	self.extra[Key] = Value
end

--[=[
]=]
function Scope:SetTag(Key: string, Value: any)
	self.tags[Key] = Value
end

--[=[
]=]
function Scope:SetTags(Dictionary: {[string]: any})
	for Key, Value in next, Dictionary do
		self.tags[Key] = Value
	end
end

--[=[
]=]
function Scope:SetContext(Key: string, Value: any)
	self.contexts[Key] = Value
end

--[=[
]=]
function Scope:SetLevel(Level: Types.EventLevel)
	self.level = Level
end

--[=[
]=]
function Scope:SetTransaction(TransactionName: string)
	rawset(self, "transaction", TransactionName)
end

--[=[
]=]
function Scope:SetFingerprint(Fingerprint: {string})
	rawset(self, "fingerprint", Fingerprint)
end

function Scope:AddEventProcessor(Processor: (Types.EventPayload) -> (Types.EventPayload?))
	print([[WIP: The function "Scope:AddEventProcessor" is not yet implemented.]])
end

function Scope:AddErrorProcessor(Processor: (Types.EventPayload) -> (Types.EventPayload?))
	print([[WIP: The function "Scope:AddErrorProcessor" is not yet implemented.]])
end

function Scope:Clear()
	print([[WIP: The function "Scope:Clear" is not yet implemented.]])
end

function Scope:AddBreadcrumb(Breadcrumb)
	print([[WIP: The function "Scope:AddBreadcrumb" is not yet implemented.]])
end

function Scope:ClearBreadcrumbs()
	print([[WIP: The function "Scope:ClearBreadcrumbs" is not yet implemented.]])
end

function Scope:ApplyToEvent(Event: Types.EventPayload, MaxBreadcrumbs: number?)
	print([[WIP: The function "Scope:ApplyToEvent" is not yet implemented.]])
end

return Scope