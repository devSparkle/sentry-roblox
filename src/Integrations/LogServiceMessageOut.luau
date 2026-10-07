local Policy = require(script.Parent.Detection.Policy)
local Types = require(script.Parent:WaitForChild("Types"))

export type Options = {
	Levels: { string }?,
	IgnorePatterns: { string }?,
	SelfFilter: boolean?,
}

local DefaultLevels = { "MessageWarning" }

local LevelByMessageType: { [string]: Types.Level } = {
	MessageError = "error",
	MessageWarning = "warning",
	MessageInfo = "info",
	MessageOutput = "debug",
}

local SelfPattern = "SentryRoblox"

local function LogServiceMessageOut(Options: Options?): Types.Integration
	local Settings: Options = Options or {}
	local Levels: { string } = Settings.Levels or DefaultLevels
	local IgnorePatterns = Settings.IgnorePatterns or {}
	local SelfFilter = Settings.SelfFilter ~= false

	local function ShouldCapture(MessageType: Enum.MessageType): Types.Level?
		for _, Level in Levels do
			if MessageType.Name == Level then return LevelByMessageType[MessageType.Name] end
		end

		return nil
	end

	return {
		Name = "LogServiceMessageOut",
		Realm = "Shared",
		Setup = function(Context: Types.Context)
			local LogService = Context.Services.LogService

			local Connection = LogService.MessageOut:Connect(function(Message: string, MessageType: Enum.MessageType)
				local Level: Types.Level? = ShouldCapture(MessageType)

				if Level == nil then return end

				if SelfFilter and string.find(Message, SelfPattern, 1, true) ~= nil then return end

				if Policy.IsInternalText(Message) then return end

				if Policy.MatchesAny(Message, IgnorePatterns) then return end

				Context.Hub:CaptureMessage(Message, Level)
			end)

			return function()
				Connection:Disconnect()
			end
		end,
	}
end

return LogServiceMessageOut
