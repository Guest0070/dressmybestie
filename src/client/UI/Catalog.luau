--!strict
-- The styling booth UI: browse the Roblox Marketplace catalog and dress your partner's mannequin.
-- The client only sends the list of picked IDs; the server validates and applies them.

local AvatarEditorService = game:GetService("AvatarEditorService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local DEBUG = RunService:IsStudio()

local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Types = require(ReplicatedStorage.Shared.Types)
local State = require(script.Parent.Parent.State)
local Kit = require(script.Parent.Kit)

local Catalog = {}

-- Set by init.client: rotates the booth camera around the mannequin.
Catalog.onRotate = function(_direction: number) end
-- Set by init.client: opens the "Buy these" panel for the Dressing Room outfit.
Catalog.onBuyOutfit = function(_look: Types.Look) end

type Look = Types.Look
type CatalogItem = { Id: number, Name: string, ItemType: string }
type SearchCache = { items: { CatalogItem }, pages: CatalogPages?, failed: boolean }

local MAX_UNDO = 30

local look: Look = { assetIds = {} }
local undoStack: { Look } = {}
local seq = 0
local currentTarget: number? = nil
local currentCategory: Config.CatalogCategory = Config.CatalogCategories[1]
local searchCache: { [string]: SearchCache } = {}
-- Searches in progress, per tab. Each tab loads on its own, so switching tabs mid-load can
-- never leave one tab showing another tab's items.
local inFlight: { [string]: boolean } = {}

local panel: Frame
local rotateBar: Frame
local selfBar: Frame
-- Dressing Room: the catalog dresses your own avatar instead of a partner's mannequin.
local selfMode = false
local grid: ScrollingFrame
local tabButtons: { [string]: TextButton } = {}
local itemButtons: { [number]: ImageButton } = {}
local wornLabel: TextLabel
local statusLabel: TextLabel
local moreButton: TextButton

local function copyLook(source: Look): Look
	return { assetIds = table.clone(source.assetIds), shoeBundleId = source.shoeBundleId }
end

local function refreshSelection()
	for _, button in itemButtons do
		local item = (button :: any):GetAttribute("ItemId")
		local itemType = (button :: any):GetAttribute("ItemType")
		local worn = if itemType == "Bundle"
			then look.shoeBundleId == item
			else table.find(look.assetIds, item) ~= nil
		local stroke = button:FindFirstChildOfClass("UIStroke")
		if stroke then
			stroke.Color = if worn then Kit.Colors.Gold else Color3.new(0, 0, 0)
			stroke.Thickness = if worn then 4 else 1
		end
		local check = button:FindFirstChild("Check")
		if check and check:IsA("GuiObject") then
			check.Visible = worn
		end
	end
	local count = #look.assetIds + (if look.shoeBundleId then 1 else 0)
	wornLabel.Text = `Wearing {count}`
end

local function sendLook()
	seq += 1
	local payload = { assetIds = look.assetIds, shoeBundleId = look.shoeBundleId, seq = seq }
	if selfMode then
		Remotes.Events.SetOwnLook:FireServer(payload)
	else
		Remotes.Events.SetMannequinLook:FireServer(payload)
	end
	refreshSelection()
end

local function pushUndo()
	table.insert(undoStack, copyLook(look))
	if #undoStack > MAX_UNDO then
		table.remove(undoStack, 1)
	end
end

local function toggleItem(item: CatalogItem)
	if DEBUG then
		print(`[Catalog] Tapped {item.ItemType} {item.Id} ({item.Name})`)
	end
	pushUndo()
	if item.ItemType == "Bundle" then
		look.shoeBundleId = if look.shoeBundleId == item.Id then nil else item.Id
	else
		local index = table.find(look.assetIds, item.Id)
		if index then
			table.remove(look.assetIds, index)
		elseif #look.assetIds < Config.Limits.MaxIdsPerLook then
			table.insert(look.assetIds, item.Id)
		end
	end
	sendLook()
end

local function undo()
	local previous = table.remove(undoStack)
	if previous then
		look = previous
		sendLook()
	end
end

local function clear()
	pushUndo()
	look = { assetIds = {} }
	sendLook()
end

local function colorKeyword(): string?
	local chaos = State.round.chaos
	return if chaos then chaos.colorName else nil
end

local function cacheKey(category: Config.CatalogCategory): string
	return category.id .. "|" .. (colorKeyword() or "")
end

local function makeItemButton(item: CatalogItem, order: number)
	local button = Kit.new("ImageButton", {
		BackgroundColor3 = Kit.Colors.PanelLight,
		Image = if item.ItemType == "Bundle" then Kit.bundleThumb(item.Id) else Kit.assetThumb(item.Id),
		LayoutOrder = order,
		Parent = grid,
	}, {
		Kit.corner(10),
		Kit.new("UIStroke", { Thickness = 1, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }),
	})
	button:SetAttribute("ItemId", item.Id)
	button:SetAttribute("ItemType", item.ItemType)
	Kit.label({
		Name = "Check",
		Text = "ON",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -4, 0, 4),
		Size = UDim2.fromOffset(34, 22),
		BackgroundTransparency = 0,
		BackgroundColor3 = Kit.Colors.Gold,
		TextColor3 = Kit.Colors.Panel,
		Visible = false,
		Parent = button,
	})
	button.Activated:Connect(function()
		Kit.playSound("Click")
		toggleItem(item)
	end)
	itemButtons[item.Id] = button
end

local function renderCategory()
	for _, button in itemButtons do
		button:Destroy()
	end
	itemButtons = {}
	local cache = searchCache[cacheKey(currentCategory)]
	if cache then
		for index, item in cache.items do
			makeItemButton(item, index)
		end
		moreButton.Visible = cache.pages ~= nil and not (cache.pages :: CatalogPages).IsFinished
		statusLabel.Visible = cache.failed or #cache.items == 0
		statusLabel.Text = if cache.failed then "Catalog is busy. Tap the tab to retry." else "Nothing found."
	else
		moreButton.Visible = false
		statusLabel.Visible = true
		statusLabel.Text = "Loading..."
	end
	refreshSelection()
end

local function addPage(cache: SearchCache, page: { any })
	for _, entry in page do
		if type(entry.Id) == "number" then
			table.insert(
				cache.items,
				{ Id = entry.Id, Name = tostring(entry.Name), ItemType = tostring(entry.ItemType) }
			)
		end
	end
end

local function search(category: Config.CatalogCategory)
	local key = cacheKey(category)
	local existing = searchCache[key]
	if (existing and not existing.failed) or inFlight[key] then
		return -- already loaded, or loading (it renders itself when done)
	end
	inFlight[key] = true
	searchCache[key] = nil
	if category == currentCategory then
		renderCategory() -- shows "Loading..."
	end

	local params = CatalogSearchParams.new()
	if category.assetTypes then
		local types = {}
		for _, name in category.assetTypes do
			table.insert(types, (Enum.AvatarAssetType :: any)[name])
		end
		params.AssetTypes = types
	end
	if category.bundleTypes then
		local types = {}
		for _, name in category.bundleTypes do
			table.insert(types, (Enum.BundleType :: any)[name])
		end
		params.BundleTypes = types
	end
	local keyword = colorKeyword()
	if keyword then
		params.SearchKeyword = keyword
	end

	local cache: SearchCache = { items = {}, pages = nil, failed = false }
	local ok, pages = pcall(AvatarEditorService.SearchCatalogAsync, AvatarEditorService, params)
	if ok and pages then
		cache.pages = pages
		addPage(cache, pages:GetCurrentPage())
	else
		warn(`[Catalog] Search failed: {pages}`)
		cache.failed = true
	end
	searchCache[key] = cache
	inFlight[key] = nil
	if category == currentCategory then
		renderCategory()
	end
end

local function loadMore()
	local key = cacheKey(currentCategory)
	local cache = searchCache[key]
	local pages = if cache then cache.pages else nil
	if not cache or not pages or pages.IsFinished or inFlight[key] then
		return
	end
	inFlight[key] = true
	local ok = pcall(pages.AdvanceToNextPageAsync, pages)
	if ok then
		addPage(cache, pages:GetCurrentPage())
	end
	inFlight[key] = nil
	renderCategory()
end

local function selectCategory(category: Config.CatalogCategory)
	currentCategory = category
	for id, button in tabButtons do
		button.BackgroundColor3 = if id == category.id then Kit.Colors.Pink else Kit.Colors.PanelLight
	end
	grid.CanvasPosition = Vector2.zero
	-- Always redraw right away: this tab's items if loaded, otherwise "Loading...".
	renderCategory()
	task.spawn(search, category)
end

local function refreshVisibility()
	if selfMode and not State.canUseLobby() then
		selfMode = false -- a round started: the Dressing Room closes
		State.setDressingRoom(false)
	end
	local stylingTarget = State.myTarget()
	local styling = State.round.phase == "Styling" and stylingTarget ~= nil
	local visible = styling or selfMode
	panel.Visible = visible
	rotateBar.Visible = visible
	selfBar.Visible = selfMode
	local target = if selfMode then State.player.UserId elseif styling then stylingTarget else nil
	if target ~= currentTarget then
		-- New round or a swap: start from an empty look (LookSync fills in a swapped look).
		currentTarget = target
		look = { assetIds = {} }
		undoStack = {}
		seq = 0
		refreshSelection()
	end
	if visible and not searchCache[cacheKey(currentCategory)] then
		selectCategory(currentCategory)
	end
end

local function onLookSync(targetUserId: number, synced: Look, syncSeq: number?)
	if DEBUG and type(synced) == "table" and type(synced.assetIds) == "table" then
		print(`[Catalog] Server accepted {#synced.assetIds} item(s) (seq {syncSeq}, mine {seq})`)
	end
	if type(synced) ~= "table" or type(synced.assetIds) ~= "table" then
		return
	end
	-- seq == nil: the server is handing us a look (swap). Otherwise only trust the reply to our
	-- newest edit, so a slow reply can't undo a newer pick. Items the server rejected disappear.
	if syncSeq == nil or (targetUserId == currentTarget and syncSeq == seq) then
		currentTarget = targetUserId
		look = copyLook(synced)
		if syncSeq == nil then
			undoStack = {}
		end
		refreshSelection()
	end
end

function Catalog.openDressingRoom()
	if not State.canUseLobby() or selfMode then
		return
	end
	selfMode = true
	State.setDressingRoom(true)
	refreshVisibility()
end

function Catalog.closeDressingRoom()
	if not selfMode then
		return
	end
	selfMode = false
	State.setDressingRoom(false)
	refreshVisibility()
end

function Catalog.start()
	local _, root = Kit.screen("Catalog", 2)

	panel = Kit.panel({
		Name = "CatalogPanel",
		Position = UDim2.new(0.5, 0, 0, 8),
		Size = UDim2.new(0.5, -8, 1, -16),
		Visible = false,
		Parent = root,
	})

	-- Category tabs (scroll sideways)
	local tabs = Kit.new("ScrollingFrame", {
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(8, 8),
		Size = UDim2.new(1, -16, 0, 52),
		CanvasSize = UDim2.new(0, 0, 0, 0),
		AutomaticCanvasSize = Enum.AutomaticSize.X,
		ScrollingDirection = Enum.ScrollingDirection.X,
		ScrollBarThickness = 4,
		Parent = panel,
	}, { Kit.list(Enum.FillDirection.Horizontal, 6) })
	for index, category in Config.CatalogCategories do
		tabButtons[category.id] = Kit.button({
			Text = category.id,
			Size = UDim2.fromOffset(104, 44),
			BackgroundColor3 = Kit.Colors.PanelLight,
			LayoutOrder = index,
			MaxTextSize = 20,
			Parent = tabs,
		}, function()
			selectCategory(category)
		end)
	end

	-- Item grid
	grid = Kit.new("ScrollingFrame", {
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(8, 66),
		Size = UDim2.new(1, -16, 1, -66 - Kit.ButtonHeight - 16),
		CanvasSize = UDim2.new(0, 0, 0, 0),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollingDirection = Enum.ScrollingDirection.Y,
		ScrollBarThickness = 6,
		Parent = panel,
	}, {
		Kit.new("UIGridLayout", {
			CellSize = UDim2.fromOffset(92, 92),
			CellPadding = UDim2.fromOffset(8, 8),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	})
	moreButton = Kit.button({
		Text = "More",
		LayoutOrder = 1e6,
		BackgroundColor3 = Kit.Colors.Blue,
		Visible = false,
		Parent = grid,
	}, function()
		task.spawn(loadMore)
	end)
	statusLabel = Kit.label({
		Position = UDim2.fromOffset(8, 120),
		Size = UDim2.new(1, -16, 0, 40),
		Font = Kit.BodyFont,
		TextColor3 = Kit.Colors.TextDim,
		Visible = false,
		Parent = panel,
	})

	-- Bottom row: undo / clear / count
	local bottom = Kit.new("Frame", {
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, 8, 1, -8),
		Size = UDim2.new(1, -16, 0, Kit.ButtonHeight),
		Parent = panel,
	}, { Kit.list(Enum.FillDirection.Horizontal, 8) })
	Kit.button({
		Text = "Undo",
		Size = UDim2.fromOffset(110, Kit.ButtonHeight),
		BackgroundColor3 = Kit.Colors.Blue,
		LayoutOrder = 1,
		Parent = bottom,
	}, undo)
	Kit.button({
		Text = "Clear",
		Size = UDim2.fromOffset(110, Kit.ButtonHeight),
		BackgroundColor3 = Kit.Colors.Grey,
		LayoutOrder = 2,
		Parent = bottom,
	}, clear)
	wornLabel =
		Kit.label({ Size = UDim2.fromOffset(140, 40), LayoutOrder = 3, Font = Kit.BodyFont, Parent = bottom })

	-- Rotate the mannequin view (bottom-left, over the 3D view)
	rotateBar = Kit.new("Frame", {
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, 8, 1, -8),
		Size = UDim2.fromOffset(2 * 72 + 8, Kit.ButtonHeight),
		Visible = false,
		Parent = root,
	}, { Kit.list(Enum.FillDirection.Horizontal, 8) })
	Kit.button(
		{ Text = "<", Size = UDim2.fromOffset(72, Kit.ButtonHeight), LayoutOrder = 1, Parent = rotateBar },
		function()
			Catalog.onRotate(-1)
		end
	)
	Kit.button(
		{ Text = ">", Size = UDim2.fromOffset(72, Kit.ButtonHeight), LayoutOrder = 2, Parent = rotateBar },
		function()
			Catalog.onRotate(1)
		end
	)

	-- Dressing Room buttons (above the rotate buttons).
	selfBar = Kit.new("Frame", {
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, 8, 1, -16 - Kit.ButtonHeight),
		Size = UDim2.fromOffset(3 * 120 + 16, Kit.ButtonHeight),
		Visible = false,
		Parent = root,
	}, { Kit.list(Enum.FillDirection.Horizontal, 8) })
	Kit.button({
		Text = "Done",
		Size = UDim2.fromOffset(120, Kit.ButtonHeight),
		BackgroundColor3 = Kit.Colors.Green,
		LayoutOrder = 1,
		Parent = selfBar,
	}, Catalog.closeDressingRoom)
	Kit.button({
		Text = "Reset me",
		Size = UDim2.fromOffset(120, Kit.ButtonHeight),
		BackgroundColor3 = Kit.Colors.Grey,
		LayoutOrder = 2,
		Parent = selfBar,
	}, function()
		pushUndo()
		look = { assetIds = {} }
		refreshSelection()
		Remotes.Events.ResetOwnLook:FireServer()
	end)
	Kit.button({
		Text = "Buy these",
		Size = UDim2.fromOffset(120, Kit.ButtonHeight),
		BackgroundColor3 = Kit.Colors.Gold,
		LayoutOrder = 3,
		Parent = selfBar,
	}, function()
		Catalog.onBuyOutfit(copyLook(look))
	end)

	selectCategory(currentCategory)
	State.RoundChanged:Connect(refreshVisibility)
	Remotes.Events.LookSync.OnClientEvent:Connect(onLookSync)
	refreshVisibility()
end

return Catalog
