--!nocheck
--// Initialization

local RunService = game:GetService("RunService")
local PlayerService = game:GetService("Players")

local HubClass = require(script:WaitForChild("Hub"))
local Defaults = require(script:WaitForChild("Defaults"))
local Transport = require(script:WaitForChild("Transport"))
local IntegrationsFolder = script:WaitForChild("Integrations")

--- @class SDK
local SDK = setmetatable({}, {__index = HubClass.new()})

--// Variables

HubClass.SDK_INTERFACE = table.freeze({
	name = "sentry.roblox.devsparkle",
	version = "1.0.0",
})

local SENTRY_PROTOCOL_VERSION = 7
local SENTRY_CLIENT = string.format("%s/%s", SDK.SDK_INTERFACE.name, SDK.SDK_INTERFACE.version)

--// Functions

--[=[
	@param Options Options
]=]
function SDK:Init(Options: Defaults.Options?)
	if not Options then return end
	if not Options.DSN then return end
	if not RunService:IsServer() then return end
	
	HubClass.Options = table.freeze(Defaults:AggregateDictionaries(Defaults.Options, Options))
	
	self.Options.Transport:Init(self.Options, SENTRY_PROTOCOL_VERSION, SENTRY_CLIENT)
	self.Scope:ConfigureScope(function(Scope)
		Scope.server_name = (if game.JobId ~= "" then game.JobId else "local")
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