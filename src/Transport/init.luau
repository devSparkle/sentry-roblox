local HttpService = game:GetService("HttpService")

local Types = require(script.Parent:WaitForChild("Types"))
local Dsn = require(script:WaitForChild("Dsn"))
local RateLimit = require(script:WaitForChild("RateLimit"))

local HoldUntil = 0

export type Transport = Types.Transport & {
	BaseUrl: string?,
	AuthHeader: string?,
}

local Transport = {
	BaseUrl = nil,
	AuthHeader = nil,
} :: any

local function Failure(StatusCode: number, StatusMessage: string, Body: string?): any
	return {
		Body = Body or "",
		Headers = {},

		StatusCode = StatusCode,
		StatusMessage = StatusMessage,
		Success = false,
	}
end

local function RequestAsync(Request: { [string]: any }): any
	local Now = DateTime.now().UnixTimestamp

	if Now < HoldUntil then return Failure(429, "TooManyRequests") end

	local CallSuccess, Response = pcall(HttpService.RequestAsync, HttpService, Request)

	if not CallSuccess then return Failure(400, "RequestFailed", `{tostring(Response)}\n{debug.traceback()}`) end

	HoldUntil = RateLimit.Resolve(Response.Headers, Response.StatusCode, Now) or 0

	return Response
end

function Transport.Init(self: Transport, Options: Types.Options, ProtocolVersion: number, Client: string): ()
	local Parsed, FailureReason = Dsn.Parse(Options.DSN or "", ProtocolVersion, Client)

	if Parsed == nil then error(`Invalid Sentry DSN: {FailureReason}`, 0) end

	self.BaseUrl = Parsed.BaseUrl
	self.AuthHeader = Parsed.AuthHeader
end

function Transport.CaptureEvent(self: Transport, EncodedPayload: string): any
	local BaseUrl = self.BaseUrl
	local AuthHeader = self.AuthHeader

	if BaseUrl == nil or AuthHeader == nil then return Failure(0, "NotInitialised") end

	return RequestAsync({
		Url = `{BaseUrl}store/`,
		Method = "POST",
		Headers = {
			["Content-Type"] = "application/json",
			["X-Sentry-Auth"] = AuthHeader,
		},

		Body = EncodedPayload,
	})
end

function Transport.CaptureEnvelope(self: Transport, Payload: { [string]: any }): any
	local BaseUrl = self.BaseUrl
	local AuthHeader = self.AuthHeader

	if BaseUrl == nil or AuthHeader == nil then return Failure(0, "NotInitialised") end

	local EncodedPayload = HttpService:JSONEncode(Payload)
	local Envelope = HttpService:JSONEncode({ event_id = HttpService:GenerateGUID(false) })
	local Item = HttpService:JSONEncode({ type = "session", length = #EncodedPayload })

	return RequestAsync({
		Url = `{BaseUrl}envelope/`,
		Method = "POST",
		Headers = {
			["Content-Type"] = "application/x-sentry-envelope",
			["X-Sentry-Auth"] = AuthHeader,
		},

		Body = table.concat({ Envelope, Item, EncodedPayload }, "\n"),
	})
end

return Transport
