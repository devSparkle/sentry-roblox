# Getting Started

There are two supported ways to get Sentry quickly up-and-running in your game:

## Public Module Install

This install has the benefit of auto-updating whenever we release bugfixes,
security patches and even new features; all without having to update your game
or pre-existing code.

*Note:* This method cannot be used from a client script. To forward errors from
the client, you must use another installation method.

Create a server-sided script in your game, and paste the following contents:

```lua
local SentrySDK = require(11721929587)

SentrySDK:Init({
	DSN = "<DSN FROM YOUR SENTRY PROJECT>"
})
```

## Static Install

Head over to the [releases tab](http://github.com/devSparkle/sentry-roblox/releases)
and download the prepared `.rbxm` file. Insert this file into your game and drag
it wherever you'd like to keep your ModuleScripts. It must be parented somewhere
that replicates to clients, such as `ReplicatedStorage`, if you intend to
monitor client errors too.

Then, require your script by calling its path:

```lua
local SentrySDK = require(game:GetService("ReplicatedStorage").SentrySDK)

SentrySDK:Init({
	DSN = "<DSN FROM YOUR SENTRY PROJECT>"
})
```
