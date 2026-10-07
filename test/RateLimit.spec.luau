return function(t)
	local RateLimit = require("../src/Transport/RateLimit")

	t.describe("RateLimit.Header", function()
		t.test("finds headers regardless of casing", function()
			local Headers = { ["X-Sentry-Rate-Limit-Remaining"] = "12" }

			t.expect(RateLimit.Header(Headers, "X-Sentry-Rate-Limit-Remaining")).is("12")
			t.expect(RateLimit.Header(Headers, "x-sentry-rate-limit-remaining")).is("12")
			t.expect(RateLimit.Header(Headers, "X-SENTRY-RATE-LIMIT-REMAINING")).is("12")
		end)

		t.test("returns nil for a missing header", function()
			t.expect(RateLimit.Header({}, "Retry-After")).is(nil)
			t.expect(RateLimit.Header(nil, "Retry-After")).is(nil)
		end)

		t.test("ignores non-string values", function()
			t.expect(RateLimit.Header({ ["Retry-After"] = 60 }, "Retry-After")).is(nil)
		end)
	end)

	t.describe("RateLimit.Resolve", function()
		t.test("clears the hold when quota remains", function()
			local Headers = {
				["X-Sentry-Rate-Limit-Remaining"] = "42",
				["X-Sentry-Rate-Limit-Reset"] = "30",
			}

			t.expect(RateLimit.Resolve(Headers, 200, 1000)).is(nil)
		end)

		t.test("holds until reset when quota is exhausted", function()
			local Headers = {
				["X-Sentry-Rate-Limit-Remaining"] = "0",
				["X-Sentry-Rate-Limit-Reset"] = "30",
			}

			t.expect(RateLimit.Resolve(Headers, 200, 1000)).is(1030)
		end)

		t.test("treats a relative reset as seconds from now", function()
			local Headers = {
				["X-Sentry-Rate-Limit-Remaining"] = "0",
				["X-Sentry-Rate-Limit-Reset"] = "60",
			}

			t.expect(RateLimit.Resolve(Headers, 200, 5000)).is(5060)
		end)

		t.test("treats an absolute reset as an epoch timestamp", function()
			local Headers = {
				["X-Sentry-Rate-Limit-Remaining"] = "0",
				["X-Sentry-Rate-Limit-Reset"] = "1759600000",
			}

			t.expect(RateLimit.Resolve(Headers, 200, 1000)).is(1759600000)
		end)

		t.test("holds on 429 using Retry-After", function()
			local Headers = { ["Retry-After"] = "17" }

			t.expect(RateLimit.Resolve(Headers, 429, 1000)).is(1017)
		end)

		t.test("holds for the default window on a bare 429", function()
			t.expect(RateLimit.Resolve({}, 429, 1000)).is(1060)
		end)

		t.test("never holds on a successful response without rate limit headers", function()
			t.expect(RateLimit.Resolve({}, 200, 1000)).is(nil)
			t.expect(RateLimit.Resolve(nil, 200, 1000)).is(nil)
		end)

		t.test("never returns a hold in the past", function()
			local Headers = {
				["X-Sentry-Rate-Limit-Remaining"] = "0",
				["X-Sentry-Rate-Limit-Reset"] = "0",
			}

			local Resolved = RateLimit.Resolve(Headers, 200, 1000)

			t.expect(Resolved).is(1060)
		end)

		t.test("ignores unparseable values", function()
			local Headers = {
				["X-Sentry-Rate-Limit-Remaining"] = "not-a-number",
				["X-Sentry-Rate-Limit-Reset"] = "also-not",
			}

			t.expect(RateLimit.Resolve(Headers, 200, 1000)).is(nil)
		end)

		t.test("prefers Retry-After over Reset on 429", function()
			local Headers = {
				["Retry-After"] = "5",
				["X-Sentry-Rate-Limit-Reset"] = "600",
			}

			t.expect(RateLimit.Resolve(Headers, 429, 1000)).is(1005)
		end)
	end)
end
