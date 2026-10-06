local Fs = require("@lune/fs")
local Process = require("@lune/process")

local Exec = require("./Shared/Exec")
local Manifest = require("./Shared/Manifest")
local VersionFile = require("./Version/File")

local ProjectFile = "build.project.json"
local OutputDirectory = "build"
local OutputName = "SentryRoblox.rbxm"

local ManifestData = Manifest.Read()
local InSync, Message = VersionFile.Verify()

if not InSync then
	print(Message)
	print("run the sync script before building")
	Process.exit(1)
end

if not Fs.isFile(ProjectFile) then error(`could not find {ProjectFile}`) end

if not Fs.isDir(OutputDirectory) then Fs.writeDir(OutputDirectory) end

local Output = `{OutputDirectory}/{OutputName}`

Exec.Require("rojo", { "build", ProjectFile, "--output", Output })

if not Fs.isFile(Output) then error(`rojo did not produce {Output}`) end

local Size = #Fs.readFile(Output)

print(`built {Output} ({Size} bytes) for {ManifestData.version}`)
