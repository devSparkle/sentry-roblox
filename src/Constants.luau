local Version = require(script.Parent:WaitForChild("Version"))
local Types = require(script.Parent:WaitForChild("Types"))

local Constants = {}

Constants.Name = "sentry.roblox.spiraljng"
Constants.Version = Version
Constants.ProtocolVersion = 7

local Interface: Types.Sdk = {
	name = Constants.Name,
	version = Constants.Version,
}

Constants.Interface = table.freeze(Interface)

function Constants.Client(): string
	return string.format("%s/%s", Constants.Interface.name, Constants.Interface.version)
end

return table.freeze(Constants)
