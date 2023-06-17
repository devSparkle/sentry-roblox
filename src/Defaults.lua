--!nocheck
--// Variables

local RunService = game:GetService("RunService")

local Module = {}

type Hint = {[string]: any}
type Filter<T> = (T, Hint) -> (T?)

--[=[
	@within SDK
	@interface Options
	
	.DSN string? -- The DSN for the sentry project to send events to
	.debug boolean? -- See [SDK.debug] (must press the "Show Private")
	
	.DefaultIntegrations boolean? -- Whether to enable the built-in integrations. Defaults to true.
	.Integrations {Integration}?
	
	.Release string?
	.Environment string?
	
	.SampleRate number?
	
	.ServerName string? -- Defaults to `game.JobId` or `"local"`
]=]
export type Options = {
	DSN: string?,
	debug: boolean?,
	
	DefaultIntegrations: boolean?,
	Integrations: {ModuleScript}?,
	
	Release: string?,
	Environment: string?,
	
	SendClientEvents: boolean?,
	SendStudioEvents: boolean?,
	
	SampleRate: number?,
	MaxBreadcrumbs: number?,
	AttachStacktrace: boolean?,
	SendDefaultPII: boolean?,
	
	ServerName: string?,
	
	InAppInclude: {string}?,
	InAppExclude: {string}?,
	
	WithLocals: boolean?,
	
	BeforeSend: Filter<unknown>?,
--	BeforeSendTransaction: Filter<unknown>?,
	BeforeBreadcrumb: Filter<unknown>?,
	
	Transport: unknown,
	ShutdownTimeout: number?,
}

Module.Options = {
	Debug = false,
	
	DefaultIntegrations = true,
	Integrations = {},
	
	Release = string.format("%s#%d@%d", game.Name, game.PlaceId, game.PlaceVersion),
	Environment = (if RunService:IsStudio() then "studio" else "production"),
	
	SendClientEvents = true,
	SendStudioEvents = false,
	
	SampleRate = 1.0,
	MaxBreadcrumbs = 100,
	AttachStacktrace = false,
	SendDefaultPII = false,
	IncludeLocalVariables = true,
	
	ServerName = (if game.JobId ~= "" then game.JobId else "local"),
	
	InAppInclude = {},
	InAppExclude = {},
	
	WithLocals = true,
	
	Transport = require(script.Parent:WaitForChild("Transport")),
	ShutdownTimeout = 2,
}:: Options

Module.Levels = {"fatal", "error", "warning", "info", "debug"}

export type ValidJSONValues = string | number | boolean
export type Level = "fatal" | "error" | "warning" | "info" | "debug"
export type Event = {
	event_id: string?,
	timestamp: string | number | nil,
	platform: "other" | nil,
	
	level: Level?, --/ The record severity. Defaults to error.
	logger: string?, --/ The name of the logger which created the record.
	transaction: string?, --/ The name of the transaction which caused this exception.
	server_name: string?, --/ Identifies the host from which the event was recorded. Defaults to game.JobId
	release: string?, --/ The release version of the application. MUST BE UNIQUE ACROSS ORGANIZATION
	dist: string?, --/ The distribution of the application.
	
	tags: {[string]: string}?, --/ A map or list of tags for this event. Each tag must be less than 200 characters.
	environment: string?, --/ The environment name, such as production or staging.
	modules: {[string]: string}?, --/ A list of relevant modules and their versions.
	extra: {[string]: string}?, --/ An arbitrary mapping of additional metadata to store with the event.
	fingerprint: {string}?, --/ A list of strings used to dictate the deduplication of this event.
	
	contexts: {[string]: {[string]: any}}?,
	
	sdk: {
		name: string,
		version: string,
		integrations: {string}?,
		packages: {{
			name: string,
			version: string,
		}}?,
	}?,
	
	exception: {
		type: string?,
		value: string?,
		module: string?,
		thread_id: string?,
		
		mechanism: {
			data: {[string]: any}?,
			description: string?,
			handled: boolean?,
			help_link: string?,
			synthetic: boolean?,
			type: string?,
		}?,
		
		stacktrace: {
			frames: {},
			registers: {[string]: string}?,
		}?,
	}?,
	
	user: {
		id: number,
		username: string,
		
		geo: {
			city: string?,
			country_code: string, --/ Two-letter country code (ISO 3166-1 alpha-2).
			region: string?,
		}
	}?,
	
	message: {
		message: string,
		formatted: string?,
		params: {string}?,
	}?,
	
	errors: {{
		type: string,
		path: string?,
		details: string?,
	}}?,
}


--// Functions

function Module:IsValidLevel(Level: Level | unknown)
	return table.find(self.Levels, Level)
end

function Module:AggregateDictionaries(...)
	local Aggregate = {}
	
	for _, Dictionary in ipairs{...} do
		for Index, Value in next, Dictionary do
			if typeof(Value) == "table" and typeof(Aggregate[Index]) == "table" then
				Aggregate[Index] = self:AggregateDictionaries(Aggregate[Index], Value)
			else
				Aggregate[Index] = Value
			end
		end
	end
	
	return Aggregate
end

function Module:DeepCopy<T>(Table: T): T
	if type(Table) == "table" then
		local Table = setmetatable(table.clone(Table), getmetatable(Table))
		
		for Index, Value in next, Table do
			Table[self:DeepCopy(Index)] = self:DeepCopy(Value)
		end
	end
	
	return Table
end


function Module:OverlapTables<B, F>(Background: B, Foreground: F?): F & B
	return setmetatable(Foreground or {}, {__index = Background})
end

return table.freeze(Module)