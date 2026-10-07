export type Headers = { [string]: any }

local RateLimit = {}

RateLimit.DefaultHoldSeconds = 60
RateLimit.AbsoluteThreshold = 1e9

function RateLimit.Header(Headers: Headers?, Name: string): string?
	if Headers == nil then return nil end

	local Direct = Headers[Name]

	if type(Direct) == "string" then return Direct end

	local Wanted = string.lower(Name)

	for Key, Value in Headers do
		if type(Key) == "string" and string.lower(Key) == Wanted and type(Value) == "string" then return Value end
	end

	return nil
end

local function ToEpoch(Value: string?, Now: number): number?
	local Number = tonumber(Value)

	if Number == nil or Number <= 0 then return nil end

	if Number >= RateLimit.AbsoluteThreshold then return Number end

	return Now + Number
end

function RateLimit.Resolve(Headers: Headers?, StatusCode: number, Now: number): number?
	local Remaining = tonumber(RateLimit.Header(Headers, "X-Sentry-Rate-Limit-Remaining"))
	local Reset = ToEpoch(RateLimit.Header(Headers, "X-Sentry-Rate-Limit-Reset"), Now)
	local RetryAfter = ToEpoch(RateLimit.Header(Headers, "Retry-After"), Now)

	if StatusCode == 429 then return RetryAfter or Reset or (Now + RateLimit.DefaultHoldSeconds) end

	if Remaining == nil then return nil end

	if Remaining > 0 then return nil end

	return Reset or (Now + RateLimit.DefaultHoldSeconds)
end

return table.freeze(RateLimit)
