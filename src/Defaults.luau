local RunService = game:GetService("RunService")

local Types = require(script.Parent:WaitForChild("Types"))
local Transport = require(script.Parent:WaitForChild("Transport"))

local Defaults = {}

Defaults.Levels = { "fatal", "error", "warning", "info", "debug" } :: { Types.Level }

Defaults.Options = table.freeze({
	Debug = false,

	DefaultIntegrations = true,
	Integrations = {},

	Release = string.format("%d@%d", game.PlaceId, game.PlaceVersion),
	Environment = (if RunService:IsStudio() then "studio" else "production"),
	ServerName = (if game.JobId ~= "" then game.JobId else "local"),

	SendClientEvents = true,
	SendStudioEvents = false,
	SendDefaultPII = false,

	SampleRate = 1.0,
	MaxBreadcrumbs = 100,
	AttachStacktrace = false,

	InAppInclude = {},
	InAppExclude = {},

	Transport = Transport,
}) :: Types.Options

function Defaults.Resolve(Overrides: Types.Options?): Types.Options
	if Overrides == nil then return Defaults.Options end

	local Resolved = table.clone(Defaults.Options :: { [any]: any })

	for Key, Value in next, Overrides do
		if Value ~= nil then Resolved[Key] = Value end
	end

	return table.freeze(Resolved :: any) :: Types.Options
end

function Defaults.IsDebug(Options: Types.Options?): boolean
	return Options ~= nil and Options.Debug == true
end

return table.freeze(Defaults)
