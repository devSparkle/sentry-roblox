--!nocheck
--// Initialization

local PlayerService = game:GetService("Players")

local RemoteEvent = script.Parent:WaitForChild("RemoteEvent")
local SentrySDK = require(script.Parent.Parent.Parent)

--// Functions

for _, Integration in next, {"ScriptContextError", "LogServiceMessageOut", "StackProcessor"} do
	require(script.Parent.Parent:WaitForChild(Integration)):SetupOnce(SentrySDK.Scope._AddGlobalEventProcessor, SentrySDK:GetCurrentHub())
end

SentrySDK:ConfigureScope(function(Scope)
	Scope.logger = "client"
	Scope:SetUser(PlayerService.LocalPlayer)
	Scope._AddGlobalEventProcessor(function(Event, Hint)
		RemoteEvent:FireServer(Event, Hint)
		
		return nil
	end)
end)