# Getting Started

There are two supported ways to get Sentry quickly up-and-running in your game:

## Static Install

Head over to the [releases tab](http://github.com/devSparkle/sentry-roblox/releases)
and [download the prepared `.rbxm`](https://github.com/devSparkle/sentry-roblox/releases/latest/download/SentrySDK.rbxm) file. Insert this file into your game and drag
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

## Wally Install

This repository is available from wally! Just add it to your `wally.toml` file.

```toml
[dependencies]
Sentry = "devsparkle/sentry-roblox@^1.0.0"
```

This install has the benefit of easily updating whenever we release bugfixes,
security patches and even new features, just by using `wally update`!

To complete the installation, add a server-sided script in your game, and paste the following contents:

```lua
local SentrySDK = require(game:GetService("ReplicatedStorage").SentrySDK)

SentrySDK:Init({
	DSN = "<DSN FROM YOUR SENTRY PROJECT>"
})
```
