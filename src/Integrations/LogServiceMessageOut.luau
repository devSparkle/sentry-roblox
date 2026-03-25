--!nocheck
--// Initialization

local LogService = game:GetService("LogService")

local Module = {}
Module.Name = script.Name

--// Functions
local function has_match(list: { string }, message: string): boolean
	for _, pattern in list do
		if string.match(message, pattern) or string.find(message, pattern) then
			return true
		end
	end
	return false
end

function Module:SetupOnce(AddGlobalEventProcessor, CurrentHub)
	LogService.MessageOut:Connect(function(Message, MessageType)
		if string.find(Message, "SentrySDK") then
			return
		end

		if CurrentHub.Options then
			local CaptureFilterMode = CurrentHub.Options.CaptureFilterMode
			if
				CaptureFilterMode == "whitelist"
				and CurrentHub.Options.WhitelistOutput
				and has_match(CurrentHub.Options.WhitelistOutput, Message)
			then
				return
			end

			if
				CaptureFilterMode == "blacklist"
				and CurrentHub.Options.BlacklistOutput
				and not has_match(CurrentHub.Options.BlacklistOutput, Message)
			then
				return
			end
		end

		if MessageType == Enum.MessageType.MessageWarning then
			CurrentHub:CaptureMessage(Message, "warning")
			--	elseif MessageType == Enum.MessageType.MessageInfo then
			--		CurrentHub:CaptureMessage(Message, "info")
			--	elseif MessageType == Enum.MessageType.MessageOutput then
			--		CurrentHub:CaptureMessage(Message, "debug")
		end
	end)
end

return Module
