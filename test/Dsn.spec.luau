return function(t)
	local Dsn = require("../src/Transport/Dsn")

	local Valid = "https://abc123@o4507.ingest.sentry.io/4507123456789"

	t.describe("Dsn.Parse", function()
		t.test("splits a valid DSN into its parts", function()
			local Parsed = Dsn.Parse(Valid, 7, "sentry.roblox.spiraljng/2.0.0")

			t.expect(Parsed).never_is(nil)
			t.expect(Parsed.Scheme).is("https")
			t.expect(Parsed.PublicKey).is("abc123")
			t.expect(Parsed.Authority).is("o4507.ingest.sentry.io")
			t.expect(Parsed.ProjectId).is("4507123456789")
		end)

		t.test("builds the store URL with a trailing slash", function()
			local Parsed = Dsn.Parse(Valid, 7, "client")

			t.expect(Parsed.BaseUrl).is("https://o4507.ingest.sentry.io/api/4507123456789/")
		end)

		t.test("builds the auth header from the protocol version and client", function()
			local Parsed = Dsn.Parse(Valid, 7, "sentry.roblox.spiraljng/2.0.0")

			t.expect(Parsed.AuthHeader)
				.is("Sentry sentry_key=abc123,sentry_version=7,sentry_client=sentry.roblox.spiraljng/2.0.0")
		end)

		t.test("accepts http for self-hosted instances", function()
			local Parsed = Dsn.Parse("http://key@sentry.local:9000/42", 7, "client")

			t.expect(Parsed.Scheme).is("http")
			t.expect(Parsed.Authority).is("sentry.local:9000")
			t.expect(Parsed.ProjectId).is("42")
		end)

		t.test("tolerates surrounding whitespace", function()
			local Parsed = Dsn.Parse(`  {Valid}\n`, 7, "client")

			t.expect(Parsed).never_is(nil)
			t.expect(Parsed.PublicKey).is("abc123")
		end)
	end)

	t.describe("Dsn.Parse rejections", function()
		t.test("rejects an empty string", function()
			local Parsed, Reason = Dsn.Parse("", 7, "client")

			t.expect(Parsed).is(nil)
			t.expect(Reason).is("not a valid DSN")
		end)

		t.test("rejects a missing public key", function()
			local Parsed, Reason = Dsn.Parse("https://o4507.ingest.sentry.io/4507123456789", 7, "client")

			t.expect(Parsed).is(nil)
			t.expect(Reason).is("not a valid DSN")
		end)

		t.test("rejects a missing project id", function()
			local Parsed, Reason = Dsn.Parse("https://abc123@o4507.ingest.sentry.io/", 7, "client")

			t.expect(Parsed).is(nil)
			t.expect(Reason).is("not a valid DSN")
		end)

		t.test("rejects a missing authority", function()
			local Parsed, Reason = Dsn.Parse("https://abc123@/4507123456789", 7, "client")

			t.expect(Parsed).is(nil)
			t.expect(Reason).is("not a valid DSN")
		end)

		t.test("rejects an unsupported scheme", function()
			local Parsed, Reason = Dsn.Parse("ftp://abc123@o4507.ingest.sentry.io/42", 7, "client")

			t.expect(Parsed).is(nil)
			t.expect(Reason).is(`unsupported scheme "ftp"`)
		end)

		t.test("names the offending scheme when rejecting", function()
			local _, Reason = Dsn.Parse("file://abc123@host/42", 7, "client")

			t.expect(Reason).is(`unsupported scheme "file"`)
		end)
	end)
end
