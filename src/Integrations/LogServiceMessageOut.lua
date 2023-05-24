--!nocheck
--// Initialization

local LogService = game:GetService("LogService")

local Module = {}
Module.Name = script.Name

--// Functions

function Module:SetupOnce(AddGlobalEventProcessor, CurrentHub)
	LogService.MessageOut:Connect(function(Message, MessageType)
		if string.find(Message, "SentrySDK") then
			return
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