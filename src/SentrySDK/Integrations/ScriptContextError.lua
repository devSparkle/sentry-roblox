--!nocheck
--// Initialization

local ScriptContext = game:GetService("ScriptContext")

local Module = {}
Module.Name = script.Name

--// Functions

function Module:SetupOnce(AddGlobalEventProcessor, CurrentHub)
	local Hub = CurrentHub:Clone()
	
	Hub:ConfigureScope(function(Scope)
		Scope.exception = Scope.exception or {}
		Scope.exception.mechanism = Scope.exception.mechanism or {}
		
		Scope.exception.mechanism.type = "scriptcontext.error"
		Scope.exception.mechanism.handled = false
	end)
	
	ScriptContext.Error:Connect(function(Message, StackTrace, Origin)
		Hub:CaptureMessage(Message, "error")
	end)
end

return Module