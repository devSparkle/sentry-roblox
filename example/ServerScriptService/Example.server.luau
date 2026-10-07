local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local SentryRoblox = require(ReplicatedStorage.SentryRoblox)
local Config = require(ReplicatedStorage.Data.Config)

type Session = { Coins: number, Multiplier: number, Display: IntValue }

SentryRoblox:Init({
	DSN = Config.DSN,
	Debug = true,
	SendStudioEvents = true,
	SendDefaultPII = true,
	BeforeSend = function(Event)
		local Message = if Event.message ~= nil then Event.message.message else nil

		if Message ~= nil and string.find(Message, "throttled", 1, true) then return nil end

		return Event
	end,
})

SentryRoblox:ConfigureScope(function(Scope)
	Scope:SetTag("region", "eu-west")
	Scope:SetTag("build", Config.Build)
	Scope:SetExtra("max_players", Players.MaxPlayers)
end)

local CoinStore = DataStoreService:GetDataStore("ExampleCoins")
local Sessions: { [Player]: Session } = {}

-- A breadcrumb written to a per-player scope instead would be private to that player, but an uncaught error cannot reach it
local function Note(Message: string, Data: { [string]: any }?): ()
	SentryRoblox:ConfigureScope(function(Scope)
		Scope:AddBreadcrumb({ category = "game", message = Message, level = "info", data = Data })
	end)
end

local function LoadCoins(Player: Player): (number, number)
	local Success, Result = pcall(function()
		return CoinStore:GetAsync(tostring(Player.UserId))
	end)

	if not Success then
		SentryRoblox:WithScope(function(Scope)
			Scope:SetUser(Player)

			SentryRoblox:CaptureException(`failed to load coins for {Player.Name}`)
		end)

		return 0, 1
	end

	if Result == nil then return 0, 1 end

	return Result.Coins or 0, Result.Multiplier or 1
end

local function SaveCoins(Player: Player, Session: Session): ()
	local Success = pcall(function()
		CoinStore:SetAsync(tostring(Player.UserId), {
			Coins = Session.Coins,
			Multiplier = Session.Multiplier,
		})
	end)

	if Success then return end

	SentryRoblox:WithScope(function(Scope)
		Scope:SetUser(Player)
		Scope:SetExtra("coins", Session.Coins)
		Scope:SetExtra("multiplier", Session.Multiplier)

		SentryRoblox:CaptureException(`failed to save coins for {Player.Name}`)
	end)
end

local function CreateCoin(Position: Vector3, Cursed: boolean): Part
	local Coin = Instance.new("Part")

	Coin.Name = if Cursed then "CursedCoin" else "Coin"
	Coin.Shape = Enum.PartType.Ball
	Coin.Size = Vector3.one * 2
	Coin.Position = Position
	Coin.Anchored = true
	Coin.Material = Enum.Material.Neon
	Coin.Color = if Cursed then Color3.fromRGB(220, 70, 70) else Color3.fromRGB(255, 200, 60)
	Coin.Parent = Workspace

	return Coin
end

local function Collect(Session: Session, Cursed: boolean): ()
	Session.Coins += 10 * Session.Multiplier
	Session.Display.Value = Session.Coins

	Note("collected a coin", { total = Session.Coins, cursed = Cursed })

	if not Cursed then return end

	Note("cursed coin, awarding a bonus")

	local Bonus = Config.Bonuses.CursedCoin

	-- Bug: Bonuses is empty, so cursed coins always throw. Uncaught, so it is automatically caught via the ScriptContext.Error hook
	if Bonus == nil then error("no bonus is configured for cursed coins") end

	Session.Coins += Bonus
	Session.Display.Value = Session.Coins
end

local function SpawnCoin(Index: number): ()
	local Cursed = Index % 3 == 0
	local Coin = CreateCoin(Vector3.new(Index * 14 - 56, 4, 0), Cursed)

	Coin.Touched:Connect(function(Hit)
		if Coin.Parent == nil then return end

		local Character = Hit:FindFirstAncestorOfClass("Model")
		local Player = if Character ~= nil then Players:GetPlayerFromCharacter(Character) else nil
		local Session = if Player ~= nil then Sessions[Player] else nil

		if Session == nil then return end

		Coin:Destroy()

		task.delay(5, SpawnCoin, Index)

		Collect(Session, Cursed)
	end)
end

local function SpawnCoins(): ()
	for Index = 1, 8 do
		SpawnCoin(Index)
	end
end

local ShopRemote = Instance.new("RemoteEvent")
ShopRemote.Name = "ShopRemote"
ShopRemote.Parent = ReplicatedStorage

local function Buy(Session: Session, ItemName: string): (boolean, string)
	local Item = Config.Items[ItemName]

	if Item == nil then return false, "unknown item" end
	if Session.Coins < Item.Price then return false, "not enough coins" end

	Session.Coins -= Item.Price

	-- Bug: Midas reads a boost that Bonuses does not contain. Caught below, so this one lands with the `item` tag attached
	if ItemName == "Midas" then
		local Boost = Config.Bonuses.Midas

		if Boost == nil then error("the Midas boost is not configured") end

		Session.Multiplier *= Boost
	end

	Session.Multiplier *= Item.Multiplier

	return true, "ok"
end

ShopRemote.OnServerEvent:Connect(function(Player: Player, ItemName: unknown)
	if type(ItemName) ~= "string" then return end

	local Session = Sessions[Player]

	if Session == nil then return end

	SentryRoblox:WithScope(function(Scope)
		Scope:SetUser(Player)
		Scope:SetTag("account_age_days", tostring(Player.AccountAge))
		Scope:SetTag("item", ItemName)

		xpcall(function()
			local Ok, Reason = Buy(Session, ItemName)

			if not Ok then
				SentryRoblox:CaptureMessage(`{Player.Name} could not buy {ItemName}: {Reason}`, "warning")

				return
			end

			Note(`bought {ItemName}`, { price = Config.Items[ItemName].Price })
		end, SentryRoblox:ExceptionHandler())
	end)

	ShopRemote:FireClient(Player, Session.Coins, Session.Multiplier)
end)

Players.PlayerAdded:Connect(function(Player: Player)
	local Leaderstats = Instance.new("Folder")
	Leaderstats.Name = "leaderstats"

	local Display = Instance.new("IntValue")
	Display.Name = "Coins"
	Display.Parent = Leaderstats

	Leaderstats.Parent = Player

	local StartingCoins, Multiplier = LoadCoins(Player)
	local Session: Session = { Coins = StartingCoins, Multiplier = Multiplier, Display = Display }

	Sessions[Player] = Session
	Display.Value = StartingCoins

	Note(`{Player.Name} joined`, { coins = StartingCoins, multiplier = Multiplier })
end)

Players.PlayerRemoving:Connect(function(Player: Player)
	local Session = Sessions[Player]

	Sessions[Player] = nil

	if Session == nil then return end

	Note(`{Player.Name} left`)

	task.spawn(SaveCoins, Player, Session)
end)

SpawnCoins()
