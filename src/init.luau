--!nocheck
--// Initialization

local RunService = game:GetService("RunService")

local Hub = require("@self/Hub")
local HubClass = require(script:WaitForChild("Hub"))
local Defaults = require(script:WaitForChild("Defaults"))
local IntegrationsFolder = script:WaitForChild("Integrations")

--- @class SDK
export type SDK = {
	Init: (self: SDK, Options: Defaults.Options?) -> (),
}

export type HttpResponse = {
	Body: string,
	Headers: { [string]: string },
	StatusCode: number,
	StatusMessage: string,
	Success: boolean,
}

-- this is done because typechecking will explode
-- please roblox add extends i beg.
export type Hub = {
	Client: HubClass.Client,
	Scope: HubClass.Scope,
	Clone: (self: SDK) -> Hub,
	GetCurrentHub: (self: SDK) -> Hub,
	CaptureEvent: (self: SDK, Event: Defaults.Event, Hint: any) -> HttpResponse,
	CaptureMessage: (self: SDK, Message: string, Level: Defaults.Level?) -> HttpResponse,
	CaptureException: (self: SDK, Exception: string?) -> HttpResponse,
	PushScope: (self: SDK) -> (Hub, () -> ()),
	PopScope: (self: SDK) -> Hub,
	ConfigureScope: (self: SDK, Callback: (Scope: HubClass.Scope) -> ()) -> Hub,
	GetClient: (self: SDK) -> HubClass.Client,
	BindClient: (self: SDK, Client: any?) -> (),
	UnbindClient: (self: SDK) -> (),
	StartSession: (self: SDK) -> (),
	EndSession: (self: SDK) -> (),
}

local SDK = setmetatable({}, { __index = HubClass.new() }) :: SDK & Hub

--// Variables

HubClass.SDK_INTERFACE = table.freeze({
	name = "sentry.roblox.devsparkle",
	version = "1.2.1",
})

local SENTRY_PROTOCOL_VERSION = 7
local SENTRY_CLIENT = string.format("%s/%s", SDK.SDK_INTERFACE.name, SDK.SDK_INTERFACE.version)

--// Functions

--[=[
	@param Options Options
]=]
function SDK:Init(Options: Defaults.Options?)
	if not Options then
		return
	end
	if not Options.DSN then
		return
	end
	if not RunService:IsServer() then
		return
	end
	
	HubClass.Options = table.freeze(Defaults:AggregateDictionaries(Defaults.Options, Options))
	
	self.Options.Transport:Init(self.Options, SENTRY_PROTOCOL_VERSION, SENTRY_CLIENT)
	self.Scope:ConfigureScope(function(Scope)
		Scope.server_name = self.Options.ServerName
		Scope.logger = "server"
		
		Scope.release = self.Options.Release
		Scope.environment = self.Options.Environment
		Scope.dist = tostring(game.PlaceVersion)
	end)
	
	if self.Options.DefaultIntegrations then
		for _, Child in next, IntegrationsFolder:GetChildren() do
			table.insert(self.Options.Integrations, Child)
		end
	end
	
	for _, Integration in next, self.Options.Integrations do
		task.spawn(function()
			require(Integration):SetupOnce(self.Scope._AddGlobalEventProcessor, SDK:GetCurrentHub())
		end)
	end
end

return SDK