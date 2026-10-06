local Manifest = require("./Shared/Manifest")
local Run = require("./Shared/Run")

local VersionFile = require("./Version/File")
local Wally = require("./Wally/Manifest")

local ManifestData = Manifest.Read()

Run.Step("version", function()
	if VersionFile.Write(ManifestData.version) then
		return true, `stamped {VersionFile.Path} with {ManifestData.version}`
	end

	return true, `{VersionFile.Path} is already at {ManifestData.version}`
end)

Run.Step("wally", function()
	if Wally.Generate(ManifestData) then return true, `generated {Wally.Path} for {ManifestData.version}` end

	return true, `{Wally.Path} is already up to date for {ManifestData.version}`
end)
