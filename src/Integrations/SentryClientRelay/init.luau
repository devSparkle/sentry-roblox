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
	RemoteEvent.OnServerEvent:Connect(function(Player, EnvType, Event, Hint)
		if not SentryClient.Enabled then
			return
		end
		
		local newHub = SentrySDK:GetCurrentHub():Clone():ConfigureScope(function(Scope)
			Scope.logger = "client"
			Scope:SetUser(Player)
		end)

		if(EnvType == "event") then
			newHub:CaptureEvent(Event, Hint)
		end

		if(EnvType == "log") then
			-- Event = Client Log Payload
			newHub:_CaptureLog(Event)
		end
	end)
end

return Module