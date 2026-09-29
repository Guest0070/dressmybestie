--!strict
-- Quests panel: daily quests (reset every day) and achievements (forever). Finished quests
-- show a Claim button; the server checks progress and pays the fixed reward.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Types = require(ReplicatedStorage.Shared.Types)
local State = require(script.Parent.Parent.State)
local Kit = require(script.Parent.Kit)

local QuestsUI = {}

local panel: Frame
local list: ScrollingFrame
local tabButtons: { [string]: TextButton } = {}
local currentKind: string = "daily" -- "daily" | "achievement"

-- True if any quest is finished but not claimed yet (the HUD shows a "!" badge).
function QuestsUI.hasClaimable(data: Types.PublicData): boolean
	for _, quest in data.quests do
		if not quest.claimed and quest.progress >= quest.target then
			return true
		end
	end
	return false
end

local function row(quest: Types.QuestView, order: number)
	local done = quest.progress >= quest.target
	local frame = Kit.new("Frame", {
		BackgroundColor3 = Kit.Colors.PanelLight,
		Size = UDim2.new(1, -8, 0, 72),
		LayoutOrder = order,
		Parent = list,
	}, { Kit.corner(12) })
	Kit.label({
		Text = quest.text,
		Position = UDim2.fromOffset(12, 6),
		Size = UDim2.new(1, -200, 0, 26),
		TextXAlignment = Enum.TextXAlignment.Left,
		MaxTextSize = 24,
		Parent = frame,
	})
	-- Progress bar
	local bar = Kit.new("Frame", {
		BackgroundColor3 = Kit.Colors.Panel,
		Position = UDim2.fromOffset(12, 40),
		Size = UDim2.new(1, -330, 0, 20),
		Parent = frame,
	}, { Kit.corner(10) })
	Kit.new("Frame", {
		BackgroundColor3 = if done then Kit.Colors.Green else Kit.Colors.Pink,
		Size = UDim2.fromScale(math.clamp(quest.progress / quest.target, 0, 1), 1),
		Parent = bar,
	}, { Kit.corner(10) })
	Kit.label({
		Text = `{quest.progress}/{quest.target}`,
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -200, 0, 38),
		Size = UDim2.fromOffset(110, 24),
		Font = Kit.BodyFont,
		MaxTextSize = 18,
		Parent = frame,
	})
	Kit.label({
		Text = `+{quest.reward}`,
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -150, 0, 6),
		Size = UDim2.fromOffset(90, 26),
		TextColor3 = Kit.Colors.Gold,
		MaxTextSize = 22,
		Parent = frame,
	})
	local text, color, clickable
	if quest.claimed then
		text, color, clickable = "Claimed", Kit.Colors.Grey, false
	elseif done then
		text, color, clickable = "Claim!", Kit.Colors.Green, true
	else
		text, color, clickable = "In progress", Kit.Colors.Panel, false
	end
	Kit.button(
		{
			Text = text,
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, -10, 0.5, 0),
			Size = UDim2.fromOffset(130, 50),
			BackgroundColor3 = color,
			AutoButtonColor = clickable,
			MaxTextSize = 20,
			Parent = frame,
		},
		if clickable
			then function()
				Remotes.Events.ClaimQuest:FireServer(quest.kind, quest.id)
			end
			else nil
	)
end

local function rebuild()
	for _, child in list:GetChildren() do
		if child:IsA("GuiObject") then
			child:Destroy()
		end
	end
	for kind, button in tabButtons do
		button.BackgroundColor3 = if kind == currentKind then Kit.Colors.Pink else Kit.Colors.PanelLight
	end
	local data = State.data
	if not data then
		return
	end
	local order = 0
	for _, quest in data.quests do
		if quest.kind == currentKind then
			-- Claimable first, then in progress, then already claimed.
			local rank = if quest.claimed then 2 elseif quest.progress >= quest.target then 0 else 1
			order += 1
			row(quest, rank * 100 + order)
		end
	end
end

function QuestsUI.open()
	if not State.canUseLobby() then
		return
	end
	rebuild()
	panel.Visible = true
end

function QuestsUI.start()
	local _, root = Kit.screen("Quests", 5)
	panel = Kit.panel({
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.new(0.9, 0, 0.9, 0),
		Visible = false,
		Parent = root,
	})
	Kit.label({
		Text = "QUESTS",
		Position = UDim2.fromOffset(14, 8),
		Size = UDim2.fromOffset(200, 40),
		TextColor3 = Kit.Colors.Pink,
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = panel,
	})
	Kit.button({
		Text = "Close",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -8, 0, 8),
		Size = UDim2.fromOffset(110, Kit.ButtonHeight - 10),
		BackgroundColor3 = Kit.Colors.Grey,
		Parent = panel,
	}, function()
		panel.Visible = false
	end)
	local tabs = Kit.new("Frame", {
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(8, 58),
		Size = UDim2.new(1, -16, 0, 48),
		Parent = panel,
	}, { Kit.list(Enum.FillDirection.Horizontal, 8) })
	for index, spec in { { "daily", "Daily (resets every day)" }, { "achievement", "Achievements" } } do
		local kind = spec[1]
		tabButtons[kind] = Kit.button({
			Text = spec[2],
			Size = UDim2.fromOffset(if index == 1 then 280 else 200, 44),
			BackgroundColor3 = Kit.Colors.PanelLight,
			LayoutOrder = index,
			MaxTextSize = 20,
			Parent = tabs,
		}, function()
			currentKind = kind
			rebuild()
		end)
	end
	list = Kit.new("ScrollingFrame", {
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(8, 112),
		Size = UDim2.new(1, -16, 1, -120),
		CanvasSize = UDim2.new(0, 0, 0, 0),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollingDirection = Enum.ScrollingDirection.Y,
		ScrollBarThickness = 6,
		Parent = panel,
	}, { Kit.list(Enum.FillDirection.Vertical, 8) })

	State.DataChanged:Connect(function()
		if panel.Visible then
			rebuild()
		end
	end)
	State.RoundChanged:Connect(function(round)
		if not State.canUseLobby() then
			panel.Visible = false
		end
	end)
end

return QuestsUI
