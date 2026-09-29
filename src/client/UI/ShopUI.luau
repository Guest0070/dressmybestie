--!strict
-- Shop: tabs of item cards (passes, entrance effects, trails, titles, walks & poses).
-- Every item shows exactly what you get; nothing is random. The client only opens Roblox's
-- purchase prompts and sends "buy with coins" / "equip" requests; the server checks everything.
-- Opens from the lobby "Shop" button or by walking up to a kiosk in the plaza.

local MarketplaceService = game:GetService("MarketplaceService")
local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Types = require(ReplicatedStorage.Shared.Types)
local State = require(script.Parent.Parent.State)
local Kit = require(script.Parent.Kit)

local ShopUI = {}

-- Set by init.client: the Dressing Room kiosk opens the catalog instead of the shop.
ShopUI.onDressingRoom = function() end

type Tab = { id: string, label: string, slots: { string }? }
local TABS: { Tab } = {
	{ id = "Passes", label = "VIP & Passes" },
	{ id = "Effects", label = "Entrances", slots = { "Entrance" } },
	{ id = "Trails", label = "Trails", slots = { "Trail" } },
	{ id = "Titles", label = "Titles", slots = { "Title" } },
	{ id = "Walks", label = "Walks & Poses", slots = { "Walk", "Pose" } },
}

local PASS_DESCRIPTIONS: { [string]: string } = {
	VIP = "More item slots, VIP themes, golden runway glow, Golden Trail + VIP title",
	PosePack = "3 signature poses at the end of your runway walk",
}
-- A symbol for each entrance effect's preview card.
local EFFECT_ICONS: { [string]: string } = {
	Smoke = "~",
	Bubbles = "o O o",
	Stars = "* * *",
	Petals = "~ ~ ~",
	Fire = "^ ^ ^",
	Hearts = "<3",
	Sparkles = "+ + +",
	Confetti = ". : .",
	Spotlight = "( O )",
}

local panel: Frame
local grid: ScrollingFrame
local coinsLabel: TextLabel
local tabButtons: { [string]: TextButton } = {}
local currentTab = "Passes"
local realPrices: { [string]: number } = {}

-- Show the real price from Roblox when we can (the dashboard price is what players pay).
local function fetchPrice(key: string, id: number, infoType: Enum.InfoType, onPrice: (number) -> ())
	if realPrices[key] then
		onPrice(realPrices[key])
		return
	end
	task.spawn(function()
		local ok, info = pcall(MarketplaceService.GetProductInfoAsync, MarketplaceService, id, infoType)
		local price = if ok and type(info) == "table" then (info :: any).PriceInRobux else nil
		if type(price) == "number" then
			realPrices[key] = price
			onPrice(price)
		end
	end)
end

type CardSpec = {
	name: string,
	description: string,
	buttonText: string,
	buttonColor: Color3,
	onClick: (() -> ())?,
	preview: (Frame) -> (),
	highlight: boolean?,
}

local order = 0
local function card(spec: CardSpec): TextButton
	order += 1
	local frame = Kit.new("Frame", {
		BackgroundColor3 = Kit.Colors.PanelLight,
		LayoutOrder = order,
		Parent = grid,
	}, {
		Kit.corner(14),
		Kit.new("UIStroke", {
			Color = if spec.highlight then Kit.Colors.Gold else Kit.Colors.Pink,
			Thickness = if spec.highlight then 3 else 1.5,
			Transparency = 0.2,
		}),
	})
	local preview = Kit.new("Frame", {
		BackgroundColor3 = Kit.Colors.Panel,
		Position = UDim2.fromOffset(8, 8),
		Size = UDim2.new(1, -16, 0, 70),
		ClipsDescendants = true,
		Parent = frame,
	}, { Kit.corner(10) })
	spec.preview(preview)
	Kit.label({
		Text = spec.name,
		Position = UDim2.fromOffset(8, 82),
		Size = UDim2.new(1, -16, 0, 24),
		MaxTextSize = 22,
		Parent = frame,
	})
	Kit.label({
		Text = spec.description,
		Position = UDim2.fromOffset(8, 106),
		Size = UDim2.new(1, -16, 0, 18),
		Font = Kit.BodyFont,
		TextColor3 = Kit.Colors.TextDim,
		MaxTextSize = 14,
		Parent = frame,
	})
	return Kit.button({
		Text = spec.buttonText,
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -8),
		Size = UDim2.new(1, -16, 0, 40),
		BackgroundColor3 = spec.buttonColor,
		AutoButtonColor = spec.onClick ~= nil,
		MaxTextSize = 20,
		Parent = frame,
	}, spec.onClick)
end

local function textPreview(text: string, color: Color3, background: Color3?): (Frame) -> ()
	return function(frame)
		if background then
			frame.BackgroundColor3 = background
		end
		Kit.label({
			Text = text,
			Size = UDim2.new(1, -12, 1, -12),
			Position = UDim2.fromOffset(6, 6),
			TextColor3 = color,
			MaxTextSize = 34,
			Parent = frame,
		})
	end
end

local function gradientPreview(a: Color3, b: Color3): (Frame) -> ()
	return function(frame)
		frame.BackgroundColor3 = Color3.new(1, 1, 1)
		Kit.new("UIGradient", {
			Color = ColorSequence.new(a, b),
			Transparency = NumberSequence.new(0, 0.3),
			Parent = frame,
		})
	end
end

local function previewFor(cosmetic: Config.Cosmetic): (Frame) -> ()
	if cosmetic.slot == "Trail" and cosmetic.color then
		return gradientPreview(cosmetic.color, cosmetic.color2 or cosmetic.color)
	elseif cosmetic.slot == "Title" then
		return textPreview(cosmetic.displayName, cosmetic.color or Kit.Colors.Text)
	elseif cosmetic.slot == "Entrance" then
		return textPreview(EFFECT_ICONS[cosmetic.id] or "*", Kit.Colors.Gold, Color3.fromRGB(60, 40, 80))
	end
	return textPreview(cosmetic.displayName, Kit.Colors.Pink)
end

local function cosmeticCard(cosmetic: Config.Cosmetic, data: Types.PublicData)
	local owned = data.ownedCosmetics[cosmetic.id] == true
	local equipped = data.equipped[cosmetic.slot] == cosmetic.id
	local preview = previewFor(cosmetic)
	if cosmetic.animationId ~= nil and cosmetic.animationId == 0 then
		card({
			name = cosmetic.displayName,
			description = "Coming soon",
			buttonText = "Soon",
			buttonColor = Kit.Colors.Grey,
			preview = preview,
		})
	elseif owned then
		card({
			name = cosmetic.displayName,
			description = if equipped then "Equipped" else "Owned",
			buttonText = if equipped then "Unequip" else "Equip",
			buttonColor = if equipped then Kit.Colors.Grey else Kit.Colors.Blue,
			highlight = equipped,
			preview = preview,
			onClick = function()
				Remotes.Events.EquipCosmetic:FireServer(cosmetic.slot, if equipped then nil else cosmetic.id)
			end,
		})
	elseif cosmetic.coinPrice then
		local price = cosmetic.coinPrice
		local affordable = data.coins >= price
		card({
			name = cosmetic.displayName,
			description = "Earn coins by playing",
			buttonText = `{price} coins`,
			buttonColor = if affordable then Kit.Colors.Gold else Kit.Colors.Grey,
			preview = preview,
			onClick = function()
				Remotes.Events.BuyWithCoins:FireServer(cosmetic.id)
			end,
		})
	elseif cosmetic.productKey then
		local product = Config.DevProducts[cosmetic.productKey]
		if product.id == 0 then
			card({
				name = cosmetic.displayName,
				description = "Coming soon",
				buttonText = "Soon",
				buttonColor = Kit.Colors.Grey,
				preview = preview,
			})
			return
		end
		local button = card({
			name = cosmetic.displayName,
			description = "Yours forever",
			buttonText = `R$ {product.price}`,
			buttonColor = Kit.Colors.Green,
			preview = preview,
			onClick = function()
				MarketplaceService:PromptProductPurchase(State.player, product.id)
			end,
		})
		fetchPrice(`p{product.id}`, product.id, Enum.InfoType.Product, function(price)
			button.Text = `R$ {price}`
		end)
	elseif cosmetic.pass then
		local pass = Config.GamePasses[cosmetic.pass]
		card({
			name = cosmetic.displayName,
			description = `Included with {pass.displayName}`,
			buttonText = if pass.id == 0 then "Soon" else `Get {pass.displayName}`,
			buttonColor = if pass.id == 0 then Kit.Colors.Grey else Kit.Colors.Green,
			preview = preview,
			onClick = if pass.id == 0
				then nil
				else function()
					MarketplaceService:PromptGamePassPurchase(State.player, pass.id)
				end,
		})
	elseif cosmetic.rank then
		card({
			name = cosmetic.displayName,
			description = "Free when you rank up",
			buttonText = `Reach Lv {cosmetic.rank}`,
			buttonColor = Kit.Colors.Grey,
			preview = preview,
		})
	end
end

local function passesTab(data: Types.PublicData)
	for key, pass in Config.GamePasses do
		local owned = data.ownedPasses[key] == true
		local preview = textPreview(pass.displayName, Kit.Colors.Gold, Color3.fromRGB(70, 55, 20))
		if pass.id == 0 then
			card({
				name = pass.displayName,
				description = PASS_DESCRIPTIONS[key] or "",
				buttonText = "Soon",
				buttonColor = Kit.Colors.Grey,
				preview = preview,
			})
		elseif owned then
			card({
				name = pass.displayName,
				description = PASS_DESCRIPTIONS[key] or "",
				buttonText = "Owned",
				buttonColor = Kit.Colors.Grey,
				preview = preview,
				highlight = true,
			})
		else
			local button = card({
				name = pass.displayName,
				description = PASS_DESCRIPTIONS[key] or "",
				buttonText = `R$ {pass.price}`,
				buttonColor = Kit.Colors.Green,
				preview = preview,
				onClick = function()
					MarketplaceService:PromptGamePassPurchase(State.player, pass.id)
				end,
			})
			fetchPrice(`g{pass.id}`, pass.id, Enum.InfoType.GamePass, function(price)
				button.Text = `R$ {price}`
			end)
		end
	end
	for _, product in Config.DevProducts do
		if product.kind ~= "Moment" then
			continue
		end
		local preview = textPreview(product.displayName, Kit.Colors.Pink, Color3.fromRGB(60, 30, 60))
		if product.id == 0 then
			card({
				name = product.displayName,
				description = "30s for the whole server",
				buttonText = "Soon",
				buttonColor = Kit.Colors.Grey,
				preview = preview,
			})
			continue
		end
		local button = card({
			name = product.displayName,
			description = "30s for the whole server, with your name!",
			buttonText = `R$ {product.price}`,
			buttonColor = Kit.Colors.Green,
			preview = preview,
			onClick = function()
				MarketplaceService:PromptProductPurchase(State.player, product.id)
			end,
		})
		fetchPrice(`p{product.id}`, product.id, Enum.InfoType.Product, function(price)
			button.Text = `R$ {price}`
		end)
	end
end

local function rebuild()
	for _, child in grid:GetChildren() do
		if child:IsA("GuiObject") then
			child:Destroy()
		end
	end
	order = 0
	for id, button in tabButtons do
		button.BackgroundColor3 = if id == currentTab then Kit.Colors.Pink else Kit.Colors.PanelLight
	end
	local data = State.data
	if not data then
		return
	end
	coinsLabel.Text = `{data.coins} coins`
	if currentTab == "Passes" then
		passesTab(data)
		return
	end
	local slots: { string } = {}
	for _, tab in TABS do
		if tab.id == currentTab and tab.slots then
			slots = tab.slots
		end
	end
	for _, cosmetic in Config.Cosmetics do
		if table.find(slots, cosmetic.slot) then
			cosmeticCard(cosmetic, data)
		end
	end
end

function ShopUI.open(tab: string?)
	if State.round.phase ~= "Lobby" then
		return -- never cover the game during a round
	end
	if tab then
		currentTab = tab
	end
	rebuild()
	panel.Visible = true
end

function ShopUI.start()
	local _, root = Kit.screen("Shop", 5)
	panel = Kit.panel({
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.new(0.94, 0, 0.92, 0),
		Visible = false,
		Parent = root,
	})
	Kit.label({
		Text = "SHOP",
		Position = UDim2.fromOffset(14, 8),
		Size = UDim2.fromOffset(140, 40),
		TextColor3 = Kit.Colors.Pink,
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = panel,
	})
	coinsLabel = Kit.label({
		Text = "",
		Position = UDim2.fromOffset(150, 12),
		Size = UDim2.fromOffset(220, 32),
		TextColor3 = Kit.Colors.Gold,
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = panel,
	})
	Kit.button({
		Text = "Close",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -8, 0, 8),
		Size = UDim2.fromOffset(110, Kit.ButtonHeight - 10),
		BackgroundColor3 = Kit.Colors.Grey,
		Parent = panel,
	}, function()
		panel.Visible = false
	end)

	local tabs = Kit.new("ScrollingFrame", {
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(8, 58),
		Size = UDim2.new(1, -16, 0, 50),
		CanvasSize = UDim2.new(0, 0, 0, 0),
		AutomaticCanvasSize = Enum.AutomaticSize.X,
		ScrollingDirection = Enum.ScrollingDirection.X,
		ScrollBarThickness = 4,
		Parent = panel,
	}, { Kit.list(Enum.FillDirection.Horizontal, 6) })
	for index, tab in TABS do
		tabButtons[tab.id] = Kit.button({
			Text = tab.label,
			Size = UDim2.fromOffset(150, 44),
			BackgroundColor3 = Kit.Colors.PanelLight,
			LayoutOrder = index,
			MaxTextSize = 20,
			Parent = tabs,
		}, function()
			currentTab = tab.id
			rebuild()
		end)
	end

	grid = Kit.new("ScrollingFrame", {
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(8, 114),
		Size = UDim2.new(1, -16, 1, -122),
		CanvasSize = UDim2.new(0, 0, 0, 0),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollingDirection = Enum.ScrollingDirection.Y,
		ScrollBarThickness = 6,
		Parent = panel,
	}, {
		Kit.new("UIGridLayout", {
			CellSize = UDim2.fromOffset(190, 180),
			CellPadding = UDim2.fromOffset(10, 10),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	})

	State.DataChanged:Connect(function()
		if panel.Visible then
			rebuild()
		end
	end)
	-- Close the shop when a round starts so it never covers the booth.
	State.RoundChanged:Connect(function(round)
		if round.phase ~= "Lobby" then
			panel.Visible = false
		end
	end)
	-- Walking up to a kiosk in the plaza and pressing E / tapping opens that shop tab.
	ProximityPromptService.PromptTriggered:Connect(function(prompt)
		local tab = prompt:GetAttribute("ShopTab")
		if tab == "DressingRoom" then
			Kit.playSound("Click")
			ShopUI.onDressingRoom()
		elseif type(tab) == "string" then
			Kit.playSound("Click")
			ShopUI.open(tab)
		end
	end)
end

return ShopUI
