local fs = require("@lune/fs")

local Exec = require("./Shared/Exec")
local Manifest = require("./Shared/Manifest")

local ProjectFile = "example.project.json"
local Output = "example/SentryExample.rbxl"

local ManifestData = Manifest.Read()

if not fs.isFile(ProjectFile) then error(`could not find {ProjectFile}`) end

Exec.Require("rojo", { "build", ProjectFile, "--output", Output })

if not fs.isFile(Output) then error(`rojo did not produce {Output}`) end

local Size = #fs.readFile(Output)

print(`built {Output} ({Size} bytes) for {ManifestData.version}`)
