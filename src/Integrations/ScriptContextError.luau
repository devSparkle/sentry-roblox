local Policy = require(script.Parent.Detection.Policy)
local Types = require(script.Parent:WaitForChild("Types"))

export type Options = {
	Filter: any?,
	ExtraInternalPatterns: { string }?,
	RejectTraceless: boolean?,
}

local LocationPrefix = "^[^:]+:%d+: (.+)$"

local function ScriptContextError(Options: Options?): Types.Integration
	local Settings: Options = Options or {}

	return {
		Name = "ScriptContextError",
		Realm = "Shared",
		Setup = function(Context: Types.Context)
			local ScriptContext = Context.Services.ScriptContext
			local Root = Context.Services.Game

			local Filter = table.clone(Policy.Defaults)

			if Settings.Filter ~= nil then
				for Key, Value in Settings.Filter do
					Filter[Key] = Value
				end
			end

			if Settings.RejectTraceless ~= nil then Filter.RejectTraceless = Settings.RejectTraceless end

			local ExtraPatterns = Settings.ExtraInternalPatterns

			local Connection = ScriptContext.Error:Connect(function(Message: string, TracebackText: string, Origin: any)
				if ExtraPatterns ~= nil and Policy.MatchesAny(Message, ExtraPatterns) then return end

				local Keep = Policy.Decide(Origin, TracebackText, Root, Filter)

				if not Keep then return end

				local Clean = string.match(Message, LocationPrefix) or Message

				Context.Hub:CaptureEvent({
					level = "error",
					exception = {
						{
							type = "Error",
							value = Clean,
							mechanism = {
								type = "generic",
								handled = false,
							},
						},
					},
				}, {
					traceback = TracebackText,
					origin = Origin,
					message = Message,
				})
			end)

			return function()
				Connection:Disconnect()
			end
		end,
	}
end

return ScriptContextError
