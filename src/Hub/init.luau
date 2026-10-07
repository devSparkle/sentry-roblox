local RunService = game:GetService("RunService")
local HttpService = game:GetService("HttpService")

local Defaults = require(script.Parent:WaitForChild("Defaults"))
local Types = require(script.Parent:WaitForChild("Types"))

local ClientClass = require(script:WaitForChild("Client"))
local ScopeClass = require(script:WaitForChild("Scope"))

local Hub = {}
local Metatable = { __index = Hub }

local InFlight = (setmetatable({}, { __mode = "k" }) :: any) :: { [thread]: boolean }
local StudioDropReported = false

function Hub.new(ClientInstance: Types.Client?, ScopeInstance: Types.Scope?, Options: Types.Options?): Types.Hub
	local Stack: { Types.Scope } = {}

	return setmetatable({
		Client = ClientInstance or ClientClass.new(),
		Scope = ScopeInstance or ScopeClass.new(),
		Options = Options,

		_scope_stack = Stack,
	}, Metatable) :: any
end

function Hub.Clone(self: Types.Hub): Types.Hub
	return Hub.new(self.Client, self.Scope:Clone(), self.Options)
end

function Hub.GetCurrentHub(self: Types.Hub): Types.Hub
	return self
end

function Hub.CaptureEvent(self: Types.Hub, Event: Types.Event, Hint: Types.Hint?): any
	if type(Event) ~= "table" then return end

	local Thread = coroutine.running()

	if InFlight[Thread] == true then return end

	local Options = self.Options

	if Options ~= nil then
		local SampleRate = Options.SampleRate

		if SampleRate ~= nil and (SampleRate <= 0 or math.random() > SampleRate) then return end

		if Options.SendStudioEvents == false and RunService:IsStudio() then
			if not StudioDropReported then
				StudioDropReported = true

				print("[SentryRoblox] dropping Studio events, set SendStudioEvents = true to test in Studio")
			end

			return
		end
	end

	InFlight[Thread] = true

	local Success, Result = pcall(function()
		return self.Client:CaptureEvent(Event, Hint, self.Scope, Options)
	end)

	InFlight[Thread] = nil

	if not Success then
		if Defaults.IsDebug(Options) then print(`[SentryRoblox] capture failed: {tostring(Result)}`) end

		return
	end

	return Result
end

function Hub.CaptureMessage(self: Types.Hub, Message: string, Level: Types.Level?): any
	local Options = self.Options
	local Hint: Types.Hint? = nil

	if Options ~= nil and Options.AttachStacktrace == true then Hint = { traceback = debug.traceback() } end

	return self:CaptureEvent({
		level = Level or "info",
		message = {
			formatted = Message,
			message = Message,
		},
	}, Hint)
end

function Hub.CaptureException(self: Types.Hub, ErrorMessage: string, TracebackText: string?): any
	local Thread = coroutine.running()
	local ThreadId = string.gsub(tostring(Thread), "thread: ", "")

	return self:CaptureEvent({
		exception = {
			{
				type = "Error",
				value = ErrorMessage,
				thread_id = ThreadId,
				mechanism = {
					type = "generic",
					handled = true,
				},
			},
		},
	}, {
		message = ErrorMessage,
		traceback = TracebackText or debug.traceback(),

		thread = Thread,
		thread_id = ThreadId,
	})
end

function Hub.ExceptionHandler(self: Types.Hub): (ErrorMessage: string?) -> ()
	return function(ErrorMessage: string?): ()
		local Message = ErrorMessage or "Unknown error"

		local TracebackText = debug.traceback()
		local Deferred = self:Clone()

		task.spawn(function()
			Deferred:CaptureException(Message, TracebackText)
		end)
	end
end

function Hub.PushScope(self: Types.Hub): () -> ()
	table.insert(self._scope_stack, self.Scope)

	self.Scope = self.Scope:Clone()

	return function()
		self:PopScope()
	end
end

function Hub.PopScope(self: Types.Hub): Types.Hub
	local Parent = table.remove(self._scope_stack)

	if Parent ~= nil then self.Scope = Parent end

	return self
end

function Hub.WithScope(self: Types.Hub, Callback: (Types.Scope) -> ...any): ...any
	local Restore = self:PushScope()
	local Results = table.pack(pcall(Callback, self.Scope))

	Restore()

	if not Results[1] then error(Results[2], 0) end

	return table.unpack(Results, 2, Results.n)
end

function Hub.ConfigureScope(self: Types.Hub, Callback: (Types.Scope) -> ()): Types.Hub
	self.Scope:ConfigureScope(Callback)

	return self
end

function Hub.GetClient(self: Types.Hub): Types.Client
	return self.Client
end

function Hub.BindClient(self: Types.Hub, ClientInstance: Types.Client?): ()
	self.Client = ClientInstance or ClientClass.new()
end

function Hub.UnbindClient(self: Types.Hub): ()
	self:BindClient(nil)
end

function Hub.StartSession(self: Types.Hub): any
	local Options = self.Options

	if Options == nil or Options.Transport == nil then return end

	local Existing = self.Scope._session
	local Session: Types.Session

	if Existing ~= nil then
		Session = Existing
	else
		Session = {
			sid = HttpService:GenerateGUID(false),
			started = DateTime.now(),
		}

		self.Scope:SetSession(Session)
	end

	local User = self.Scope.user
	local CurrentTime = DateTime.now()

	return Options.Transport:CaptureEnvelope({
		sid = Session.sid,
		did = (if User ~= nil and User.id ~= nil then tostring(User.id) else nil),
		seq = CurrentTime.UnixTimestampMillis,
		timestamp = CurrentTime:ToIsoDate(),
		started = Session.started:ToIsoDate(),
		init = true,

		status = "ok",

		attrs = {
			release = self.Scope.release,
			environment = self.Scope.environment,
		},
	})
end

function Hub.EndSession(self: Types.Hub): any
	local Session = self.Scope._session
	local Options = self.Options

	if Session == nil or Options == nil or Options.Transport == nil then return end

	local User = self.Scope.user
	local CurrentTime = DateTime.now()

	return Options.Transport:CaptureEnvelope({
		sid = Session.sid,
		did = (if User ~= nil and User.id ~= nil then tostring(User.id) else nil),
		seq = CurrentTime.UnixTimestampMillis,
		timestamp = CurrentTime:ToIsoDate(),
		started = Session.started:ToIsoDate(),

		status = "exited",

		attrs = {
			release = self.Scope.release,
			environment = self.Scope.environment,
		},
	})
end

return Hub
