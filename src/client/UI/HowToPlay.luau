--!strict
-- "How to play" card. Opens automatically for brand-new players (once per session) and from
-- the "?" button in the lobby.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Types = require(ReplicatedStorage.Shared.Types)
local State = require(script.Parent.Parent.State)
local Kit = require(script.Parent.Kit)

local HowToPlay = {}

local STEPS = {
	{ "1. Get paired", "You're secretly paired with someone. Style THEIR mannequin. They can't see it!" },
	{
		"2. Match the theme",
		"Pick hair, clothes, shoes and more from the catalog. Follow the theme... or don't.",
	},
	{ "3. Walk the runway", "Now you wear what YOUR stylist picked for you. Surprise!" },
	{ "4. Give hearts", "Tap hearts on your 3 favorite looks. Hearts earn the stylist coins and XP." },
}

local panel: Frame
local shownThisSession = false

function HowToPlay.open()
	shownThisSession = true
	panel.Visible = true
end

function HowToPlay.start()
	local _, root = Kit.screen("HowToPlay", 6)
	panel = Kit.panel({
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(640, 400),
		Visible = false,
		Parent = root,
	})
	Kit.label({
		Text = "How to play",
		Size = UDim2.new(1, -24, 0, 40),
		Position = UDim2.fromOffset(12, 10),
		TextColor3 = Kit.Colors.Pink,
		Parent = panel,
	})
	local list = Kit.new("Frame", {
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(16, 58),
		Size = UDim2.new(1, -32, 0, 4 * 62),
		Parent = panel,
	}, { Kit.list(Enum.FillDirection.Vertical, 6) })
	for index, step in STEPS do
		local row = Kit.new("Frame", {
			BackgroundColor3 = Kit.Colors.PanelLight,
			Size = UDim2.new(1, 0, 0, 56),
			LayoutOrder = index,
			Parent = list,
		}, { Kit.corner(10) })
		Kit.label({
			Text = step[1],
			Size = UDim2.new(1, -16, 0, 24),
			Position = UDim2.fromOffset(8, 3),
			TextColor3 = Kit.Colors.Gold,
			TextXAlignment = Enum.TextXAlignment.Left,
			Parent = row,
		})
		Kit.label({
			Text = step[2],
			Size = UDim2.new(1, -16, 0, 24),
			Position = UDim2.fromOffset(8, 29),
			Font = Kit.BodyFont,
			TextXAlignment = Enum.TextXAlignment.Left,
			Parent = row,
		})
	end
	Kit.button({
		Text = "Let's go!",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -10),
		Size = UDim2.fromOffset(220, Kit.ButtonHeight),
		BackgroundColor3 = Kit.Colors.Green,
		Parent = panel,
	}, function()
		panel.Visible = false
	end)

	-- First visit: show it once as soon as we know they've never played.
	State.DataChanged:Connect(function(data: Types.PublicData)
		if not shownThisSession and data.roundsPlayed == 0 and State.round.phase == "Lobby" then
			HowToPlay.open()
		end
	end)
	-- Never cover the game once a round starts.
	State.RoundChanged:Connect(function(round)
		if round.phase ~= "Lobby" then
			panel.Visible = false
		end
	end)
end

return HowToPlay
