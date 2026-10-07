return function(t)
	local Scrubber = require("../src/Integrations/Detection/Scrubber")

	t.describe("Scrubber.Escape", function()
		t.test("escapes pattern magic characters", function()
			t.expect(Scrubber.Escape("Bob")).is("Bob")
			t.expect(Scrubber.Escape("foo_bar")).is("foo%_bar")
			t.expect(Scrubber.Escape("a.b*c")).is("a%.b%*c")
			t.expect(Scrubber.Escape("a-b")).is("a%-b")
		end)
	end)

	t.describe("Scrubber.ReplaceWhole", function()
		t.test("replaces whole occurrences only", function()
			t.expect((Scrubber.ReplaceWhole("Build failed for Bob", "Bob", "<P>"))).is("Build failed for <P>")
			t.expect((Scrubber.ReplaceWhole("Bob's tool", "Bob", "<P>"))).is("<P>'s tool")
			t.expect((Scrubber.ReplaceWhole("names: Bob,Alice", "Alice", "<P>"))).is("names: Bob,<P>")
		end)

		t.test("does not touch substrings inside identifiers", function()
			t.expect((Scrubber.ReplaceWhole("BobBuilder", "Bob", "<P>"))).is("BobBuilder")
			t.expect((Scrubber.ReplaceWhole("xBob", "Bob", "<P>"))).is("xBob")
			t.expect((Scrubber.ReplaceWhole("Bob1", "Bob", "<P>"))).is("Bob1")
			t.expect((Scrubber.ReplaceWhole("Bob_Bob", "Bob", "<P>"))).is("Bob_Bob")
		end)

		t.test("does not mangle short names inside words", function()
			t.expect((Scrubber.ReplaceWhole("Banana", "a", "<P>"))).is("Banana")
			t.expect((Scrubber.ReplaceWhole("a Banana", "a", "<P>"))).is("<P> Banana")
		end)

		t.test("reports the number of replacements", function()
			local _, Count = Scrubber.ReplaceWhole("Bob met Bob", "Bob", "<P>")

			t.expect(Count).is(2)
		end)

		t.test("treats underscores as word characters", function()
			t.expect((Scrubber.ReplaceWhole("foo_bar", "foo", "<P>"))).is("foo_bar")
			t.expect((Scrubber.ReplaceWhole("foo_bar", "foo_bar", "<P>"))).is("<P>")
		end)
	end)

	t.describe("Scrubber.SortByLength", function()
		t.test("orders longest first", function()
			local Sorted = Scrubber.SortByLength({ "Al", "Alexandra", "Alex" })

			t.expect(Sorted[1]).is("Alexandra")
			t.expect(Sorted[2]).is("Alex")
			t.expect(Sorted[3]).is("Al")
		end)

		t.test("does not mutate the input", function()
			local Input = { "Al", "Alexandra" }
			Scrubber.SortByLength(Input)

			t.expect(Input[1]).is("Al")
		end)
	end)

	t.describe("Scrubber.ScrubString", function()
		t.test("assigns placeholders longest-first then alphabetically", function()
			local Result = Scrubber.ScrubString("Bob and Alice", { "Bob", "Alice" }, "<PLAYER:%d>")

			t.expect(Result).is("<PLAYER:2> and <PLAYER:1>")
		end)

		t.test("is deterministic regardless of input order", function()
			local A = Scrubber.ScrubString("Bob and Alice", { "Bob", "Alice" }, "<PLAYER:%d>")
			local B = Scrubber.ScrubString("Bob and Alice", { "Alice", "Bob" }, "<PLAYER:%d>")

			t.expect(A).is(B)
		end)

		t.test("prefers the longest match", function()
			local Result = Scrubber.ScrubString("Alexandra and Alex", { "Alex", "Alexandra" }, "<PLAYER:%d>")

			t.expect(Result).is("<PLAYER:1> and <PLAYER:2>")
		end)
	end)

	t.describe("Scrubber.Contains", function()
		t.test("matches whole words only", function()
			t.expect(Scrubber.Contains("Build failed for Bob", "Bob")).is(true)
			t.expect(Scrubber.Contains("BobBuilder", "Bob")).is(false)
			t.expect(Scrubber.Contains("Bob_Bob", "Bob")).is(false)
			t.expect(Scrubber.Contains("Banana", "a")).is(false)
		end)
	end)

	t.describe("Scrubber.Find", function()
		t.test("reports implicated players without mutating", function()
			local Payload = { message = "Bob failed", other = "Alice watched" }
			local Found = Scrubber.Find(Payload, { "Bob", "Alice" })

			t.expect(#Found).is(2)
			t.expect(Payload.message).is("Bob failed")
		end)

		t.test("finds names nested in tables", function()
			local Payload = { exception = { { value = "Bob exploded" } } }
			local Found = Scrubber.Find(Payload, { "Bob" })

			t.expect(#Found).is(1)
			t.expect(Found[1]).is("Bob")
		end)

		t.test("returns nothing for an empty name list", function()
			t.expect(#Scrubber.Find({ message = "Bob" }, {})).is(0)
		end)

		t.test("does not double count", function()
			local Payload = { a = "Bob", b = "Bob" }

			t.expect(#Scrubber.Find(Payload, { "Bob" })).is(1)
		end)
	end)

	t.describe("Scrubber.Apply", function()
		t.test("returns the payload untouched when there are no names", function()
			local Payload = { message = "Bob failed" }
			local Result, Found = Scrubber.Apply(Payload, {})

			t.expect(Result.message).is("Bob failed")
			t.expect(#Found).is(0)
		end)

		t.test("scrubs nested tables", function()
			local Payload = {
				message = "Bob failed",
				exception = {
					{
						value = "Bob exploded",
						nested = { deep = "Bob again" },
					},
				},
			}

			local Result, Found = Scrubber.Apply(Payload, { "Bob" })

			t.expect(Result.message).is("<PLAYER> failed")
			t.expect(Result.exception[1].value).is("<PLAYER> exploded")
			t.expect(Result.exception[1].nested.deep).is("<PLAYER> again")
			t.expect(#Found).is(1)
			t.expect(Found[1]).is("Bob")
		end)

		t.test("reports each implicated player once", function()
			local Payload = { a = "Bob", b = "Bob and Alice", c = "Alice" }
			local _, Found = Scrubber.Apply(Payload, { "Bob", "Alice" })

			t.expect(#Found).is(2)
		end)

		t.test("leaves non-string leaves alone", function()
			local Payload = { count = 5, flag = true, nothing = nil }
			local Result = Scrubber.Apply(Payload, { "Bob" })

			t.expect(Result.count).is(5)
			t.expect(Result.flag).is(true)
		end)

		t.test("stops recursing past the depth limit", function()
			local Payload = { level = 1 }
			local Cursor = Payload

			for Index = 2, 20 do
				Cursor.next = { level = Index }
				Cursor = Cursor.next
			end

			Cursor.message = "Bob"

			local Result = Scrubber.Apply(Payload, { "Bob" })
			local Walk = Result

			while Walk.next do
				Walk = Walk.next
			end

			t.expect(Walk.message).is("Bob")
		end)
	end)

	t.describe("Scrubber.Render", function()
		t.test("uses the placeholder as-is when it has no index", function()
			t.expect(Scrubber.Render("<PLAYER>", 3)).is("<PLAYER>")
		end)

		t.test("formats the placeholder when it has a %d", function()
			t.expect(Scrubber.Render("<PLAYER:%d>", 3)).is("<PLAYER:3>")
		end)
	end)

	t.describe("Scrubber grouping stability", function()
		t.test("produces identical text regardless of who else is in the server", function()
			local Alone = Scrubber.Apply({ message = "Bob failed" }, { "Bob" })
			local Crowded = Scrubber.Apply({ message = "Bob failed" }, { "Alice", "Bob", "Charlotte", "Dave" })

			t.expect(Alone.message).is(Crowded.message)
			t.expect(Alone.message).is("<PLAYER> failed")
		end)

		t.test("produces identical text regardless of name ordering", function()
			local A = Scrubber.Apply({ message = "Bob failed" }, { "Bob", "Alice" })
			local B = Scrubber.Apply({ message = "Bob failed" }, { "Alice", "Bob" })

			t.expect(A.message).is(B.message)
		end)

		t.test("collapses several implicated players to one token", function()
			local Result = Scrubber.Apply({ message = "Bob attacked Alice" }, { "Bob", "Alice" })

			t.expect(Result.message).is("<PLAYER> attacked <PLAYER>")
		end)
	end)

	t.describe("Scrubber with user id tokens", function()
		t.test("scrubs a user id appearing in text", function()
			local Result = Scrubber.Apply({ message = "failed to save user 1234567" }, { "1234567" })

			t.expect(Result.message).is("failed to save user <PLAYER>")
		end)

		t.test("does not partially match a longer number", function()
			local Result = Scrubber.Apply({ message = "count 12345678" }, { "1234567" })

			t.expect(Result.message).is("count 12345678")
		end)

		t.test("keeps the name and the id collapsing to the same token", function()
			local ByName = Scrubber.Apply({ message = "Bob failed" }, { "Bob" })
			local ById = Scrubber.Apply({ message = "1234567 failed" }, { "1234567" })

			t.expect(ByName.message).is(ById.message)
		end)
	end)

	t.describe("Scrubber.Apply on frozen tables", function()
		t.test("does not throw on a frozen table", function()
			local Payload = { sdk = table.freeze({ name = "sentry.roblox.spiraljng" }) }

			local Ok = pcall(function()
				Scrubber.Apply(Payload, { "Bob" }, "<PLAYER>")
			end)

			t.expect(Ok).is_true()
		end)

		t.test("replaces the frozen table with a scrubbed mutable copy", function()
			local Payload = { sdk = table.freeze({ name = "Bob" }) }
			local Result = Scrubber.Apply(Payload, { "Bob" }, "<PLAYER>")

			t.expect(Result.sdk.name).is("<PLAYER>")
			t.expect(table.isfrozen(Result.sdk)).is(false)
			t.expect(Result.sdk.name ~= "Bob").is_true()
		end)

		t.test("still scrubs the mutable fields around it", function()
			local Payload = {
				sdk = table.freeze({ name = "sentry.roblox.spiraljng" }),
				message = { message = "no inventory for Bob" },
			}

			local Result = Scrubber.Apply(Payload, { "Bob" }, "<PLAYER>")

			t.expect(Result.message.message).is("no inventory for <PLAYER>")
		end)
	end)
end
