--!nocheck
--// Initialization

local SentrySDK = require(script.Parent:WaitForChild("SentrySDK"))

--// Functions

local function Test1()
	SentrySDK:CaptureMessage("Test client message")
	SentrySDK:CaptureException("Test client exception")
end

local function Test2()
	warn("Test!")
end

task.wait(3)
task.spawn(Test1)
--task.spawn(Test2)