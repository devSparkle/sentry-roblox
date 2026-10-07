local Players = game:GetService("Players")
local LocalizationService = game:GetService("LocalizationService")

local Types = require(script.Parent.Parent:WaitForChild("Types"))
local Table = require(script.Parent.Parent:WaitForChild("Utility"):WaitForChild("Table"))
local Processors = require(script.Parent:WaitForChild("Processors"))

local Scope = {}
local Metatable = { __index = Scope }

local BreadcrumbLimit = 100
local BreadcrumbFilter: Types.Filter<Types.Breadcrumb>? = nil
local IncludeIdentity = false

local PreservedOnClear = { "release", "environment", "server_name", "dist", "logger" }

function Scope.SetBreadcrumbLimit(Limit: number): ()
	BreadcrumbLimit = math.max(math.floor(Limit), 0)
end

function Scope.SetBreadcrumbFilter(Filter: Types.Filter<Types.Breadcrumb>?): ()
	BreadcrumbFilter = Filter
end

function Scope.SetDefaultPII(Enabled: boolean): ()
	IncludeIdentity = Enabled
end

function Scope.new(): Types.Scope
	local Extra: { [string]: any } = {}
	local Contexts: { [string]: { [string]: any } } = {}
	local Tags: { [string]: string } = {}
	local Breadcrumbs: { Types.Breadcrumb } = {}
	local EventProcessors: { Types.Processor } = {}

	local Level: Types.Level? = nil
	local Transaction: string? = nil
	local Fingerprint: { string }? = nil
	local User: Types.User? = nil
	local Release: string? = nil
	local Environment: string? = nil
	local ServerName: string? = nil
	local Logger: string? = nil
	local Dist: string? = nil
	local Session: Types.Session? = nil

	return setmetatable({
		extra = Extra,
		contexts = Contexts,
		tags = Tags,
		breadcrumbs = Breadcrumbs,

		level = Level,
		transaction = Transaction,
		fingerprint = Fingerprint,
		user = User,
		release = Release,
		environment = Environment,
		server_name = ServerName,
		logger = Logger,
		dist = Dist,

		_event_processors = EventProcessors,
		_session = Session,
	}, Metatable) :: any
end

function Scope.ConfigureScope(self: Types.Scope, Callback: (Types.Scope) -> ()): ()
	Callback(self)
end

function Scope.SetUser(self: Types.Scope, User: Player | number | nil, Identity: boolean?): ()
	if User == nil then
		self.user = nil

		return
	end

	if type(User) == "number" then
		self.user = { id = User }

		return
	end

	local Subject = User :: Player

	if not (if Identity ~= nil then Identity else IncludeIdentity) then
		self.user = { id = Subject.UserId }

		return
	end

	local LocaleId = (if Subject == Players.LocalPlayer then LocalizationService.SystemLocaleId else Subject.LocaleId)

	local CountryCode = string.split(LocaleId, "-")[2]

	if CountryCode ~= nil then CountryCode = string.upper(CountryCode) end

	self.user = {
		id = Subject.UserId,
		username = Subject.Name,
		data = {
			AccountAge = Subject.AccountAge,
			MembershipType = Subject.MembershipType.Name,
			Team = (if Subject.Team then tostring(Subject.Team) else nil),
		},
		geo = {
			city = "Unknown",
			country_code = CountryCode,
			region = CountryCode,
		},
	}
end

function Scope.SetExtra(self: Types.Scope, Key: string, Value: any): ()
	self.extra[Key] = Value
end

function Scope.SetExtras(self: Types.Scope, Dictionary: { [string]: any }): ()
	for Key, Value in next, Dictionary do
		self.extra[Key] = Value
	end
end

function Scope.SetTag(self: Types.Scope, Key: string, Value: string | number | boolean): ()
	self.tags[Key] = tostring(Value)
end

function Scope.SetTags(self: Types.Scope, Dictionary: { [string]: string | number | boolean }): ()
	for Key, Value in next, Dictionary do
		self.tags[Key] = tostring(Value)
	end
end

function Scope.SetContext(self: Types.Scope, Key: string, Value: { [string]: any }): ()
	self.contexts[Key] = Value
end

function Scope.SetLevel(self: Types.Scope, Level: Types.Level): ()
	self.level = Level
end

function Scope.SetTransaction(self: Types.Scope, TransactionName: string): ()
	self.transaction = TransactionName
end

function Scope.SetFingerprint(self: Types.Scope, Fingerprint: { string }): ()
	self.fingerprint = Fingerprint
end

function Scope.SetSession(self: Types.Scope, Session: Types.Session?): ()
	self._session = Session
end

function Scope.AddEventProcessor(self: Types.Scope, Processor: Types.Processor): ()
	table.insert(self._event_processors, Processor)
end

function Scope.Clear(self: Types.Scope): ()
	local Fields = self :: { [any]: any }
	local Kept: { [string]: any } = {}

	for _, Key in PreservedOnClear do
		Kept[Key] = Fields[Key]
	end

	local Fresh = Scope.new()

	for Key in next, Fields do
		rawset(self, Key, nil)
	end

	for Key, Value in next, Fresh :: { [any]: any } do
		rawset(self, Key, Value)
	end

	for Key, Value in next, Kept do
		rawset(self, Key, Value)
	end
end

function Scope.Clone(self: Types.Scope): Types.Scope
	local Copy = Scope.new()

	for Key, Value in next, self :: { [any]: any } do
		rawset(Copy, Key, (if type(Value) == "table" then Table.DeepCopy(Value) else Value))
	end

	return Copy
end

function Scope.AddBreadcrumb(self: Types.Scope, Breadcrumb: Types.Breadcrumb, Hint: Types.Hint?): ()
	if BreadcrumbFilter ~= nil then
		local Success, Result = pcall(BreadcrumbFilter, Breadcrumb, Hint)

		if not Success or Result == nil then return end

		Breadcrumb = Result
	end

	if Breadcrumb.timestamp == nil then
		if table.isfrozen(Breadcrumb) then Breadcrumb = table.clone(Breadcrumb) end

		Breadcrumb.timestamp = DateTime.now().UnixTimestampMillis / 1000
	end

	table.insert(self.breadcrumbs, Breadcrumb)

	while #self.breadcrumbs > BreadcrumbLimit do
		table.remove(self.breadcrumbs, 1)
	end
end

function Scope.ClearBreadcrumbs(self: Types.Scope): ()
	table.clear(self.breadcrumbs)
end

function Scope.ApplyToEvent(self: Types.Scope, Event: Types.Event, Hint: Types.Hint?): Types.Event?
	local Fields = Event :: { [string]: any }

	for Key, Value in next, self :: { [any]: any } do
		if string.sub(Key, 1, 1) == "_" then continue end

		local Existing = Fields[Key]

		if type(Value) == "table" then
			Fields[Key] = if type(Existing) == "table" then Table.Merge(Existing, Value) else Table.DeepCopy(Value)
		else
			Fields[Key] = Value
		end
	end

	local Pipeline: { Types.Processor } = {}

	for _, Processor in Processors.List() do
		table.insert(Pipeline, Processor)
	end

	for _, Processor in self._event_processors do
		table.insert(Pipeline, Processor)
	end

	for _, Processor in Pipeline do
		local Success, Response = pcall(Processor, Event, Hint)

		if Success then
			if Response == nil then return nil end

			Event = Response
		else
			local Errors: { Types.EventError } = Event.errors or {}

			Event.errors = Errors

			table.insert(Errors, {
				type = "unknown_error",
				details = "Encountered error when calling an EventProcessor.",
				name = tostring(Response),
			})
		end
	end

	return Event
end

return Scope
