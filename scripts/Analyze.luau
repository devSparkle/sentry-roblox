local Fs = require("@lune/fs")
local Net = require("@lune/net")
local Process = require("@lune/process")

local Exec = require("./Shared/Exec")
local Sourcemap = require("./Shared/Sourcemap")

local DefinitionsPath = "globalTypes.d.luau"
local DefinitionsUrl = "https://raw.githubusercontent.com/JohnnyMorganz/luau-lsp/main/scripts/globalTypes.d.luau"

local Ignored = {
	"build/**",
	"roblox_packages/**",
	".pesde/**",
}

local function DownloadDefinitions()
	local Success, Response = pcall(function()
		return Net.request(DefinitionsUrl)
	end)

	if not Success then error("could not reach the Roblox definitions source") end

	if Response.statusCode ~= 200 then
		error(`could not download the Roblox definitions (HTTP {Response.statusCode})`)
	end

	Fs.writeFile(DefinitionsPath, Response.body)
	print(`downloaded {DefinitionsPath}`)
end

if table.find(Process.args, "--refresh") or not Fs.isFile(DefinitionsPath) then DownloadDefinitions() end

local SourcemapPath = Sourcemap.Generate()
local Args = { "analyze", `--sourcemap={SourcemapPath}`, `--defs={DefinitionsPath}` }

for _, Pattern in Ignored do
	table.insert(Args, `--ignore={Pattern}`)
end

table.insert(Args, "src")

Exec.Require("luau-lsp", Args)

print("typecheck passed")
