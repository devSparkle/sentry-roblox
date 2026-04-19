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
			CurrentHub.Logger:Warn(Message, {origin="LogServiceMessageOut"})
	--	elseif MessageType == Enum.MessageType.MessageInfo then
	--		CurrentHub.Logger:Info(Message, {origin="LogServiceMessageOut"})
	--	elseif MessageType == Enum.MessageType.MessageOutput then
	--		CurrentHub.Logger:Debug(Message, {origin="LogServiceMessageOut"})
		end
	end)
end

return Module