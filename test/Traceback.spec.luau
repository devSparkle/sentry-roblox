return function(t)
	local Traceback = require("../src/Integrations/Detection/Traceback")

	t.describe("Traceback.Lines", function()
		t.test("strips the stack markers", function()
			local Lines = Traceback.Lines("Stack Begin\nScript 'a', Line 1\nStack End")

			t.expect(#Lines).is(1)
			t.expect(Lines[1]).is("Script 'a', Line 1")
		end)

		t.test("handles blank input", function()
			t.expect(#Traceback.Lines("")).is(0)
			t.expect(#Traceback.Lines("Stack Begin\nStack End")).is(0)
		end)

		t.test("keeps every real line", function()
			local Lines = Traceback.Lines("one\ntwo\r\nthree")

			t.expect(#Lines).is(3)
			t.expect(Lines[1]).is("one")
			t.expect(Lines[3]).is("three")
		end)
	end)

	t.describe("Traceback.HasFrame", function()
		t.test("detects a script frame", function()
			t.expect(Traceback.HasFrame("Script 'Foo', Line 3")).is(true)
		end)

		t.test("returns false without frames", function()
			t.expect(Traceback.HasFrame("")).is(false)
			t.expect(Traceback.HasFrame(nil)).is(false)
			t.expect(Traceback.HasFrame("no frames here")).is(false)
		end)
	end)

	t.describe("Traceback.Mentions", function()
		t.test("finds plain substrings", function()
			t.expect(Traceback.Mentions("CoreScripts/AppShell", { "CoreScripts" })).is(true)
			t.expect(Traceback.Mentions("ReplicatedStorage/Foo", { "CoreScripts" })).is(false)
			t.expect(Traceback.Mentions(nil, { "CoreScripts" })).is(false)
		end)

		t.test("treats needles literally", function()
			t.expect(Traceback.Mentions("a.b", { "a.b" })).is(true)
			t.expect(Traceback.Mentions("axb", { "a.b" })).is(false)
		end)
	end)

	t.describe("Traceback.Matches", function()
		t.test("uses Lua patterns", function()
			t.expect(Traceback.Matches("CoreScriptFoo", { "^CoreScript" })).is(true)
			t.expect(Traceback.Matches("MyCoreScript", { "^CoreScript" })).is(false)
		end)

		t.test("survives malformed patterns", function()
			t.expect(Traceback.Matches("anything", { "[" })).is(false)
		end)

		t.test("handles nil", function()
			t.expect(Traceback.Matches(nil, { "x" })).is(false)
		end)
	end)

	t.describe("Traceback.Parse", function()
		t.test("parses the Script 'name', Line N form", function()
			local Frames = Traceback.Parse("Stack Begin\nScript 'Workspace.Foo.Bar', Line 12\nStack End")

			t.expect(#Frames).is(1)
			t.expect(Frames[1].Path).is("Workspace.Foo.Bar")
			t.expect(Frames[1].Line).is(12)
			t.expect(Frames[1].Function).is(nil)
		end)

		t.test("parses the colon form", function()
			local Frames = Traceback.Parse("ReplicatedStorage.Packages.Foo:42")

			t.expect(#Frames).is(1)
			t.expect(Frames[1].Path).is("ReplicatedStorage.Packages.Foo")
			t.expect(Frames[1].Line).is(42)
		end)

		t.test("extracts the function name when present", function()
			local Frames = Traceback.Parse("Script 'Foo', Line 3 - function doThing")

			t.expect(Frames[1].Function).is("doThing")
		end)

		t.test("keeps unrecognised lines as raw frames", function()
			local Frames = Traceback.Parse("something odd happened")

			t.expect(#Frames).is(1)
			t.expect(Frames[1].Path).is(nil)
			t.expect(Frames[1].Raw).is("something odd happened")
		end)

		t.test("returns nothing for nil input", function()
			t.expect(#Traceback.Parse(nil)).is(0)
		end)

		t.test("parses multiple frames in order", function()
			local Frames = Traceback.Parse("Script 'A', Line 1\nScript 'B', Line 2")

			t.expect(#Frames).is(2)
			t.expect(Frames[1].Path).is("A")
			t.expect(Frames[2].Path).is("B")
		end)
	end)

	t.describe("Traceback.IsTraceless", function()
		t.test("treats blank input as traceless", function()
			t.expect(Traceback.IsTraceless(nil)).is(true)
			t.expect(Traceback.IsTraceless("  \n ")).is(true)
		end)

		t.test("treats content as traced", function()
			t.expect(Traceback.IsTraceless("x")).is(false)
		end)
	end)

	t.describe("Traceback.Parse forms", function()
		t.test("parses the Script 'name', Line N form", function()
			local Frames = Traceback.Parse("Stack Begin\nScript 'Foo.Bar', Line 12 - function Baz\nStack End")

			t.expect(Frames[1].Path).is("Foo.Bar")
			t.expect(Frames[1].Line).is(12)
			t.expect(Frames[1].Function).is("Baz")
		end)

		t.test("parses the name:line form that debug.traceback gives", function()
			local Frames = Traceback.Parse("Stack Begin\nFoo.Bar:12 function Baz\nStack End")

			t.expect(Frames[1].Path).is("Foo.Bar")
			t.expect(Frames[1].Line).is(12)
			t.expect(Frames[1].Function).is("Baz")
		end)

		t.test("parses the name, line N form that ScriptContext.Error gives", function()
			local Frames = Traceback.Parse("Foo.Bar, line 12 - function Baz")

			t.expect(Frames[1].Path).is("Foo.Bar")
			t.expect(Frames[1].Line).is(12)
			t.expect(Frames[1].Function).is("Baz")
		end)

		t.test("parses the comma form without a function name", function()
			local Frames = Traceback.Parse("Players.spiraljng.PlayerScripts.Example, line 80")

			t.expect(Frames[1].Path).is("Players.spiraljng.PlayerScripts.Example")
			t.expect(Frames[1].Line).is(80)
			t.expect(Frames[1].Function).is(nil)
		end)
	end)
end
