--!strict
-- Stars mode: while a look walks the runway, everyone watching (spectators too) gets 5 stars at
-- the bottom of the screen. Tapping the 3rd star fills stars 1-3 with a little pop and sends the
-- rating. You can change your mind until the next look walks. The walker and their stylists
-- don't see it (the server blocks those votes too).

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local State = require(script.Parent.Parent.State)
local Kit = require(script.Parent.Kit)

local StarsUI = {}

local FILLED = "★"
local EMPTY = "☆"

local panel: Frame
local titleLabel: TextLabel
local thanksLabel: TextLabel
local stars: { TextButton } = {}
local currentWearer: number? = nil

local function paint(count: number, animate: boolean)
	for i, star in stars do
		local on = i <= count
		star.Text = if on then FILLED else EMPTY
		star.TextColor3 = if on then Kit.Colors.Gold else Kit.Colors.TextDim
		if animate and on then
			local scale = star:FindFirstChildOfClass("UIScale")
			if scale then
				scale.Scale = 1.5
				TweenService
					:Create(scale, TweenInfo.new(0.25 + i * 0.05, Enum.EasingStyle.Back), { Scale = 1 })
					:Play()
			end
		end
	end
end

local function canRate(): boolean
	local round = State.round
	local wearer = round.runwayWearer
	if round.phase ~= "Runway" or not round.rating or not wearer then
		return false
	end
	if wearer == State.player.UserId or State.myTarget() == wearer then
		return false
	end
	local stylists: { string } = round.runwayStylists or {}
	for _, name in stylists do
		if name == State.player.DisplayName then
			return false -- you styled this look
		end
	end
	return true
end

local function refresh()
	local wearer = State.round.runwayWearer
	if wearer ~= currentWearer then
		currentWearer = wearer
		paint(0, false)
		thanksLabel.Visible = false
	end
	local visible = canRate()
	panel.Visible = visible
	if visible and wearer then
		titleLabel.Text = `Rate {State.nameOf(wearer)}'s look!`
	end
end

function StarsUI.start()
	if Config.VotingMode ~= "Stars" then
		return
	end
	local _, root = Kit.screen("Stars", 3)
	panel = Kit.panel({
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -10),
		Size = UDim2.fromOffset(460, 130),
		Visible = false,
		Parent = root,
	})
	titleLabel = Kit.label({
		Position = UDim2.fromOffset(10, 6),
		Size = UDim2.new(1, -20, 0, 30),
		MaxTextSize = 26,
		Parent = panel,
	})
	thanksLabel = Kit.label({
		Text = "Vote saved! Tap again to change it.",
		Position = UDim2.new(0, 10, 1, -24),
		Size = UDim2.new(1, -20, 0, 18),
		Font = Kit.BodyFont,
		TextColor3 = Kit.Colors.Green,
		MaxTextSize = 16,
		Visible = false,
		Parent = panel,
	})
	local row = Kit.new("Frame", {
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 38),
		Size = UDim2.fromOffset(5 * 76, 66),
		Parent = panel,
	}, { Kit.list(Enum.FillDirection.Horizontal, 8, Enum.HorizontalAlignment.Center) })
	for i = 1, 5 do
		local star = Kit.new("TextButton", {
			Text = EMPTY,
			BackgroundTransparency = 1,
			Font = Enum.Font.GothamBold,
			TextScaled = true,
			TextColor3 = Kit.Colors.TextDim,
			Size = UDim2.fromOffset(68, 64),
			LayoutOrder = i,
			Parent = row,
		}, { Kit.new("UIScale", {}), Kit.new("UIStroke", { Thickness = 2, Transparency = 0.3 }) })
		star.Activated:Connect(function()
			if not canRate() or not currentWearer then
				return
			end
			paint(i, true)
			thanksLabel.Visible = true
			Kit.playSound("Heart")
			Remotes.Events.RateLook:FireServer(currentWearer, i)
		end)
		stars[i] = star
	end
	State.RoundChanged:Connect(refresh)
	refresh()
end

return StarsUI
