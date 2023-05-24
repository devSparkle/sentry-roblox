--!nocheck
--// Initialization

local SentrySDK = require(script.Parent.Parent)
local SentryClient = script:FindFirstChild("SentryClient")

local Module = {}
Module.Name = script.Name

--// Functions

function Module:SetupOnce(AddGlobalEventProcessor, CurrentHub)
	local RemoteEvent = Instance.new("RemoteEvent")
	
	SentryClient.Enabled = true
	RemoteEvent.Parent = script
	RemoteEvent.OnServerEvent:Connect(function(Player, Event, Hint)
		if not SentryClient.Enabled then
			return
		end
		
		SentrySDK:GetCurrentHub():Clone():ConfigureScope(function(Scope)
			Scope.logger = "client"
			Scope:SetUser(Player)
		end):CaptureEvent(Event, Hint)
	end)
end

return Module