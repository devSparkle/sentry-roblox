# SentryRoblox

Unofficial [Sentry](https://sentry.io) SDK for Roblox/Luau.

Works with any Sentry-compatible error tracking software, including open-source Sentry alternatives like [GlitchTip](https://glitchtip.com/) and [Bugsink](https://www.bugsink.com/).

### Features

- Automatic error and warning captures
- Scrubs PII and generalizes message info to preserve issue grouping
- Built in client relay without DSN leakage
- Fully typed
- Tested (programmatically and in live-service games)

### Installation


First, map your packages folder in your Rojo project file:

```json
"ReplicatedStorage": {
	"$className": "ReplicatedStorage",
	"Packages": {
		"$className": "Folder",
		"$path": "roblox_packages" // "Packages" for wally
	}
}
```

<details>

<summary>using pesde</summary>

```sh
pesde add spiraljng/sentryroblox --target roblox --alias SentryRoblox
```


Require it as `require(game.ReplicatedStorage.Packages.SentryRoblox)`.

</details>

<details>

<summary>using wally</summary>

in `wally.toml`:

```toml
[dependencies]
SentryRoblox = "spiraljng/sentryroblox@2.0.0"
```

```sh
wally install
```

Require it as `require(game.ReplicatedStorage.Packages.SentryRoblox)`.

</details>

<details>

<summary>using the model file</summary>

Download `SentryRoblox.rbxm` from the [releases page](https://github.com/spiraljng/sentryroblox/releases) and drop it into `ReplicatedStorage`.

Require it as `require(game.ReplicatedStorage.SentryRoblox)`.

</details>

### Usage

#### Initialising

```lua
local SentryRoblox = require(game.ReplicatedStorage.SentryRoblox)

SentryRoblox:Init({
	DSN = "https://example@o0.ingest.sentry.io/0",
})
```

`DSN` is the only argument you have to pass. `Init` does nothing without one

**`Init` is server-only.** See [the client relay](#the-client-relay) for more info regarding client captures.

| option           | type      | default                      |
| ---------------- | --------- | ---------------------------- |
| `DSN`            | `string`  | required                     |
| `Release`        | `string`  | `PlaceId@PlaceVersion`       |
| `Environment`    | `string`  | `"studio"` or `"production"` |
| `SampleRate`     | `number`  | `1.0`                        |
| `SendDefaultPII` | `boolean` | `false`                      |
| `Debug`          | `boolean` | `false`                      |

**`Release`** defaults to a string built from the place id and place version. Override it with your own versioning if available

**`Environment`** is derived from `RunService:IsStudio()`, so Studio traffic and live traffic do not mix in your issue list. If you override this flag, it is recommended you keep studio traffic separate

**`SampleRate`** samples error events (only sends the specified % of requests). Sentry's advice is to sample transactions rather than errors, so leave this alone unless you have some reason for it

**`SendDefaultPII`** controls how much of the player's info gets attached. See [Privacy and grouping](#privacy-and-grouping)

**`Debug`** prints extra detail when an integration fails to set up or a capture throws. Off by default.

Delivery failures are the exception. The first failed request always prints, with the status and the reason, so a misconfigured SDK never fails silently. It stays quiet until a request succeeds again.

#### Capturing errors

By default, you do not have to do anything. Once `Init` has run, these are captured automatically:

- Uncaught errors, via `ScriptContext.Error`
- Warnings, via `LogService.MessageOut`
- Errors and warnings on the client are [forwarded over the relay](#the-client-relay)

For everything else:

```lua
SentryRoblox:CaptureMessage("checkpoint reached", "info")

SentryRoblox:CaptureException("inventory failed to reconcile")

SentryRoblox:CaptureEvent(Event, Hint?)
```

`CaptureMessage` takes a level: `fatal`, `error`, `warning`, `info` or `debug`

To catch an error rather than report one you already have, use `ExceptionHandler`. It returns a function that works as `xpcall`'s message handler:

```lua
xpcall(Reconcile, SentryRoblox:ExceptionHandler())
```

Errors thrown inside a Sentry handler cannot recurse back through the SDK. A failure while reporting a failure is dropped rather than looping

#### Scopes

A scope is a collection of context that gets copied onto an event at the moment it is captured.

There are two levels worth thinking about. A top-level scope that describes the server, and lower-level scopes for narrow operations (examples below)

##### Top-level scope

The main hub's scope is active from `Init` onwards, for the whole session, until you change it. Context that is true for the entire server belong here.

```lua
SentryRoblox:ConfigureScope(function(Scope)
	Scope:SetTag("region", "eu-west")
	Scope:SetTag("server_type", "ranked")
	Scope:SetExtra("matchmaker_version", "3.1.0")
end)
```

Set it once at startup and leave it. If you find yourself wanting to change one of these per player, that is the sign it belongs in a lower scope instead

##### Lower-level scopes

For context that is only true of one piece of work, one player, or one situation. `WithScope` pushes a copy of the active scope, runs your callback, then throws the copy away

```lua
SentryRoblox:WithScope(function(Scope)
	Scope:SetTag("phase", "matchmaking")
	Scope:SetExtra("queue_size", 12)

	RunMatchmaking()
end)
```

It starts as a copy, so it inherits the top-level tags and then diverges. `region=eu-west` is still on the event, plus `phase=matchmaking`, and the phase is gone once the callback returns

That is what makes per-player tagging work:

```lua
local function RunInBiome(Player: Player, BiomeName: string)
	SentryRoblox:WithScope(function(Scope)
		Scope:SetTag("biome", BiomeName)
		Scope:SetUser(Player)

		xpcall(function()
			DoBiomeWork(Player, BiomeName)
		end, SentryRoblox:ExceptionHandler())
	end)
end
```

Player A in Forest reports `region=eu-west, biome=Forest`. Player B in Volcano reports `region=eu-west, biome=Volcano`

The catch is timing. The scope is read when the event is captured, so a tag only lands on errors captured while the callback is still running. An error from a `task.delay` or a later remote event has no biome tag, which is why the example catches its own error rather than relying on automatic capture. It also means `WithScope` is for synchronous blocks

Two variations on the same idea:

|                              |                                                                                          |
| ---------------------------- | ---------------------------------------------------------------------------------------- |
| `PushScope()` / `PopScope()` | `WithScope` by hand, when you need to restore somewhere other than the end of a callback |
| `Clone()`                    | A whole separate hub with its own top-level scope                                        |

`Clone` is for context tied to one thing for a long time. For example, `TrackSessions` uses it to give each player their own hub and so session state never bleeds between players. If you find yourself setting and unsetting the same tag around every call, that is a sign you want a cloned hub instead.

##### What goes in a scope

| method                                        | use for                                                        |
| --------------------------------------------- | -------------------------------------------------------------- |
| `SetUser(Player \| number \| nil, Identity?)` | Who the event belongs to, see [Privacy](#privacy-and-grouping) |
| `SetTag` / `SetTags`                          | Short strings you want to filter by                            |
| `SetExtra` / `SetExtras`                      | Arbitrary data you only want to read                           |
| `SetContext(Key, Table)`                      | A named group of related fields                                |
| `SetLevel(Level)`                             | Default level for events from this scope                       |
| `SetTransaction(Name)`                        | Names the current transaction                                  |
| `SetFingerprint({ "name" })`                  | Forces grouping, see [Privacy](#privacy-and-grouping)          |
| `AddEventProcessor(P)`                        | Scope-local processor                                          |
| `Clear()` / `Clone()`                         | Reset or deep copy                                             |

**Tags** are indexed, so Sentry can filter and search by them. Use them for things with a small set of values: biome, game mode, difficulty, server region. **Extras** and **contexts** are only readable. Use them for detail you want to see on an issue but would never filter by, like an inventory table or a stat block. Neither affects grouping

**`SetUser`** takes a `Player`, a raw `UserId`, or `nil` to clear it. One at a time. What actually gets attached depends on `SendDefaultPII`.

**`SetFingerprint`** is the bandaid fix for when an error splits into more issues than it should. See [Privacy](#privacy-and-grouping) for why that happens and what else you can do about it

**`Clear()` replaces the scope with a fresh one, but keeps `release`, `environment`, `server_name` and `dist`.** Those come from `Init` rather than from you, so clearing in the middle of a session will not drop them from later events. Everything else, including tags, extra, contexts, breadcrumbs and the user, is reset. If you only want to drop accumulated context, clear the parts you mean rather than the whole scope

**`Clone()` deep copies.** Mutating the clone never touches the parent, including nested tables like `tags` and `breadcrumbs`

##### Breadcrumbs

A breadcrumb is a note about something that happened, kept in a rolling buffer and attached to the next error

Nothing is recorded automatically, so you add them at the points that matter:

```lua
SentryRoblox:ConfigureScope(function(Scope)
	Scope:AddBreadcrumb({ message = "opened the vault", level = "info" })
	Scope:AddBreadcrumb({
		category = "combat",
		message = "hit by lava",
		level = "warning",
		data = { damage = 40 },
	})
end)
```

Breadcrumbs live on the scope you write them to, and an event only carries the breadcrumbs from the one scope that was active when it was captured. That matters as soon as you have more than one scope. A breadcrumb added inside `WithScope` disappears with the block, and one added to a cloned hub belongs to that hub alone

Put them on the scope whose events you want them on. Uncaught errors are captured on the main hub, so a breadcrumb written to a per-player scope will not reach them, and Roblox never says which player an uncaught server error belongs to, so there is nothing to look up

The buffer is capped by `MaxBreadcrumbs` and drops the oldest first, so you can log freely without thinking about payload size. They are attached oldest first, which puts the newest one nearest the error

`ClearBreadcrumbs()` empties the buffer. `BeforeBreadcrumb` filters them globally, which is useful when you want to keep a whole category out of every event without editing each call site

##### Advanced configurations

<details>

<summary>Options</summary>

| option                | type            | default                   |
| --------------------- | --------------- | ------------------------- |
| `ServerName`          | `string`        | `game.JobId` or `"local"` |
| `MaxBreadcrumbs`      | `number`        | `100`                     |
| `AttachStacktrace`    | `boolean`       | `false`                   |
| `SendStudioEvents`    | `boolean`       | `false`                   |
| `SendClientEvents`    | `boolean`       | `true`                    |
| `InAppInclude`        | `{string}`      | `{}`                      |
| `InAppExclude`        | `{string}`      | `{}`                      |
| `BeforeSend`          | `function`      | none                      |
| `BeforeBreadcrumb`    | `function`      | none                      |
| `DefaultIntegrations` | `boolean`       | `true`                    |
| `Integrations`        | `{Integration}` | `{}`                      |
| `Transport`           | `Transport`     | built-in HTTP             |

**`AttachStacktrace`** attaches a stack trace to messages as well as exceptions. Two consequences before you turn it on:

1. Sentry groups events with traces separately from events without, so it reshuffles your issue list
2. `LogService` warnings take their trace from the SDK's handler rather than from the code that logged them, so they all share one trace and collapse into a single issue

It is useful for `CaptureMessage` calls you make yourself, not for warnings

**`SendStudioEvents`** is off by default, which means **nothing you do in Studio is reported**. The reason for the default is that warnings fire constantly in Studio and most are not worth sending.

When events are being dropped for this reason, the SDK prints a one-time notice in the output.

**`InAppInclude`** and **`InAppExclude`** control which stack frames Sentry treats as yours. Both are lists of plain substrings, matched against frame paths.

Frames are in app by default, except Roblox's internals, which are dropped entirely. `InAppExclude` is a veto and is checked first, so a path matching both lists is excluded.

**`InAppInclude` is a whitelist.** Set it and only frames matching one of its entries count as yours, and everything else is marked as a library. Leave it empty and everything not excluded stays yours. This is stricter than Sentry's own SDKs, where the include list only promotes frames and a project-root heuristic supplies the default

Sentry uses in-app frames to decide which part of a trace to blame, so this is how you stop third-party code from becoming the headline of an issue. Frames from the SDK itself are always excluded.

```lua
SentryRoblox:Init({
	DSN = DSN,
	InAppInclude = { "ServerScriptService", "ReplicatedStorage.MyGame" },
})
```

That says only your own `ServerScriptService` and `MyGame` code is yours, and everything else, including any library you vendored into `ReplicatedStorage`, is treated as third party. Reach for `InAppExclude` instead when it is easier to list what is not yours

**`BeforeSend`** runs after the scope merge and before encoding. Return the event to send it, return `nil` to drop it. This SDK already blocks out some common Roblox noise, but you may need to make some alterations

```lua
SentryRoblox:Init({
	DSN = DSN,
	BeforeSend = function(Event)
		if Event.message and string.find(Event.message.message, "known noise") then
			return nil
		end

		return Event
	end,
})
```

**`BeforeBreadcrumb`** does the same for breadcrumbs.

</details>

#### Privacy and grouping

Player names found in a payload are replaced with `<PLAYER>`, a single token. That is about grouping as much as privacy. Sentry groups errors into issues by reading the message, so a per-player placeholder like `<PLAYER:3>` would turn every player's copy of the same crash into its own issue. One token means one issue

`UserId`s are scrubbed from text too, so `failed to save user 1234567` merges the same way

`SendDefaultPII` decides how much of the player goes into `event.user`:

| setting | `user` contains                    |
| ------- | ---------------------------------- |
| `false` | `id` only                          |
| `true`  | `id`, `username`, `data` and `geo` |

`data` is `AccountAge`, `MembershipType`, `Team`. `geo` is derived from the player's `LocaleId`

The `id` is kept in both cases. It is a pseudonymous number that Sentry uses to count unique users, and it is metadata, so it never splits an issue

##### What affects grouping

Sentry checks these in order and stops at the first it can use:

1. `fingerprint`, if you set one
2. the stack trace
3. the exception `type` and `value`
4. the message

Nothing else splits an issue. `user`, `tags`, `context`, `extras`, `breadcrumbs`, `release`, `environment` and `server_name` are all metadata. You can log the player, the biome and the whole character sheet without creating extra issues

If an error still splits when it should not, the cause is usually a value inside the message, like `expected 5 got 7`. Two ways out:

- `Scope:SetFingerprint({ "inventory-reconcile" })` for one call site
- `BeforeSend` for a rule across everything

##### The client relay

By default, the client captures, filters and forwards over a `RemoteEvent`, and the server does the sending

The server treats everything it receives as untrusted. Payloads are validated against an allowlist, server-authoritative fields are stripped, string and frame lengths are capped, and each player is rate limited. Identity is attached by the server from the player who sent it

The client half starts on its own. It waits 30 seconds for the relay to appear. If the server never called `Init`, the relay is never created and the client quietly does nothing

Set `SendClientEvents = false` to skip the relay entirely

#### Custom integrations

An integration is a plain value

```lua
local ServerUptime = {
	Name = "ServerUptime",
	Realm = "Server",
	Setup = function(Context)
		local Started = os.clock()

		Context.AddProcessor(function(Event, _Hint)
			Event.extra = Event.extra or {}
			Event.extra.ServerUptime = os.clock() - Started

			return Event
		end)

		return nil
	end,
}
```

Register it with `Init`:

```lua
SentryRoblox:Init({
	DSN = DSN,
	Integrations = { ServerUptime },
})
```

| field            |                                                  |
| ---------------- | ------------------------------------------------ |
| `Name`           | Shows up in setup failure messages               |
| `Realm`          | `"Server"`, `"Client"` or `"Shared"`             |
| `Setup(Context)` | Runs at `Init`, may return a destructor function |

`Setup` receives a `Context` object:

|                    |                             |
| ------------------ | --------------------------- |
| `Realm`            | The realm being set up      |
| `Hub`              | Capture through this        |
| `Options`          | The resolved options        |
| `AddProcessor(fn)` | Register an event processor |
| `Services`         | Injected services           |

`Services` carries `Players`, `HttpService`, `ScriptContext`, `LogService`, `RunService`, `DateTime` and `Clock`. They are injected rather than reached for globally, which is what makes an integration testable outside Roblox

`Setup` must return explicitly. Return a function to tear down what you set up, or `nil` if there is nothing to tear down

Built-in integrations are set up before yours, and processors run in setup order. `StackProcessor` turns a traceback into frames before `PlayerContext` scrubs them, so a processor that rewrites the traceback has to run late.

Set `DefaultIntegrations = false` to drop the built-in set and list only what you want. The built-ins are exposed on the SDK:

```lua
SentryRoblox:Init({
	DSN = DSN,
	DefaultIntegrations = false,
	Integrations = { SentryRoblox.Integrations.ScriptContextError() },
})
```

##### Working example: code view

Sentry shows `No code context or variables available for this frame` for every Roblox frame. Roblox gives a script no way to read its own source at runtime, and no way to read local variables

That said, you can supply the code yourself. Frames already carry `filename` and `lineno`, and those are the same strings `rojo sourcemap` produces, so the lookup is a plain table index. This is not part of the SDK because it ships your source as plain text and roughly doubles the size of every script it covers. If that is a trade you want, here it is.

**1. Generate a source table.** Save this as `scripts/Source.luau` and run it after `rojo sourcemap` and before `rojo build`:

```lua
local fs = require("@lune/fs")
local Serde = require("@lune/serde")

local Output = "src/Sources.luau"
local Include = { "ServerScriptService", "StarterPlayer" }

local function IsIncluded(Path: string): boolean
	for _, Prefix in Include do
		if Path == Prefix or string.sub(Path, 1, #Prefix + 1) == `{Prefix}.` then return true end
	end

	return false
end

local function Collect(Node: any, Path: string, Out: { { Path: string, File: string } }): ()
	local Here = if Path == "" then Node.name else `{Path}.{Node.name}`

	for _, FilePath in Node.filePaths or {} do
		if string.sub(FilePath, -5) == ".luau" and IsIncluded(Here) then
			table.insert(Out, { Path = Here, File = FilePath })
		end
	end

	for _, Child in Node.children or {} do
		Collect(Child, Here, Out)
	end
end

local Root = Serde.decode("json", fs.readFile("sourcemap.json"))
local Entries = {}

for _, Child in Root.children or {} do
	Collect(Child, "", Entries)
end

local Lines = { "-- Generated. Do not edit.", "return {" }

for _, Entry in Entries do
	table.insert(Lines, `\t[{Serde.encode("json", Entry.Path)}] = {Serde.encode("json", Fs.readFile(Entry.File))},`)
end

table.insert(Lines, "}")

fs.writeFile(Output, table.concat(Lines, "\n") .. "\n")

print(`wrote {Output} with {#Entries} scripts`)
```

Point `Output` at a folder Rojo already syncs into `ReplicatedStorage`, and put whatever you want in `Include`

**2. Fill the frames.** A processor that runs after the built-in ones:

```lua
local function CodeView(Sources)
	return {
		Name = "CodeView",
		Realm = "Shared",
		Setup = function(Context)
			Context.AddProcessor(function(Event, _Hint)
				for _, Exception in Event.exception or {} do
					local Stacktrace = Exception.stacktrace

					if Stacktrace == nil then continue end

					for _, Frame in Stacktrace.frames do
						local Text = Sources[Frame.filename]
						local Line = Frame.lineno

						if Text == nil or Line == nil then continue end

						local Lines = string.split(Text, "\n")

						Frame.context_line = Lines[Line]
						Frame.pre_context = { Lines[Line - 2], Lines[Line - 1] }
						Frame.post_context = { Lines[Line + 1], Lines[Line + 2] }
					end
				end

				return Event
			end)
		end,
	}
end
```

**3. Register it.**

```lua
local Sources = require(game.ReplicatedStorage.Sources)

SentryRoblox:Init({
	DSN = DSN,
	Integrations = { CodeView(Sources) },
})
```

**Before you commit to this.** The generator has to run on every build, else you risk reporting the wrong lines. It also puts your source into the place file as readable strings, which is a real difference from bytecode (even though bytecode can be decompiled)

### More

#### Acknowledgements

- The original [sentry-roblox](https://github.com/devSparkle/sentry-roblox)
- [tiniest](https://github.com/dphfox/tiniest) for testing

#### Why the fork?

Original is infrequently maintained. This fork started as a bug-fix and turned into a rewrite

What changed (so far):

- Client events are now untrusted and heavily validated
- Roblox's internal noise (CoreScript, CoreGui and CorePackages), as well as most exploit scripts (nil origins, not a descendant of `game`, generated-looking script names), are filtered by default
- Name scrubber was replaced with more reliable methods
- PII handling was redesigned around grouping
- Custom integrations were rebuilt from the ground up
- Fully typed core with a test suite
- Bug and quirk fixes

If you want the full list, it's in the commit history