return function(t)
	local PlayerRegistry = require("../src/Integrations/Detection/PlayerRegistry")

	local function Build()
		local Registry = PlayerRegistry.new()

		PlayerRegistry.Add(Registry, "Bob", 1)
		PlayerRegistry.Add(Registry, "Alice", 2)

		return Registry
	end

	t.describe("PlayerRegistry", function()
		t.test("starts empty", function()
			local Registry = PlayerRegistry.new()

			t.expect(PlayerRegistry.Count(Registry)).is(0)
			t.expect(#PlayerRegistry.Names(Registry)).is(0)
		end)

		t.test("tracks added players", function()
			local Registry = Build()

			t.expect(PlayerRegistry.Count(Registry)).is(2)
			t.expect(PlayerRegistry.Find(Registry, "Bob").UserId).is(1)
		end)

		t.test("returns sorted names", function()
			local Registry = Build()
			local Names = PlayerRegistry.Names(Registry)

			t.expect(Names[1]).is("Alice")
			t.expect(Names[2]).is("Bob")
		end)
	end)

	t.describe("PlayerRegistry removal and retention", function()
		t.test("retains a departed player within the window", function()
			local Registry = Build()

			PlayerRegistry.Remove(Registry, "Bob", 100, 60)

			t.expect(PlayerRegistry.Count(Registry)).is(2)
			t.expect(PlayerRegistry.Find(Registry, "Bob").UserId).is(1)
			t.expect(PlayerRegistry.Find(Registry, "Bob").ExpiresAt).is(160)
		end)

		t.test("expires a departed player after the window", function()
			local Registry = Build()

			PlayerRegistry.Remove(Registry, "Bob", 100, 60)
			t.expect(PlayerRegistry.Sweep(Registry, 159)).is(0)
			t.expect(PlayerRegistry.Sweep(Registry, 160)).is(1)
			t.expect(PlayerRegistry.Find(Registry, "Bob")).is(nil)
			t.expect(PlayerRegistry.Count(Registry)).is(1)
		end)

		t.test("does not retain when the window is zero", function()
			local Registry = Build()

			PlayerRegistry.Remove(Registry, "Bob", 100, 0)

			t.expect(PlayerRegistry.Find(Registry, "Bob")).is(nil)
			t.expect(PlayerRegistry.Count(Registry)).is(1)
		end)

		t.test("ignores removal of an unknown player", function()
			local Registry = Build()

			PlayerRegistry.Remove(Registry, "Nobody", 100, 60)

			t.expect(PlayerRegistry.Count(Registry)).is(2)
		end)

		t.test("clears retention when the player rejoins", function()
			local Registry = Build()

			PlayerRegistry.Remove(Registry, "Bob", 100, 60)
			PlayerRegistry.Add(Registry, "Bob", 1)

			t.expect(PlayerRegistry.Find(Registry, "Bob").ExpiresAt).is(nil)
			t.expect(PlayerRegistry.Count(Registry)).is(2)
			t.expect(PlayerRegistry.Sweep(Registry, 9999)).is(0)
		end)
	end)

	t.describe("PlayerRegistry.UserIds", function()
		t.test("collects ids from current and retained players", function()
			local Registry = Build()

			PlayerRegistry.Remove(Registry, "Bob", 100, 60)

			local Ids = PlayerRegistry.UserIds(Registry)

			table.sort(Ids)

			t.expect(#Ids).is(2)
			t.expect(Ids[1]).is(1)
			t.expect(Ids[2]).is(2)
		end)
	end)
end
