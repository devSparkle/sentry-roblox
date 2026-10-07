export type Limits = {
	MaximumStringLength: number?,
	MaximumFrames: number?,
	MaximumExceptions: number?,
	MaximumBreadcrumbs: number?,
	MaximumDepth: number?,
}

export type Limiter = {
	Burst: number,
	Window: number,
	Tokens: { [any]: number },
	UpdatedAt: { [any]: number },
}

local Protocol = {}

Protocol.Defaults = {
	MaximumStringLength = 2048,
	MaximumFrames = 100,
	MaximumExceptions = 8,
	MaximumBreadcrumbs = 64,
	MaximumDepth = 8,
}

Protocol.AllowedTopLevel = {
	message = true,
	exception = true,
	threads = true,
	stacktrace = true,
	level = true,
	logger = true,
	transaction = true,
	tags = true,
	extra = true,
	contexts = true,
	fingerprint = true,
	modules = true,
	breadcrumbs = true,
}

Protocol.ReservedTopLevel = {
	event_id = true,
	timestamp = true,
	platform = true,
	sdk = true,
	server_name = true,
	release = true,
	environment = true,
	dist = true,
	user = true,
	errors = true,
}

local function ClampString(Value: string, Maximum: number): string
	if #Value <= Maximum then return Value end

	return string.sub(Value, 1, Maximum)
end

local function SanitizeValue(Value: any, Limits: Limits, Depth: number): any
	if Depth > (Limits.MaximumDepth or Protocol.Defaults.MaximumDepth) then return nil end

	local Kind = type(Value)

	if Kind == "string" then
		return ClampString(Value, Limits.MaximumStringLength or Protocol.Defaults.MaximumStringLength)
	end

	if Kind == "number" or Kind == "boolean" then return Value end

	if Kind ~= "table" then return nil end

	local Result = {}

	for Key, Inner in Value do
		if type(Key) == "string" then
			local Clean = SanitizeValue(Inner, Limits, Depth + 1)

			if Clean ~= nil then Result[Key] = Clean end
		end
	end

	return Result
end

local function LimitFrames(Stacktrace: any, Maximum: number): any
	if type(Stacktrace) ~= "table" then return nil end

	local Frames = Stacktrace.frames

	if type(Frames) ~= "table" then return nil end

	local Trimmed = {}

	for Index, Frame in Frames do
		if Index > Maximum then break end

		if type(Frame) == "table" then
			table.insert(Trimmed, {
				filename = if type(Frame.filename) == "string" then ClampString(Frame.filename, 512) else nil,
				lineno = if type(Frame.lineno) == "number" then Frame.lineno else nil,
				["function"] = if type(Frame["function"]) == "string" then ClampString(Frame["function"], 256) else nil,
				module = if type(Frame.module) == "string" then ClampString(Frame.module, 256) else nil,
			})
		end
	end

	return { frames = Trimmed }
end

function Protocol.Validate(Payload: any): (boolean, string?)
	if type(Payload) ~= "table" then return false, "payload_not_table" end

	if Payload.message ~= nil and type(Payload.message) ~= "table" then return false, "message_not_table" end

	if Payload.exception ~= nil and type(Payload.exception) ~= "table" then return false, "exception_not_table" end

	if Payload.message == nil and Payload.exception == nil then return false, "empty_event" end

	return true, nil
end

function Protocol.Sanitize(Payload: any, Limits: Limits?): any
	local Settings = Limits or Protocol.Defaults
	local Clean = {}

	for Key, Value in Payload do
		if type(Key) ~= "string" then continue end

		if Protocol.ReservedTopLevel[Key] then continue end

		if not Protocol.AllowedTopLevel[Key] then continue end

		if Key == "exception" then
			local Exceptions = {}

			for Index, Exception in Value do
				if Index > (Settings.MaximumExceptions or Protocol.Defaults.MaximumExceptions) then break end

				if type(Exception) == "table" then
					table.insert(Exceptions, {
						type = if type(Exception.type) == "string" then ClampString(Exception.type, 256) else "Error",
						value = if type(Exception.value) == "string"
							then ClampString(
								Exception.value,
								Settings.MaximumStringLength or Protocol.Defaults.MaximumStringLength
							)
							else nil,
						mechanism = if type(Exception.mechanism) == "table"
							then SanitizeValue(Exception.mechanism, Settings, 1)
							else nil,
						stacktrace = LimitFrames(
							Exception.stacktrace,
							Settings.MaximumFrames or Protocol.Defaults.MaximumFrames
						),
					})
				end
			end

			Clean.exception = Exceptions
		elseif Key == "stacktrace" then
			Clean.stacktrace = LimitFrames(Value, Settings.MaximumFrames or Protocol.Defaults.MaximumFrames)
		elseif Key == "level" then
			if type(Value) == "string" then Clean.level = ClampString(Value, 16) end
		else
			Clean[Key] = SanitizeValue(Value, Settings, 1)
		end
	end

	return Clean
end

function Protocol.ValidateEnvelope(Envelope: any): (boolean, string?)
	if type(Envelope) ~= "table" then return false, "envelope_not_table" end

	if type(Envelope.event) ~= "table" then return false, "envelope_missing_event" end

	if Envelope.traceback ~= nil and type(Envelope.traceback) ~= "string" then
		return false, "envelope_bad_traceback"
	end

	return Protocol.Validate(Envelope.event)
end

function Protocol.SanitizeEnvelope(Envelope: any, Limits: Limits?): any
	local Settings = Limits or Protocol.Defaults
	local Traceback = Envelope.traceback

	if type(Traceback) == "string" then
		Traceback = ClampString(Traceback, (Settings.MaximumStringLength or Protocol.Defaults.MaximumStringLength) * 8)
	end

	return {
		event = Protocol.Sanitize(Envelope.event, Settings),
		traceback = Traceback,
	}
end

function Protocol.Limiter(Burst: number, Window: number): Limiter
	return {
		Burst = Burst,
		Window = Window,
		Tokens = {},
		UpdatedAt = {},
	}
end

function Protocol.Allow(Limiter: Limiter, Key: any, Now: number): boolean
	local Tokens = Limiter.Tokens[Key]

	if Tokens == nil then
		Limiter.Tokens[Key] = Limiter.Burst - 1
		Limiter.UpdatedAt[Key] = Now

		return true
	end

	local Elapsed = math.max(Now - (Limiter.UpdatedAt[Key] or Now), 0)
	local Refill = Elapsed * (Limiter.Burst / Limiter.Window)
	local Available = math.min(Tokens + Refill, Limiter.Burst)

	Limiter.UpdatedAt[Key] = Now

	if Available < 1 then
		Limiter.Tokens[Key] = Available

		return false
	end

	Limiter.Tokens[Key] = Available - 1

	return true
end

function Protocol.Forget(Limiter: Limiter, Key: any): ()
	Limiter.Tokens[Key] = nil
	Limiter.UpdatedAt[Key] = nil
end

return table.freeze(Protocol)
