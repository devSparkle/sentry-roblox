--!nocheck
--// Initialization

local HttpService = game:GetService("HttpService")
local PlayerService = game:GetService("Players")

local Module = {}
Module.Name = script.Name

--// Functions

function Module:SetupOnce(AddGlobalEventProcessor, CurrentHub)
	local UserHubs = {}
	local function StartSession(Player: Player)
		local UserHub = CurrentHub:Clone()
		UserHub:ConfigureScope(function(HubScope)
			HubScope:SetUser(Player)
			HubScope.user.sid = HttpService:GenerateGUID(false)
			HubScope.user.started = DateTime.now()
		end)
		
		UserHubs[Player] = UserHub
		UserHub:StartSession()
	end
	
	for _, Player in next, PlayerService:GetPlayers() do
		task.spawn(StartSession, Player)
	end
	
	PlayerService.PlayerAdded:Connect(StartSession)
	PlayerService.PlayerRemoving:Connect(function(Player)
		local UserHub = UserHubs[Player]
		
		UserHubs[Player] = nil
		UserHub:EndSession()
	end)
end

return Module