-- This file has no Sentry code on purpose. The SDK handles the client relay for you!

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Data.Config)

local Player = Players.LocalPlayer
local Remote = ReplicatedStorage:WaitForChild("ShopRemote")

local Gui = Instance.new("ScreenGui")
Gui.Name = "Shop"
Gui.ResetOnSpawn = false
Gui.Parent = Player:WaitForChild("PlayerGui")

local Panel = Instance.new("Frame")
Panel.Size = UDim2.fromOffset(210, 0)
Panel.AutomaticSize = Enum.AutomaticSize.Y
Panel.Position = UDim2.new(1, -226, 0, 16)
Panel.BackgroundColor3 = Color3.fromRGB(20, 22, 28)
Panel.Parent = Gui

local Padding = Instance.new("UIPadding")
Padding.PaddingTop = UDim.new(0, 8)
Padding.PaddingBottom = UDim.new(0, 8)
Padding.PaddingLeft = UDim.new(0, 8)
Padding.PaddingRight = UDim.new(0, 8)
Padding.Parent = Panel

local Layout = Instance.new("UIListLayout")
Layout.Padding = UDim.new(0, 6)
Layout.SortOrder = Enum.SortOrder.LayoutOrder
Layout.Parent = Panel

local function Label(Text: string, Order: number): TextLabel
	local Item = Instance.new("TextLabel")

	Item.Size = UDim2.new(1, 0, 0, 22)
	Item.BackgroundTransparency = 1
	Item.Font = Enum.Font.GothamMedium
	Item.TextSize = 14
	Item.TextColor3 = Color3.fromRGB(235, 235, 240)
	Item.TextXAlignment = Enum.TextXAlignment.Left
	Item.Text = Text
	Item.LayoutOrder = Order
	Item.Parent = Panel

	return Item
end

local Balance = Label("0 coins", 0)

local Names = {}

for Name in Config.Items do
	table.insert(Names, Name)
end

table.sort(Names)

for Order, Name in Names do
	local Item = Config.Items[Name]

	local Button = Instance.new("TextButton")
	Button.Size = UDim2.new(1, 0, 0, 28)
	Button.BackgroundColor3 = Color3.fromRGB(48, 52, 62)
	Button.Font = Enum.Font.GothamMedium
	Button.TextSize = 14
	Button.TextColor3 = Color3.fromRGB(235, 235, 240)
	Button.Text = `{Name}   {Item.Price}   x{Item.Multiplier}`
	Button.LayoutOrder = Order
	Button.Parent = Panel

	Button.Activated:Connect(function()
		Remote:FireServer(Name)

		local Sound = Button:FindFirstChildOfClass("Sound")

		-- Bug: the Sound was never added to the button. Uncaught on the client, so it reports to server as a runtime error
		if Sound == nil then error("the purchase sound is missing from the shop button") end

		Sound:Play()
	end)
end

Remote.OnClientEvent:Connect(function(Coins: number, Multiplier: number)
	Balance.Text = `{Coins} coins   (x{Multiplier})`
end)
