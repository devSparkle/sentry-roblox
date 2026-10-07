local Dsn = {}

local Pattern = "^([^:]+)://([^:]+)@([^/]+)/(.+)$"

export type Parsed = {
	Scheme: string,
	PublicKey: string,
	Authority: string,
	ProjectId: string,
	BaseUrl: string,
	AuthHeader: string,
}

function Dsn.Parse(Value: string, ProtocolVersion: number, Client: string): (Parsed?, string?)
	local Trimmed = string.gsub(Value, "%s", "")
	local Scheme, PublicKey, Authority, ProjectId = string.match(Trimmed, Pattern)

	if Scheme == nil then return nil, "not a valid DSN" end

	local LowerScheme = string.lower(Scheme)

	if LowerScheme ~= "http" and LowerScheme ~= "https" then return nil, `unsupported scheme "{Scheme}"` end

	return {
		Scheme = Scheme,
		PublicKey = PublicKey,
		Authority = Authority,
		ProjectId = ProjectId,

		BaseUrl = `{Scheme}://{Authority}/api/{ProjectId}/`,
		AuthHeader = `Sentry sentry_key={PublicKey},sentry_version={ProtocolVersion},sentry_client={Client}`,
	}
end

return table.freeze(Dsn)
