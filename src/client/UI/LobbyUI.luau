--!strict
-- Lobby screen (premium-fashion style, see Theme.luau):
--   * Top bar: Coins, Style XP (with progress to next rank), Settings. Lobby only (the round timer
--     takes its place during a round). Starts right of Roblox's chat window.
--   * Round status strip (in the top bar, lobby only): round number, what's happening, live timer
--     or players ready. Kept out of the middle so the avatar stays visible.
--   * Actions (bottom centre): JOIN RANDOM, SPECTATE, CUSTOMIZE.
--   * Side columns: Shop, Quests, Daily reward, Buy looks, Admin / Games, Invite, How to play.
--
-- Want to design it yourself? Put a ScreenGui named "LobbyUI" in StarterGui (copy the built one
-- during Play, see README). This script then wires that one instead of building its own: it finds
-- each piece by Name (TopBar, Lobby, RoundStatus > Headline/Value, Coins/StyleXP > Value, Settings,
-- JoinRandom, Spectate, Customize, Shop, Quests > Badge, Daily, BuyLooks, Admin, Invite, HowToPlay;
-- optional Coins > BuyCoins opens the coin packs, optional Games opens the minigames panel).
--
-- JOIN RANDOM does not matchmake (not built yet). It opts you into the next round in this server,
-- the same thing as turning spectating off. Everything shown comes from State; nothing is faked.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local SocialService = game:GetService("SocialService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Types = require(ReplicatedStorage.Shared.Types)
local State = require(script.Parent.Parent.State)
local Components = require(script.Parent.Components)
local Kit = require(script.Parent.Kit)
local Theme = require(script.Parent.Theme)

local LobbyUI = {}

-- Hooks plugged in by init.client.
LobbyUI.onOpenShop = function(_tab: string?) end
LobbyUI.onOpenGames = function() end
LobbyUI.onOpenQuests = function() end
LobbyUI.onOpenLooks = function() end
LobbyUI.onOpenHelp = function() end
LobbyUI.onOpenAdmin = function() end
LobbyUI.onOpenSettings = function() end
LobbyUI.onCustomize = function() end
LobbyUI.onToast = function(_text: string) end
LobbyUI.hasClaimableQuest = function(_data: Types.PublicData): boolean
	return false
end

local topBar: GuiObject
local lobbyContent: GuiObject
local coinsPill: Components.PillHandle
local xpPill: Components.PillHandle

local headline: TextLabel
local bigValue: TextLabel
local statusPanel: GuiObject
local valueColor = Theme.Colors.Primary -- the status number colour (taken from the design)

local joinButton: Components.ButtonHandle
local spectateButton: Components.ButtonHandle
local dailyButton: Components.ButtonHandle
local looksButton: Components.ButtonHandle
local adminButton: Components.ButtonHandle
local questsBadge: GuiObject

local lastCoins: number? = nil

local function isSpectating(player: Player): boolean
	return player:GetAttribute("Spectating") == true
end

local function playersNeeded(): number
	return if RunService:IsStudio() then Config.StudioMinPlayers else Config.MinPlayersToStart
end

local function readyCount(): number
	local count = 0
	for _, player in Players:GetPlayers() do
		if not isSpectating(player) then
			count += 1
		end
	end
	return count
end

local function formatNumber(n: number): string
	local s = tostring(math.floor(n))
	local formatted = s:reverse():gsub("(%d%d%d)", "%1,"):reverse()
	return (formatted:gsub("^,", ""))
end

local function setText(label: TextLabel, text: string)
	if label.Text ~= text then
		label.Text = text
	end
end

---------------------------------------------------------------------------------------------------
-- Live state
---------------------------------------------------------------------------------------------------

local function refreshVisibility()
	local lobby = State.canUseLobby() and not State.dressingRoom
	-- While you're playing a minigame the buttons step aside (the game's banner takes over).
	local inMinigame = false
	for _, minigame in State.minigames do
		if
			(minigame.phase == "Playing" or minigame.phase == "Countdown")
			and table.find(minigame.players, State.player.UserId)
		then
			inMinigame = true
		end
	end
	lobbyContent.Visible = lobby and not inMinigame
	statusPanel.Visible = lobby
	-- Coins / XP / status share the top of the screen with the round timer (HUD): show one or the
	-- other, never both.
	topBar.Visible = lobby
end

local function refreshSpectating()
	local spectating = isSpectating(State.player)
	if spectating then
		joinButton:setText("JOIN RANDOM")
		joinButton:setState("Normal")
		spectateButton:setText("SPECTATING")
		spectateButton:setState("Active")
	else
		joinButton:setText("JOINED ✓")
		joinButton:setState("Active")
		spectateButton:setText("SPECTATE")
		spectateButton:setState("Normal")
	end
end

-- Status panel text. Called on round changes and ~5x a second for the timer.
local function refreshStatus()
	local round = State.round
	local now = Workspace:GetServerTimeNow()
	local remaining = if round.endsAt then math.max(0, round.endsAt - now) else nil
	local inLobby = round.phase == "Lobby"

	local roundText = `ROUND {if inLobby then round.roundNumber + 1 else round.roundNumber}  ·  `
	if inLobby and remaining then
		setText(headline, roundText .. "STARTS IN")
		setText(bigValue, Kit.formatTime(remaining))
	elseif inLobby then
		setText(headline, roundText .. "NEED PLAYERS")
		setText(bigValue, `{readyCount()} / {playersNeeded()}`)
	else
		setText(headline, roundText .. "IN PROGRESS")
		setText(bigValue, if remaining then Kit.formatTime(remaining) else "--:--")
	end
	-- Last 10 seconds of a countdown flash red.
	local urgent = remaining ~= nil
		and remaining <= 10
		and remaining > 0
		and math.floor(remaining * 2) % 2 == 0
	bigValue.TextColor3 = if urgent then Theme.Colors.Danger else valueColor
end

local function coinPop(amount: number)
	local pill = coinsPill.instance
	local pop = Components.text({
		Text = `+{formatNumber(amount)}`,
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 1, 2),
		Size = UDim2.fromScale(0.8, 0.8),
		FontFace = Theme.Fonts.Heading,
		TextColor3 = Theme.Colors.Gold,
		MaxTextSize = 24,
		ZIndex = 5,
		Parent = pill,
	})
	local tween =
		TweenService:Create(pop, TweenInfo.new(1.1, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			Position = UDim2.new(0.5, 0, 1, 34),
			TextTransparency = 1,
		})
	tween:Play()
	tween.Completed:Once(function()
		pop:Destroy()
	end)
end

local function refreshData(data: Types.PublicData)
	if lastCoins and data.coins > lastCoins and topBar.Visible then
		coinPop(data.coins - lastCoins)
	end
	lastCoins = data.coins
	coinsPill:setValue(formatNumber(data.coins))

	local floor = Config.RankXp[data.rank] or 0
	local nextXp = Config.RankXp[data.rank + 1]
	if nextXp then
		xpPill:setValue(`LV {data.rank}  {formatNumber(data.styleXp)}/{formatNumber(nextXp)}`)
		xpPill:setProgress((data.styleXp - floor) / math.max(1, nextXp - floor))
	else
		xpPill:setValue(`LV {data.rank}  MAX`)
		xpPill:setProgress(1)
	end

	dailyButton.instance.Visible = data.canClaimDaily
	dailyButton:setText(`🎁 DAILY +{data.nextDailyReward}`)
	questsBadge.Visible = LobbyUI.hasClaimableQuest(data)
	adminButton.instance.Visible = data.isAdmin
end

---------------------------------------------------------------------------------------------------
-- Build (only used when there's no Studio-designed StarterGui.LobbyUI). Creates instances only;
-- wire() below finds them by name and makes them work, exactly as it does for a designed one.
---------------------------------------------------------------------------------------------------

local function buildTopBar(root: ScreenGui)
	local bar = Instance.new("Frame")
	bar.Name = "TopBar"
	bar.BackgroundTransparency = 1
	-- Starts right of Roblox's chat window (top-left, about 30% wide) so the two never overlap.
	bar.Position = UDim2.new(0.31, 12, 0, 8)
	bar.Size = UDim2.new(0.69, -24, 0.08, 0)
	bar.Parent = root
	Components.sizeLimit(Vector2.new(0, Theme.MinTouch), Vector2.new(math.huge, 44)).Parent = bar

	local stats = Instance.new("Frame")
	stats.Name = "Stats"
	stats.BackgroundTransparency = 1
	stats.Size = UDim2.new(1, -56, 1, 0) -- leave room for the settings button
	stats.Parent = bar
	Components.list(Enum.FillDirection.Horizontal, 8, Enum.HorizontalAlignment.Left).Parent = stats

	local coins = Components.styleStatPill({
		Name = "Coins",
		Glyph = "C",
		IconColor = Theme.Colors.Gold,
		Size = UDim2.fromScale(1, 1),
		LayoutOrder = 1,
		Parent = stats,
	})
	Kit.new("UIAspectRatioConstraint", {
		AspectRatio = 3.8,
		DominantAxis = Enum.DominantAxis.Height,
		Parent = coins,
	})
	-- "+" on the coins pill opens the coin packs.
	local coinsValue = coins:FindFirstChild("Value") :: TextLabel
	coinsValue.Size = UDim2.new(0.7, -40, 0.6, 0)
	local buyCoins = Components.styleButton({
		Name = "BuyCoins",
		Text = "+",
		Variant = "Primary",
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -4, 0.5, 0),
		Size = UDim2.fromScale(0.75, 0.75),
		MaxTextSize = 18,
		Parent = coins,
	})
	buyCoins.SizeConstraint = Enum.SizeConstraint.RelativeYY
	local xp = Components.styleStatPill({
		Name = "StyleXP",
		Glyph = "XP",
		IconColor = Theme.Colors.Primary,
		HasProgress = true,
		Size = UDim2.fromScale(1, 1),
		LayoutOrder = 2,
		Parent = stats,
	})
	Kit.new("UIAspectRatioConstraint", {
		AspectRatio = 4.4,
		DominantAxis = Enum.DominantAxis.Height,
		Parent = xp,
	})

	-- Round status lives in the top bar so the middle of the screen stays clear for the avatar.
	-- It takes whatever width is left (UIFlexItem Fill), capped on wide screens.
	local status = Components.panel({
		Name = "RoundStatus",
		Size = UDim2.fromScale(0, 1),
		LayoutOrder = 3,
		Parent = stats,
	})
	Kit.new("UIFlexItem", { FlexMode = Enum.UIFlexMode.Fill, Parent = status })
	Components.sizeLimit(Vector2.new(140, 0), Vector2.new(420, math.huge)).Parent = status
	Kit.new("Frame", {
		Name = "Accent",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.fromScale(0.5, 0),
		Size = UDim2.new(0.4, 0, 0, 3),
		BackgroundColor3 = Theme.Colors.Primary,
		BorderSizePixel = 0,
		Parent = status,
	}, { Components.corner(2) })
	local row = Kit.new("Frame", {
		Name = "Content",
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		Parent = status,
	}, { Components.padding(4, 12), Components.list(Enum.FillDirection.Horizontal, 8) :: Instance })
	local head = Components.text({
		Name = "Headline",
		Size = UDim2.fromScale(0, 0.6),
		FontFace = Theme.Fonts.Heading,
		TextXAlignment = Enum.TextXAlignment.Left,
		MaxTextSize = 14,
		LayoutOrder = 1,
		Parent = row,
	})
	Kit.new("UIFlexItem", { FlexMode = Enum.UIFlexMode.Fill, Parent = head })
	local value = Components.text({
		Name = "Value",
		Size = UDim2.fromScale(1, 0.9),
		FontFace = Theme.Fonts.Heading,
		TextColor3 = Theme.Colors.Primary,
		TextXAlignment = Enum.TextXAlignment.Right,
		MaxTextSize = 24,
		LayoutOrder = 2,
		Parent = row,
	})
	Kit.new("UIAspectRatioConstraint", {
		AspectRatio = 2.4,
		DominantAxis = Enum.DominantAxis.Height,
		Parent = value,
	})

	local settings = Components.styleButton({
		Name = "Settings",
		Text = "⚙",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.fromScale(1, 0),
		Size = UDim2.fromScale(1, 1),
		MaxTextSize = 18,
		Parent = bar,
	})
	Kit.new("UIAspectRatioConstraint", {
		AspectRatio = 1,
		DominantAxis = Enum.DominantAxis.Height,
		Parent = settings,
	})
end

local function buildActions(content: Frame)
	local actions = Instance.new("Frame")
	actions.Name = "Actions"
	actions.BackgroundTransparency = 1
	actions.AnchorPoint = Vector2.new(0.5, 1)
	actions.Position = UDim2.new(0.5, 0, 1, -12)
	actions.Size = UDim2.fromScale(0.18, 0.17)
	actions.Parent = content
	Components.sizeLimit(Vector2.new(180, 72), Vector2.new(240, 96)).Parent = actions
	Components.list(Enum.FillDirection.Vertical, 8).Parent = actions

	Components.styleButton({
		Name = "JoinRandom",
		Text = "JOIN RANDOM",
		Variant = "Primary",
		Size = UDim2.fromScale(1, 0.56),
		MaxTextSize = 24,
		LayoutOrder = 1,
		Parent = actions,
	})
	local row = Instance.new("Frame")
	row.Name = "Secondary"
	row.BackgroundTransparency = 1
	row.Size = UDim2.new(1, 0, 0.44, -8)
	row.LayoutOrder = 2
	row.Parent = actions
	local rowList = Components.list(Enum.FillDirection.Horizontal, 8)
	rowList.HorizontalFlex = Enum.UIFlexAlignment.Fill -- both buttons share the width
	rowList.Parent = row
	Components.styleButton({
		Name = "Spectate",
		Text = "SPECTATE",
		Size = UDim2.fromScale(0, 1),
		LayoutOrder = 1,
		Parent = row,
	})
	Components.styleButton({
		Name = "Customize",
		Text = "CUSTOMIZE",
		Size = UDim2.fromScale(0, 1),
		LayoutOrder = 2,
		Parent = row,
	})
end

local function sideColumn(content: Frame, name: string, anchorX: number): Frame
	local column = Instance.new("Frame")
	column.Name = name
	column.BackgroundTransparency = 1
	column.AnchorPoint = Vector2.new(anchorX, 0.5)
	column.Position = UDim2.new(anchorX, if anchorX == 0 then 12 else -12, 0.56, 0)
	column.Size = UDim2.fromScale(0.1, 0.46)
	column.Parent = content
	Components.sizeLimit(Vector2.new(96, 0), Vector2.new(128, math.huge)).Parent = column
	Components.list(
		Enum.FillDirection.Vertical,
		6,
		if anchorX == 0 then Enum.HorizontalAlignment.Left else Enum.HorizontalAlignment.Right
	).Parent =
		column
	return column
end

local function sideButton(
	column: Frame,
	order: number,
	name: string,
	text: string,
	variant: string?,
	visible: boolean?
): TextButton
	return Components.styleButton({
		Name = name,
		Text = text,
		Variant = variant,
		Size = UDim2.fromScale(1, 0.15),
		MaxTextSize = if (utf8.len(text) or #text) > 12 then 12 else 14,
		LayoutOrder = order,
		Visible = visible ~= false,
		Parent = column,
	})
end

local function buildSideColumns(content: Frame)
	local left = sideColumn(content, "Left", 0)
	sideButton(left, 1, "Shop", "🛍️ SHOP", "Special")
	local quests = sideButton(left, 2, "Quests", "📜 QUESTS")
	Kit.new("Frame", {
		Name = "Badge",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(1, -4, 0, 4),
		Size = UDim2.fromOffset(14, 14),
		BackgroundColor3 = Theme.Colors.Danger,
		BorderSizePixel = 0,
		Visible = false,
		ZIndex = 3,
		Parent = quests,
	}, { Components.corner(999), Components.stroke(Theme.Colors.Background, 2) })
	-- Outline style: JOIN RANDOM stays the one filled button.
	sideButton(left, 3, "Daily", "🎁 DAILY", "Special", false)
	sideButton(left, 4, "BuyLooks", "👗 BUY LOOKS", nil, false)
	sideButton(left, 5, "Admin", "🛠️ ADMIN", nil, false)

	local right = sideColumn(content, "Right", 1)
	sideButton(right, 1, "Games", "🏆 GAMES", "Special")
	sideButton(right, 2, "Invite", "💌 INVITE")
	sideButton(right, 3, "HowToPlay", "❓ HOW TO PLAY")
end

local function build(): ScreenGui
	local root = Components.screen("LobbyUI", 1)
	local content = Instance.new("Frame")
	content.Name = "Lobby"
	content.BackgroundTransparency = 1
	content.Size = UDim2.fromScale(1, 1)
	content.Parent = root
	buildTopBar(root)
	buildActions(content)
	buildSideColumns(content)
	return root
end

---------------------------------------------------------------------------------------------------
-- Wire: find every piece by Name (anywhere under the ScreenGui) and make it work. Returns the
-- names it couldn't find; an empty list means success.
---------------------------------------------------------------------------------------------------

local function wire(root: ScreenGui): { string }
	local missing: { string } = {}
	local find = Components.finder(missing)

	topBar = find(root, "TopBar", "GuiObject")
	lobbyContent = find(root, "Lobby", "GuiObject")
	statusPanel = find(root, "RoundStatus", "GuiObject")
	local coins = find(root, "Coins", "Frame")
	local xp = find(root, "StyleXP", "Frame")
	local buttons = {
		settings = find(root, "Settings", "TextButton"),
		join = find(root, "JoinRandom", "TextButton"),
		spectate = find(root, "Spectate", "TextButton"),
		customize = find(root, "Customize", "TextButton"),
		shop = find(root, "Shop", "TextButton"),
		quests = find(root, "Quests", "TextButton"),
		daily = find(root, "Daily", "TextButton"),
		looks = find(root, "BuyLooks", "TextButton"),
		admin = find(root, "Admin", "TextButton"),
		invite = find(root, "Invite", "TextButton"),
		help = find(root, "HowToPlay", "TextButton"),
	}
	if statusPanel then
		headline = find(statusPanel, "Headline", "TextLabel")
		bigValue = find(statusPanel, "Value", "TextLabel")
	end
	if buttons.quests then
		questsBadge = find(buttons.quests, "Badge", "GuiObject")
	end
	local coinsHandle = if coins then Components.attachStatPill(coins) else nil
	local xpHandle = if xp then Components.attachStatPill(xp) else nil
	if coins and not coinsHandle then
		table.insert(missing, "Coins > Value (TextLabel)")
	end
	if xp and not xpHandle then
		table.insert(missing, "StyleXP > Value (TextLabel)")
	end
	if #missing > 0 or not coinsHandle or not xpHandle then
		return missing
	end
	coinsPill = coinsHandle
	xpPill = xpHandle
	valueColor = bigValue.TextColor3

	Components.attachButton(buttons.settings, function()
		LobbyUI.onOpenSettings()
	end)
	joinButton = Components.attachButton(buttons.join, function()
		-- Opt into the next round (no matchmaking yet). Already in: nothing to do.
		if isSpectating(State.player) then
			Remotes.Events.SetSpectating:FireServer(false)
		end
	end)
	spectateButton = Components.attachButton(buttons.spectate, function()
		Remotes.Events.SetSpectating:FireServer(not isSpectating(State.player))
	end)
	Components.attachButton(buttons.customize, function()
		LobbyUI.onCustomize()
	end)
	Components.attachButton(buttons.shop, function()
		LobbyUI.onOpenShop()
	end)
	-- Optional (a Studio-designed LobbyUI may not have it): the minigames panel.
	local games = root:FindFirstChild("Games", true)
	if games and games:IsA("TextButton") then
		Components.attachButton(games, function()
			LobbyUI.onOpenGames()
		end)
	end
	-- Optional (a Studio-designed LobbyUI may not have it): opens the shop on the coin packs.
	local buyCoins = coins:FindFirstChild("BuyCoins", true)
	if buyCoins and buyCoins:IsA("TextButton") then
		Components.attachButton(buyCoins, function()
			LobbyUI.onOpenShop("Coins")
		end)
	end
	Components.attachButton(buttons.quests, function()
		LobbyUI.onOpenQuests()
	end)
	dailyButton = Components.attachButton(buttons.daily, function()
		Remotes.Events.ClaimDailyReward:FireServer()
	end)
	looksButton = Components.attachButton(buttons.looks, function()
		LobbyUI.onOpenLooks()
	end)
	adminButton = Components.attachButton(buttons.admin, function()
		LobbyUI.onOpenAdmin()
	end)
	Components.attachButton(buttons.invite, function()
		local player = State.player
		local ok, canInvite = pcall(SocialService.CanSendGameInviteAsync, SocialService, player)
		if ok and canInvite then
			pcall(SocialService.PromptGameInvite, SocialService, player)
		else
			LobbyUI.onToast("Invites aren't available right now.")
		end
	end)
	Components.attachButton(buttons.help, function()
		LobbyUI.onOpenHelp()
	end)
	return missing
end

function LobbyUI.start()
	Components.designable("LobbyUI", build, wire)

	State.RoundChanged:Connect(function(round)
		refreshVisibility()
		refreshStatus()
		looksButton.instance.Visible = round.phase == "Lobby" and #State.lastShopLooks > 0
	end)
	State.DressingRoomChanged:Connect(refreshVisibility)
	State.MinigameChanged:Connect(refreshVisibility)
	State.DataChanged:Connect(refreshData)
	State.player:GetAttributeChangedSignal("Spectating"):Connect(function()
		refreshSpectating()
		refreshStatus()
	end)

	-- Timer + ready count tick locally (cheap: text only changes when it differs).
	local accumulator = 0
	RunService.Heartbeat:Connect(function(dt)
		accumulator += dt
		if accumulator >= 0.2 and lobbyContent.Visible then
			accumulator = 0
			refreshStatus()
		end
	end)

	refreshVisibility()
	refreshSpectating()
	refreshStatus()
	if State.data then
		refreshData(State.data)
	end
end

return LobbyUI
