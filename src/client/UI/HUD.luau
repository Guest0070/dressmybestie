--!strict
-- In-round screen: phase + big timer, "You're styling" banner, theme reveal, photo button, toasts
-- and the end-of-round reward popup. Lobby things (coins/XP, round status, JOIN RANDOM, shop...)
-- live in LobbyUI.luau.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local CaptureService = game:GetService("CaptureService")
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

local root: Frame
local topPanel: Frame
local phaseLabel: TextLabel
local timerLabel: TextLabel
local bannerFrame: Frame
local bannerLabel: TextLabel
local subLabel: TextLabel
local photoButton: TextButton
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
	-- LobbyUI's round-status panel replaces the timer + banner whenever the lobby screen shows.
	local lobby = State.canUseLobby() and not State.dressingRoom
	-- Photo button for the best moments: the runway, the results and the Dressing Room.
	local phase = State.round.phase
	photoButton.Visible = phase == "Runway" or phase == "Results" or State.dressingRoom
	topPanel.Visible = not lobby
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
		-- In the lobby: between the round-status panel and the JOIN RANDOM buttons.
		toastLabel.Position = if lobby then UDim2.fromScale(0.5, 0.5) else UDim2.new(0.5, 0, 0, 168)
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
	bannerFrame.Visible = main ~= nil and not (State.canUseLobby() and not State.dressingRoom)

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
	Remotes.Events.Toast.OnClientEvent:Connect(function(text: string)
		HUD.toast(text)
	end)
	Remotes.Events.RewardSummary.OnClientEvent:Connect(showRewards)
	refreshRound(State.round, nil)
end

return HUD
