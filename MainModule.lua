--!nonstrict
--// Initialization

local RunService = game:GetService("RunService")
local LogService = game:GetService("LogService")
local HttpService = game:GetService("HttpService")
local PlayerService = game:GetService("Players")
local ScriptContext = game:GetService("ScriptContext")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

--[=[
	@class SDK
]=]
local SDK = {}
SDK.__index = SDK

--[=[
	@class Hub
	@private
]=]
local Hub = setmetatable({}, SDK)
Hub.__index = Hub

--[=[
	@class Scope
]=]
local Scope = {}
Scope.__index = Scope

type EventLevel = "fatal" | "error" | "warning" | "info" | "debug"
type EventPayload = {
	event_id: string?,
	timestamp: string | number | nil,
	platform: "other" | nil,
	
	level: EventLevel?, --/ The record severity. Defaults to error.
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

--[=[
	@within SDK
	@interface HubOptions
	
	.DSN string -- The DSN for the sentry project to send events to
	.debug boolean? -- See [SDK.debug] (must press the "Show Private")
	
	.Release string? -- See [SDK.Release]
	.Environment string? -- See [SDK.Environment]
	
	.AutoTrackClient boolean? -- See [SDK.AutoTrackClient]
	.AutoErrorTracking boolean? -- See [SDK.AutoErrorTracking]
	.AutoWarningTracking boolean? -- See [SDK.AutoWarningTracking]
]=]

--[=[
@within SDK
@prop debug boolean?
@private

:::warning
 This property must be set in [SDK:Init] through the [HubOptions] table.
:::

Internal debug mode, prints info about the current state of the SDK when set to `true`
]=]

--[=[
@within SDK
@prop Release string?

:::warning
 This property must be set in [SDK:Init] through the [HubOptions] table.
:::

An arbitrary release identifier, used to determine the current version of the game.
This can be very useful to track which versions of the game are currently affected.

Should be in the format `GameName@1.2.3` using Semantic Versioning; although this
is not strictly enforced by the SDK or Sentry. The version must be unique in a sentry
organization.

:::info
Using the format `GameName@1.2.3` is recommended, as sentry will treat everything
after the `@` as the version number, and automatically adapt their UI to this format.
:::
]=]
--[=[
@within SDK
@prop Environment string?

:::warning
 This property must be set in [SDK:Init] through the [HubOptions] table.
:::

Arbitrary environment identifier. Defaults to `studio` or `live` as appropriate.
]=]

--[=[
@within SDK
@prop AutoTrackClient boolean?

:::warning
 This property must be set in [SDK:Init] through the [HubOptions] table.
:::

When not explicitly set to false, Sentry will automatically monitor the client-side console.
]=]
--[=[
@within SDK
@prop AutoErrorTracking boolean?

:::warning
 This property must be set in [SDK:Init] through the [HubOptions] table.
:::

When not explicitly set to false, Sentry will automatically monitor and report console errors.
]=]
--[=[
@within SDK
@prop AutoWarningTracking boolean?

:::warning
 This property must be set in [SDK:Init] through the [HubOptions] table.
:::

When not explicitly set to false, Sentry will automatically monitor and report console warnings.
]=]

type HubOptions = {
	DSN: string?,
	debug: boolean?,
	
	Release: string?,
	Environment: string?,
	
	AutoTrackClient: boolean?,
	AutoErrorTracking: boolean?,
	AutoWarningTracking: boolean?,
--	AutoSessionTracking: boolean?,
}

local RATE_LIMIT_UNTIL = 0

--// Variables

local SDK_INTERFACE = {
	name = "sentry.roblox.devsparkle",
	version = "0.2.0-dev",
}

local SENTRY_PROTOCOL_VERSION = 7
local SENTRY_CLIENT = string.format("%s/%s", SDK_INTERFACE.name, SDK_INTERFACE.version)

local CLIENT_RELAY_NAME = "SentryClientRelay"
local CLIENT_RELAY_PARENT = ReplicatedStorage

--// Functions

local function Close(self, ...)
	if self and self.Options and self.Options.Debug then
		print("Sentry Debug:", ...)
	end
	
	task.defer(task.cancel, coroutine.running())
	coroutine.yield()
end

local function RemovePlayerNamesFromString(String: string)
	for _, Player in next, PlayerService:GetPlayers() do
		String = string.gsub(String, Player.Name, "<RemovedPlayerName>")
	end
	
	return String
end

local function ConvertStacktraceToFrames(Stacktrace: string)
	if not Stacktrace then return end
	local StacktraceFrames = {}
	
	for Line in string.gmatch(RemovePlayerNamesFromString(Stacktrace), "[^\n\r]+") do
		if string.match(Line, "^Stack Begin$") then continue end
		if string.match(Line, "^Stack End$") then continue end
		
		table.insert(StacktraceFrames, 1, {
			module = Line,
		})
		
		--[[
		local Path, LineNumber, FunctionName
		
		if string.find(Line, "^Script ") then
			Path, LineNumber, FunctionName = string.match(
				Line, "^Script '(.-)', Line (%d+)%s?%-?%s?(.*)$"
			)
		else
			Path, LineNumber, FunctionName = string.match(
				Line, "^(.-), line (%d+)%s?%-?%s?(.*)$"
			)
		end
		
		if FunctionName then
			FunctionName = string.gsub(FunctionName, "function ", "")
		end
		
		if Path and LineNumber then
			table.insert(StacktraceFrames, 1, {
				["function"] = FunctionName or "Unknown",
				filename = Path,
				
				lineno = LineNumber,
				module = Path,
			})
		end
		--]]
	end
	
	if #StacktraceFrames > 0 then
		return StacktraceFrames
	end
	
	return nil
end

local function AggregateDictionaries(...)
	local Aggregate = {}
	
	for _, Dictionary in ipairs{...} do
		for Index, Value in next, Dictionary do
			if typeof(Value) == "table" and typeof(Aggregate[Index]) == "table" then
				Aggregate[Index] = AggregateDictionaries(Aggregate[Index], Value)
			else
				Aggregate[Index] = Value
			end
		end
	end
	
	return Aggregate
end

local function DispatchToServer(...)
	local RemoteEvent = CLIENT_RELAY_PARENT:FindFirstChild(CLIENT_RELAY_NAME):: RemoteEvent
	
	if RemoteEvent then
		RemoteEvent:FireServer(...)
	end
end

--[=[
	Adds information of the given player to each event sent.
	Only one user may be associated with a Scope at any given time. Calling this method will override the current user.
	When no player is provided, any existing player information is removed.
	
	The `UserId`, `Name` and country-code of the player is sent.
]=]
function Scope:SetUser(Player: Player?)
	if Player then
		self.user = {
			id = Player.UserId,
			name = Player.Name,
			
			geo = {
				country_code = string.split(Player.LocaleId, "-")[2],
			},
		}
	else
		self.user = nil
	end
end

--[=[
]=]
function Scope:SetExtra(Key: string, Value: any)
	self.extra[Key] = Value
end

--[=[
]=]
function Scope:SetTag(Key: string, Value: any)
	self.tags[Key] = Value
end

--[=[
]=]
function Scope:SetTags(Dictionary: {[string]: any})
	for Key, Value in next, Dictionary do
		self.tags[Key] = Value
	end
end

--[=[
]=]
function Scope:SetContext(Key: string, Value: any)
	self.contexts[Key] = Value
end

--[=[
]=]
function Scope:SetLevel(Level: EventLevel)
	self.level = Level
end

--[=[
]=]
function Scope:SetTransaction(TransactionName: string)
	rawset(self, "transaction", TransactionName)
end

--[=[
]=]
function Scope:SetFingerprint(Fingerprint: {string})
	rawset(self, "fingerprint", Fingerprint)
end

function Scope:AddEventProcessor(Processor: (EventPayload) -> (EventPayload?))
	print([[WIP: The function "Scope:AddEventProcessor" is not yet implemented.]])
end

function Scope:AddErrorProcessor(Processor: (EventPayload) -> (EventPayload?))
	print([[WIP: The function "Scope:AddErrorProcessor" is not yet implemented.]])
end

function Scope:Clear()
	print([[WIP: The function "Scope:Clear" is not yet implemented.]])
end

function Scope:AddBreadcrumb(Breadcrumb)
	print([[WIP: The function "Scope:AddBreadcrumb" is not yet implemented.]])
end

function Scope:ClearBreadcrumbs()
	print([[WIP: The function "Scope:ClearBreadcrumbs" is not yet implemented.]])
end

function Scope:ApplyToEvent(Event: EventPayload, MaxBreadcrumbs: number?)
	print([[WIP: The function "Scope:ApplyToEvent" is not yet implemented.]])
end

local function DetermineRateLimit(RawTimeout: unknown)
	local Timeout = tonumber(RawTimeout) or 60
	--/ The timeout defaults to 60, in case its not provided by sentry, as per sentry's guidelines
	
	RATE_LIMIT_UNTIL = (os.clock() + Timeout)
	--/ os.clock() is used in favour of time(), so that this SDK may be used in studio plugins
end

--[=[
]=]
function SDK:CaptureEvent(Event: EventPayload)
	if os.clock() < RATE_LIMIT_UNTIL then return print("RATE LIMITING!") end
	if not self.BaseUrl then return end
	if not Event then return end
	
	task.spawn(function()
		local Payload: EventPayload = AggregateDictionaries(self.Scope, {
			event_id = string.gsub(HttpService:GenerateGUID(false), "-", ""),
			timestamp = DateTime.now().UnixTimestamp,
			platform = "other",
			
			sdk = SDK_INTERFACE,
		}, Event)
		
		local EncodeSuccess, EncodedPayload = pcall(HttpService.JSONEncode, HttpService, Payload)
		if not EncodeSuccess then
			Close(self, "Failed to encode Sentry payload, exited with error:", EncodedPayload)
		end
		
		local Request = {
			Url = self.BaseUrl .. "/store/",
			Method = "POST",
			Headers = {
				["Content-Type"] = "application/json",
				["X-Sentry-Auth"] = self.AuthHeader
			},
			
			Body = EncodedPayload,
		}
		
		local RequestSuccess, RequestResult = pcall(HttpService.RequestAsync, HttpService, Request)
		if not RequestSuccess then
			Close(self, "RequestAsync failed, exited with error:", RequestResult)
		elseif RequestResult.Headers["X-Sentry-Rate-Limits"] then
			DetermineRateLimit(RequestResult.Headers["X-Sentry-Rate-Limits"])
		elseif RequestResult.StatusCode == 429 then
			DetermineRateLimit(RequestResult.Headers["Retry-After"])
		end
	end)
end

--[=[
]=]
function SDK:CaptureMessage(Message: string, Level: EventLevel?)
	if RunService:IsClient() then
		return DispatchToServer("Message", Message, Level)
	end
	
	return self:CaptureEvent{
		level = Level or "info",
		message = {
			formatted = RemovePlayerNamesFromString(Message),
			message = Message,
		}
	}
end

--[=[
]=]
function SDK:CaptureException(Exception: string, Stacktrace: string?, Origin: LuaSourceContainer)
	if RunService:IsClient() then
		return DispatchToServer("Exception", Exception, Stacktrace, Origin)
	end
	
	Exception = string.match(Exception, ":%d+: (.+)") or Exception
	
	local Frames = ConvertStacktraceToFrames(Stacktrace or debug.traceback())
	local Event: EventPayload = {
		exception = {
			type = Exception,
			module = (if Origin then Origin.Name else nil),
		}
	}
	
	if Frames and Event.exception then
		Event.exception.stacktrace = {
			frames = Frames
		}
	else
		Event.errors = {{
			type = "invalid_data",
			details = "Failed to convert stracktrace or traceback to frames."
		}}
	end
	
	return self:CaptureEvent(Event)
end

--[=[
	@param Callback any
]=]
function SDK:ConfigureScope(Callback)
	if typeof(Callback) == "function" then
		Callback(self.Scope)
	else
		self.Scope = AggregateDictionaries(self.Scope, Callback)
	end
end


function SDK:StartSession()
	if not self.BaseUrl then return end
	if not self.Scope.user then return end
	
	task.spawn(function()
		local CurrentTime = DateTime.now()
		local Payload = HttpService:JSONEncode({
			sid = self.Scope.user.sid,
			did = tostring(self.Scope.user.id),
			seq = CurrentTime.UnixTimestampMillis,
			timestamp = CurrentTime:ToIsoDate(),
			started = self.Scope.user.started:ToIsoDate(),
			init = true,
			
			status = "ok",
			
			attrs = {
				release = self.Scope.release,
				environment = self.Scope.environment,
			}
		})
		
		local Envelope = HttpService:JSONEncode({event_id = HttpService:GenerateGUID(false)})
		local Item = HttpService:JSONEncode({type = "session", length = #Payload})
		
		local Request = {
			Url = self.BaseUrl .. "/envelope/",
			Method = "POST",
			Headers = {
				["Content-Type"] = "application/x-sentry-envelope",
				["X-Sentry-Auth"] = self.AuthHeader
			},
			
			Body = table.concat({Envelope, Item, Payload}, "\n"),
		}
		
		local RequestSuccess, RequestResult = pcall(HttpService.RequestAsync, HttpService, Request)
	end)
end

function SDK:EndSession()
	if not self.BaseUrl then return end
	if not self.Scope.user then return end
	
	task.spawn(function()
		local CurrentTime = DateTime.now()
		local Payload = HttpService:JSONEncode({
			sid = self.Scope.user.sid,
			did = tostring(self.Scope.user.id),
			seq = CurrentTime.UnixTimestampMillis,
			timestamp = CurrentTime:ToIsoDate(),
			started = self.Scope.user.started:ToIsoDate(),
			
			status = "exited",
			
			attrs = {
				release = self.Scope.release,
				environment = self.Scope.environment,
			}
		})
		
		local Envelope = HttpService:JSONEncode({event_id = HttpService:GenerateGUID(false)})
		local Item = HttpService:JSONEncode({type = "session", length = #Payload})
		
		local Request = {
			Url = self.BaseUrl .. "/envelope/",
			Method = "POST",
			Headers = {
				["Content-Type"] = "application/x-sentry-envelope",
				["X-Sentry-Auth"] = self.AuthHeader
			},
			
			Body = table.concat({Envelope, Item, Payload}, "\n"),
		}
		
		local RequestSuccess, RequestResult = pcall(HttpService.RequestAsync, HttpService, Request)
	end)
end


--[=[
	@return Hub
]=]

function SDK:New()
	local self = setmetatable({}, Hub)
	
	self.Options = table.clone(self.Options or {})
	
	return self
end

--[=[
	@return SDK
]=]
function SDK:Init(Options: HubOptions?)
	if RunService:IsClient() then
		if not Options or Options.AutoErrorTracking ~= false then
			ScriptContext.Error:Connect(function(Message, StackTrace, Origin)
				self:CaptureException(Message, StackTrace, Origin)
			end)
		end
		
		if not Options or Options.AutoWarningTracking ~= false then
			LogService.MessageOut:Connect(function(Message, MessageType)
				if MessageType == Enum.MessageType.MessageWarning then
					self:CaptureMessage(Message, "warning")
				end
			end)
		end
		
		return
	end
	
	assert(Options, "Init was called without Options.")
	assert(Options.DSN, "Init was called without a DSN.")
	
	local Scheme, PublicKey, Authority, ProjectId = string.match(Options.DSN, "^([^:]+)://([^:]+)@([^/]+)/(.+)$")
	
	assert(Scheme, "Invalid Sentry DSN: Scheme not found.")
	assert(string.match(string.lower(Scheme), "^https?$"), "Invalid Sentry DSN: Scheme not valid.")
	
	assert(PublicKey, "Invalid Sentry DSN: Public Key not found.")
	assert(Authority, "Invalid Sentry DSN: Authority not found.")
	assert(ProjectId, "Invalid Sentry DSN: Project ID not found.")
	
	self.BaseUrl = string.format("%s://%s/api/%d/", Scheme, Authority, ProjectId)
	self.AuthHeader = string.format(
		"Sentry sentry_key=%s,sentry_version=%d,sentry_client=%s",
		PublicKey, SENTRY_PROTOCOL_VERSION, SENTRY_CLIENT
	)
	
	self.Options = table.freeze(Options)
	self.Scope = setmetatable({
		server_name = game.JobId ~= "" and game.JobId or "N/A",
		release = self.Options.Release,
		
		logger = "server",
		environment = 
			self.Options.Environment
			or (if RunService:IsStudio() then "studio" else "live"),
	}, Scope)
	
	if game.PlaceVersion ~= 0 then
		self.Scope.dist = tostring(game.PlaceVersion)
		self.Scope.release = self.Scope.release or string.format("%s#%d@%d", game.Name, game.PlaceId, game.PlaceVersion)
	end
	
	if self.Options.AutoErrorTracking ~= false then
		local ExceptionHub = self:New()
		ExceptionHub:ConfigureScope({exception = {mechanism = {
			type = "autoerrortracking",
			handled = false,
		}}})
		
		ScriptContext.Error:Connect(function(Message, StackTrace, Origin)
			ExceptionHub:CaptureException(Message, StackTrace, Origin)
		end)
	end
	
	if self.Options.AutoWarningTracking ~= false then
		LogService.MessageOut:Connect(function(Message, MessageType)
			if MessageType == Enum.MessageType.MessageWarning then
				self:CaptureMessage(Message, "warning")
			end
		end)
	end
	
	if self.Options.AutoTrackClient ~= false then
		local BlockedUsers = {}
		local function BlockPlayer(Player: Player)
			BlockedUsers[Player.UserId] = true
			return
		end
		
		self.ClientRelay = Instance.new("RemoteEvent")
		self.ClientRelay.Name = CLIENT_RELAY_NAME
		self.ClientRelay.Parent = CLIENT_RELAY_PARENT
		
		self.ClientRelay.OnServerEvent:Connect(function(Player, CallType: unknown, ...: unknown)
			if BlockedUsers[Player.UserId] then return end
			if type(CallType) ~= "string" then
				return BlockPlayer(Player)
			end
			
			local UserHub = self:New()
			UserHub:ConfigureScope(function(HubScope)
				HubScope.logger = "client"
				HubScope:SetUser(Player)
			end)
			
			if CallType == "Message" then
				local Message, Level = ...
				
				if type(Message) ~= "string" then return BlockPlayer(Player) end
				if type(Level) ~= "string" then return BlockPlayer(Player) end
				
				UserHub:CaptureMessage(Message, Level)
			elseif CallType == "Exception" then
				local Exception, Stacktrace, Origin = ...
				
				if type(Exception) ~= "string" then return BlockPlayer(Player) end
				if Stacktrace and type(Stacktrace) ~= "string" then return BlockPlayer(Player) end
				if Origin and typeof(Origin) ~= "Instance" then return BlockPlayer(Player) end
				
				UserHub:CaptureException(Exception, Stacktrace, Origin)
			end
		end)
	end
	
	if self.Options.AutoTrackSessions ~= false then
		local UserHubs = {}
		
		PlayerService.PlayerAdded:Connect(function(Player)
			local UserHub = self:New()
			UserHub:ConfigureScope(function(HubScope)
				HubScope:SetUser(Player)
				HubScope.user.sid = HttpService:GenerateGUID(false)
				HubScope.user.started = DateTime.now()
			end)
			
			UserHubs[Player] = UserHub
			UserHub:StartSession()
		end)
		
		PlayerService.PlayerRemoving:Connect(function(Player)
			local UserHub = UserHubs[Player]
			
			UserHubs[Player] = nil
			UserHub:EndSession()
		end)
	end
	
	return self
end

return SDK