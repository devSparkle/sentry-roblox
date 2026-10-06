local Fs = require("@lune/fs")

local Manifest = require("../Shared/Manifest")

local File = {}

File.Path = "src/Version.luau"

local function Render(Version: string): string
	return `return "{Version}"\n`
end

function File.Expected(Version: string): string
	return Render(Version)
end

function File.Read(): string?
	if not Fs.isFile(File.Path) then return nil end

	return Fs.readFile(File.Path)
end

function File.Write(Version: string): boolean
	local Rendered = Render(Version)

	if File.Read() == Rendered then return false end

	Fs.writeFile(File.Path, Rendered)
	return true
end

function File.Verify(): (boolean, string)
	local ManifestData = Manifest.Read()
	local Actual = File.Read()

	if Actual == nil then return false, `${File.Path} is missing` end

	if Actual ~= Render(ManifestData.version) then
		local Found = string.match(Actual, "%d+%.%d+%.%d+") or "unknown"
		return false, `{File.Path} says {Found} but pesde.toml says {ManifestData.version}`
	end

	return true, `{File.Path} is in sync at {ManifestData.version}`
end

return table.freeze(File)
