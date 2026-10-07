local Policy = require(script.Parent.Detection.Policy)
local Types = require(script.Parent:WaitForChild("Types"))
local Protocol = require(script:WaitForChild("Protocol"))

export type Options = {
	Burst: number?,
	Window: number?,
	MaximumStringLength: number?,
	MaximumFrames: number?,
}

local function SentryClientRelay(Options: Options?): Types.Integration
	local Settings: Options = Options or {}

	return {
		Name = "SentryClientRelay",
		Realm = "Server",
		Setup = function(Context: Types.Context)
			local SdkOptions = Context.Options

			if SdkOptions ~= nil and SdkOptions.SendClientEvents == false then return nil end

			local Players = Context.Services.Players
			local Clock = Context.Services.Clock or os.clock

			local Existing = script:FindFirstChild("RemoteEvent")
			local Remote: RemoteEvent

			if Existing ~= nil and Existing:IsA("RemoteEvent") then
				Remote = Existing
			else
				Remote = Instance.new("RemoteEvent")
				Remote.Name = "RemoteEvent"
				Remote.Parent = script
			end

			local Limiter = Protocol.Limiter(Settings.Burst or 20, Settings.Window or 10)

			local Limits = {
				MaximumStringLength = Settings.MaximumStringLength,
				MaximumFrames = Settings.MaximumFrames,
			}

			local function IsAcceptable(Clean: any): boolean
				if Policy.IsInternalText(Clean.traceback) then return false end

				local Exceptions = Clean.event.exception

				if Exceptions ~= nil then
					for _, Exception in Exceptions do
						if Policy.IsInternalText(Exception.value) then return false end
					end
				end

				local Message = Clean.event.message

				if Message ~= nil and Policy.IsInternalText(Message.message) then return false end

				return true
			end

			local Connections = {}

			table.insert(
				Connections,
				Remote.OnServerEvent:Connect(function(Player: Player, Envelope: any)
					if not Protocol.Allow(Limiter, Player, Clock()) then return end

					local Valid = Protocol.ValidateEnvelope(Envelope)

					if not Valid then return end

					local Clean = Protocol.SanitizeEnvelope(Envelope, Limits)

					if not IsAcceptable(Clean) then return end

					local Hub = Context.Hub:Clone()

					Hub:ConfigureScope(function(Scope: any)
						Scope.logger = "client"
						Scope:SetUser(Player)
					end)

					Hub:CaptureEvent(Clean.event, {
						traceback = Clean.traceback,
						client = true,
						thread_id = Player.UserId,
					})
				end)
			)

			table.insert(
				Connections,
				Players.PlayerRemoving:Connect(function(Player: Player)
					Protocol.Forget(Limiter, Player)
				end)
			)

			return function()
				for _, Connection in Connections do
					Connection:Disconnect()
				end
			end
		end,
	}
end

return SentryClientRelay
