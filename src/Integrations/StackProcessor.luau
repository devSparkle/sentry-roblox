local Policy = require(script.Parent.Detection.Policy)
local Traceback = require(script.Parent.Detection.Traceback)
local Types = require(script.Parent:WaitForChild("Types"))

export type Options = {
	IncludeInternalFrames: boolean?,
	MaximumFrames: number?,
	IgnoredFunctions: { string }?,
}

local DefaultIgnoredFunctions = {
	"CaptureException",
	"CaptureEvent",
	"CaptureMessage",
}

local function ToFrame(Parsed: Traceback.Frame, IsInApp: (string?) -> boolean): any
	local Path = Parsed.Path
	local Module = nil

	if Path ~= nil then
		local Segments = string.split(Path, ".")

		Module = Segments[#Segments]
	end

	return {
		filename = Path,
		lineno = Parsed.Line,
		["function"] = Parsed.Function,
		module = Module,
		raw = Parsed.Raw,
		in_app = IsInApp(Path),
	}
end

local function StackProcessor(Options: Options?): Types.Integration
	local Settings: Options = Options or {}
	local Ignored = Settings.IgnoredFunctions or DefaultIgnoredFunctions
	local MaximumFrames = Settings.MaximumFrames or 100
	local IncludeInternalFrames = Settings.IncludeInternalFrames == true

	return {
		Name = "StackProcessor",
		Realm = "Shared",
		Setup = function(Context: Types.Context)
			local SdkOptions = Context.Options
			local Include = if SdkOptions ~= nil then SdkOptions.InAppInclude else nil
			local Exclude = if SdkOptions ~= nil then SdkOptions.InAppExclude else nil

			local function IsInApp(Path: string?): boolean
				if Exclude ~= nil and Policy.MentionsAny(Path, Exclude) then return false end

				if Include ~= nil and #Include > 0 then return Policy.MentionsAny(Path, Include) end

				return not Policy.IsInternalText(Path)
			end

			local SdkRoot = script.Parent.Parent:GetFullName()

			local function IsSdkFrame(Path: string?): boolean
				if Path == nil then return false end

				return string.sub(Path, 1, #SdkRoot) == SdkRoot
			end

			local function Convert(Event: any, Hint: any?): any
				if Hint == nil then return Event end

				local Text = Hint.traceback

				if Text == nil then return Event end

				local Frames = {}
				local Unfiltered = {}

				for _, Parsed in Traceback.Parse(Text) do
					if Parsed.Function ~= nil and table.find(Ignored, Parsed.Function) ~= nil then continue end

					if not IncludeInternalFrames and Parsed.Path ~= nil and Policy.IsInternalText(Parsed.Path) then
						continue
					end

					if Parsed.Path == nil and Parsed.Line == nil and #Unfiltered > 0 then continue end

					local Frame = ToFrame(Parsed, IsInApp)

					table.insert(Unfiltered, 1, Frame)

					if not IsSdkFrame(Parsed.Path) then table.insert(Frames, 1, Frame) end
				end

				if #Frames == 0 then Frames = Unfiltered end

				while #Frames > MaximumFrames do
					table.remove(Frames)
				end

				if #Frames == 0 then
					Event.errors = Event.errors or {}
					table.insert(Event.errors, {
						type = "native_symbolicator_failed",
						details = "No stack frames could be parsed from the traceback.",
					})

					return Event
				end

				if Event.exception ~= nil and Event.exception[1] ~= nil then
					Event.exception[1].stacktrace = { frames = Frames }
				elseif Hint.thread ~= nil then
					Event.threads = Event.threads or {}
					table.insert(Event.threads, 1, {
						id = tostring(Hint.thread_id),
						stacktrace = { frames = Frames },
					})
				else
					Event.stacktrace = { frames = Frames }
				end

				return Event
			end

			Context.AddProcessor(Convert)

			return nil
		end,
	}
end

return StackProcessor
