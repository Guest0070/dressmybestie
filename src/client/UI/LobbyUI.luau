--!strict
-- Lobby screen (premium-fashion style, see Theme.luau):
--   * Top bar: Coins, Style XP (with progress to next rank), Settings. Visible except while styling.
--   * Round status panel (top centre): round number, what's happening, live timer, who's in.
--   * Actions (bottom centre): JOIN RANDOM, SPECTATE, CUSTOMIZE.
--   * Side columns: Shop, Quests, Daily reward, Buy looks, Admin / Invite, How to play.
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
LobbyUI.onOpenShop = function() end
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

local gui: ScreenGui
local topBar: Frame
local lobbyContent: Frame
local coinsPill: Components.PillHandle
local xpPill: Components.PillHandle

local headline: TextLabel
local bigValue: TextLabel
local footer: TextLabel

local joinButton: Components.ButtonHandle
local spectateButton: Components.ButtonHandle
local dailyButton: Components.ButtonHandle
local looksButton: Components.ButtonHandle
local adminButton: Components.ButtonHandle
local questsBadge: Frame

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
	local styling = (State.round.phase == "Styling" and State.myTarget() ~= nil) or State.dressingRoom
	topBar.Visible = not styling
	lobbyContent.Visible = State.canUseLobby() and not State.dressingRoom
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
	local spectating = isSpectating(State.player)
	local inLobby = round.phase == "Lobby"

	local roundText = `ROUND {if inLobby then round.roundNumber + 1 else round.roundNumber}  ·  `
	if inLobby and remaining then
		setText(headline, roundText .. "STARTS IN")
		setText(bigValue, Kit.formatTime(remaining))
	elseif inLobby then
		setText(headline, roundText .. "WAITING FOR PLAYERS")
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
	bigValue.TextColor3 = if urgent then Theme.Colors.Danger else Theme.Colors.Primary

	local line
	if spectating then
		line = "You're spectating  ·  tap JOIN RANDOM to play"
	elseif not inLobby then
		line = if round.theme then `Theme: {round.theme}  ·  you join next round` else "You join next round"
	else
		line = `{readyCount()} ready  ·  you're in the next round`
	end
	setText(footer, line)
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
	dailyButton:setText(`DAILY +{data.nextDailyReward}`)
	questsBadge.Visible = LobbyUI.hasClaimableQuest(data)
	adminButton.instance.Visible = data.isAdmin
end

---------------------------------------------------------------------------------------------------
-- Build
---------------------------------------------------------------------------------------------------

local function buildTopBar()
	topBar = Instance.new("Frame")
	topBar.Name = "TopBar"
	topBar.BackgroundTransparency = 1
	topBar.Position = UDim2.fromOffset(12, 8)
	topBar.Size = UDim2.new(1, -24, 0.1, 0)
	topBar.Parent = gui
	Components.sizeLimit(Vector2.new(0, Theme.MinTouch), Vector2.new(math.huge, 56)).Parent = topBar

	local stats = Instance.new("Frame")
	stats.Name = "Stats"
	stats.BackgroundTransparency = 1
	stats.Size = UDim2.fromScale(0.8, 1)
	stats.Parent = topBar
	Components.list(Enum.FillDirection.Horizontal, 10, Enum.HorizontalAlignment.Left).Parent = stats

	coinsPill = Components.statPill({
		Name = "Coins",
		Glyph = "C",
		IconColor = Theme.Colors.Gold,
		Size = UDim2.fromScale(1, 1),
		LayoutOrder = 1,
		Parent = stats,
	})
	Kit.new("UIAspectRatioConstraint", {
		AspectRatio = 3.2,
		DominantAxis = Enum.DominantAxis.Height,
		Parent = coinsPill.instance,
	})
	xpPill = Components.statPill({
		Name = "StyleXP",
		Glyph = "XP",
		IconColor = Theme.Colors.Primary,
		Size = UDim2.fromScale(1, 1),
		LayoutOrder = 2,
		Parent = stats,
	})
	Kit.new("UIAspectRatioConstraint", {
		AspectRatio = 4.4,
		DominantAxis = Enum.DominantAxis.Height,
		Parent = xpPill.instance,
	})

	local settings = Components.button({
		Name = "Settings",
		Text = "⚙",
		Variant = "Secondary",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.fromScale(1, 0),
		Size = UDim2.fromScale(1, 1),
		MaxTextSize = 28,
		Parent = topBar,
		onClick = function()
			LobbyUI.onOpenSettings()
		end,
	})
	Kit.new("UIAspectRatioConstraint", {
		AspectRatio = 1,
		DominantAxis = Enum.DominantAxis.Height,
		Parent = settings.instance,
	})
end

local function buildStatusPanel()
	local panel = Components.panel({
		Name = "RoundStatus",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 72), -- just under the top bar (max 56 tall + 8 + gap)
		Size = UDim2.fromScale(0.32, 0.22),
		Parent = lobbyContent,
	})
	Components.sizeLimit(Vector2.new(260, 96), Vector2.new(440, 150)).Parent = panel
	-- Cyan accent line along the top edge.
	Kit.new("Frame", {
		Name = "Accent",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.fromScale(0.5, 0),
		Size = UDim2.new(0.4, 0, 0, 3),
		BackgroundColor3 = Theme.Colors.Primary,
		BorderSizePixel = 0,
		Parent = panel,
	}, { Components.corner(2) })
	local content = Kit.new("Frame", {
		Name = "Content",
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		Parent = panel,
	}, { Components.padding(10, 16), Components.list(Enum.FillDirection.Vertical, 2) :: Instance })

	headline = Components.text({
		Name = "Headline",
		Size = UDim2.fromScale(1, 0.28),
		FontFace = Theme.Fonts.Heading,
		MaxTextSize = 24,
		LayoutOrder = 2,
		Parent = content,
	})
	bigValue = Components.text({
		Name = "Value",
		Size = UDim2.fromScale(1, 0.44),
		FontFace = Theme.Fonts.Heading,
		TextColor3 = Theme.Colors.Primary,
		MaxTextSize = 48,
		LayoutOrder = 3,
		Parent = content,
	})
	footer = Components.text({
		Name = "Footer",
		Size = UDim2.fromScale(1, 0.2),
		TextColor3 = Theme.Colors.Muted,
		MaxTextSize = 16,
		LayoutOrder = 4,
		Parent = content,
	})
end

local function buildActions()
	local actions = Instance.new("Frame")
	actions.Name = "Actions"
	actions.BackgroundTransparency = 1
	actions.AnchorPoint = Vector2.new(0.5, 1)
	actions.Position = UDim2.new(0.5, 0, 1, -12)
	actions.Size = UDim2.fromScale(0.3, 0.26)
	actions.Parent = lobbyContent
	Components.sizeLimit(Vector2.new(260, 104), Vector2.new(420, 160)).Parent = actions
	Components.list(Enum.FillDirection.Vertical, 8).Parent = actions

	joinButton = Components.button({
		Name = "JoinRandom",
		Text = "JOIN RANDOM",
		Variant = "Primary",
		Size = UDim2.fromScale(1, 0.56),
		MaxTextSize = 34,
		LayoutOrder = 1,
		Parent = actions,
		onClick = function()
			-- Opt into the next round (no matchmaking yet). Already in: nothing to do.
			if isSpectating(State.player) then
				Remotes.Events.SetSpectating:FireServer(false)
			end
		end,
	})

	local row = Instance.new("Frame")
	row.Name = "Secondary"
	row.BackgroundTransparency = 1
	row.Size = UDim2.new(1, 0, 0.44, -8)
	row.LayoutOrder = 2
	row.Parent = actions
	local rowList = Components.list(Enum.FillDirection.Horizontal, 10)
	rowList.HorizontalFlex = Enum.UIFlexAlignment.Fill -- both buttons share the width
	rowList.Parent = row

	spectateButton = Components.button({
		Name = "Spectate",
		Text = "SPECTATE",
		Variant = "Secondary",
		Size = UDim2.fromScale(0, 1),
		LayoutOrder = 1,
		Parent = row,
		onClick = function()
			Remotes.Events.SetSpectating:FireServer(not isSpectating(State.player))
		end,
	})
	Components.button({
		Name = "Customize",
		Text = "CUSTOMIZE",
		Variant = "Secondary",
		Size = UDim2.fromScale(0, 1),
		LayoutOrder = 2,
		Parent = row,
		onClick = function()
			LobbyUI.onCustomize()
		end,
	})
end

local function sideColumn(name: string, anchorX: number): Frame
	local column = Instance.new("Frame")
	column.Name = name
	column.BackgroundTransparency = 1
	column.AnchorPoint = Vector2.new(anchorX, 0.5)
	column.Position = UDim2.new(anchorX, if anchorX == 0 then 12 else -12, 0.56, 0)
	column.Size = UDim2.fromScale(0.16, 0.62)
	column.Parent = lobbyContent
	Components.sizeLimit(Vector2.new(130, 0), Vector2.new(200, math.huge)).Parent = column
	Components.list(
		Enum.FillDirection.Vertical,
		6,
		if anchorX == 0 then Enum.HorizontalAlignment.Left else Enum.HorizontalAlignment.Right
	).Parent =
		column
	return column
end

local function sideButton(column: Frame, options: Components.Props): Components.ButtonHandle
	options.Size = UDim2.fromScale(1, 0.17)
	options.MaxTextSize = options.MaxTextSize or 20
	options.Parent = column
	return Components.button(options)
end

local function buildSideColumns()
	local left = sideColumn("Left", 0)
	sideButton(left, {
		Name = "Shop",
		Text = "SHOP",
		Variant = "Special",
		LayoutOrder = 1,
		onClick = function()
			LobbyUI.onOpenShop()
		end,
	})
	local quests = sideButton(left, {
		Name = "Quests",
		Text = "QUESTS",
		LayoutOrder = 2,
		onClick = function()
			LobbyUI.onOpenQuests()
		end,
	})
	questsBadge = Kit.new("Frame", {
		Name = "Badge",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(1, -4, 0, 4),
		Size = UDim2.fromOffset(14, 14),
		BackgroundColor3 = Theme.Colors.Danger,
		BorderSizePixel = 0,
		Visible = false,
		ZIndex = 3,
		Parent = quests.instance,
	}, { Components.corner(999), Components.stroke(Theme.Colors.Background, 2) })
	dailyButton = sideButton(left, {
		Name = "Daily",
		Text = "DAILY",
		Variant = "Primary",
		LayoutOrder = 3,
		Visible = false,
		onClick = function()
			Remotes.Events.ClaimDailyReward:FireServer()
		end,
	})
	looksButton = sideButton(left, {
		Name = "BuyLooks",
		Text = "BUY LOOKS",
		LayoutOrder = 4,
		Visible = false,
		onClick = function()
			LobbyUI.onOpenLooks()
		end,
	})
	adminButton = sideButton(left, {
		Name = "Admin",
		Text = "ADMIN",
		LayoutOrder = 5,
		Visible = false,
		onClick = function()
			LobbyUI.onOpenAdmin()
		end,
	})

	local right = sideColumn("Right", 1)
	sideButton(right, {
		Name = "Invite",
		Text = "INVITE",
		Variant = "Special",
		LayoutOrder = 1,
		onClick = function()
			local player = State.player
			local ok, canInvite = pcall(SocialService.CanSendGameInviteAsync, SocialService, player)
			if ok and canInvite then
				pcall(SocialService.PromptGameInvite, SocialService, player)
			else
				LobbyUI.onToast("Invites aren't available right now.")
			end
		end,
	})
	sideButton(right, {
		Name = "HowToPlay",
		Text = "HOW TO PLAY",
		LayoutOrder = 2,
		MaxTextSize = 18,
		onClick = function()
			LobbyUI.onOpenHelp()
		end,
	})
end

function LobbyUI.start()
	gui = Components.screen("LobbyUI", 1)

	lobbyContent = Instance.new("Frame")
	lobbyContent.Name = "Lobby"
	lobbyContent.BackgroundTransparency = 1
	lobbyContent.Size = UDim2.fromScale(1, 1)
	lobbyContent.Parent = gui

	buildTopBar()
	buildStatusPanel()
	buildActions()
	buildSideColumns()

	State.RoundChanged:Connect(function(round)
		refreshVisibility()
		refreshStatus()
		looksButton.instance.Visible = round.phase == "Lobby" and #State.lastShopLooks > 0
	end)
	State.DressingRoomChanged:Connect(refreshVisibility)
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
