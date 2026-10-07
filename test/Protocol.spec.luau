return function(t)
	local Protocol = require("../src/Integrations/SentryClientRelay/Protocol")

	t.describe("Protocol.ValidateEnvelope", function()
		t.test("rejects non-tables", function()
			t.expect((Protocol.ValidateEnvelope(nil))).is(false)
			t.expect((Protocol.ValidateEnvelope("nope"))).is(false)
			t.expect((Protocol.ValidateEnvelope(42))).is(false)
		end)

		t.test("requires an event table", function()
			t.expect((Protocol.ValidateEnvelope({}))).is(false)
			t.expect((Protocol.ValidateEnvelope({ event = "nope" }))).is(false)
		end)

		t.test("rejects a non-string traceback", function()
			local Valid = Protocol.ValidateEnvelope({
				event = { message = { message = "hi" } },
				traceback = {},
			})

			t.expect(Valid).is(false)
		end)

		t.test("accepts a well-formed envelope", function()
			local Valid = Protocol.ValidateEnvelope({
				event = { message = { message = "hi" } },
				traceback = "Stack Begin\nStack End",
			})

			t.expect(Valid).is(true)
		end)

		t.test("rejects an event with neither message nor exception", function()
			t.expect((Protocol.ValidateEnvelope({ event = { level = "error" } }))).is(false)
		end)
	end)

	t.describe("Protocol.Sanitize", function()
		t.test("drops reserved server-authoritative fields", function()
			local Clean = Protocol.Sanitize({
				message = { message = "hi" },
				sdk = { name = "fake" },
				user = { id = 1 },
				event_id = "abc",
				release = "9.9.9",
				environment = "prod",
				server_name = "evil",
				dist = "1",
				platform = "other",
				timestamp = 0,
				errors = {},
			})

			t.expect(Clean.message.message).is("hi")
			t.expect(Clean.sdk).is(nil)
			t.expect(Clean.user).is(nil)
			t.expect(Clean.event_id).is(nil)
			t.expect(Clean.release).is(nil)
			t.expect(Clean.environment).is(nil)
			t.expect(Clean.server_name).is(nil)
			t.expect(Clean.dist).is(nil)
			t.expect(Clean.errors).is(nil)
		end)

		t.test("drops fields that are not allowed", function()
			local Clean = Protocol.Sanitize({
				message = { message = "hi" },
				malicious = "payload",
				_metatable = {},
			})

			t.expect(Clean.malicious).is(nil)
			t.expect(Clean._metatable).is(nil)
		end)

		t.test("keeps allowed fields", function()
			local Clean = Protocol.Sanitize({
				exception = { { type = "Error", value = "boom" } },
				level = "error",
				logger = "client",
				tags = { biome = "volcano" },
			})

			t.expect(Clean.level).is("error")
			t.expect(Clean.logger).is("client")
			t.expect(Clean.tags.biome).is("volcano")
			t.expect(Clean.exception[1].value).is("boom")
		end)

		t.test("truncates over-long strings", function()
			local Long = string.rep("a", 5000)
			local Clean = Protocol.Sanitize({ message = { message = Long } }, { MaximumStringLength = 32 })

			t.expect(#Clean.message.message).is(32)
		end)

		t.test("limits the number of exceptions", function()
			local Exceptions = {}

			for Index = 1, 50 do
				table.insert(Exceptions, { type = "Error", value = `boom {Index}` })
			end

			local Clean = Protocol.Sanitize({ exception = Exceptions }, { MaximumExceptions = 3 })

			t.expect(#Clean.exception).is(3)
		end)

		t.test("limits and normalises stack frames", function()
			local Frames = {}

			for Index = 1, 500 do
				table.insert(Frames, { filename = "Foo", lineno = Index, ["function"] = "bar" })
			end

			local Clean = Protocol.Sanitize({
				exception = {
					{ type = "Error", value = "boom", stacktrace = { frames = Frames } },
				},
			}, { MaximumFrames = 10 })

			t.expect(#Clean.exception[1].stacktrace.frames).is(10)
			t.expect(Clean.exception[1].stacktrace.frames[1].filename).is("Foo")
		end)

		t.test("drops frame fields that are not recognised", function()
			local Clean = Protocol.Sanitize({
				exception = {
					{
						type = "Error",
						value = "boom",
						stacktrace = {
							frames = { { filename = "Foo", lineno = 1, injected = "bad", vars = { secret = 1 } } },
						},
					},
				},
			})

			t.expect(Clean.exception[1].stacktrace.frames[1].injected).is(nil)
			t.expect(Clean.exception[1].stacktrace.frames[1].vars).is(nil)
		end)

		t.test("rejects non-table exception entries", function()
			local Clean = Protocol.Sanitize({ exception = { "not a table", 42 } })

			t.expect(#Clean.exception).is(0)
		end)

		t.test("stops recursing past the depth limit", function()
			local Payload = { message = { message = "hi" }, extra = {} }
			local Cursor = Payload.extra

			for Index = 1, 30 do
				Cursor.deep = { level = Index }
				Cursor = Cursor.deep
			end

			local Clean = Protocol.Sanitize(Payload, { MaximumDepth = 3 })
			local Walk = Clean.extra
			local Depth = 0

			while Walk ~= nil and Walk.deep ~= nil do
				Walk = Walk.deep
				Depth += 1
			end

			t.expect(Depth < 30).is(true)
			t.expect(Depth <= 3).is(true)
			t.expect(Walk ~= nil).is(true)
		end)
	end)

	t.describe("Protocol.Limiter", function()
		t.test("allows a burst then refuses", function()
			local Limiter = Protocol.Limiter(3, 10)

			t.expect(Protocol.Allow(Limiter, "player", 0)).is(true)
			t.expect(Protocol.Allow(Limiter, "player", 0)).is(true)
			t.expect(Protocol.Allow(Limiter, "player", 0)).is(true)
			t.expect(Protocol.Allow(Limiter, "player", 0)).is(false)
		end)

		t.test("refills over time", function()
			local Limiter = Protocol.Limiter(3, 10)

			Protocol.Allow(Limiter, "player", 0)
			Protocol.Allow(Limiter, "player", 0)
			Protocol.Allow(Limiter, "player", 0)

			t.expect(Protocol.Allow(Limiter, "player", 0)).is(false)
			t.expect(Protocol.Allow(Limiter, "player", 5)).is(true)
			t.expect(Protocol.Allow(Limiter, "player", 5)).is(false)
		end)

		t.test("tracks keys independently", function()
			local Limiter = Protocol.Limiter(1, 10)

			t.expect(Protocol.Allow(Limiter, "a", 0)).is(true)
			t.expect(Protocol.Allow(Limiter, "b", 0)).is(true)
			t.expect(Protocol.Allow(Limiter, "a", 0)).is(false)
			t.expect(Protocol.Allow(Limiter, "b", 0)).is(false)
		end)

		t.test("never exceeds the burst after a long idle period", function()
			local Limiter = Protocol.Limiter(2, 10)

			t.expect(Protocol.Allow(Limiter, "a", 0)).is(true)

			local Allowed = 0

			for _ = 1, 10 do
				if Protocol.Allow(Limiter, "a", 1000) then
					Allowed += 1
				end
			end

			t.expect(Allowed).is(2)
		end)

		t.test("forgets a key on request", function()
			local Limiter = Protocol.Limiter(1, 10)

			Protocol.Allow(Limiter, "a", 0)
			t.expect(Protocol.Allow(Limiter, "a", 0)).is(false)

			Protocol.Forget(Limiter, "a")
			t.expect(Protocol.Allow(Limiter, "a", 0)).is(true)
		end)
	end)
end
