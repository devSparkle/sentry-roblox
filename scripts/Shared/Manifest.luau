local Fs = require("@lune/fs")
local Serde = require("@lune/serde")

export type Target = {
	environment: string,
	lib: string?,
	bin: string?,
}

export type Shape = {
	name: string,
	version: string,
	description: string?,
	license: string?,
	authors: { string }?,
	repository: string?,
	includes: { string }?,
	target: Target,
	scripts: { [string]: string }?,
	engines: { [string]: string }?,
}

local Manifest = {}

Manifest.Path = "pesde.toml"

local RequiredFields = { "name", "version", "target" }

local function Validate(Decoded: any): Shape
	if type(Decoded) ~= "table" then error("pesde.toml did not decode to a table") end

	for _, Field in RequiredFields do
		if Decoded[Field] == nil then error(`pesde.toml is missing the required field "{Field}"`) end
	end

	if type(Decoded.name) ~= "string" then error('pesde.toml field "name" must be a string') end

	if type(Decoded.version) ~= "string" then error('pesde.toml field "version" must be a string') end

	if type(Decoded.target) ~= "table" then error('pesde.toml field "target" must be a table') end

	if type(Decoded.target.environment) ~= "string" then
		error('pesde.toml field "target.environment" must be a string')
	end

	return Decoded :: Shape
end

function Manifest.Read(Path: string?): Shape
	local ResolvedPath = Path or Manifest.Path

	if not Fs.isFile(ResolvedPath) then error(`could not find {ResolvedPath}`) end

	local Success, Decoded = pcall(function()
		return Serde.decode("toml", Fs.readFile(ResolvedPath))
	end)

	if not Success then error(`${ResolvedPath} is not valid TOML`) end

	return Validate(Decoded)
end

function Manifest.Scope(Name: string): string
	return string.split(Name, "/")[1]
end

function Manifest.Package(Name: string): string
	return string.split(Name, "/")[2]
end

function Manifest.WallyName(Name: string): string
	return string.gsub(Name, "_", "-")
end

return table.freeze(Manifest)
