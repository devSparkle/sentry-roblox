export type Entry = {
	Name: string,
	UserId: number,
	ExpiresAt: number?,
}

export type Registry = {
	Current: { [string]: Entry },
	Retained: { [string]: Entry },
}

local PlayerRegistry = {}

PlayerRegistry.DefaultRetention = 60

function PlayerRegistry.new(): Registry
	return {
		Current = {},
		Retained = {},
	}
end

function PlayerRegistry.Add(Registry: Registry, Name: string, UserId: number): ()
	Registry.Current[Name] = {
		Name = Name,
		UserId = UserId,
	}

	Registry.Retained[Name] = nil
end

function PlayerRegistry.Remove(Registry: Registry, Name: string, Now: number, Retention: number?): ()
	local Entry = Registry.Current[Name]

	Registry.Current[Name] = nil

	if Entry == nil then return end

	local Window = Retention or PlayerRegistry.DefaultRetention

	if Window <= 0 then return end

	Registry.Retained[Name] = {
		Name = Name,
		UserId = Entry.UserId,
		ExpiresAt = Now + Window,
	}
end

function PlayerRegistry.Sweep(Registry: Registry, Now: number): number
	local Removed = 0

	for Name, Entry in Registry.Retained do
		if Entry.ExpiresAt ~= nil and Now >= Entry.ExpiresAt then
			Registry.Retained[Name] = nil
			Removed += 1
		end
	end

	return Removed
end

function PlayerRegistry.Names(Registry: Registry): { string }
	local Names = {}

	for Name in Registry.Current do
		table.insert(Names, Name)
	end

	for Name in Registry.Retained do
		table.insert(Names, Name)
	end

	table.sort(Names)

	return Names
end

function PlayerRegistry.Entries(Registry: Registry): { Entry }
	local Entries = {}

	for _, Entry in Registry.Current do
		table.insert(Entries, Entry)
	end

	for _, Entry in Registry.Retained do
		table.insert(Entries, Entry)
	end

	return Entries
end

function PlayerRegistry.UserIds(Registry: Registry): { number }
	local Ids = {}

	for _, Entry in Registry.Current do
		table.insert(Ids, Entry.UserId)
	end

	for _, Entry in Registry.Retained do
		table.insert(Ids, Entry.UserId)
	end

	return Ids
end

function PlayerRegistry.Find(Registry: Registry, Name: string): Entry?
	return Registry.Current[Name] or Registry.Retained[Name]
end

function PlayerRegistry.Count(Registry: Registry): number
	local Total = 0

	for _ in Registry.Current do
		Total += 1
	end

	for _ in Registry.Retained do
		Total += 1
	end

	return Total
end

return table.freeze(PlayerRegistry)
