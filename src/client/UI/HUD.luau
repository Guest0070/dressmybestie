--!strict
-- Always-on screen: phase + big timer, "You're styling" banner, coins/rank, daily reward,
-- shop + looks buttons, toasts and the end-of-round reward popup.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local CaptureService = game:GetService("CaptureService")
local SocialService = game:GetService("SocialService")
local StarterGui = game:GetService("StarterGui")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Types = require(ReplicatedStorage.Shared.Types)
local State = require(script.Parent.Parent.State)
local Kit = require(script.Parent.Kit)

local HUD = {}

local PHASE_TITLES: { [string]: string } = {
	Lobby = "Lobby",
	Pairing = "Pairing up!",
	ThemeReveal = "Theme",
	Styling = "Style time!",
	Runway = "Runway",
	Voting = "Vote!",
	Results = "Results",
}

-- Callbacks other modules plug in (set by init.client).
HUD.onOpenShop = function() end
HUD.onOpenLooks = function() end
HUD.onOpenHelp = function() end
HUD.onOpenAdmin = function() end
HUD.onOpenQuests = function() end
-- Returns true when a quest can be claimed (shows the "!" badge). Set by init.client.
HUD.hasClaimableQuest = function(_data: Types.PublicData): boolean
	return false
end

local root: Frame
local topPanel: Frame
local statsPanel: Frame
local buttonColumn: Frame
local phaseLabel: TextLabel
local timerLabel: TextLabel
local bannerFrame: Frame
local bannerLabel: TextLabel
local subLabel: TextLabel
local coinsLabel: TextLabel
local rankLabel: TextLabel
local dailyButton: TextButton
local looksButton: TextButton
local adminButton: TextButton
local questsBadge: TextLabel
local photoButton: TextButton
local rightColumn: Frame
local toastLabel: TextLabel
local revealFrame: Frame
local revealTheme: TextLabel
local revealChaos: TextLabel

local toastToken = 0

function HUD.toast(text: string, seconds: number?)
	toastToken += 1
	local token = toastToken
	toastLabel.Text = text
	toastLabel.Visible = true
	task.delay(seconds or 3.5, function()
		if token == toastToken then
			toastLabel.Visible = false
		end
	end)
end

local function stylistsText(names: { string }?): string
	if not names or #names == 0 then
		return "a mystery stylist"
	end
	return table.concat(names, " & ")
end

-- Main banner text for the current phase, from this player's point of view.
local function bannerFor(round: Types.RoundState): (string?, string?)
	local me = State.player.UserId
	local target = State.myTarget()
	local theme = round.theme
	local chaosLine = if round.chaos
		then `CHAOS: {round.chaos.displayName} - {round.chaos.description}`
		else nil

	if round.phase == "Lobby" then
		return round.message, nil
	elseif round.phase == "Pairing" then
		if target == me then
			return "Solo test: you're styling yourself!", nil
		elseif target then
			return `You're styling: {State.nameOf(target)}`, "They can't see what you pick!"
		end
		return "Watching this round", nil
	elseif round.phase == "ThemeReveal" or round.phase == "Styling" then
		local line = if theme then `Theme: {theme}` else nil
		if chaosLine then
			line = if line then `{line}  |  {chaosLine}` else chaosLine
		end
		if round.phase == "Styling" and target then
			return `You're styling: {State.nameOf(target)}`, line
		end
		return line, nil
	elseif round.phase == "Runway" then
		local wearer = round.runwayWearer
		if not wearer then
			return "Get ready for the runway!", nil
		elseif wearer == me then
			return "IT'S YOU! Strut!", `Styled by {stylistsText(round.runwayStylists)}`
		end
		local sub = `Styled by {stylistsText(round.runwayStylists)}`
		if round.rating then
			sub ..= "  ·  Rate it with the stars!"
		end
		return `{State.nameOf(wearer)}`, sub
	elseif round.phase == "Voting" then
		if round.chaos and round.chaos.reverseVoting then
			return "Hearts for the most gloriously TERRIBLE look!", "Tap up to 3"
		end
		return "Tap a heart on up to 3 favorite looks!", nil
	elseif round.phase == "Results" then
		return if theme then `Theme was: {theme}` else nil, nil
	end
	return nil, nil
end

-- While styling, the catalog takes the right half of the screen, so the HUD moves to the left half.
local function applyLayout(styling: boolean)
	-- Lobby buttons only in the lobby: during a round they'd cover the voting/results panels.
	local lobby = State.canUseLobby()
	-- Photo button for the best moments: the runway, the results and the Dressing Room.
	local phase = State.round.phase
	photoButton.Visible = phase == "Runway" or phase == "Results" or State.dressingRoom
	statsPanel.Visible = not styling
	buttonColumn.Visible = lobby and not styling
	rightColumn.Visible = lobby and not styling
	if styling then
		topPanel.AnchorPoint = Vector2.new(0, 0)
		topPanel.Position = UDim2.fromOffset(8, 8)
		bannerFrame.AnchorPoint = Vector2.new(0, 0)
		bannerFrame.Position = UDim2.fromOffset(8, 98)
		bannerFrame.Size = UDim2.new(0.5, -16, 0, 62)
		toastLabel.AnchorPoint = Vector2.new(0, 0)
		toastLabel.Position = UDim2.fromOffset(8, 168)
		toastLabel.Size = UDim2.new(0.5, -16, 0, 70)
	else
		topPanel.AnchorPoint = Vector2.new(0.5, 0)
		topPanel.Position = UDim2.new(0.5, 0, 0, 8)
		bannerFrame.AnchorPoint = Vector2.new(0.5, 0)
		bannerFrame.Position = UDim2.new(0.5, 0, 0, 98)
		bannerFrame.Size = UDim2.fromOffset(520, 62)
		toastLabel.AnchorPoint = Vector2.new(0.5, 0)
		toastLabel.Position = UDim2.new(0.5, 0, 0, 168)
		toastLabel.Size = UDim2.fromOffset(520, 70)
	end
end

local function refreshRound(round: Types.RoundState, changedFrom: Types.RoundPhase?)
	local styling = (round.phase == "Styling" and State.myTarget() ~= nil) or State.dressingRoom
	applyLayout(styling)
	-- Roblox's player list sits over the catalog tabs on small screens; hide it while styling.
	pcall(StarterGui.SetCoreGuiEnabled, StarterGui, Enum.CoreGuiType.PlayerList, not styling)
	phaseLabel.Text = PHASE_TITLES[round.phase] or round.phase
	local main, sub = bannerFor(round)
	if State.dressingRoom then
		main, sub = "Dressing Room", "Try anything on! Tap Buy these to keep it."
	end
	bannerLabel.Text = main or ""
	subLabel.Text = sub or ""
	subLabel.Visible = sub ~= nil
	bannerFrame.Visible = main ~= nil
	looksButton.Visible = round.phase == "Lobby" and #State.lastShopLooks > 0

	-- Theme reveal gets a big centered card.
	revealFrame.Visible = round.phase == "ThemeReveal"
	if round.phase == "ThemeReveal" then
		revealTheme.Text = round.theme or ""
		revealChaos.Text = if round.chaos
			then `CHAOS ROUND: {round.chaos.displayName}\n{round.chaos.description}`
			else ""
		revealFrame.Size = UDim2.fromOffset(200, 80)
		TweenService:Create(revealFrame, TweenInfo.new(0.4, Enum.EasingStyle.Back), {
			Size = UDim2.fromOffset(560, 200),
		}):Play()
	end
	if changedFrom then
		Kit.playSound("PhaseChange")
	end
end

local lastCoins: number? = nil

-- A "+X" that floats up from the coin counter whenever coins go up.
local function coinPop(amount: number)
	local pop = Kit.label({
		Text = `+{amount}`,
		Position = UDim2.fromOffset(150, 20),
		Size = UDim2.fromOffset(120, 36),
		TextColor3 = Kit.Colors.Gold,
		MaxTextSize = 32,
		ZIndex = 20,
		Parent = root,
	})
	local tween =
		TweenService:Create(pop, TweenInfo.new(1.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			Position = UDim2.fromOffset(150, -20),
			TextTransparency = 1,
		})
	tween:Play()
	tween.Completed:Once(function()
		pop:Destroy()
	end)
end

local function refreshData(data: Types.PublicData)
	if lastCoins and data.coins > lastCoins then
		coinPop(data.coins - lastCoins)
	end
	lastCoins = data.coins
	coinsLabel.Text = `{data.coins} coins`
	local rankName = Config.RankNames[data.rank] or `Rank {data.rank}`
	local nextXp = Config.RankXp[data.rank + 1]
	rankLabel.Text = if nextXp
		then `{rankName}  {data.styleXp}/{nextXp} XP`
		else `{rankName}  {data.styleXp} XP`
	dailyButton.Visible = data.canClaimDaily
	dailyButton.Text = `Daily +{data.nextDailyReward}`
	questsBadge.Visible = HUD.hasClaimableQuest(data)
	adminButton.Visible = data.isAdmin
end

-- Big "RANK UP!" card with falling confetti and the items that just unlocked.
local function celebrateRankUp(rank: number)
	local unlocked = {}
	for _, cosmetic in Config.Cosmetics do
		if cosmetic.rank == rank then
			table.insert(unlocked, cosmetic.displayName)
		end
	end
	local card = Kit.panel({
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.45),
		Size = UDim2.fromOffset(520, 200),
		BackgroundColor3 = Kit.Colors.PinkDark,
		ZIndex = 30,
		Parent = root,
	})
	local scale = Kit.new("UIScale", { Scale = 0.3, Parent = card })
	Kit.label({
		Text = "RANK UP!",
		Size = UDim2.new(1, -20, 0, 60),
		Position = UDim2.fromOffset(10, 10),
		TextColor3 = Kit.Colors.Gold,
		MaxTextSize = 56,
		ZIndex = 31,
		Parent = card,
	})
	Kit.label({
		Text = `You're now: {Config.RankNames[rank] or "a legend"} (Lv {rank})`,
		Size = UDim2.new(1, -20, 0, 40),
		Position = UDim2.fromOffset(10, 76),
		ZIndex = 31,
		Parent = card,
	})
	Kit.label({
		Text = if #unlocked > 0
			then `Unlocked: {table.concat(unlocked, ", ")}`
			else "Keep styling to unlock more!",
		Size = UDim2.new(1, -20, 0, 34),
		Position = UDim2.fromOffset(10, 124),
		Font = Kit.BodyFont,
		ZIndex = 31,
		Parent = card,
	})
	TweenService:Create(scale, TweenInfo.new(0.5, Enum.EasingStyle.Back), { Scale = 1 }):Play()
	local colors = { Kit.Colors.Pink, Kit.Colors.Gold, Kit.Colors.Blue, Kit.Colors.Green }
	for i = 1, 40 do
		local piece = Kit.new("Frame", {
			BackgroundColor3 = colors[i % #colors + 1],
			Size = UDim2.fromOffset(10, 16),
			Position = UDim2.new(math.random(), 0, 0, -20),
			Rotation = math.random(0, 360),
			ZIndex = 29,
			Parent = root,
		})
		TweenService:Create(
			piece,
			TweenInfo.new(1.5 + math.random() * 1.5, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
			{
				Position = UDim2.new(math.random(), 0, 1, 20),
				Rotation = math.random(0, 720),
			}
		):Play()
		task.delay(3.2, function()
			piece:Destroy()
		end)
	end
	task.delay(4.5, function()
		card:Destroy()
	end)
end

local function showRewards(summary: Types.RewardSummary)
	if summary.rankUp then
		celebrateRankUp(summary.rankUp)
	end
	local lines = { `+{summary.coins} coins   +{summary.xp} XP` }
	if summary.heartsForYourStyling > 0 then
		table.insert(lines, `Your styling got {summary.heartsForYourStyling} heart(s)!`)
	end
	if summary.rankUp then
		table.insert(lines, `RANK UP! You're now a {Config.RankNames[summary.rankUp] or "legend"}!`)
	end
	HUD.toast(table.concat(lines, "\n"), 6)
end

function HUD.start()
	local _, r = Kit.screen("HUD", 1)
	root = r

	-- Top center: phase title + big timer
	topPanel = Kit.panel({
		Name = "Top",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 8),
		Size = UDim2.fromOffset(260, 84),
		Parent = root,
	})
	phaseLabel = Kit.label({
		Size = UDim2.new(1, -16, 0, 26),
		Position = UDim2.fromOffset(8, 4),
		TextColor3 = Kit.Colors.Pink,
		Parent = topPanel,
	})
	timerLabel = Kit.label({
		Size = UDim2.new(1, -16, 0, 48),
		Position = UDim2.fromOffset(8, 30),
		MaxTextSize = 48,
		Text = "",
		Parent = topPanel,
	})

	-- Banner under the timer
	bannerFrame = Kit.panel({
		Name = "Banner",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 98),
		Size = UDim2.fromOffset(520, 62),
		Parent = root,
	})
	bannerLabel = Kit.label({
		Size = UDim2.new(1, -20, 0, 34),
		Position = UDim2.fromOffset(10, 4),
		Parent = bannerFrame,
	})
	subLabel = Kit.label({
		Size = UDim2.new(1, -20, 0, 20),
		Position = UDim2.fromOffset(10, 38),
		Font = Kit.BodyFont,
		TextColor3 = Kit.Colors.Gold,
		Parent = bannerFrame,
	})

	-- Top left: coins + rank
	statsPanel =
		Kit.panel({ Position = UDim2.fromOffset(8, 8), Size = UDim2.fromOffset(190, 64), Parent = root })
	local stats = statsPanel
	coinsLabel = Kit.label({
		Size = UDim2.new(1, -16, 0, 30),
		Position = UDim2.fromOffset(8, 4),
		TextColor3 = Kit.Colors.Gold,
		Text = "...",
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = stats,
	})
	rankLabel = Kit.label({
		Size = UDim2.new(1, -16, 0, 20),
		Position = UDim2.fromOffset(8, 38),
		Font = Kit.BodyFont,
		TextColor3 = Kit.Colors.TextDim,
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = stats,
	})

	-- Left column buttons (below stats): shop, daily, looks
	buttonColumn = Kit.new("Frame", {
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(8, 80),
		Size = UDim2.fromOffset(150, 5 * (Kit.ButtonHeight + 8)),
		Parent = root,
	}, { Kit.list(Enum.FillDirection.Vertical, 8) })
	local column = buttonColumn
	Kit.button(
		{ Text = "Shop", Size = UDim2.fromOffset(150, Kit.ButtonHeight), LayoutOrder = 1, Parent = column },
		function()
			HUD.onOpenShop()
		end
	)
	dailyButton = Kit.button({
		Text = `Daily +{Config.Rewards.DailyRewardCoins}`,
		BackgroundColor3 = Kit.Colors.Green,
		Size = UDim2.fromOffset(150, Kit.ButtonHeight),
		LayoutOrder = 3,
		Visible = false,
		Parent = column,
	}, function()
		Remotes.Events.ClaimDailyReward:FireServer()
	end)
	local questsButton = Kit.button({
		Text = "Quests",
		BackgroundColor3 = Kit.Colors.Blue,
		Size = UDim2.fromOffset(150, Kit.ButtonHeight),
		LayoutOrder = 2,
		Parent = column,
	}, function()
		HUD.onOpenQuests()
	end)
	questsBadge = Kit.label({
		Text = "!",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, 6, 0, -6),
		Size = UDim2.fromOffset(26, 26),
		BackgroundTransparency = 0,
		BackgroundColor3 = Color3.fromRGB(235, 60, 60),
		Visible = false,
		ZIndex = 5,
		Parent = questsButton,
	})
	Kit.corner(13).Parent = questsBadge

	-- Photo: screenshot + Roblox's own share / save prompt (great for TikTok clips).
	photoButton = Kit.button({
		Text = "Photo",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -8, 0, 96),
		Size = UDim2.fromOffset(120, Kit.ButtonHeight),
		BackgroundColor3 = Kit.Colors.Blue,
		Visible = false,
		Parent = root,
	}, function()
		pcall(CaptureService.CaptureScreenshot, CaptureService, function(capture)
			local shared = pcall(
				CaptureService.PromptShareCapture,
				CaptureService,
				capture,
				"",
				function() end,
				function() end
			)
			if not shared then
				pcall(CaptureService.PromptSaveCapturesToGallery, CaptureService, { capture }, function() end)
			end
		end)
	end)

	-- Right column (bottom-right): how to play + invite friends.
	rightColumn = Kit.new("Frame", {
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, -8, 1, -8),
		Size = UDim2.fromOffset(170, 3 * (Kit.ButtonHeight + 8)),
		Parent = root,
	}, { Kit.list(Enum.FillDirection.Vertical, 8, Enum.HorizontalAlignment.Right) })
	Kit.button({
		Text = "Invite friends",
		BackgroundColor3 = Kit.Colors.Green,
		Size = UDim2.fromOffset(170, Kit.ButtonHeight),
		LayoutOrder = 1,
		MaxTextSize = 22,
		Parent = rightColumn,
	}, function()
		local player = State.player
		local ok, canInvite = pcall(SocialService.CanSendGameInviteAsync, SocialService, player)
		if ok and canInvite then
			pcall(SocialService.PromptGameInvite, SocialService, player)
		else
			HUD.toast("Invites aren't available right now.")
		end
	end)
	-- Spectator toggle: sit out of rounds and just watch + vote (the server also switches idle
	-- players to spectating).
	local afkButton: TextButton
	afkButton = Kit.button({
		Text = "Spectate",
		BackgroundColor3 = Kit.Colors.PanelLight,
		Size = UDim2.fromOffset(170, Kit.ButtonHeight),
		LayoutOrder = 3,
		MaxTextSize = 22,
		Parent = rightColumn,
	}, function()
		Remotes.Events.SetSpectating:FireServer(State.player:GetAttribute("Spectating") ~= true)
	end)
	local function refreshAfk()
		local afk = State.player:GetAttribute("Spectating") == true
		afkButton.Text = if afk then "Play next round" else "Spectate"
		afkButton.BackgroundColor3 = if afk then Kit.Colors.Gold else Kit.Colors.PanelLight
	end
	State.player:GetAttributeChangedSignal("Spectating"):Connect(refreshAfk)
	refreshAfk()
	Kit.button({
		Text = "How to play",
		BackgroundColor3 = Kit.Colors.PanelLight,
		Size = UDim2.fromOffset(170, Kit.ButtonHeight),
		LayoutOrder = 2,
		MaxTextSize = 22,
		Parent = rightColumn,
	}, function()
		HUD.onOpenHelp()
	end)
	adminButton = Kit.button({
		Text = "Admin",
		BackgroundColor3 = Kit.Colors.Gold,
		Size = UDim2.fromOffset(150, Kit.ButtonHeight),
		LayoutOrder = 5,
		Visible = false,
		Parent = column,
	}, function()
		HUD.onOpenAdmin()
	end)
	looksButton = Kit.button({
		Text = "Buy looks",
		BackgroundColor3 = Kit.Colors.PinkDark,
		Size = UDim2.fromOffset(150, Kit.ButtonHeight),
		LayoutOrder = 4,
		Visible = false,
		Parent = column,
	}, function()
		HUD.onOpenLooks()
	end)

	-- Theme reveal card
	revealFrame = Kit.panel({
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.55),
		Size = UDim2.fromOffset(560, 200),
		Visible = false,
		BackgroundColor3 = Kit.Colors.PinkDark,
		Parent = root,
	})
	Kit.label({
		Text = "THE THEME IS",
		Size = UDim2.new(1, -20, 0, 30),
		Position = UDim2.fromOffset(10, 10),
		Parent = revealFrame,
	})
	revealTheme = Kit.label({
		Size = UDim2.new(1, -20, 0, 70),
		Position = UDim2.fromOffset(10, 44),
		MaxTextSize = 64,
		TextColor3 = Kit.Colors.Gold,
		Parent = revealFrame,
	})
	revealChaos = Kit.label({
		Size = UDim2.new(1, -20, 0, 60),
		Position = UDim2.fromOffset(10, 124),
		Font = Kit.BodyFont,
		Parent = revealFrame,
	})

	-- Toasts (bottom center, above other panels)
	toastLabel = Kit.label({
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 168),
		Size = UDim2.fromOffset(520, 70),
		BackgroundTransparency = 0.2,
		BackgroundColor3 = Kit.Colors.Panel,
		Font = Kit.BodyFont,
		MaxTextSize = 24,
		Visible = false,
		ZIndex = 10,
		Parent = root,
	})
	Kit.corner(12).Parent = toastLabel

	-- Timer ticks locally from the server's end time.
	local accumulator = 0
	RunService.Heartbeat:Connect(function(dt)
		accumulator += dt
		if accumulator < 0.2 then
			return
		end
		accumulator = 0
		local endsAt = State.round.endsAt
		local remaining = if endsAt then endsAt - Workspace:GetServerTimeNow() else nil
		timerLabel.Text = if remaining then Kit.formatTime(remaining) else "--"
		-- Last 10 seconds: the timer flashes red/white so nobody misses the deadline.
		local urgent = remaining ~= nil and remaining <= 10 and remaining > 0
		timerLabel.TextColor3 = if urgent and math.floor((remaining :: number) * 2) % 2 == 0
			then Color3.fromRGB(255, 90, 90)
			else Kit.Colors.Text
	end)

	State.RoundChanged:Connect(refreshRound)
	State.DressingRoomChanged:Connect(function()
		refreshRound(State.round, nil)
	end)
	State.DataChanged:Connect(refreshData)
	Remotes.Events.Toast.OnClientEvent:Connect(function(text: string)
		HUD.toast(text)
	end)
	Remotes.Events.RewardSummary.OnClientEvent:Connect(showRewards)
	refreshRound(State.round, nil)
	if State.data then
		refreshData(State.data)
	end
end

return HUD
