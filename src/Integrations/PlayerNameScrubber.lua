--!nocheck
--// Initialization

local PlayerService = game:GetService("Players")

local Module = {}
Module.Name = script.Name

--// Functions

local function GetPlayerNames()
	local PlayerNames = {}
	
	for _, Player in next, PlayerService:GetPlayers() do
		table.insert(PlayerNames, Player.Name)
	end
	
	table.sort(PlayerNames, function(A, B)
		return #A > #B
	end)
	
	return PlayerNames
end

local function ScrubTable(Table, PlayerName, Replacement): boolean
	local DidReplace = false
	
	for Index, Value in next, Table do
		if typeof(Value) == "string" then
			local Occurences
			
			Table[Index], Occurences = string.gsub(Value, PlayerName, Replacement)
			
			if Occurences > 0 then
				DidReplace = true
			end
		elseif typeof(Value) == "table" then
			if ScrubTable(Value, PlayerName, Replacement) then
				DidReplace = true
			end
		end
	end
	
	return DidReplace
end

function Module:SetupOnce(AddGlobalEventProcessor, CurrentHub)
	local SendDefaultPII = (if CurrentHub.Options then CurrentHub.Options.SendDefaultPII else false)
	
	AddGlobalEventProcessor(function(Event, Hint)
		local EventUser = if Event.user then Event.user.username else nil
		local PlayerNames = GetPlayerNames()
		local OccuringPlayers = {}
		
		for _, PlayerName in ipairs(PlayerNames) do
			if ScrubTable(Event, PlayerName, `<PLAYER{#OccuringPlayers + 1}>`) then
				table.insert(OccuringPlayers, PlayerName)
			end
		end
		
		if SendDefaultPII and #OccuringPlayers == 1 then
			ScrubTable(Event, "<PLAYER1>", "<PLAYER>")
			
			if Event.user then
				Event.user.username = OccuringPlayers[1]
			else
				local Player = PlayerService:FindFirstChild(OccuringPlayers[1])
				if not Player then return end
				if not Player:IsA("Player") then return end
				
				local CountryCode = string.split(Player.LocaleId, "-")[2]
				
				Event.user = {
					id = Player.UserId,
					username = Player.Name,
					
					geo = {
						city = "Unknown",
						country_code = CountryCode,
						region = CountryCode,
					},
				}
			end
		elseif SendDefaultPII and EventUser then
			ScrubTable(Event, `<PLAYER{table.find(OccuringPlayers, EventUser) or 0}>`, "<PLAYER>")
		end
		
		return Event
	end)
end

return Module