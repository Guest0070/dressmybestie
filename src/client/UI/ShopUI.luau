--!strict
-- Shop: tabs of item cards (passes, entrance effects, trails, titles, walks & poses, auras).
-- Every item shows exactly what you get; nothing is random. The client only opens Roblox's
-- purchase prompts and sends "buy with coins" / "equip" requests; the server checks everything.
-- Opens from the lobby "Shop" button or by walking up to a kiosk in the plaza.
--
-- Designable in Studio: put a ScreenGui "ShopUI" in StarterGui (copy the built one during Play)
-- and it's used instead. Pieces found by Name: Coins (TextLabel), Close (TextButton), Grid
-- (ScrollingFrame), CardTemplate (hidden; with Preview, ItemName, Description, Action, optional
-- Try), tab buttons Tab_Passes / Tab_Effects / Tab_Trails / Tab_Titles / Tab_Walks / Tab_Auras
-- (delete one to hide that tab), optional Backdrop (tap to close). Each item is a copy of
-- CardTemplate, so style that one card and every item follows.

local MarketplaceService = game:GetService("MarketplaceService")
local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Auras = require(ReplicatedStorage.Shared.Auras)
local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Types = require(ReplicatedStorage.Shared.Types)
local State = require(script.Parent.Parent.State)
local Components = require(script.Parent.Components)
local Kit = require(script.Parent.Kit)
local Theme = require(script.Parent.Theme)

local ShopUI = {}

-- Set by init.client: the Dressing Room kiosk opens the catalog instead of the shop.
ShopUI.onDressingRoom = function() end

type Tab = { id: string, label: string, slots: { string }? }
local TABS: { Tab } = {
	{ id = "Passes", label = "VIP & PASSES" },
	{ id = "Coins", label = "COINS" },
	{ id = "Effects", label = "ENTRANCES", slots = { "Entrance" } },
	{ id = "Trails", label = "TRAILS", slots = { "Trail" } },
	{ id = "Titles", label = "TITLES", slots = { "Title" } },
	{ id = "Walks", label = "WALKS & POSES", slots = { "Walk", "Pose" } },
	{ id = "Auras", label = "AURAS", slots = { "Aura" } },
}

local VIP_DAILY_PERCENT = math.floor(Config.PassPerks.VipDailyBonus * 100)
local PASS_DESCRIPTIONS: { [string]: string } = {
	StarterPack = `{Config.PassPerks.StarterCoins} coins + Rising Star trail and title. One time only!`,
	VIP = `Extra item slots, Golden Trail + Aura, VIP title, +{VIP_DAILY_PERCENT}% daily coins`,
	DoubleCoins = `{Config.PassPerks.DoubleCoinsMultiplier}x coins from every round you play, forever`,
	PosePack = "3 signature poses at the end of your runway walk",
}
-- Shop order (Config tables are keyed by name, which has no order). Anything not listed goes last.
local PASS_ORDER = { "StarterPack", "VIP", "DoubleCoins", "PosePack" }
local MOMENT_ORDER = { "MomentCoinShower", "MomentConfetti", "MomentDisco", "MomentHearts", "MomentSnow" }
local MOMENT_DESCRIPTIONS: { [string]: string } = {
	CoinShower = `Everyone in the server gets {Config.CoinShowerCoins} coins, from you!`,
}

-- Keys of a Config table in the given order, then any others sorted by name.
local function ordered(source: { [string]: any }, first: { string }): { string }
	local keys = {}
	for _, key in first do
		if source[key] then
			table.insert(keys, key)
		end
	end
	local rest = {}
	for key in source do
		if not table.find(keys, key) then
			table.insert(rest, key)
		end
	end
	table.sort(rest)
	table.move(rest, 1, #rest, #keys + 1, keys)
	return keys
end

-- Developer products of one kind, cheapest first.
local function productsOfKind(kind: string): { Config.DevProduct }
	local list = {}
	for _, product in Config.DevProducts do
		if product.kind == kind then
			table.insert(list, product)
		end
	end
	table.sort(list, function(a, b)
		return a.price < b.price
	end)
	return list
end
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

local gui: ScreenGui
local grid: ScrollingFrame
local cardTemplate: GuiObject
local coinsLabel: TextLabel
local tabButtons: { [string]: Components.ButtonHandle } = {}
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
	state: Components.ButtonState?, -- Normal (default), Active (equipped/owned), Disabled, Locked
	onClick: (() -> ())?,
	preview: (Frame) -> (),
	highlight: boolean?,
	try: (() -> ())?, -- optional "Try" button over the preview (auras)
}

local order = 0
-- One item = one copy of CardTemplate.
local function card(spec: CardSpec): Components.ButtonHandle
	order += 1
	local frame = cardTemplate:Clone()
	frame.Name = "Card"
	frame.LayoutOrder = order
	frame.Visible = true
	if spec.highlight then
		local stroke = frame:FindFirstChildOfClass("UIStroke")
		if stroke then
			stroke.Color = Theme.Colors.Primary
			stroke.Thickness = 2.5
		end
	end
	local preview = frame:FindFirstChild("Preview", true) :: Frame
	for _, child in preview:GetChildren() do
		if child:IsA("GuiObject") then
			child:Destroy() -- whatever was left in the template's preview
		end
	end
	spec.preview(preview)
	local try = frame:FindFirstChild("Try", true)
	if try and try:IsA("TextButton") then
		try.Visible = spec.try ~= nil
		if spec.try then
			Components.attachButton(try, spec.try)
		end
	end
	(frame:FindFirstChild("ItemName", true) :: TextLabel).Text = spec.name;
	(frame:FindFirstChild("Description", true) :: TextLabel).Text = spec.description
	local action = Components.attachButton(
		frame:FindFirstChild("Action", true) :: TextButton,
		spec.onClick,
		spec.state or (if spec.onClick then "Normal" else "Disabled")
	)
	action:setText(spec.buttonText)
	frame.Parent = grid
	return action
end

local function textPreview(text: string, color: Color3, background: Color3?): (Frame) -> ()
	return function(frame)
		if background then
			frame.BackgroundColor3 = background
		end
		Components.text({
			Text = text,
			Size = UDim2.new(1, -12, 1, -12),
			Position = UDim2.fromOffset(6, 6),
			FontFace = Theme.Fonts.Heading,
			TextColor3 = color,
			MaxTextSize = 32,
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

-- Live preview: a copy of your own character in a little 3D window, playing the animation.
local function animatedPreview(animationId: number): (Frame) -> ()
	return function(frame)
		local character = State.player.Character
		if not character or animationId <= 0 then
			return
		end
		local viewport = Kit.new("ViewportFrame", {
			BackgroundTransparency = 1,
			Size = UDim2.fromScale(1, 1),
			Ambient = Color3.fromRGB(200, 200, 210),
			LightColor = Color3.new(1, 1, 1),
			Parent = frame,
		})
		local world = Instance.new("WorldModel") -- animations only play inside a WorldModel
		world.Parent = viewport
		character.Archivable = true
		local clone = character:Clone()
		for _, descendant in clone:GetDescendants() do
			if descendant:IsA("BaseScript") or descendant:IsA("Sound") or descendant:IsA("BillboardGui") then
				descendant:Destroy()
			elseif descendant:GetAttribute("AuraFx") or descendant:GetAttribute("AuraPreview") then
				descendant:Destroy()
			end
		end
		local root = clone:FindFirstChild("HumanoidRootPart")
		if root and root:IsA("BasePart") then
			root.Anchored = true
		end
		clone:PivotTo(CFrame.new(0, 0, 0))
		clone.Parent = world
		local camera = Instance.new("Camera")
		camera.FieldOfView = 40
		camera.CFrame = CFrame.lookAt(Vector3.new(4, 1, -8), Vector3.new(0, 0, 0))
		camera.Parent = viewport
		viewport.CurrentCamera = camera
		local humanoid = clone:FindFirstChildOfClass("Humanoid")
		if not humanoid then
			return
		end
		local animator = humanoid:FindFirstChildOfClass("Animator") or Instance.new("Animator")
		animator.Parent = humanoid
		local animation = Instance.new("Animation")
		animation.AnimationId = `rbxassetid://{animationId}`
		local ok, track = pcall((animator :: Animator).LoadAnimation, animator :: Animator, animation)
		if ok and track then
			track.Looped = true
			track:Play()
		end
	end
end

local function previewFor(cosmetic: Config.Cosmetic): (Frame) -> ()
	if
		(cosmetic.slot == "Walk" or cosmetic.slot == "Pose")
		and cosmetic.animationId
		and cosmetic.animationId > 0
	then
		return animatedPreview(cosmetic.animationId)
	elseif cosmetic.slot == "Aura" then
		return textPreview(
			cosmetic.displayName,
			cosmetic.color or Theme.Colors.Gold,
			Theme.Colors.PanelRaised
		)
	end
	if cosmetic.slot == "Trail" and cosmetic.color then
		return gradientPreview(cosmetic.color, cosmetic.color2 or cosmetic.color)
	elseif cosmetic.slot == "Title" then
		return textPreview(cosmetic.displayName, cosmetic.color or Theme.Colors.Text)
	elseif cosmetic.slot == "Entrance" then
		return textPreview(EFFECT_ICONS[cosmetic.id] or "*", Theme.Colors.Primary, Theme.Colors.PanelRaised)
	end
	return textPreview(cosmetic.displayName, Theme.Colors.Primary)
end

local function cosmeticCard(cosmetic: Config.Cosmetic, data: Types.PublicData)
	local owned = data.ownedCosmetics[cosmetic.id] == true
	local equipped = data.equipped[cosmetic.slot] == cosmetic.id
	local preview = previewFor(cosmetic)
	-- Auras: "Try" shows it on your own character for a few seconds (only you see it).
	local try = if cosmetic.slot == "Aura"
		then function()
			local character = State.player.Character
			if character then
				Auras.preview(character, cosmetic.id, 6)
			end
		end
		else nil
	local base = { name = cosmetic.displayName, preview = preview, try = try }
	local function with(extra: { [string]: any }): CardSpec
		local spec = table.clone(base) :: any
		for key, value in extra do
			spec[key] = value
		end
		return spec
	end
	if cosmetic.animationId ~= nil and cosmetic.animationId == 0 then
		card(with({ description = "Coming soon", buttonText = "SOON", state = "Disabled" }))
	elseif owned then
		card(with({
			description = if equipped then "Equipped" else "Owned",
			buttonText = if equipped then "UNEQUIP" else "EQUIP",
			state = if equipped then "Active" else "Normal",
			highlight = equipped,
			onClick = function()
				Remotes.Events.EquipCosmetic:FireServer(cosmetic.slot, if equipped then nil else cosmetic.id)
			end,
		}))
	elseif cosmetic.coinPrice then
		local price = cosmetic.coinPrice
		local short = price - data.coins
		card(with({
			description = if short > 0 then `{short} more coins needed` else "Buy with coins",
			buttonText = `{price} COINS`,
			onClick = function()
				if short > 0 then
					ShopUI.open("Coins") -- not enough yet: show the ways to get more
				else
					Remotes.Events.BuyWithCoins:FireServer(cosmetic.id)
				end
			end,
		}))
	elseif cosmetic.tip then
		card(with({
			description = "Thank you for supporting the game!",
			buttonText = "TIP",
			onClick = function()
				ShopUI.open("Passes")
			end,
		}))
	elseif cosmetic.productKey then
		local product = Config.DevProducts[cosmetic.productKey]
		if product.id == 0 then
			card(with({ description = "Coming soon", buttonText = "SOON", state = "Disabled" }))
			return
		end
		local button = card(with({
			description = "Yours forever",
			buttonText = `R$ {product.price}`,
			onClick = function()
				MarketplaceService:PromptProductPurchase(State.player, product.id)
			end,
		}))
		fetchPrice(`p{product.id}`, product.id, Enum.InfoType.Product, function(price)
			button:setText(`R$ {price}`)
		end)
	elseif cosmetic.pass then
		local pass = Config.GamePasses[cosmetic.pass]
		card(with({
			description = `Included with {pass.displayName}`,
			buttonText = if pass.id == 0 then "SOON" else `GET {string.upper(pass.displayName)}`,
			state = if pass.id == 0 then "Disabled" else "Normal",
			onClick = if pass.id == 0
				then nil
				else function()
					MarketplaceService:PromptGamePassPurchase(State.player, pass.id)
				end,
		}))
	elseif cosmetic.rank then
		card(with({
			description = "Free when you rank up",
			buttonText = `LV {cosmetic.rank}`,
			state = "Locked",
		}))
	end
end

-- A developer product card: "SOON" until it has an ID, then the live Robux price.
local function productCard(
	product: Config.DevProduct,
	description: string,
	preview: (Frame) -> (),
	highlight: boolean?
)
	if product.id == 0 then
		card({ name = product.displayName, description = description, buttonText = "SOON", preview = preview })
		return
	end
	local button = card({
		name = product.displayName,
		description = description,
		buttonText = `R$ {product.price}`,
		preview = preview,
		highlight = highlight,
		onClick = function()
			MarketplaceService:PromptProductPurchase(State.player, product.id)
		end,
	})
	fetchPrice(`p{product.id}`, product.id, Enum.InfoType.Product, function(price)
		button:setText(`R$ {price}`)
	end)
end

local function passesTab(data: Types.PublicData)
	for _, key in ordered(Config.GamePasses, PASS_ORDER) do
		local pass = Config.GamePasses[key]
		local owned = data.ownedPasses[key] == true
		local preview = textPreview(pass.displayName, Theme.Colors.Gold, Theme.Colors.PanelRaised)
		local description = PASS_DESCRIPTIONS[key] or ""
		if owned then
			card({
				name = pass.displayName,
				description = description,
				buttonText = "OWNED",
				state = "Active",
				highlight = true,
				preview = preview,
			})
		elseif pass.id == 0 then
			card({
				name = pass.displayName,
				description = description,
				buttonText = "SOON",
				preview = preview,
			})
		else
			local button = card({
				name = pass.displayName,
				description = description,
				buttonText = `R$ {pass.price}`,
				preview = preview,
				highlight = key == "StarterPack",
				onClick = function()
					MarketplaceService:PromptGamePassPurchase(State.player, pass.id)
				end,
			})
			fetchPrice(`g{pass.id}`, pass.id, Enum.InfoType.GamePass, function(price)
				button:setText(`R$ {price}`)
			end)
		end
	end
	for _, key in ordered(Config.DevProducts, MOMENT_ORDER) do
		local product = Config.DevProducts[key]
		if product.kind ~= "Moment" then
			continue
		end
		local description = MOMENT_DESCRIPTIONS[product.moment or ""]
			or "30s for the whole server, with your name!"
		productCard(
			product,
			description,
			textPreview(product.displayName, Theme.Colors.Primary, Theme.Colors.PanelRaised)
		)
	end
	-- Roblox Premium: Roblox pays the game for time Premium members spend in it.
	if State.player.MembershipType ~= Enum.MembershipType.Premium then
		card({
			name = "Roblox Premium",
			description = `+{math.floor(Config.Rewards.PremiumCoinBonus * 100)}% coins from every round here`,
			buttonText = "GET PREMIUM",
			preview = textPreview("Premium", Theme.Colors.Text, Theme.Colors.PanelRaised),
			onClick = function()
				pcall(MarketplaceService.PromptPremiumPurchase, MarketplaceService, State.player)
			end,
		})
	end
	local supporter = data.ownedCosmetics.TitleSupporter == true
	for _, product in productsOfKind("Tip") do
		productCard(
			product,
			if supporter then "Thank you for supporting us!" else "Support the game + Supporter title",
			textPreview("<3", Theme.Colors.Primary, Theme.Colors.PanelRaised)
		)
	end
end

local function coinsTab()
	for _, product in productsOfKind("Coins") do
		local coins = product.coins or 0
		local description = if product.bonus then `{coins} coins  {product.bonus}` else `{coins} coins`
		productCard(product, description, textPreview(`{coins}`, Theme.Colors.Gold, Theme.Colors.PanelRaised))
	end
	-- The coin pass lives in Passes; show it here too, where people look for coins.
	local pass = Config.GamePasses.DoubleCoins
	local data = State.data
	if pass and pass.id ~= 0 and data and not data.ownedPasses.DoubleCoins then
		local button = card({
			name = pass.displayName,
			description = PASS_DESCRIPTIONS.DoubleCoins,
			buttonText = `R$ {pass.price}`,
			preview = textPreview("2x", Theme.Colors.Gold, Theme.Colors.PanelRaised),
			onClick = function()
				MarketplaceService:PromptGamePassPurchase(State.player, pass.id)
			end,
		})
		fetchPrice(`g{pass.id}`, pass.id, Enum.InfoType.GamePass, function(price)
			button:setText(`R$ {price}`)
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
		button:setState(if id == currentTab then "Active" else "Normal")
	end
	local data = State.data
	if not data then
		return
	end
	coinsLabel.Text = `{data.coins} COINS`
	if currentTab == "Passes" then
		passesTab(data)
		return
	elseif currentTab == "Coins" then
		coinsTab()
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

function ShopUI.close()
	gui.Enabled = false
	Kit.hideChat("Shop", false)
end

function ShopUI.open(tab: string?)
	if not State.canUseLobby() then
		return -- never cover the game during your round
	end
	-- Coins opens even without a Tab_Coins button (a Studio-designed shop made before it existed).
	if tab and (tabButtons[tab] or tab == "Coins") then
		currentTab = tab
	end
	rebuild()
	gui.Enabled = true
	Kit.hideChat("Shop", true)
end

---------------------------------------------------------------------------------------------------
-- Default layout (used when there's no StarterGui.ShopUI). Instances only; wire() makes them work.
---------------------------------------------------------------------------------------------------

local function buildCardTemplate(parent: Instance)
	local template = Components.panel({
		Name = "CardTemplate",
		Raised = true,
		Size = UDim2.fromOffset(150, 190),
		Visible = false,
		Parent = parent,
	})
	Kit.new("Frame", {
		Name = "Preview",
		Position = UDim2.fromOffset(6, 6),
		Size = UDim2.new(1, -12, 0.46, 0),
		BackgroundColor3 = Theme.Colors.Background,
		BorderSizePixel = 0,
		ClipsDescendants = true,
		Parent = template,
	}, { Components.corner(Theme.Radius) })
	Components.styleButton({
		Name = "Try",
		Text = "TRY",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.fromOffset(144, 10),
		Size = UDim2.fromOffset(52, 28),
		MaxTextSize = 12,
		ZIndex = 3,
		Visible = false,
		Parent = template,
	})
	Components.text({
		Name = "ItemName",
		Position = UDim2.new(0, 8, 0.5, 0),
		Size = UDim2.new(1, -16, 0.12, 0),
		FontFace = Theme.Fonts.Heading,
		MaxTextSize = 16,
		Parent = template,
	})
	Components.text({
		Name = "Description",
		Position = UDim2.new(0, 8, 0.63, 0),
		Size = UDim2.new(1, -16, 0.1, 0),
		TextColor3 = Theme.Colors.Muted,
		MaxTextSize = 12,
		MinTextSize = 8,
		Parent = template,
	})
	Components.styleButton({
		Name = "Action",
		Text = "BUY",
		Variant = "Primary",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -6),
		Size = UDim2.new(1, -12, 0.2, 0),
		MaxTextSize = 14,
		Parent = template,
	})
end

local function build(): ScreenGui
	local root = Components.screen("ShopUI", 5)
	local backdrop = Instance.new("TextButton")
	backdrop.Name = "Backdrop"
	backdrop.Text = ""
	backdrop.AutoButtonColor = false
	backdrop.BackgroundColor3 = Color3.new(0, 0, 0)
	backdrop.BackgroundTransparency = 0.45
	backdrop.Size = UDim2.fromScale(1, 1)
	backdrop.Selectable = false
	backdrop.Parent = root

	local window = Components.panel({
		Name = "Window",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(0.86, 0.84),
		Parent = root,
	})
	Components.sizeLimit(Vector2.new(320, 240), Vector2.new(960, 600)).Parent = window
	Components.padding(12, 12).Parent = window

	Components.text({
		Name = "Title",
		Text = "SHOP",
		Size = UDim2.new(0, 90, 0, 36),
		FontFace = Theme.Fonts.Heading,
		TextXAlignment = Enum.TextXAlignment.Left,
		MaxTextSize = 24,
		Parent = window,
	})
	Components.text({
		Name = "Coins",
		Position = UDim2.fromOffset(96, 0),
		Size = UDim2.new(0.4, 0, 0, 36),
		FontFace = Theme.Fonts.Number,
		TextColor3 = Theme.Colors.Gold,
		TextXAlignment = Enum.TextXAlignment.Left,
		MaxTextSize = 18,
		Parent = window,
	})
	Components.styleButton({
		Name = "Close",
		Text = "X", -- the UI font has no ✕ glyph
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.fromScale(1, 0),
		Size = UDim2.fromOffset(Theme.MinTouch, Theme.MinTouch),
		MaxTextSize = 18,
		Parent = window,
	})

	local tabs = Kit.new("ScrollingFrame", {
		Name = "Tabs",
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(0, 44),
		Size = UDim2.new(1, 0, 0, 40),
		CanvasSize = UDim2.new(0, 0, 0, 0),
		AutomaticCanvasSize = Enum.AutomaticSize.X,
		ScrollingDirection = Enum.ScrollingDirection.X,
		ScrollBarThickness = 3,
		Parent = window,
	}, { Components.list(Enum.FillDirection.Horizontal, 8, Enum.HorizontalAlignment.Left) :: Instance })
	for index, tab in TABS do
		Components.styleButton({
			Name = `Tab_{tab.id}`,
			Text = tab.label,
			Size = UDim2.new(0, if #tab.label > 10 then 130 else 100, 1, -4),
			MaxTextSize = 14,
			LayoutOrder = index,
			Parent = tabs,
		})
	end

	Kit.new("ScrollingFrame", {
		Name = "Grid",
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(0, 92),
		Size = UDim2.new(1, 0, 1, -92),
		CanvasSize = UDim2.new(0, 0, 0, 0),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollingDirection = Enum.ScrollingDirection.Y,
		ScrollBarThickness = 4,
		Parent = window,
	}, {
		Kit.new("UIGridLayout", {
			CellSize = UDim2.fromOffset(150, 190),
			CellPadding = UDim2.fromOffset(8, 8),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	})
	buildCardTemplate(window)
	return root
end

local function wire(root: ScreenGui): { string }
	local missing: { string } = {}
	local find = Components.finder(missing)
	local coins = find(root, "Coins", "TextLabel")
	local close = find(root, "Close", "TextButton")
	local gridFrame = find(root, "Grid", "ScrollingFrame")
	local template = find(root, "CardTemplate", "GuiObject")
	if template then
		find(template, "Preview", "Frame")
		find(template, "ItemName", "TextLabel")
		find(template, "Description", "TextLabel")
		find(template, "Action", "TextButton")
	end
	if #missing > 0 then
		return missing
	end
	coinsLabel = coins
	grid = gridFrame
	cardTemplate = template
	template.Visible = false
	Components.attachButton(close, ShopUI.close)
	local backdrop = root:FindFirstChild("Backdrop")
	if backdrop and backdrop:IsA("GuiButton") then
		backdrop.Activated:Connect(ShopUI.close)
	end
	-- Tabs are optional one by one: delete a Tab_ button in Studio to hide that tab.
	table.clear(tabButtons)
	for _, tab in TABS do
		local button = root:FindFirstChild(`Tab_{tab.id}`, true)
		if button and button:IsA("TextButton") then
			tabButtons[tab.id] = Components.attachButton(button, function()
				currentTab = tab.id
				rebuild()
			end)
		end
	end
	if not tabButtons[currentTab] then
		currentTab = next(tabButtons) or currentTab
	end
	return missing
end

function ShopUI.start()
	gui = Components.designable("ShopUI", build, wire)
	gui.Enabled = false

	State.DataChanged:Connect(function()
		if gui.Enabled then
			rebuild()
		end
	end)
	-- Close the shop when a round starts so it never covers the booth.
	State.RoundChanged:Connect(function()
		if not State.canUseLobby() then
			ShopUI.close()
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
