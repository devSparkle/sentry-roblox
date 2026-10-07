local Scrubber = {}

Scrubber.DefaultPlaceholder = "<PLAYER>"
Scrubber.MaximumDepth = 12

function Scrubber.Escape(Name: string): string
	return (string.gsub(Name, "%W", "%%%0"))
end

function Scrubber.Render(Placeholder: string, Index: number): string
	if string.find(Placeholder, "%d", 1, true) ~= nil then return string.format(Placeholder, Index) end

	return Placeholder
end

function Scrubber.ReplaceWhole(Text: string, Name: string, Replacement: string): (string, number)
	if string.find(Text, Name, 1, true) == nil then return Text, 0 end

	local Pattern = "%f[%w_]" .. Scrubber.Escape(Name) .. "%f[^%w_]"

	return string.gsub(Text, Pattern, Replacement)
end

function Scrubber.Contains(Text: string, Name: string): boolean
	if string.find(Text, Name, 1, true) == nil then return false end

	local Pattern = "%f[%w_]" .. Scrubber.Escape(Name) .. "%f[^%w_]"

	return string.find(Text, Pattern) ~= nil
end

function Scrubber.SortByLength(Names: { string }): { string }
	local Sorted = table.clone(Names)

	table.sort(Sorted, function(A, B)
		if #A == #B then return A < B end

		return #A > #B
	end)

	return Sorted
end

function Scrubber.ScrubString(Text: string, Names: { string }, Placeholder: string): (string, { string })
	local Found = {}
	local Result = Text
	local Ordered = Scrubber.SortByLength(Names)

	for Index, Name in Ordered do
		local Replaced, Count = Scrubber.ReplaceWhole(Result, Name, Scrubber.Render(Placeholder, Index))

		if Count > 0 then
			Result = Replaced
			table.insert(Found, Name)
		end
	end

	return Result, Found
end

function Scrubber.ScrubValue(Value: any, Names: { string }, Placeholder: string, Depth: number, Found: { string }): any
	if Depth > Scrubber.MaximumDepth then return Value end

	if type(Value) == "string" then
		local Replaced, Matches = Scrubber.ScrubString(Value, Names, Placeholder)

		for _, Match in Matches do
			if not table.find(Found, Match) then table.insert(Found, Match) end
		end

		return Replaced
	end

	if type(Value) == "table" then
		if table.isfrozen(Value) then Value = table.clone(Value) end

		for Key, Inner in Value do
			Value[Key] = Scrubber.ScrubValue(Inner, Names, Placeholder, Depth + 1, Found)
		end

		return Value
	end

	return Value
end

function Scrubber.FindValue(Value: any, Names: { string }, Depth: number, Found: { string }): ()
	if Depth > Scrubber.MaximumDepth then return end

	if type(Value) == "string" then
		for _, Name in Names do
			if not table.find(Found, Name) and Scrubber.Contains(Value, Name) then table.insert(Found, Name) end
		end

		return
	end

	if type(Value) == "table" then
		for _, Inner in Value do
			Scrubber.FindValue(Inner, Names, Depth + 1, Found)
		end
	end
end

function Scrubber.Find(Payload: any, Names: { string }): { string }
	if #Names == 0 then return {} end

	local Found = {}

	Scrubber.FindValue(Payload, Scrubber.SortByLength(Names), 1, Found)

	return Found
end

function Scrubber.Apply(Payload: any, Names: { string }, Placeholder: string?): (any, { string })
	if #Names == 0 then return Payload, {} end

	local Found = {}
	local Result = Scrubber.ScrubValue(Payload, Names, Placeholder or Scrubber.DefaultPlaceholder, 1, Found)

	return Result, Found
end

return table.freeze(Scrubber)
