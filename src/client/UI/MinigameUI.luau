--!strict
-- Lobby minigames on screen:
--   * Live banner (top centre) for the game you're in or standing next to: "PINK!", "FREEZE!",
--     a countdown bar, wave / players left, and "You're out" when you drop.
--   * Games panel (lobby "GAMES" button): every minigame with its live status and a GO button
--     that takes you there.
-- Everything shown comes from the server (State.minigames); the server decides who's out.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Types = require(ReplicatedStorage.Shared.Types)
local State = require(script.Parent.Parent.State)
local Components = require(script.Parent.Components)
local Kit = require(script.Parent.Kit)
local Theme = require(script.Parent.Theme)

local MinigameUI = {}

local NEAR_DISTANCE = 55 -- studs: close enough to watch a game
local GAMES = {
	{
		id = "ColorRush",
		name = "Color Rush",
		icon = "🟪",
		blurb = "A colour is called. Every other tile vanishes. Don't fall!",
		hint = "Stand on the tile of the colour that's called",
	},
	{
		id = "FreezeFrame",
		name = "Freeze Frame",
		icon = "🧊",
		blurb = "Dance on the stage... then FREEZE. Move and you're out!",
		hint = "Dance, then don't move a muscle on FREEZE!",
	},
	{
		id = "SpinSweep",
		name = "Spin Sweep",
		icon = "🌀",
		blurb = "Jump the spinning arm. It speeds up, then becomes a cross!",
		hint = "Jump when the arm comes round",
	},
	{
		id = "RunwayDash",
		name = "Runway Dash",
		icon = "⏱️",
		blurb = "Timed obstacle course. Beat the clock for coins!",
		hint = "Step on the green pad and run for the gold one",
	},
	{
		id = "Obby",
		name = "Sky Obby",
		icon = "🧗",
		blurb = "16 jumps into the sky. Reach the top for coins!",
		hint = "Climb to the golden deck at the top",
	},
}
local HINTS: { [string]: string } = {}
for _, info in GAMES do
	HINTS[info.id] = info.hint
end

local banner: Frame
local bannerName: TextLabel
local bannerHeadline: TextLabel
local bannerDetail: TextLabel
local barBack: Frame
local barFill: Frame
local panel: Frame
local cards: { [string]: { status: TextLabel, button: Components.ButtonHandle } } = {}

local wasIn: { [string]: boolean } = {}
local shownId: string? = nil
local lastHeadline = ""
local barFor: number? = nil
local barTotal = 1

local function isIn(minigame: Types.MinigameState): boolean
	return table.find(minigame.players, State.player.UserId) ~= nil
end

local function distanceTo(minigame: Types.MinigameState): number
	local character = State.player.Character
	local root = if character then character:FindFirstChild("HumanoidRootPart") else nil
	if not root or not root:IsA("BasePart") then
		return math.huge
	end
	return (root.Position - minigame.center).Magnitude
end

-- The game the banner should follow right now (the one you're in, else the nearest busy one).
local function pick(): Types.MinigameState?
	if not State.canUseLobby() or State.dressingRoom then
		return nil
	end
	local best: Types.MinigameState? = nil
	local bestDistance = NEAR_DISTANCE
	for _, minigame in State.minigames do
		if minigame.phase ~= "Idle" and isIn(minigame) then
			return minigame
		end
		local d = distanceTo(minigame)
		if d < bestDistance then
			best, bestDistance = minigame, d
		end
	end
	return best
end

local function statusText(minigame: Types.MinigameState): string
	if minigame.id == "RunwayDash" or minigame.id == "Obby" then
		return minigame.headline -- always open
	elseif minigame.phase == "Idle" then
		return "Open: step on to start"
	elseif minigame.phase == "Countdown" then
		return `Starting soon · {#minigame.players} ready`
	elseif minigame.phase == "Playing" then
		return `Playing · {#minigame.players} left`
	end
	return minigame.headline
end

local function refreshPanel()
	for id, card in cards do
		local minigame = State.minigames[id]
		if minigame then
			card.status.Text = statusText(minigame)
			card.status.TextColor3 = if minigame.phase == "Playing"
				then Theme.Colors.Accent
				else Theme.Colors.Muted
			card.button:setText(if minigame.phase == "Playing" then "WATCH" else "GO")
		end
	end
end

local function refreshBanner()
	local minigame = pick()
	if not minigame then
		banner.Visible = false
		shownId = nil
		return
	end
	local inIt = isIn(minigame)
	local out = minigame.phase == "Playing" and not inIt and wasIn[minigame.id] == true
	bannerName.Text = string.upper(minigame.name)
	if minigame.phase == "Idle" then
		bannerHeadline.Text = if minigame.id == "RunwayDash" or minigame.id == "Obby"
			then minigame.headline
			else "Step on to play!"
		bannerHeadline.TextColor3 = Theme.Colors.Text
		bannerDetail.Text = HINTS[minigame.id] or ""
	else
		bannerHeadline.Text = minigame.headline
		bannerHeadline.TextColor3 = minigame.color or Theme.Colors.Text
		bannerDetail.Text = if out
			then "You're out! Watch, or hop on for the next game."
			else minigame.detail or ""
	end
	-- Pop the headline whenever it changes ("PINK!" -> "BLUE!").
	if minigame.headline ~= lastHeadline or minigame.id ~= shownId then
		lastHeadline = minigame.headline
		local scale = bannerHeadline:FindFirstChildOfClass("UIScale") :: UIScale
		scale.Scale = 1.35
		TweenService:Create(scale, Theme.TweenSlow, { Scale = 1 }):Play()
	end
	shownId = minigame.id
	banner.Visible = true
end

-- Countdown bar: runs every frame while the banner shows a game with an end time.
local function tickBar()
	if not banner.Visible or not shownId then
		return
	end
	local minigame = State.minigames[shownId]
	local endsAt = if minigame then minigame.endsAt else nil
	barBack.Visible = endsAt ~= nil
	if endsAt and minigame then
		local left = endsAt - Workspace:GetServerTimeNow()
		-- The bar's full length is whatever was left when this end time first arrived.
		if barFor ~= endsAt then
			barFor = endsAt
			barTotal = math.max(0.1, left)
		end
		barFill.Size = UDim2.fromScale(math.clamp(left / barTotal, 0, 1), 1)
		barFill.BackgroundColor3 = minigame.color or Theme.Colors.Primary
	end
end

function MinigameUI.togglePanel()
	panel.Visible = not panel.Visible
	if panel.Visible then
		refreshPanel()
	end
end

local function buildBanner(root: Frame)
	banner = Components.panel({
		Name = "MinigameBanner",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 70),
		Size = UDim2.fromOffset(360, 108),
		Visible = false,
		Parent = root,
	})
	bannerName = Components.text({
		Name = "GameName",
		Position = UDim2.fromOffset(0, 8),
		Size = UDim2.new(1, 0, 0, 16),
		FontFace = Theme.Fonts.Heading,
		TextColor3 = Theme.Colors.Accent,
		MaxTextSize = 14,
		Parent = banner,
	})
	bannerHeadline = Components.text({
		Name = "Headline",
		Position = UDim2.fromOffset(0, 24),
		Size = UDim2.new(1, 0, 0, 44),
		FontFace = Theme.Fonts.Heading,
		MaxTextSize = 40,
		Parent = banner,
	})
	Kit.new("UIScale", { Parent = bannerHeadline })
	Kit.new("UIStroke", { Thickness = 2, Color = Theme.Colors.Background, Parent = bannerHeadline })
	bannerDetail = Components.text({
		Name = "Detail",
		Position = UDim2.fromOffset(12, 70),
		Size = UDim2.new(1, -24, 0, 18),
		TextColor3 = Theme.Colors.Silver,
		MaxTextSize = 15,
		Parent = banner,
	})
	barBack = Kit.new("Frame", {
		Name = "Bar",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -8),
		Size = UDim2.new(1, -24, 0, 5),
		BackgroundColor3 = Theme.Colors.Stroke,
		BorderSizePixel = 0,
		Parent = banner,
	}, { Components.corner(3) })
	barFill = Kit.new("Frame", {
		Name = "Fill",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Theme.Colors.Primary,
		BorderSizePixel = 0,
		Parent = barBack,
	}, { Components.corner(3) })
end

local function buildPanel(root: Frame)
	panel = Components.panel({
		Name = "GamesPanel",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(760, 400),
		Visible = false,
		ZIndex = 2,
		Parent = root,
	})
	Components.text({
		Text = "MINIGAMES",
		Position = UDim2.fromOffset(20, 14),
		Size = UDim2.new(1, -120, 0, 30),
		FontFace = Theme.Fonts.Heading,
		TextColor3 = Theme.Colors.Primary,
		TextXAlignment = Enum.TextXAlignment.Left,
		MaxTextSize = 28,
		Parent = panel,
	})
	Components.text({
		Text = "Play while you wait for the next round. Wins pay coins!",
		Position = UDim2.fromOffset(20, 44),
		Size = UDim2.new(1, -40, 0, 18),
		TextColor3 = Theme.Colors.Muted,
		TextXAlignment = Enum.TextXAlignment.Left,
		MaxTextSize = 15,
		Parent = panel,
	})
	Components.button({
		Text = "X",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -12, 0, 12),
		Size = UDim2.fromOffset(Theme.MinTouch, Theme.MinTouch),
		onClick = MinigameUI.togglePanel,
		Parent = panel,
	})
	local list = Kit.new("Frame", {
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(16, 74),
		Size = UDim2.new(1, -32, 1, -90),
		Parent = panel,
	}, {
		Kit.new("UIGridLayout", {
			CellSize = UDim2.new(1 / 3, -8, 0, 148),
			CellPadding = UDim2.fromOffset(12, 12),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	})
	for index, info in GAMES do
		local card = Components.panel({
			Raised = true,
			LayoutOrder = index,
			Parent = list,
		})
		Components.text({
			Text = info.icon,
			Position = UDim2.fromOffset(14, 12),
			Size = UDim2.fromOffset(40, 40),
			MaxTextSize = 34,
			Parent = card,
		})
		Components.text({
			Text = info.name,
			Position = UDim2.fromOffset(62, 14),
			Size = UDim2.new(1, -74, 0, 26),
			FontFace = Theme.Fonts.Heading,
			TextXAlignment = Enum.TextXAlignment.Left,
			MaxTextSize = 24,
			Parent = card,
		})
		local status = Components.text({
			Text = "",
			Position = UDim2.fromOffset(62, 40),
			Size = UDim2.new(1, -74, 0, 16),
			FontFace = Theme.Fonts.Number,
			TextColor3 = Theme.Colors.Muted,
			TextXAlignment = Enum.TextXAlignment.Left,
			MaxTextSize = 14,
			Parent = card,
		})
		Components.text({
			Text = info.blurb,
			Position = UDim2.fromOffset(14, 62),
			Size = UDim2.new(1, -28, 0, 34),
			TextColor3 = Theme.Colors.Silver,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextYAlignment = Enum.TextYAlignment.Top,
			TextWrapped = true,
			MaxTextSize = 15,
			Parent = card,
		})
		local button = Components.button({
			Text = "GO",
			Variant = "Primary",
			AnchorPoint = Vector2.new(0.5, 1),
			Position = UDim2.new(0.5, 0, 1, -12),
			Size = UDim2.new(1, -28, 0, 36),
			MaxTextSize = 18,
			onClick = function()
				Remotes.Events.MinigameGo:FireServer(info.id)
				panel.Visible = false
			end,
			Parent = card,
		})
		cards[info.id] = { status = status, button = button }
	end
end

function MinigameUI.start()
	local _, root = Kit.screen("Minigames", 4)
	buildBanner(root)
	buildPanel(root)
	panel:GetPropertyChangedSignal("Visible"):Connect(function()
		Kit.hideChat("Games", panel.Visible)
	end)

	State.MinigameChanged:Connect(function(minigame)
		if minigame.phase == "Countdown" or (minigame.phase == "Playing" and isIn(minigame)) then
			wasIn[minigame.id] = isIn(minigame)
		elseif minigame.phase == "Idle" then
			wasIn[minigame.id] = nil
		end
		refreshBanner()
		if panel.Visible then
			refreshPanel()
		end
	end)
	State.RoundChanged:Connect(function()
		if not State.canUseLobby() then
			panel.Visible = false
		end
		refreshBanner()
	end)
	-- Walking up to / away from a game shows / hides its banner.
	local accumulator = 0
	RunService.Heartbeat:Connect(function(dt)
		accumulator += dt
		if accumulator > 0.4 then
			accumulator = 0
			refreshBanner()
		end
		tickBar()
	end)
end

return MinigameUI
