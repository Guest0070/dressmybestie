--!strict
-- Runway reactions: while a look walks, everyone except the walker gets a column of emoji buttons
-- (Config.Reactions). Tapping one sends it to the server, which passes it to everyone; each
-- reaction floats up over the walker's head and fades. Just cheering: nothing is scored.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local State = require(script.Parent.Parent.State)
local Components = require(script.Parent.Components)
local Kit = require(script.Parent.Kit)
local Theme = require(script.Parent.Theme)

local ReactionsUI = {}

local MAX_FLOATING = 30 -- per walker, so a reaction storm stays readable

local column: Frame
local floating: { [number]: number } = {}

local function refresh()
	local wearer = State.round.runwayWearer
	column.Visible = State.round.phase == "Runway" and wearer ~= nil and wearer ~= State.player.UserId
end

-- One emoji rising over the walker's head.
local function float(walkerUserId: number, emoji: string)
	local walker = Players:GetPlayerByUserId(walkerUserId)
	local character = if walker then walker.Character else nil
	local head = if character then character:FindFirstChild("Head") else nil
	if not head or not head:IsA("BasePart") then
		return
	end
	if (floating[walkerUserId] or 0) >= MAX_FLOATING then
		return
	end
	floating[walkerUserId] = (floating[walkerUserId] or 0) + 1
	local billboard = Instance.new("BillboardGui")
	billboard.Size = UDim2.fromOffset(46, 46)
	billboard.StudsOffset = Vector3.new((math.random() - 0.5) * 3, 1.5, 0)
	billboard.AlwaysOnTop = true
	billboard.LightInfluence = 0
	billboard.Adornee = head
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1, 1)
	label.Text = emoji
	label.TextScaled = true
	label.Parent = billboard
	local scale = Instance.new("UIScale")
	scale.Scale = 0.4
	scale.Parent = label
	billboard.Parent = head
	local rise = TweenInfo.new(1.8, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	TweenService:Create(billboard, rise, {
		StudsOffset = billboard.StudsOffset
			+ Vector3.new((math.random() - 0.5) * 2, 5 + math.random() * 2, 0),
	}):Play()
	TweenService:Create(scale, TweenInfo.new(0.25, Enum.EasingStyle.Back), { Scale = 1 }):Play()
	TweenService
		:Create(label, TweenInfo.new(0.6, Enum.EasingStyle.Quad, Enum.EasingDirection.In, 0, false, 1.2), {
			TextTransparency = 1,
		})
		:Play()
	task.delay(1.9, function()
		billboard:Destroy()
		floating[walkerUserId] = math.max(0, (floating[walkerUserId] or 1) - 1)
	end)
end

function ReactionsUI.start()
	local _, root = Kit.screen("Reactions", 3)
	column = Components.panel({
		Name = "Column",
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -10, 0.55, 0),
		Size = UDim2.fromOffset(64, 16 + #Config.Reactions.Emojis * 56),
		Visible = false,
		Parent = root,
	})
	Kit.new("UIListLayout", {
		FillDirection = Enum.FillDirection.Vertical,
		HorizontalAlignment = Enum.HorizontalAlignment.Center,
		VerticalAlignment = Enum.VerticalAlignment.Center,
		Padding = UDim.new(0, 6),
		SortOrder = Enum.SortOrder.LayoutOrder,
		Parent = column,
	})
	for index, emoji in Config.Reactions.Emojis do
		local button = Kit.new("TextButton", {
			Name = `React{index}`,
			Text = emoji,
			TextScaled = true,
			BackgroundColor3 = Theme.Colors.PanelRaised,
			AutoButtonColor = true,
			Size = UDim2.fromOffset(50, 50),
			LayoutOrder = index,
			Parent = column,
		}, { Components.corner(999), Kit.padding(6) })
		local pop = Kit.new("UIScale", { Parent = button })
		button.Activated:Connect(function()
			Remotes.Events.React:FireServer(index)
			Kit.playSound("Reaction")
			pop.Scale = 1.3
			TweenService:Create(pop, TweenInfo.new(0.2, Enum.EasingStyle.Back), { Scale = 1 }):Play()
		end)
	end

	Remotes.Events.Reaction.OnClientEvent:Connect(function(walkerUserId: number, index: number)
		local emoji = Config.Reactions.Emojis[index]
		if emoji then
			float(walkerUserId, emoji)
		end
	end)
	State.RoundChanged:Connect(refresh)
	refresh()
end

return ReactionsUI
