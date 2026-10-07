local Types = require(script.Parent.Parent:WaitForChild("Types"))

export type Realm = Types.Realm
export type Level = Types.Level
export type Scope = Types.Scope
export type Event = Types.Event
export type Hint = Types.Hint
export type User = Types.User
export type Hub = Types.Hub
export type Processor = Types.Processor
export type AddProcessor = (Processor: Types.Processor) -> ()
export type Services = { [string]: any }

export type Context = {
	Realm: Realm,
	Hub: Types.Hub,
	Options: Types.Options,
	AddProcessor: AddProcessor,
	Services: Services,
}

export type Setup = (Context: Context) -> (() -> ())?

export type Integration = Types.Integration<Context>

export type MatchOptions = {
	ExtraPatterns: { string }?,
}

export type OriginOptions = {
	RejectNil: boolean?,
	RejectForeign: boolean?,
	RejectGeneratedNames: boolean?,
	MinimumGeneratedNameLength: number?,
}

return table.freeze({})
