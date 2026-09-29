--!strict
-- Shop: game passes, lobby moments, and cosmetics (coins or Robux). Every item says exactly
-- what you get; nothing is random. The client only opens Roblox's purchase prompts and sends
-- "buy with coins"/"equip" requests; the server checks prices and ownership.

local MarketplaceService = game:GetService("MarketplaceService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Types = require(ReplicatedStorage.Shared.Types)
local State = require(script.Parent.Parent.State)
local Kit = require(script.Parent.Kit)

local ShopUI = {}

local SLOT_TITLES =
	{ Entrance = "Runway entrance effects", Walk = "Runway walks", Pose = "Poses (Pose Pack)" }
local PASS_DESCRIPTIONS: { [string]: string } = {
	VIP = "Extra item slots, VIP themes and golden runway lighting",
	PosePack = "3 signature poses for the end of your runway walk",
}

local panel: Frame
local list: ScrollingFrame
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

local order = 0
local function nextOrder(): number
	order += 1
	return order
end

local function header(text: string)
	Kit.label({
		Text = text,
		Size = UDim2.new(1, -8, 0, 34),
		TextColor3 = Kit.Colors.Gold,
		TextXAlignment = Enum.TextXAlignment.Left,
		LayoutOrder = nextOrder(),
		Parent = list,
	})
end

-- One row: name + description on the left, an action button on the right.
local function row(
	title: string,
	description: string,
	buttonText: string,
	color: Color3,
	onClick: (() -> ())?
): TextButton
	local frame = Kit.new("Frame", {
		BackgroundColor3 = Kit.Colors.PanelLight,
		Size = UDim2.new(1, -8, 0, 64),
		LayoutOrder = nextOrder(),
		Parent = list,
	}, { Kit.corner(10) })
	Kit.label({
		Text = title,
		Size = UDim2.new(1, -200, 0, 28),
		Position = UDim2.fromOffset(10, 4),
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = frame,
	})
	Kit.label({
		Text = description,
		Size = UDim2.new(1, -200, 0, 24),
		Position = UDim2.fromOffset(10, 34),
		Font = Kit.BodyFont,
		TextColor3 = Kit.Colors.TextDim,
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = frame,
	})
	return Kit.button({
		Text = buttonText,
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -6, 0.5, 0),
		Size = UDim2.fromOffset(170, 52),
		BackgroundColor3 = color,
		AutoButtonColor = onClick ~= nil,
		Parent = frame,
	}, onClick)
end

local function cosmeticRow(cosmetic: Config.Cosmetic, data: Types.PublicData)
	local owned = data.ownedCosmetics[cosmetic.id] == true
	local equipped = data.equipped[cosmetic.slot] == cosmetic.id
	if owned then
		row(
			cosmetic.displayName,
			if equipped then "Equipped" else "Owned",
			if equipped then "Unequip" else "Equip",
			if equipped then Kit.Colors.Grey else Kit.Colors.Blue,
			function()
				Remotes.Events.EquipCosmetic:FireServer(cosmetic.slot, if equipped then nil else cosmetic.id)
			end
		)
	elseif cosmetic.coinPrice then
		local price = cosmetic.coinPrice
		row(
			cosmetic.displayName,
			"Buy with coins you earn by playing",
			`{price} coins`,
			Kit.Colors.Gold,
			function()
				Remotes.Events.BuyWithCoins:FireServer(cosmetic.id)
			end
		)
	elseif cosmetic.productKey then
		local product = Config.DevProducts[cosmetic.productKey]
		if product.id == 0 then
			row(cosmetic.displayName, "Coming soon", "Soon", Kit.Colors.Grey, nil)
			return
		end
		local button = row(
			cosmetic.displayName,
			"Yours forever",
			`R$ {product.price}`,
			Kit.Colors.Green,
			function()
				MarketplaceService:PromptProductPurchase(State.player, product.id)
			end
		)
		fetchPrice(`p{product.id}`, product.id, Enum.InfoType.Product, function(price)
			button.Text = `R$ {price}`
		end)
	elseif cosmetic.pass then
		local pass = Config.GamePasses[cosmetic.pass]
		row(cosmetic.displayName, `Included with {pass.displayName}`, pass.displayName, Kit.Colors.Grey, nil)
	elseif cosmetic.rank then
		row(cosmetic.displayName, "Free at this style rank", `Rank {cosmetic.rank}`, Kit.Colors.Grey, nil)
	end
end

local function rebuild()
	for _, child in list:GetChildren() do
		if child:IsA("GuiObject") then
			child:Destroy()
		end
	end
	order = 0
	local data = State.data
	if not data then
		header("Loading...")
		return
	end

	header("Passes")
	for key, pass in Config.GamePasses do
		local owned = data.ownedPasses[key] == true
		if pass.id == 0 then
			row(pass.displayName, PASS_DESCRIPTIONS[key] or "", "Soon", Kit.Colors.Grey, nil)
		elseif owned then
			row(pass.displayName, PASS_DESCRIPTIONS[key] or "", "Owned", Kit.Colors.Grey, nil)
		else
			local button = row(
				pass.displayName,
				PASS_DESCRIPTIONS[key] or "",
				`R$ {pass.price}`,
				Kit.Colors.Green,
				function()
					MarketplaceService:PromptGamePassPurchase(State.player, pass.id)
				end
			)
			fetchPrice(`g{pass.id}`, pass.id, Enum.InfoType.GamePass, function(price)
				button.Text = `R$ {price}`
			end)
		end
	end

	header("Lobby moments (everyone sees your name!)")
	for _, product in Config.DevProducts do
		if product.kind ~= "Moment" then
			continue
		end
		if product.id == 0 then
			row(product.displayName, "30 seconds for the whole server", "Soon", Kit.Colors.Grey, nil)
			continue
		end
		local button = row(
			product.displayName,
			"30 seconds for the whole server",
			`R$ {product.price}`,
			Kit.Colors.Green,
			function()
				MarketplaceService:PromptProductPurchase(State.player, product.id)
			end
		)
		fetchPrice(`p{product.id}`, product.id, Enum.InfoType.Product, function(price)
			button.Text = `R$ {price}`
		end)
	end

	for _, slot in { "Entrance", "Walk", "Pose" } do
		local shown = false
		for _, cosmetic in Config.Cosmetics do
			-- Walks/poses need a catalog animation ID before they can be offered.
			if cosmetic.slot ~= slot or (cosmetic.animationId ~= nil and cosmetic.animationId == 0) then
				continue
			end
			if not shown then
				header(SLOT_TITLES[slot])
				shown = true
			end
			cosmeticRow(cosmetic, data)
		end
	end
end

function ShopUI.open()
	rebuild()
	panel.Visible = true
end

function ShopUI.start()
	local _, root = Kit.screen("Shop", 5)
	panel = Kit.panel({
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.new(0.9, 0, 0.9, 0),
		Visible = false,
		Parent = root,
	})
	Kit.label({
		Text = "Shop",
		Size = UDim2.new(1, -140, 0, 40),
		Position = UDim2.fromOffset(12, 8),
		Parent = panel,
	})
	Kit.button({
		Text = "Close",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -8, 0, 8),
		Size = UDim2.fromOffset(110, Kit.ButtonHeight - 8),
		BackgroundColor3 = Kit.Colors.Grey,
		Parent = panel,
	}, function()
		panel.Visible = false
	end)
	list = Kit.new("ScrollingFrame", {
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(8, 60),
		Size = UDim2.new(1, -16, 1, -68),
		CanvasSize = UDim2.new(0, 0, 0, 0),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollingDirection = Enum.ScrollingDirection.Y,
		ScrollBarThickness = 6,
		Parent = panel,
	}, { Kit.list(Enum.FillDirection.Vertical, 6) })

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
end

return ShopUI
