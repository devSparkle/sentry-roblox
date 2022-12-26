--!strict

export type EventLevel = "fatal" | "error" | "warning" | "info" | "debug"
export type EventPayload = {
	event_id: string?,
	timestamp: string | number | nil,
	platform: "other" | nil,
	
	level: EventLevel?, --/ The record severity. Defaults to error.
	logger: string?, --/ The name of the logger which created the record.
	transaction: string?, --/ The name of the transaction which caused this exception.
	server_name: string?, --/ Identifies the host from which the event was recorded. Defaults to game.JobId
	release: string?, --/ The release version of the application. MUST BE UNIQUE ACROSS ORGANIZATION
	dist: string?, --/ The distribution of the application.
	
	tags: {[string]: string}?, --/ A map or list of tags for this event. Each tag must be less than 200 characters.
	environment: string?, --/ The environment name, such as production or staging.
	modules: {[string]: string}?, --/ A list of relevant modules and their versions.
	extra: {[string]: string}?, --/ An arbitrary mapping of additional metadata to store with the event.
	fingerprint: {string}?, --/ A list of strings used to dictate the deduplication of this event.
	
	contexts: {[string]: {[string]: any}}?,
	
	sdk: {
		name: string,
		version: string,
		integrations: {string}?,
		packages: {{
			name: string,
			version: string,
		}}?,
	}?,
	
	exception: {
		type: string?,
		value: string?,
		module: string?,
		thread_id: string?,
		
		mechanism: {
			data: {[string]: any}?,
			description: string?,
			handled: boolean?,
			help_link: string?,
			synthetic: boolean?,
			type: string?,
		}?,
		
		stacktrace: {
			frames: {},
			registers: {[string]: string}?,
		}?,
	}?,
	
	user: {
		id: number,
		username: string,
		
		geo: {
			city: string?,
			country_code: string, --/ Two-letter country code (ISO 3166-1 alpha-2).
			region: string?,
		}
	}?,
	
	message: {
		message: string,
		formatted: string?,
		params: {string}?,
	}?,
	
	errors: {{
		type: string,
		path: string?,
		details: string?,
	}}?,
}

--[=[
	@within SDK
	@interface HubOptions
	
	.DSN string -- The DSN for the sentry project to send events to
	.debug boolean? -- See [SDK.debug] (must press the "Show Private")
	
	.Release string? -- See [SDK.Release]
	.Environment string? -- See [SDK.Environment]
	
	.AutoTrackClient boolean? -- See [SDK.AutoTrackClient]
	.AutoErrorTracking boolean? -- See [SDK.AutoErrorTracking]
	.AutoWarningTracking boolean? -- See [SDK.AutoWarningTracking]
]=]

--[=[
@within SDK
@prop debug boolean?
@private

:::warning
 This property must be set in [SDK:Init] through the [HubOptions] table.
:::

Internal debug mode, prints info about the current state of the SDK when set to `true`
]=]

--[=[
@within SDK
@prop Release string?

:::warning
 This property must be set in [SDK:Init] through the [HubOptions] table.
:::

An arbitrary release identifier, used to determine the current version of the game.
This can be very useful to track which versions of the game are currently affected.

Should be in the format `GameName@1.2.3` using Semantic Versioning; although this
is not strictly enforced by the SDK or Sentry. The version must be unique in a sentry
organization.

:::info
Using the format `GameName@1.2.3` is recommended, as sentry will treat everything
after the `@` as the version number, and automatically adapt their UI to this format.
:::
]=]
--[=[
@within SDK
@prop Environment string?

:::warning
 This property must be set in [SDK:Init] through the [HubOptions] table.
:::

Arbitrary environment identifier. Defaults to `studio` or `live` as appropriate.
]=]

--[=[
@within SDK
@prop AutoTrackClient boolean?

:::warning
 This property must be set in [SDK:Init] through the [HubOptions] table.
:::

When not explicitly set to false, Sentry will automatically monitor the client-side console.
]=]
--[=[
@within SDK
@prop AutoErrorTracking boolean?

:::warning
 This property must be set in [SDK:Init] through the [HubOptions] table.
:::

When not explicitly set to false, Sentry will automatically monitor and report console errors.
]=]
--[=[
@within SDK
@prop AutoWarningTracking boolean?

:::warning
 This property must be set in [SDK:Init] through the [HubOptions] table.
:::

When not explicitly set to false, Sentry will automatically monitor and report console warnings.
]=]

export type HubOptions = {
	DSN: string?,
	debug: boolean?,
	
	Release: string?,
	Environment: string?,
	
	AutoTrackClient: boolean?,
	AutoErrorTracking: boolean?,
	AutoWarningTracking: boolean?,
--	AutoSessionTracking: boolean?,
}

return true