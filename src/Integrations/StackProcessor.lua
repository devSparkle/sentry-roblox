--!nocheck
--// Initialization

local Module = {}
Module.Name = script.Name

--// Functions

local function SanitizeEnvironment(Environment)
	if not Environment then return end
	local SanitizedEnvironment = {}
	
	for Index, Value in next, Environment do
		SanitizedEnvironment[tostring(Index)] = tonumber(Value) or tostring(Value)
	end
	
	return SanitizedEnvironment
end

local function ConvertStacktraceToFrames(Event, Hint)
	if not Hint then return Event end
	if not Hint.traceback then return Event end
	
	local StacktraceFrames = {}
	local Index = 0
	
	for Line in string.gmatch(Hint.traceback, "[^\n\r]+") do
		if string.match(Line, "^Stack Begin$") then continue end
		if string.match(Line, "^Stack End$") then continue end
		Index += 1
		
		local Path, LineNumber, FunctionName
		local Variables = (if Hint.environments then Hint.environments[Index] else nil)
		local SourceScript = (if Variables then Variables.script else nil)
		
		if string.find(Line, "^Script ") then
			Path, LineNumber, FunctionName = string.match(
				Line, "^Script '(.-)', Line (%d+)%s?%-?%s?(.*)$"
			)
		elseif string.find(Line, ", line") then
			Path, LineNumber, FunctionName = string.match(
				Line, "^(.-), line (%d+)%s?%-?%s?(.*)$"
			)
		else
			Path, LineNumber, FunctionName = string.match(
				Line, "^(.-):(%d+)%s?%-?%s?(.*)$"
			)
		end
		
		if FunctionName then
			FunctionName = string.gsub(FunctionName, "function ", "")
			
			if FunctionName == "CaptureException" then
				continue
			end
		end
		
		if Path and LineNumber then
			table.insert(StacktraceFrames, 1, {
				["function"] = FunctionName,
				filename = Path,
				
				lineno = tonumber(LineNumber),
				module = (if SourceScript then SourceScript.Name else select(-1, unpack(string.split(Path, ".")))),
				vars = SanitizeEnvironment(Variables)
			})
		else
			table.insert(StacktraceFrames, 1, {
				filename = (if SourceScript then SourceScript:GetFullName() else nil),
				module = Line,
				vars = SanitizeEnvironment(Variables)
			})
		end
	end
	
	if #StacktraceFrames > 0 then
		if Event.exception then
			Event.exception.stacktrace = {
				frames = StacktraceFrames,
			}
		elseif Hint.thread then
			Event.threads = Event.threads or {}
			table.insert(Event.threads, 1, {
				id = string.gsub(tostring(Hint.thread), "thread: ", ""),
				stacktrace = {
					frames = StacktraceFrames
				},
			})
		end
	else
		Event.errors = Event.errors or {}
		table.insert(Event.errors, {
			type = "native_symbolicator_failed",
			details = "Failed to process native stacktraces.",
		})
	end
	
	return Event
end

function Module:SetupOnce(AddGlobalEventProcessor, CurrentHub)
	AddGlobalEventProcessor(ConvertStacktraceToFrames)
end

return Module