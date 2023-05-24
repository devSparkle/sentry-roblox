--!nocheck
--// Initialization

local SentrySDK = require(script.Parent.Parent)
local SentryClient = script:FindFirstChild("SentryClient")
local RemoteEvent = script:FindFirstChild("RemoteEvent")

local Module = {}
Module.Name = script.Name

--// Functions

RemoteEvent.OnServerEvent:Connect(function(Player, Event, Hint)
	if not SentryClient.Enabled then
		return
	end
	
	SentrySDK:GetCurrentHub():Clone():ConfigureScope(function(Scope)
		Scope.logger = "client"
		Scope:SetUser(Player)
	end):CaptureEvent(Event, Hint)
end)

function Module:SetupOnce(AddGlobalEventProcessor, CurrentHub)
	SentryClient.Enabled = true
end

return Module