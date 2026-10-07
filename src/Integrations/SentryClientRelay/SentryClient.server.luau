local RunService = game:GetService("RunService")
local ScriptContext = game:GetService("ScriptContext")
local LogService = game:GetService("LogService")

local Policy = require(script.Parent.Parent.Detection.Policy)

if not RunService:IsClient() then return end

local Relay = script.Parent:WaitForChild("RemoteEvent", 30)

if Relay == nil then return end

local LocationPrefix = "^[^:]+:%d+: (.+)$"
local SelfPattern = "SentryRoblox"

local function Forward(Event: any, TracebackText: string?): ()
	pcall(function()
		(Relay :: RemoteEvent):FireServer({
			event = Event,
			traceback = TracebackText,
		})
	end)
end

ScriptContext.Error:Connect(function(Message: string, TracebackText: string, Origin: any)
	local Keep = Policy.Decide(Origin, TracebackText, game)

	if not Keep then return end

	Forward({
		exception = {
			{
				type = "Error",
				value = string.match(Message, LocationPrefix) or Message,
			},
		},
	}, TracebackText)
end)

LogService.MessageOut:Connect(function(Message: string, MessageType: Enum.MessageType)
	if MessageType ~= Enum.MessageType.MessageWarning then return end

	if string.find(Message, SelfPattern, 1, true) ~= nil then return end

	if Policy.IsInternalText(Message) then return end

	Forward({
		message = {
			message = Message,
			formatted = Message,
		},
		level = "warning",
	})
end)
