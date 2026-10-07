return function(t)
	local Table = require("../src/Utility/Table")

	t.describe("Table.DeepCopy", function()
		t.test("copies nested tables without sharing", function()
			local Original = { a = 1, nested = { b = 2 } }
			local Copy = Table.DeepCopy(Original)

			Copy.nested.b = 99

			t.expect(Original.nested.b).is(2)
			t.expect(Copy.nested.b).is(99)
		end)

		t.test("survives a self-referencing table", function()
			local Cyclic = { name = "cycle" }
			Cyclic.self = Cyclic

			local Copy = Table.DeepCopy(Cyclic)

			t.expect(Copy.name).is("cycle")
			t.expect(Copy.self).is(Copy)
		end)

		t.test("survives two tables pointing at each other", function()
			local A = { name = "a" }
			local B = { name = "b", other = A }
			A.other = B

			local Copy = Table.DeepCopy(A)

			t.expect(Copy.other.other).is(Copy)
			t.expect(Copy.other.name).is("b")
		end)

		t.test("passes non-tables straight through", function()
			t.expect(Table.DeepCopy(7)).is(7)
			t.expect(Table.DeepCopy("text")).is("text")
			t.expect(Table.DeepCopy(nil)).is(nil)
		end)

		t.test("copies a frozen table into a mutable one", function()
			local Copy = Table.DeepCopy(table.freeze({ a = 1 }))

			t.expect(table.isfrozen(Copy)).is(false)

			Copy.a = 2

			t.expect(Copy.a).is(2)
		end)
	end)

	t.describe("Table.Merge", function()
		t.test("overlays keys from the second table", function()
			local Merged = Table.Merge({ a = 1, b = 2 }, { b = 99, c = 3 })

			t.expect(Merged.a).is(1)
			t.expect(Merged.b).is(99)
			t.expect(Merged.c).is(3)
		end)

		t.test("merges nested tables rather than replacing them", function()
			local Merged = Table.Merge({ nested = { a = 1, b = 2 } }, { nested = { b = 99 } })

			t.expect(Merged.nested.a).is(1)
			t.expect(Merged.nested.b).is(99)
		end)

		t.test("does not mutate the base table", function()
			local Base = { a = 1 }
			Table.Merge(Base, { a = 2, b = 3 })

			t.expect(Base.a).is(1)
			t.expect(Base.b).is(nil)
		end)

		t.test("survives a cycle present in both tables", function()
			local Base = { name = "base" }
			Base.self = Base

			local Override = { extra = true }
			Override.self = Override

			local Merged = Table.Merge(Base, Override)

			t.expect(Merged.name).is("base")
			t.expect(Merged.extra).is(true)
			t.expect(Merged.self).is(Merged)
		end)

		t.test("aliases an override-only table rather than recursing into it", function()
			local Cyclic = { name = "cycle" }
			Cyclic.self = Cyclic

			local Merged = Table.Merge({}, Cyclic)

			t.expect(Merged.name).is("cycle")
			t.expect(Merged.self).is(Cyclic)
		end)
	end)

	t.describe("Table.Sanitize", function()
		t.test("keeps ordinary data untouched", function()
			local Clean = Table.Sanitize({ a = 1, b = "two", c = { d = true } })

			t.expect(Clean.a).is(1)
			t.expect(Clean.b).is("two")
			t.expect(Clean.c.d).is(true)
		end)

		t.test("drops a self-reference rather than the whole table", function()
			local Cyclic = { name = "cycle" }
			Cyclic.self = Cyclic

			local Clean = Table.Sanitize(Cyclic)

			t.expect(Clean.name).is("cycle")
			t.expect(Clean.self).is(nil)
		end)

		t.test("drops a two table cycle", function()
			local A = { name = "a" }
			local B = { name = "b", other = A }
			A.other = B

			local Clean = Table.Sanitize(A)

			t.expect(Clean.name).is("a")
			t.expect(Clean.other.name).is("b")
			t.expect(Clean.other.other).is(nil)
		end)

		t.test("keeps a table referenced twice, duplicated", function()
			local Shared = { value = 7 }
			local Clean = Table.Sanitize({ first = Shared, second = Shared })

			t.expect(Clean.first.value).is(7)
			t.expect(Clean.second.value).is(7)
		end)

		t.test("drops values that cannot be encoded", function()
			local Clean = Table.Sanitize({ fn = function() end, ok = 1 })

			t.expect(Clean.fn).is(nil)
			t.expect(Clean.ok).is(1)
		end)

		t.test("drops keys that are not strings or numbers", function()
			local Key = {}
			local Clean = Table.Sanitize({ [Key] = "dropped", kept = "yes" })

			t.expect(Clean.kept).is("yes")
			t.expect(next(Clean, nil)).is("kept")
		end)

		t.test("caps nesting depth", function()
			local Root = {}
			local Cursor = Root

			for _ = 1, 20 do
				Cursor.next = {}
				Cursor = Cursor.next
			end

			local Clean = Table.Sanitize(Root, 5)
			local Depth = 0
			local Walk = Clean

			while Walk ~= nil do
				Depth += 1
				Walk = Walk.next
			end

			t.expect(Depth).is(5)
		end)

		t.test("does not mutate the input", function()
			local Cyclic = { name = "cycle" }
			Cyclic.self = Cyclic

			Table.Sanitize(Cyclic)

			t.expect(Cyclic.self).is(Cyclic)
		end)
	end)
end
