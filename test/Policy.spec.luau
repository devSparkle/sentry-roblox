return function(t)
	local Policy = require("../src/Integrations/Detection/Policy")

	t.describe("Policy.IsGeneratedName", function()
		t.test("flags random alphanumeric names", function()
			t.expect(Policy.IsGeneratedName("aB3kL9xQ")).is(true)
			t.expect(Policy.IsGeneratedName("x7f2k9zq")).is(true)
			t.expect(Policy.IsGeneratedName("Zq4Wm8Tp2")).is(true)
		end)

		t.test("accepts readable identifiers", function()
			t.expect(Policy.IsGeneratedName("ShopUI")).is(false)
			t.expect(Policy.IsGeneratedName("PlayerData123")).is(false)
			t.expect(Policy.IsGeneratedName("MainModule")).is(false)
			t.expect(Policy.IsGeneratedName("CombatSystem2")).is(false)
		end)

		t.test("ignores names below the minimum length", function()
			t.expect(Policy.IsGeneratedName("aB3")).is(false)
			t.expect(Policy.IsGeneratedName("x7f2k9z")).is(false)
			t.expect(Policy.IsGeneratedName("aB3kL9xZ", 8)).is(true)
		end)

		t.test("keeps names sitting exactly on the vowel threshold", function()
			t.expect(Policy.IsGeneratedName("HTMLParser5")).is(false)
			t.expect(Policy.IsGeneratedName("aB3kL9x", 7)).is(false)
		end)

		t.test("requires both digits and letters", function()
			t.expect(Policy.IsGeneratedName("BCDFGHJK")).is(false)
			t.expect(Policy.IsGeneratedName("12345678")).is(false)
		end)

		t.test("rejects names containing separators", function()
			t.expect(Policy.IsGeneratedName("aB3k-L9xQ")).is(false)
			t.expect(Policy.IsGeneratedName("aB3k L9xQ")).is(false)
			t.expect(Policy.IsGeneratedName("aB3k.L9xQ")).is(false)
		end)

		t.test("handles nil and empty input", function()
			t.expect(Policy.IsGeneratedName(nil)).is(false)
			t.expect(Policy.IsGeneratedName("")).is(false)
		end)
	end)

	t.describe("Policy.IsTraceless", function()
		t.test("treats missing and blank text as traceless", function()
			t.expect(Policy.IsTraceless(nil)).is(true)
			t.expect(Policy.IsTraceless("")).is(true)
			t.expect(Policy.IsTraceless("   ")).is(true)
			t.expect(Policy.IsTraceless("\n\t\r")).is(true)
		end)

		t.test("treats real content as traced", function()
			t.expect(Policy.IsTraceless("Script 'x', Line 1")).is(false)
			t.expect(Policy.IsTraceless("a")).is(false)
		end)
	end)

	t.describe("Policy.IsInternalText", function()
		t.test("detects Roblox internal roots", function()
			t.expect(Policy.IsInternalText("CoreScripts/AppShell")).is(true)
			t.expect(Policy.IsInternalText("CorePackages/React")).is(true)
			t.expect(Policy.IsInternalText("RobloxScript.Foo")).is(true)
			t.expect(Policy.IsInternalText("CoreGui/SomeThing")).is(true)
			t.expect(Policy.IsInternalText("[CoreGui] failed")).is(true)
		end)

		t.test("leaves game code alone", function()
			t.expect(Policy.IsInternalText("ReplicatedStorage/MyScript")).is(false)
			t.expect(Policy.IsInternalText("ServerScriptService/Main")).is(false)
			t.expect(Policy.IsInternalText(nil)).is(false)
		end)
	end)

	t.describe("Policy.IsInternalOrigin", function()
		t.test("detects CoreScript instances", function()
			local Fake = {
				IsA = function(_, ClassName)
					return ClassName == "CoreScript"
				end,
			}

			t.expect(Policy.IsInternalOrigin(Fake)).is(true)
		end)

		t.test("detects instances living under internal roots", function()
			local Fake = {
				IsA = function()
					return false
				end,
				GetFullName = function()
					return "CoreGui/RobloxGui/CoreScripts/AppShell"
				end,
			}

			t.expect(Policy.IsInternalOrigin(Fake)).is(true)
		end)

		t.test("accepts ordinary game instances", function()
			local Fake = {
				IsA = function()
					return false
				end,
				GetFullName = function()
					return "ReplicatedStorage/Packages/MyModule"
				end,
			}

			t.expect(Policy.IsInternalOrigin(Fake)).is(false)
			t.expect(Policy.IsInternalOrigin(nil)).is(false)
		end)
	end)

	t.describe("Policy.IsForeignOrigin", function()
		t.test("treats a nil origin as foreign", function()
			t.expect(Policy.IsForeignOrigin(nil, {})).is(true)
		end)

		t.test("treats non-descendants of the root as foreign", function()
			local Root = {
				IsAncestorOf = function()
					return false
				end,
			}

			t.expect(Policy.IsForeignOrigin({}, Root)).is(true)
		end)

		t.test("accepts descendants of the root", function()
			local Root = {
				IsAncestorOf = function()
					return true
				end,
			}

			t.expect(Policy.IsForeignOrigin({}, Root)).is(false)
		end)

		t.test("does not reject when the root cannot answer", function()
			local Root = {
				IsAncestorOf = function()
					error("boom")
				end,
			}

			t.expect(Policy.IsForeignOrigin({}, Root)).is(false)
		end)
	end)

	t.describe("Policy.Decide", function()
		local Game = {
			IsAncestorOf = function()
				return true
			end,
		}

		local function Origin(Name)
			return {
				Name = Name,
				IsA = function()
					return false
				end,
				GetFullName = function()
					return `ReplicatedStorage/{Name}`
				end,
			}
		end

		t.test("keeps ordinary game errors", function()
			local Keep, Reason = Policy.Decide(Origin("CombatHandler"), "Script 'CombatHandler', Line 12", Game)

			t.expect(Keep).is(true)
			t.expect(Reason).is(nil)
		end)

		t.test("drops nil origins", function()
			local Keep, Reason = Policy.Decide(nil, "Stack Begin", Game)

			t.expect(Keep).is(false)
			t.expect(Reason).is("nil_origin")
		end)

		t.test("drops internal traces", function()
			local Keep, Reason = Policy.Decide(Origin("CombatHandler"), "CorePackages/React/init", Game)

			t.expect(Keep).is(false)
			t.expect(Reason).is("internal_trace")
		end)

		t.test("drops foreign origins", function()
			local Foreign = {
				Name = "Foreign",
				IsA = function()
					return false
				end,
				GetFullName = function()
					return "Foreign"
				end,
			}

			local Orphan = {
				IsAncestorOf = function()
					return false
				end,
			}

			local Keep, Reason = Policy.Decide(Foreign, "Script 'Foreign', Line 1", Orphan)

			t.expect(Keep).is(false)
			t.expect(Reason).is("foreign_origin")
		end)

		t.test("drops generated script names", function()
			local Keep, Reason = Policy.Decide(Origin("aB3kL9xQ"), "Script 'aB3kL9xQ', Line 1", Game)

			t.expect(Keep).is(false)
			t.expect(Reason).is("generated_name")
		end)

		t.test("honours an explicit settings table", function()
			local Permissive = {
				RejectNilOrigin = false,
				RejectForeignOrigin = false,
				RejectGeneratedNames = false,
				RejectInternal = false,
				RejectTraceless = false,
			}

			local Keep = Policy.Decide(nil, nil, Game, Permissive)

			t.expect(Keep).is(true)
		end)

		t.test("can opt into dropping traceless errors", function()
			local Strict = {
				RejectTraceless = true,
			}

			local Keep, Reason = Policy.Decide(Origin("CombatHandler"), nil, Game, Strict)

			t.expect(Keep).is(false)
			t.expect(Reason).is("traceless")
		end)
	end)
end
