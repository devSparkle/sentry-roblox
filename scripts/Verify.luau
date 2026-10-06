local Process = require("@lune/process")

local Manifest = require("./Shared/Manifest")
local Run = require("./Shared/Run")

local VersionFile = require("./Version/File")
local Wally = require("./Wally/Manifest")

local ManifestData = Manifest.Read()

local function FirstArgument(): string?
	for _, Argument in Process.args do
		if Argument ~= "--" then return Argument end
	end

	return nil
end

Run.Step("version", VersionFile.Verify)
Run.Step("wally", Wally.Verify)

local Tag = FirstArgument()

if Tag ~= nil and Tag ~= "" then
	Run.Step("tag", function()
		local Expected = `v{ManifestData.version}`

		if Tag ~= Expected then return false, `tag {Tag} does not match pesde.toml version {Expected}` end

		return true, `tag {Tag} matches pesde.toml`
	end)
end
