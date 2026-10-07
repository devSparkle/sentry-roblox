local LogServiceMessageOut = require(script:WaitForChild("LogServiceMessageOut"))
local PlayerContext = require(script:WaitForChild("PlayerContext"))
local ScriptContextError = require(script:WaitForChild("ScriptContextError"))
local SentryClientRelay = require(script:WaitForChild("SentryClientRelay"))
local StackProcessor = require(script:WaitForChild("StackProcessor"))
local TrackSessions = require(script:WaitForChild("TrackSessions"))

local Integrations = {}

Integrations.LogServiceMessageOut = LogServiceMessageOut
Integrations.PlayerContext = PlayerContext
Integrations.ScriptContextError = ScriptContextError
Integrations.SentryClientRelay = SentryClientRelay
Integrations.StackProcessor = StackProcessor
Integrations.TrackSessions = TrackSessions

Integrations.Defaults = table.freeze({
	StackProcessor(),
	PlayerContext(),
	ScriptContextError(),
	LogServiceMessageOut(),
	TrackSessions(),
	SentryClientRelay(),
})

return table.freeze(Integrations)
