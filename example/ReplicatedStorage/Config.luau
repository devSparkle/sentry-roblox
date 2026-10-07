export type Item = {
	Price: number,
	Multiplier: number,
}

export type Settings = {
	DSN: string,
	Build: string,
	Items: { [string]: Item },
	Bonuses: { [string]: number },
}

return {
	DSN = "https://76b6ed905381452ea54ee1fcecb19708@bugsink.spiraljng.dev/3", -- Paste your project DSN here. Without it the SDK is inert and the game still runs, it just reports nothing.
	Build = "local",

	-- Not SDK related
	Items = {
		Charm = { Price = 50, Multiplier = 2 },
		Glove = { Price = 250, Multiplier = 5 },
		Midas = { Price = 500, Multiplier = 20 },
	},

	Bonuses = {},
} :: Settings
