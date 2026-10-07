export type Level = "fatal" | "error" | "warning" | "info" | "debug"
export type Realm = "Server" | "Client" | "Shared"

export type Hint = { [string]: any }
export type Filter<T> = (Value: T, Hint: Hint?) -> T?

export type Breadcrumb = {
	type: string?,
	category: string?,
	message: string?,
	level: Level?,
	timestamp: number?,
	data: { [string]: any }?,
}

export type Geo = {
	city: string?,
	country_code: string?,
	region: string?,
}

export type User = {
	id: number?,
	username: string?,
	email: string?,
	data: { [string]: any }?,
	geo: Geo?,
}

export type Session = {
	sid: string,
	started: DateTime,
}

export type Frame = {
	filename: string?,
	module: string?,
	lineno: number?,
	colno: number?,
	abs_path: string?,
	context_line: string?,
	in_app: boolean?,
	pre_context: { string }?,
	post_context: { string }?,
	["function"]: string?,
}

export type Stacktrace = {
	frames: { Frame },
	registers: { [string]: string }?,
}

export type Mechanism = {
	type: string?,
	description: string?,
	handled: boolean?,
	synthetic: boolean?,
	help_link: string?,
	data: { [string]: any }?,
}

export type Exception = {
	type: string?,
	value: string?,
	module: string?,
	thread_id: string?,
	mechanism: Mechanism?,
	stacktrace: Stacktrace?,
}

export type Sdk = {
	name: string,
	version: string,
	integrations: { string }?,
	packages: { { name: string, version: string } }?,
}

export type EventError = {
	type: string,
	path: string?,
	details: string?,
	name: string?,
}

export type Event = {
	event_id: string?,
	timestamp: number?,
	platform: "other"?,

	level: Level?,
	logger: string?,
	transaction: string?,
	server_name: string?,
	release: string?,
	dist: string?,
	environment: string?,

	tags: { [string]: string }?,
	extra: { [string]: any }?,
	contexts: { [string]: { [string]: any } }?,
	modules: { [string]: string }?,
	fingerprint: { string }?,

	sdk: Sdk?,

	user: User?,
	exception: { Exception }?,
	message: {
		message: string,
		formatted: string?,
		params: { string }?,
	}?,

	errors: { EventError }?,
}

export type Processor = (Event: Event, Hint: Hint?) -> Event?

export type Transport = {
	Init: (self: Transport, Options: Options, ProtocolVersion: number, Client: string) -> (),
	CaptureEvent: (self: Transport, EncodedPayload: string) -> any,
	CaptureEnvelope: (self: Transport, Payload: { [string]: any }) -> any,
}

export type Integration<Context = any> = {
	Name: string,
	Realm: Realm,
	Setup: (Context: Context) -> (() -> ())?,
}

export type Options = {
	DSN: string?,
	Debug: boolean?,

	DefaultIntegrations: boolean?,
	Integrations: { Integration }?,

	Release: string?,
	Environment: string?,
	ServerName: string?,

	SendClientEvents: boolean?,
	SendStudioEvents: boolean?,
	SendDefaultPII: boolean?,

	SampleRate: number?,
	MaxBreadcrumbs: number?,
	AttachStacktrace: boolean?,

	InAppInclude: { string }?,
	InAppExclude: { string }?,

	BeforeSend: Filter<Event>?,
	BeforeBreadcrumb: Filter<Breadcrumb>?,

	Transport: Transport?,
}

export type Scope = {
	extra: { [string]: any },
	contexts: { [string]: { [string]: any } },
	tags: { [string]: string },
	breadcrumbs: { Breadcrumb },

	level: Level?,
	transaction: string?,
	fingerprint: { string }?,
	user: User?,
	release: string?,
	environment: string?,
	server_name: string?,
	logger: string?,
	dist: string?,

	_event_processors: { Processor },
	_session: Session?,

	ConfigureScope: (self: Scope, Callback: (Scope) -> ()) -> (),
	SetUser: (self: Scope, User: Player | number | nil, Identity: boolean?) -> (),
	SetExtra: (self: Scope, Key: string, Value: any) -> (),
	SetExtras: (self: Scope, Dictionary: { [string]: any }) -> (),
	SetTag: (self: Scope, Key: string, Value: string | number | boolean) -> (),
	SetTags: (self: Scope, Dictionary: { [string]: string | number | boolean }) -> (),
	SetContext: (self: Scope, Key: string, Value: { [string]: any }) -> (),
	SetLevel: (self: Scope, Level: Level) -> (),
	SetTransaction: (self: Scope, TransactionName: string) -> (),
	SetFingerprint: (self: Scope, Fingerprint: { string }) -> (),
	SetSession: (self: Scope, Session: Session?) -> (),
	AddEventProcessor: (self: Scope, Processor: Processor) -> (),
	Clear: (self: Scope) -> (),
	Clone: (self: Scope) -> Scope,
	AddBreadcrumb: (self: Scope, Breadcrumb: Breadcrumb, Hint: Hint?) -> (),
	ClearBreadcrumbs: (self: Scope) -> (),
	ApplyToEvent: (self: Scope, Event: Event, Hint: Hint?) -> Event?,
}

export type Client = {
	CaptureEvent: (self: Client, Event: Event, Hint: Hint?, Scope: Scope, Options: Options?) -> any,
	Close: (self: Client, Timeout: number?) -> boolean,
	Flush: (self: Client, Timeout: number?) -> boolean,
}

export type Hub = {
	Client: Client,
	Scope: Scope,
	Options: Options?,

	_scope_stack: { Scope },

	CaptureEvent: (self: Hub, Event: Event, Hint: Hint?) -> any,
	CaptureMessage: (self: Hub, Message: string, Level: Level?) -> any,
	CaptureException: (self: Hub, ErrorMessage: string, TracebackText: string?) -> any,
	ExceptionHandler: (self: Hub) -> (ErrorMessage: string?) -> (),
	ConfigureScope: (self: Hub, Callback: (Scope) -> ()) -> Hub,
	Clone: (self: Hub) -> Hub,
	GetCurrentHub: (self: Hub) -> Hub,
	GetClient: (self: Hub) -> Client,
	BindClient: (self: Hub, Client: Client?) -> (),
	UnbindClient: (self: Hub) -> (),
	PushScope: (self: Hub) -> () -> (),
	PopScope: (self: Hub) -> Hub,
	WithScope: (self: Hub, Callback: (Scope) -> ...any) -> ...any,
	StartSession: (self: Hub) -> any,
	EndSession: (self: Hub) -> any,
}

return table.freeze({})
