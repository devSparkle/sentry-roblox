export type Frame = {
	Path: string?,
	Line: number?,
	Function: string?,
	Raw: string,
}

local FramePatterns = {
	"^Script '(.-)', [Ll]ine (%d+)",
	"^(.-):(%d+)",
	"^(.-), [Ll]ine (%d+)",
}

local FunctionSuffix = "^%s*%-?%s*function (.*)$"

local Traceback = {}

local FramePrefix = "^Script "

function Traceback.Lines(Text: string): { string }
	local Lines = {}

	for Line in string.gmatch(Text, "[^\r\n]+") do
		if Line == "Stack Begin" or Line == "Stack End" then continue end

		table.insert(Lines, Line)
	end

	return Lines
end

function Traceback.IsTraceless(Text: string?): boolean
	if Text == nil then return true end

	if string.match(Text, "%S") == nil then return true end

	return false
end

function Traceback.Mentions(Text: string?, Markers: { string }): boolean
	if Text == nil then return false end

	for _, Marker in Markers do
		if string.find(Text, Marker, 1, true) ~= nil then return true end
	end

	return false
end

function Traceback.Matches(Text: string?, Patterns: { string }): boolean
	if Text == nil then return false end

	for _, Pattern in Patterns do
		local Success, Found = pcall(string.find, Text, Pattern)

		if Success and Found ~= nil then return true end
	end

	return false
end

function Traceback.HasFrame(Text: string?): boolean
	if Text == nil then return false end

	for _, Line in Traceback.Lines(Text) do
		if string.find(Line, FramePrefix) ~= nil then return true end
	end

	return false
end

function Traceback.Parse(Text: string?): { Frame }
	local Frames = {}

	if Text == nil then return Frames end

	for _, Line in Traceback.Lines(Text) do
		local Path, LineNumber, Remainder = nil, nil, nil

		for _, Pattern in FramePatterns do
			local Start, Finish, FoundPath, FoundLine = string.find(Line, Pattern)

			if Start ~= nil and Finish ~= nil then
				Path = FoundPath
				LineNumber = FoundLine
				Remainder = string.sub(Line, Finish + 1)

				break
			end
		end

		local FunctionName = nil

		if Remainder ~= nil then FunctionName = string.match(Remainder, FunctionSuffix) end

		table.insert(Frames, {
			Path = Path,
			Line = if LineNumber then tonumber(LineNumber) else nil,
			Function = FunctionName,
			Raw = Line,
		})
	end

	return Frames
end

return table.freeze(Traceback)
