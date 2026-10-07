local Types = require(script.Parent:WaitForChild("Types"))

export type Options = {
	TrackStudio: boolean?,
}

local function TrackSessions(Options: Options?): Types.Integration
	local Settings: Options = Options or {}

	return {
		Name = "TrackSessions",
		Realm = "Server",
		Setup = function(Context: Types.Context)
			local Players = Context.Services.Players
			local HttpService = Context.Services.HttpService
			local DateTime = Context.Services.DateTime
			local RunService = Context.Services.RunService

			local Sessions: { [Player]: Types.Hub } = {}
			local Connections: { RBXScriptConnection } = {}

			local function Start(Player: Player): ()
				if Sessions[Player] ~= nil then return end

				local Hub = Context.Hub:Clone()

				Hub:ConfigureScope(function(Scope: Types.Scope)
					Scope:SetUser(Player)
					Scope:SetSession({
						sid = HttpService:GenerateGUID(false),
						started = DateTime.now(),
					})
				end)

				Sessions[Player] = Hub
				Hub:StartSession()
			end

			local function Finish(Player: Player): ()
				local Hub = Sessions[Player]

				Sessions[Player] = nil

				if Hub == nil then return end

				task.spawn(function()
					Hub:EndSession()
				end)
			end

			for _, Player in Players:GetPlayers() do
				task.spawn(Start, Player)
			end

			table.insert(Connections, Players.PlayerAdded:Connect(Start))
			table.insert(Connections, Players.PlayerRemoving:Connect(Finish))

			if Settings.TrackStudio == true and RunService:IsStudio() then
				local First = Players:GetPlayers()[1]

				if First ~= nil then Start(First) end
			end

			return function()
				for _, Connection in Connections do
					Connection:Disconnect()
				end

				table.clear(Sessions)
			end
		end,
	}
end

return TrackSessions
