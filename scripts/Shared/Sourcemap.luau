local fs = require("@lune/fs")

local Exec = require("./Exec")

local Sourcemap = {}

Sourcemap.ProjectFile = "example.project.json"
Sourcemap.Path = "sourcemap.json"

function Sourcemap.Generate(): string
	if not fs.isFile(Sourcemap.ProjectFile) then error(`could not find {Sourcemap.ProjectFile}`) end

	Exec.Require("rojo", { "sourcemap", Sourcemap.ProjectFile, "--output", Sourcemap.Path })

	if not fs.isFile(Sourcemap.Path) then error(`rojo did not produce {Sourcemap.Path}`) end

	return Sourcemap.Path
end

return table.freeze(Sourcemap)
