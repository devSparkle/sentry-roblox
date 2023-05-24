--!nocheck
--// Initialization

local RunService = game:GetService("RunService")
local HttpService = game:GetService("HttpService")

--[=[
	@class Transport
	
	The transport is an internal construct of the client that abstracts away
	the event sending. Typically the transport runs in a separate thread and
	gets events to send via a queue.
	
	The transport is responsible for sending, retrying and handling rate
	limits. The transport might also persist unsent events across restarts
	if needed.
]=]
local Module = {}

--// Functions

function Module:_GetRelay(): RemoteFunction | BindableFunction | nil
	if RunService:IsClient() then
	--	return script:FindFirstChild("ClientRelay"):: RemoteFunction
	else
		return script:FindFirstChild("ServerRelay"):: BindableFunction
	end
end

function Module:_Relay(...)
	local Relay = self:_GetRelay()
	if not Relay then return end
	
	if Relay:IsA("RemoteFunction") then
		Relay:InvokeServer(...)
	else
		Relay:Invoke(...)
	end
end

function Module:CaptureEvent(EncodedPayload)
	if not self.InitThread then
		return self:_Relay("CaptureEvent", EncodedPayload)
	end
	
	return pcall(HttpService.RequestAsync, HttpService, {
		Url = self.BaseUrl .. "/store/",
		Method = "POST",
		Headers = {
			["Content-Type"] = "application/json",
			["X-Sentry-Auth"] = self.AuthHeader
		},
		
		Body = EncodedPayload,
	})
end

function Module:CaptureEnvelope(Payload)
	if not self.InitThread then
		return self:_Relay("CaptureEnvelope", Payload)
	end
	
	local Payload = HttpService:JSONEncode(Payload)
	local Envelope = HttpService:JSONEncode({event_id = HttpService:GenerateGUID(false)})
	local Item = HttpService:JSONEncode({type = "session", length = #Payload})
	
	return pcall(HttpService.RequestAsync, HttpService, {
		Url = self.BaseUrl .. "/envelope/",
		Method = "POST",
		Headers = {
			["Content-Type"] = "application/x-sentry-envelope",
			["X-Sentry-Auth"] = self.AuthHeader
		},
		
		Body = table.concat({Envelope, Item, Payload}, "\n"),
	})
end

function Module:Init(Options, SENTRY_PROTOCOL_VERSION, SENTRY_CLIENT)
	assert(not script:FindFirstChildWhichIsA("BindableFunction"), "The SentrySDK Transport can only be initialized once!")
	assert(not script:FindFirstChildWhichIsA("RemoteFunction"), "The SentrySDK Transport can only be initialized once!")
	
	self.InitThread = true
	
	do --/ Process Options
		local Scheme, PublicKey, Authority, ProjectId = string.match(Options.DSN or "", "^([^:]+)://([^:]+)@([^/]+)/(.+)$")
		
		assert(Scheme, "Invalid Sentry DSN: Scheme not found.")
		assert(string.match(string.lower(Scheme), "^https?$"), "Invalid Sentry DSN: Scheme not valid.")
		
		assert(PublicKey, "Invalid Sentry DSN: Public Key not found.")
		assert(Authority, "Invalid Sentry DSN: Authority not found.")
		assert(ProjectId, "Invalid Sentry DSN: Project ID not found.")
		
		self.BaseUrl = string.format("%s://%s/api/%s/", Scheme, Authority, ProjectId)
		self.AuthHeader = string.format(
			"Sentry sentry_key=%s,sentry_version=%d,sentry_client=%s",
			PublicKey, SENTRY_PROTOCOL_VERSION, SENTRY_CLIENT
		)
	end
	
	do --/ Load Relays
		local ServerRelay = Instance.new("BindableFunction")
		ServerRelay.Name = "ServerRelay"
		ServerRelay.Parent = script
		
		function ServerRelay.OnInvoke(FunctionName, ...)
			return self[FunctionName](self, ...)
		end
		
		local ClientRelay = Instance.new("RemoteFunction")
		ClientRelay.Name = "ClientRelay"
		ClientRelay.Parent = script
		
		function ClientRelay.OnServerInvoke(Player, ...)
			--// TODO: Player input validation
			--// TODO: Forced user scope
			
			return ServerRelay:Invoke(...)
		end
	end
end

return Module