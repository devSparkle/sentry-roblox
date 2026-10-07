local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")
local ScriptContext = game:GetService("ScriptContext")
local LogService = game:GetService("LogService")

local Constants = require(script:WaitForChild("Constants"))
local Defaults = require(script:WaitForChild("Defaults"))
local Types = require(script:WaitForChild("Types"))

local HubClass = require(script:WaitForChild("Hub"))
local ScopeClass = require(script:WaitForChild("Hub"):WaitForChild("Scope"))
local Processors = require(script:WaitForChild("Hub"):WaitForChild("Processors"))

local Integrations = require(script:WaitForChild("Integrations"))
local IntegrationTypes = require(script:WaitForChild("Integrations"):WaitForChild("Types"))

local ProtocolVersion = Constants.ProtocolVersion
local ClientName = Constants.Client()

export type SDK = Types.Hub & {
	Integrations: typeof(Integrations),
	Init: (self: SDK, Options: Types.Options?) -> (),
}

local SDK = (HubClass.new() :: any) :: SDK

SDK.Integrations = Integrations

local function Report(Message: string): ()
	if Defaults.IsDebug(SDK.Options) then warn(`[SentryRoblox] {Message}`) end
end

local Teardowns: { () -> () } = {}

local function Teardown(): ()
	for Index = #Teardowns, 1, -1 do
		local Ok, Err = pcall(Teardowns[Index] :: any)

		if not Ok then Report(`integration teardown failed: {tostring(Err)}`) end
	end

	table.clear(Teardowns)
end

local function BuildServices(): IntegrationTypes.Services
	return {
		Game = game,
		Players = Players,
		HttpService = HttpService,
		ScriptContext = ScriptContext,
		LogService = LogService,
		RunService = RunService,
		DateTime = DateTime,
		Clock = os.clock,
	}
end

local function ResolveIntegrations(Options: Types.Options): { IntegrationTypes.Integration }
	local Requested: { IntegrationTypes.Integration } = {}

	if Options.DefaultIntegrations ~= false then
		for _, Integration in Integrations.Defaults do
			table.insert(Requested, Integration)
		end
	end

	local Overrides = Options.Integrations

	if Overrides ~= nil then
		for _, Integration in Overrides do
			table.insert(Requested, Integration)
		end
	end

	return Requested
end

function SDK.Init(self: SDK, Options: Types.Options?): ()
	if Options == nil then return end

	local Dsn = Options.DSN

	if Dsn == nil or string.match(Dsn, "^%s*$") ~= nil then
		if Defaults.IsDebug(Options) then print("[SentryRoblox] no DSN configured, the SDK is inert") end

		return
	end

	local Resolved = Defaults.Resolve(Options)
	local Realm: Types.Realm = if RunService:IsServer() then "Server" else "Client"

	if Realm == "Client" then
		self.Options = Resolved

		Report("Init is server-only; the client half configures itself through the client relay.")

		return
	end

	local Transport = Resolved.Transport

	if Transport ~= nil then
		local Ok, Err = pcall(Transport.Init :: any, Transport, Resolved, ProtocolVersion, ClientName)

		if not Ok then
			if Defaults.IsDebug(Options) then print(`[SentryRoblox] {Err}`) end

			return
		end
	end

	self.Options = Resolved

	ScopeClass.SetBreadcrumbLimit(Resolved.MaxBreadcrumbs or 100)
	ScopeClass.SetBreadcrumbFilter(Resolved.BeforeBreadcrumb)
	ScopeClass.SetDefaultPII(Resolved.SendDefaultPII == true)

	self.Scope:ConfigureScope(function(Scope)
		Scope.server_name = Resolved.ServerName
		Scope.logger = "server"

		Scope.release = Resolved.Release
		Scope.environment = Resolved.Environment
		Scope.dist = tostring(game.PlaceVersion)
	end)

	Teardown()
	Processors.Clear()

	local Context: IntegrationTypes.Context = {
		Realm = Realm,
		Hub = self,
		Options = Resolved,
		AddProcessor = Processors.Add,
		Services = BuildServices(),
	}

	for _, Integration in ResolveIntegrations(Resolved) do
		if Integration.Realm ~= "Shared" and Integration.Realm ~= Realm then continue end

		local Success, Result = pcall(Integration.Setup, Context)

		if not Success then
			Report(`integration "{Integration.Name}" failed to set up: {tostring(Result)}`)
		elseif type(Result) == "function" then
			table.insert(Teardowns, Result)
		end
	end
end

return SDK
