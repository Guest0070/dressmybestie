--!strict
-- Admin panel: fixed buttons that send commands to the server. The button that opens it only
-- shows for admins, and the server re-checks every command anyway.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Kit = require(script.Parent.Kit)

local AdminPanel = {}

local panel: Frame

local function send(command: string, arg: any?)
	Remotes.Events.AdminCommand:FireServer(command, arg)
end

function AdminPanel.toggle()
	panel.Visible = not panel.Visible
end

function AdminPanel.start()
	local _, root = Kit.screen("Admin", 7)
	panel = Kit.panel({
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -8, 0, 8),
		Size = UDim2.fromOffset(380, 420),
		Visible = false,
		Parent = root,
	})
	Kit.label({
		Text = "Admin",
		Size = UDim2.new(1, -130, 0, 36),
		Position = UDim2.fromOffset(12, 8),
		TextColor3 = Kit.Colors.Gold,
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = panel,
	})
	Kit.button({
		Text = "Close",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -8, 0, 8),
		Size = UDim2.fromOffset(100, 40),
		BackgroundColor3 = Kit.Colors.Grey,
		MaxTextSize = 20,
		Parent = panel,
	}, AdminPanel.toggle)

	local grid = Kit.new("ScrollingFrame", {
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(8, 56),
		Size = UDim2.new(1, -16, 1, -64),
		CanvasSize = UDim2.new(0, 0, 0, 0),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollBarThickness = 6,
		Parent = panel,
	}, {
		Kit.new("UIGridLayout", {
			CellSize = UDim2.fromOffset(172, 52),
			CellPadding = UDim2.fromOffset(8, 8),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	})

	local order = 0
	local function add(text: string, color: Color3, command: string, arg: any?)
		order += 1
		Kit.button(
			{ Text = text, BackgroundColor3 = color, LayoutOrder = order, MaxTextSize = 20, Parent = grid },
			function()
				send(command, arg)
			end
		)
	end

	add("Start round now", Kit.Colors.Green, "StartNow")
	add("Skip phase", Kit.Colors.Blue, "SkipPhase")
	for _, modifier in Config.ChaosModifiers do
		add(`Chaos: {modifier.displayName}`, Kit.Colors.PinkDark, "ForceChaos", modifier.id)
	end
	add(`+{Config.Admin.CoinsGrant} coins`, Kit.Colors.Gold, "GiveCoins")
	add(`+{Config.Admin.XpGrant} XP`, Kit.Colors.Gold, "GiveXp")
	add("Daily reward again", Kit.Colors.PanelLight, "DailyAgain")
	add("Reset my data", Kit.Colors.Grey, "ResetMyData")
end

return AdminPanel
