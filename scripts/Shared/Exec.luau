local Process = require("@lune/process")

local Exec = {}

export type Result = {
	ok: boolean,
	code: number,
	stdout: string,
	stderr: string,
}

function Exec.Attempt(Command: string, Args: { string }, Cwd: string?): Result
	local Success, Response = pcall(function()
		return Process.exec(Command, Args, {
			cwd = Cwd,
			stdio = "forward",
		})
	end)

	if not Success then error(`could not run "{Command}" — is it installed and on PATH?`) end

	return Response :: Result
end

function Exec.Require(Command: string, Args: { string }, Cwd: string?): Result
	local Response = Exec.Attempt(Command, Args, Cwd)

	if not Response.ok then error(`"{Command}" failed with exit code {Response.code}`) end

	return Response
end

return table.freeze(Exec)
