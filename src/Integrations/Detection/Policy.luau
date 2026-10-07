local Policy = {}

Policy.Markers = {
	"CoreScripts",
	"CorePackages",
	"RobloxScript",
	"CoreGui",
	"RobloxReplicatedStorage",
}

Policy.Patterns = {
	"^CoreScript",
	"^%[CoreGui%]",
	"RobloxScriptSecurity",
	"RobloxScript%.",
}

Policy.Defaults = {
	RejectNilOrigin = true,
	RejectForeignOrigin = true,
	RejectGeneratedNames = true,
	RejectInternal = true,
	RejectTraceless = false,
	MinimumGeneratedNameLength = 8,
}

local function Mentions(Text: string?, Needles: { string }): boolean
	if Text == nil then return false end

	for _, Needle in Needles do
		if string.find(Text, Needle, 1, true) ~= nil then return true end
	end

	return false
end

local function Matches(Text: string?, Patterns: { string }): boolean
	if Text == nil then return false end

	for _, Pattern in Patterns do
		local Success, Found = pcall(string.find, Text, Pattern)

		if Success and Found ~= nil then return true end
	end

	return false
end

function Policy.MentionsAny(Text: string?, Needles: { string }): boolean
	return Mentions(Text, Needles)
end

function Policy.MatchesAny(Text: string?, Patterns: { string }): boolean
	return Matches(Text, Patterns)
end

function Policy.IsTraceless(Text: string?): boolean
	if Text == nil then return true end

	return string.match(Text, "%S") == nil
end

function Policy.IsCoreScript(Instance: any?): boolean
	if Instance == nil then return false end

	local Success, IsCoreScript = pcall(function()
		return Instance:IsA("CoreScript")
	end)

	return Success and IsCoreScript == true
end

function Policy.IsInternalOrigin(Instance: any?): boolean
	if Instance == nil then return false end

	if Policy.IsCoreScript(Instance) then return true end

	local Success, FullName = pcall(function()
		return Instance:GetFullName()
	end)

	if not Success or type(FullName) ~= "string" then return false end

	return Mentions(FullName, Policy.Markers)
end

function Policy.IsInternalText(Text: string?): boolean
	if Mentions(Text, Policy.Markers) then return true end

	return Matches(Text, Policy.Patterns)
end

function Policy.IsForeignOrigin(Instance: any?, Root: any?): boolean
	if Instance == nil then return true end

	if Root == nil then return false end

	local Success, IsDescendant = pcall(function()
		return Root:IsAncestorOf(Instance)
	end)

	if not Success then return false end

	return IsDescendant ~= true
end

function Policy.IsGeneratedName(Name: string?, MinimumLength: number?): boolean
	if Name == nil then return false end

	local Minimum = MinimumLength or Policy.Defaults.MinimumGeneratedNameLength

	if #Name < Minimum then return false end

	if string.match(Name, "^[%w_]+$") == nil then return false end

	if string.match(Name, "%d") == nil or string.match(Name, "%a") == nil then return false end

	local Letters = (string.gsub(Name, "[%d_]", ""))

	if #Letters == 0 then return false end

	local Vowels = { a = true, e = true, i = true, o = true, u = true, y = true }
	local VowelCount = 0

	for Index = 1, #Letters do
		if Vowels[string.lower(string.sub(Letters, Index, Index))] then
			VowelCount += 1
		end
	end

	return (VowelCount / #Letters) < 0.2
end

function Policy.Decide(Origin: any?, TracebackText: string?, Root: any?, Options: any?): (boolean, string?)
	local Settings = Options or Policy.Defaults

	if Settings.RejectNilOrigin and Origin == nil then return false, "nil_origin" end

	if Settings.RejectInternal and Policy.IsInternalOrigin(Origin) then return false, "internal_origin" end

	if Settings.RejectInternal and Policy.IsInternalText(TracebackText) then return false, "internal_trace" end

	if Settings.RejectForeignOrigin and Policy.IsForeignOrigin(Origin, Root) then return false, "foreign_origin" end

	if Settings.RejectGeneratedNames and Origin ~= nil then
		local Name = Origin.Name

		if Policy.IsGeneratedName(Name, Settings.MinimumGeneratedNameLength) then return false, "generated_name" end
	end

	if Settings.RejectTraceless and Policy.IsTraceless(TracebackText) then return false, "traceless" end

	return true, nil
end

return table.freeze(Policy)
