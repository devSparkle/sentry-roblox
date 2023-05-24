--!nocheck
--// Initialization

local HttpService = game:GetService("HttpService")

local Defaults = require(script.Parent.Parent:WaitForChild("Defaults"))
local Transport = require(script.Parent.Parent:WaitForChild("Transport"))

--[=[
	@class Client
	
	A Client is the part of the SDK that is responsible for event creation. To give
	an example, the Client should convert an exception to a Sentry event.
	
	The Client should be stateless, it gets the Scope injected and delegates the
	work of sending the event to the Transport.
]=]
local Client = {}

--// Functions

function Client.new()
	return setmetatable({}, {__index = Client})
end

--[=[
	Captures the event by merging it with other data with defaults from the client.
	
	In addition, if a scope is passed to this system, the data from the scope
	passes it to the internal transport.
	
	@param Event Event
	@param Scope Scope
]=]
function Client:CaptureEvent(Event, Hint: {[string]: any}, Scope)
	if not Hint then Hint = {} end
	
	Event.event_id = (Hint.event_id or string.gsub(HttpService:GenerateGUID(false), "-", ""))
	Event.timestamp = DateTime.now().UnixTimestamp
	Event.sdk = self.SDK_INTERFACE
	Event.platform = "other"
	Event = Scope:ApplyToEvent(Event, Hint)
	
	if not Event then
		return
	end
	
	local EncodeSuccess, EncodedPayload = pcall(HttpService.JSONEncode, HttpService, Event)
	if not EncodeSuccess then return end
	
	return Transport:CaptureEvent(EncodedPayload)
end

--[=[
	Flushes out the queue for up to timeout seconds. If the client can guarantee
	delivery of events only up to the current point in time this is preferred. This
	might block for timeout seconds.
	
	The client is disabled after this method is called.
]=]
function Client:Close(Timeout: number?)
	
end

--[=[
	Same as close difference is that the client is NOT disposed after invocation.
]=]
function Client:Flush(Timeout: number?)
	
end

export type Client = typeof(Client.new())

return table.freeze(Client)