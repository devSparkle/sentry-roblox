local fs = require("@lune/fs")
local Serde = require("@lune/serde")

local Manifest = require("../Shared/Manifest")

local Wally = {}

Wally.Path = "wally.toml"

local Registry = "https://github.com/UpliftGames/wally-index"
local Realm = "shared"

function Wally.PackageName(ManifestData: Manifest.Shape): string
	return `{Manifest.Scope(ManifestData.name)}/{Manifest.WallyName(Manifest.Package(ManifestData.name))}`
end

function Wally.Render(ManifestData: Manifest.Shape): string
	return table.concat({
		"# This file is generated from pesde.toml. Do not edit it by hand.",
		"# Run `pesde run sync` to rebuild it.",
		"",
		"[package]",
		`name = "{Wally.PackageName(ManifestData)}"`,
		`description = "{ManifestData.description or ""}"`,
		`version = "{ManifestData.version}"`,
		`license = "{ManifestData.license or ""}"`,
		`registry = "{Registry}"`,
		`realm = "{Realm}"`,
		"",
	}, "\n")
end

function Wally.Read(): { [string]: any }?
	if not fs.isFile(Wally.Path) then return nil end

	local Success, Decoded = pcall(function()
		return Serde.decode("toml", fs.readFile(Wally.Path))
	end)

	if not Success then return nil end

	return (Decoded :: any).package
end

function Wally.Generate(ManifestData: Manifest.Shape): boolean
	local Rendered = Wally.Render(ManifestData)

	if fs.isFile(Wally.Path) and fs.readFile(Wally.Path) == Rendered then return false end

	fs.writeFile(Wally.Path, Rendered)
	return true
end

function Wally.Verify(): (boolean, string)
	local ManifestData = Manifest.Read()
	local Package = Wally.Read()

	if Package == nil then return false, `${Wally.Path} is missing or unreadable` end

	local Expected = Wally.PackageName(ManifestData)

	if Package.name ~= Expected then
		return false, `{Wally.Path} name is {tostring(Package.name)} but pesde.toml implies {Expected}`
	end

	if Package.version ~= ManifestData.version then
		return false, `{Wally.Path} version is {tostring(Package.version)} but pesde.toml says {ManifestData.version}`
	end

	return true, `{Wally.Path} is in sync at {ManifestData.version}`
end

return table.freeze(Wally)
