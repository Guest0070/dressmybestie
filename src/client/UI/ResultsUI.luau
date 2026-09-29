--!strict
-- Results podium (top 3 only, never a "last place") and the "Buy this look" panel.
-- Buying uses Roblox's own purchase prompts; the game earns a commission on catalog sales.

local MarketplaceService = game:GetService("MarketplaceService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Types = require(ReplicatedStorage.Shared.Types)
local State = require(script.Parent.Parent.State)
local Kit = require(script.Parent.Kit)

local ResultsUI = {}

local PLACE_NAMES = { "1st", "2nd", "3rd" }
local PLACE_COLORS =
	{ Color3.fromRGB(255, 210, 80), Color3.fromRGB(210, 210, 225), Color3.fromRGB(220, 150, 90) }

local podiumPanel: Frame
local podiumList: Frame
local looksPanel: Frame
local looksTabs: ScrollingFrame
local looksGrid: ScrollingFrame
local priceCache: { [string]: string } = {}

local function priceText(id: number, isBundle: boolean, label: TextLabel)
	local key = (if isBundle then "b" else "a") .. id
	if priceCache[key] then
		label.Text = priceCache[key]
		return
	end
	task.spawn(function()
		local ok, info = pcall(
			MarketplaceService.GetProductInfoAsync,
			MarketplaceService,
			id,
			if isBundle then Enum.InfoType.Bundle else Enum.InfoType.Asset
		)
		local text = "Buy"
		if ok and type(info) == "table" then
			local price = (info :: any).PriceInRobux
			if (info :: any).IsForSale == false then
				text = "Off sale"
			elseif type(price) == "number" then
				text = if price == 0 then "Free" else `R$ {price}`
			end
		end
		priceCache[key] = text
		label.Text = text
	end)
end

local function itemCard(id: number, isBundle: boolean, order: number)
	local card = Kit.new("Frame", {
		BackgroundColor3 = Kit.Colors.PanelLight,
		LayoutOrder = order,
		Parent = looksGrid,
	}, { Kit.corner(10) })
	Kit.new("ImageLabel", {
		BackgroundTransparency = 1,
		Image = if isBundle then Kit.bundleThumb(id) else Kit.assetThumb(id),
		Size = UDim2.new(1, -8, 0, 92),
		Position = UDim2.fromOffset(4, 4),
		Parent = card,
	})
	local buy = Kit.button({
		Text = "...",
		Size = UDim2.new(1, -8, 0, 44),
		Position = UDim2.fromOffset(4, 100),
		BackgroundColor3 = Kit.Colors.Green,
		MaxTextSize = 20,
		Parent = card,
	}, function()
		if isBundle then
			MarketplaceService:PromptBundlePurchase(State.player, id)
		else
			MarketplaceService:PromptPurchase(State.player, id)
		end
	end)
	priceText(id, isBundle, buy :: any)
end

local function showLook(shopLook: Types.ShopLook)
	for _, child in looksGrid:GetChildren() do
		if child:IsA("GuiObject") then
			child:Destroy()
		end
	end
	for index, id in shopLook.look.assetIds do
		itemCard(id, false, index)
	end
	if shopLook.look.shoeBundleId then
		itemCard(shopLook.look.shoeBundleId, true, 1000)
	end
end

function ResultsUI.openLooks()
	local looks = State.lastShopLooks
	if #looks == 0 then
		return
	end
	for _, child in looksTabs:GetChildren() do
		if child:IsA("GuiObject") then
			child:Destroy()
		end
	end
	-- Your own look first: you'll most likely want what your stylist put on you.
	local ordered = table.clone(looks)
	table.sort(ordered, function(a, b)
		return a.wearerUserId == State.player.UserId and b.wearerUserId ~= State.player.UserId
	end)
	for index, shopLook in ordered do
		local label = if shopLook.wearerUserId == State.player.UserId
			then "Your look"
			else shopLook.wearerName
		Kit.button({
			Text = label,
			Size = UDim2.fromOffset(150, 44),
			BackgroundColor3 = Kit.Colors.PanelLight,
			LayoutOrder = index,
			MaxTextSize = 20,
			Parent = looksTabs,
		}, function()
			showLook(shopLook)
		end)
	end
	showLook(ordered[1])
	looksPanel.Visible = true
end

local function refresh()
	local round = State.round
	podiumPanel.Visible = round.phase == "Results"
	if round.phase ~= "Results" then
		if round.phase ~= "Lobby" then
			looksPanel.Visible = false
		end
		return
	end
	for _, child in podiumList:GetChildren() do
		if child:IsA("GuiObject") then
			child:Destroy()
		end
	end
	local podium: { Types.PodiumEntry } = round.podium or {}
	if #podium == 0 then
		Kit.label({
			Text = "No hearts this round. Everyone's a star!",
			Size = UDim2.new(1, 0, 0, 36),
			Parent = podiumList,
		})
	end
	local worst = round.chaos and round.chaos.reverseVoting
	for _, entry in podium do
		local row = Kit.new("Frame", {
			BackgroundColor3 = PLACE_COLORS[entry.place],
			Size = UDim2.new(1, 0, 0, 44),
			LayoutOrder = entry.place,
			Parent = podiumList,
		}, { Kit.corner(10) })
		local stylists = if #entry.stylistNames > 0 then table.concat(entry.stylistNames, " & ") else "?"
		Kit.label({
			Text = `{PLACE_NAMES[entry.place]}  {entry.wearerName}  (styled by {stylists})  ♥ {entry.hearts}`,
			Size = UDim2.new(1, -16, 1, -8),
			Position = UDim2.fromOffset(8, 4),
			TextColor3 = Kit.Colors.Panel,
			TextXAlignment = Enum.TextXAlignment.Left,
			Parent = row,
		})
	end
	local title = podiumPanel:FindFirstChild("Title") :: TextLabel
	title.Text = if worst then "Most Gloriously Terrible" else "Top Looks"
end

function ResultsUI.start()
	local _, root = Kit.screen("Results", 4)

	podiumPanel = Kit.panel({
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -8),
		Size = UDim2.fromOffset(620, 240),
		Visible = false,
		Parent = root,
	})
	Kit.label({
		Name = "Title",
		Text = "Top Looks",
		Size = UDim2.new(1, -16, 0, 34),
		Position = UDim2.fromOffset(8, 6),
		TextColor3 = Kit.Colors.Gold,
		Parent = podiumPanel,
	})
	podiumList = Kit.new("Frame", {
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(12, 44),
		Size = UDim2.new(1, -24, 0, 3 * 50),
		Parent = podiumPanel,
	}, { Kit.list(Enum.FillDirection.Vertical, 6) })
	Kit.button({
		Text = "Buy this look",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -8),
		Size = UDim2.fromOffset(240, Kit.ButtonHeight - 8),
		BackgroundColor3 = Kit.Colors.Green,
		Parent = podiumPanel,
	}, ResultsUI.openLooks)

	looksPanel = Kit.panel({
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.new(0.9, 0, 0.9, 0),
		Visible = false,
		ZIndex = 5,
		Parent = root,
	})
	Kit.label({
		Text = "Buy this look",
		Size = UDim2.new(1, -140, 0, 40),
		Position = UDim2.fromOffset(12, 8),
		Parent = looksPanel,
	})
	Kit.button({
		Text = "Close",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -8, 0, 8),
		Size = UDim2.fromOffset(110, Kit.ButtonHeight - 8),
		BackgroundColor3 = Kit.Colors.Grey,
		Parent = looksPanel,
	}, function()
		looksPanel.Visible = false
	end)
	looksTabs = Kit.new("ScrollingFrame", {
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(8, 60),
		Size = UDim2.new(1, -16, 0, 52),
		CanvasSize = UDim2.new(0, 0, 0, 0),
		AutomaticCanvasSize = Enum.AutomaticSize.X,
		ScrollingDirection = Enum.ScrollingDirection.X,
		ScrollBarThickness = 4,
		Parent = looksPanel,
	}, { Kit.list(Enum.FillDirection.Horizontal, 6) })
	looksGrid = Kit.new("ScrollingFrame", {
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(8, 118),
		Size = UDim2.new(1, -16, 1, -126),
		CanvasSize = UDim2.new(0, 0, 0, 0),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollingDirection = Enum.ScrollingDirection.Y,
		ScrollBarThickness = 6,
		Parent = looksPanel,
	}, {
		Kit.new("UIGridLayout", {
			CellSize = UDim2.fromOffset(120, 150),
			CellPadding = UDim2.fromOffset(8, 8),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	})

	State.RoundChanged:Connect(refresh)
	refresh()
end

return ResultsUI
