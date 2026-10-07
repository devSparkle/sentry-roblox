local Types = require(script.Parent.Parent:WaitForChild("Types"))

local Processors = {}

local Registered: { Types.Processor } = {}

function Processors.Add(Processor: Types.Processor): ()
	table.insert(Registered, Processor)
end

function Processors.List(): { Types.Processor }
	return Registered
end

function Processors.Count(): number
	return #Registered
end

function Processors.Clear(): ()
	table.clear(Registered)
end

return Processors
