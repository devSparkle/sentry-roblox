--!nocheck
--// Initialization

local SentrySDK = require(script.Parent:WaitForChild("SentrySDK"))

SentrySDK:Init({
	DSN = "https://7ff547eb16d543e083befe3eae7cb403@sentry.unnamed.services/7",
})

local function Test1()
	SentrySDK:CaptureMessage("Test message")
	SentrySDK:CaptureException("Test exception")
	
	for _, Level in next, {"fatal", "error", "warning", "info", "debug"} do
		SentrySDK:CaptureMessage("Test message at severity: " .. Level, Level)
	end
end

local function Test2()
	game:GetService("Players").PlayerAdded:Connect(function(Player: Player)
		SentrySDK:GetCurrentHub():Clone():ConfigureScope(function(Scope)
			Scope:SetUser(Player)
		end):CaptureMessage("Test hub message")
	end)
end

local function Test3()
	local TestService = game:GetService("TestService")
	
	TestService:Message("TestService Message", script, 30)
	TestService:Warn(false, "TestService Warn", script, 31)
	print("print")
end

--task.spawn(Test1)
--task.spawn(Test2)
--task.spawn(Test3)