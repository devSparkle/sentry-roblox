local Process = require("@lune/process")

local tiniest = require("../lune_packages/tiniest_lune").configure({
	pretty = {
		disable_colour = true,
	},
})

local Specs = {
	"Dsn",
	"PlayerRegistry",
	"Policy",
	"Protocol",
	"RateLimit",
	"Scrubber",
	"Table",
	"Traceback",
}

local function Suite()
	for _, Name in Specs do
		local Spec = require(`../test/{Name}.spec`)
		Spec(tiniest)
	end
end

local Tests = tiniest.collect_tests(Suite)
local Result = tiniest.run_tests(Tests, {})

if Result.status_tally.fail > 0 then Process.exit(1) end
