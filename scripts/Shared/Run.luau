local Process = require("@lune/process")

local Run = {}

function Run.Step(Label: string, Operation: () -> (boolean, string))
	local Success, Ok, Message = pcall(Operation)

	if not Success then
		print(`{Label}: {tostring(Ok)}`)
		Process.exit(1)
	end

	print(`{Label}: {Message}`)

	if not Ok then Process.exit(1) end
end

return table.freeze(Run)
