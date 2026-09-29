--!strict
-- Walk-in booths (Skin Tones, Body Types). Every booth has a "Zone" part with a BoothPanel
-- attribute. While my character stands inside a zone, its panel is open; walking out closes it.
-- Picks are sent to the server, which checks, saves and applies them.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local State = require(script.Parent.Parent.State)
local Kit = require(script.Parent.Kit)

local BoothsUI = {}

local zones: { BasePart } = {}
local panels: { [string]: Frame } = {}
local openPanel: string? = nil
local skinButtons: { TextButton } = {}
local bodyButtons: { [string]: TextButton } = {}

local function trackZone(instance: Instance)
	if instance:IsA("BasePart") and instance:GetAttribute("BoothPanel") then
		table.insert(zones, instance)
	end
end

-- Which booth panel my character is standing in right now (if any).
local function zoneUnderMe(): string?
	local character = State.player.Character
	local root = if character then character:FindFirstChild("HumanoidRootPart") else nil
	if not root or not root:IsA("BasePart") then
		return nil
	end
	for _, zone in zones do
		if zone.Parent then
			local radius = zone:GetAttribute("Radius")
			local r = if type(radius) == "number" then radius else 5
			local offset = root.Position - zone.Position
			if Vector3.new(offset.X, 0, offset.Z).Magnitude <= r and offset.Y > -2 and offset.Y < 10 then
				local panel = zone:GetAttribute("BoothPanel")
				return if type(panel) == "string" then panel else nil
			end
		end
	end
	return nil
end

local function highlight()
	local data = State.data
	if not data then
		return
	end
	for index, button in skinButtons do
		local stroke = button:FindFirstChildOfClass("UIStroke")
		if stroke then
			stroke.Color = if data.skinTone == index then Kit.Colors.Gold else Color3.new(0, 0, 0)
			stroke.Thickness = if data.skinTone == index then 4 else 1.5
		end
	end
	for id, button in bodyButtons do
		button.BackgroundColor3 = if data.bodyType == id then Kit.Colors.Pink else Kit.Colors.PanelLight
	end
end

local function makePanel(root: Frame, name: string, title: string): (Frame, ScrollingFrame)
	local panel = Kit.panel({
		Name = name,
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -8, 0.5, 0),
		Size = UDim2.new(0.4, 0, 0.8, 0),
		Visible = false,
		Parent = root,
	})
	Kit.label({
		Text = title,
		Position = UDim2.fromOffset(10, 8),
		Size = UDim2.new(1, -20, 0, 36),
		TextColor3 = Kit.Colors.Pink,
		Parent = panel,
	})
	Kit.label({
		Text = "Walk out of the booth to close",
		Position = UDim2.new(0, 10, 1, -26),
		Size = UDim2.new(1, -20, 0, 18),
		Font = Kit.BodyFont,
		TextColor3 = Kit.Colors.TextDim,
		MaxTextSize = 14,
		Parent = panel,
	})
	local grid = Kit.new("ScrollingFrame", {
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(10, 50),
		Size = UDim2.new(1, -20, 1, -84),
		CanvasSize = UDim2.new(0, 0, 0, 0),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollBarThickness = 6,
		Parent = panel,
	})
	panels[name] = panel
	return panel, grid
end

local function buildSkinPanel(root: Frame)
	local _, grid = makePanel(root, "SkinTone", "SKIN TONES")
	Kit.new("UIGridLayout", {
		CellSize = UDim2.fromOffset(64, 64),
		CellPadding = UDim2.fromOffset(10, 10),
		SortOrder = Enum.SortOrder.LayoutOrder,
		Parent = grid,
	})
	Kit.button({
		Text = "Mine",
		BackgroundColor3 = Kit.Colors.Grey,
		LayoutOrder = 0,
		MaxTextSize = 18,
		Parent = grid,
	}, function()
		Remotes.Events.SetSkinTone:FireServer(0)
	end)
	for index, color in Config.SkinTones do
		local swatch = Kit.new("TextButton", {
			Text = "",
			BackgroundColor3 = color,
			AutoButtonColor = true,
			LayoutOrder = index,
			Parent = grid,
		}, {
			Kit.corner(32),
			Kit.new("UIStroke", { Thickness = 1.5, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }),
		})
		swatch.Activated:Connect(function()
			Kit.playSound("Click")
			Remotes.Events.SetSkinTone:FireServer(index)
		end)
		skinButtons[index] = swatch
	end
end

local function buildBodyPanel(root: Frame)
	local _, grid = makePanel(root, "BodyType", "BODY TYPES")
	Kit.list(Enum.FillDirection.Vertical, 8).Parent = grid
	local list = grid:FindFirstChildOfClass("UIListLayout")
	if list then
		list.VerticalAlignment = Enum.VerticalAlignment.Top
	end
	local mine = Kit.button({
		Text = "My own body",
		Size = UDim2.new(1, -8, 0, Kit.ButtonHeight),
		BackgroundColor3 = Kit.Colors.Grey,
		LayoutOrder = 0,
		Parent = grid,
	}, function()
		Remotes.Events.SetBodyType:FireServer("")
	end)
	bodyButtons[""] = mine
	for index, bodyType in Config.BodyTypes do
		bodyButtons[bodyType.id] = Kit.button({
			Text = bodyType.displayName,
			Size = UDim2.new(1, -8, 0, Kit.ButtonHeight),
			BackgroundColor3 = Kit.Colors.PanelLight,
			LayoutOrder = index,
			Parent = grid,
		}, function()
			Remotes.Events.SetBodyType:FireServer(bodyType.id)
		end)
	end
end

local function update()
	local want = if State.canUseLobby() and not State.dressingRoom then zoneUnderMe() else nil
	if want == openPanel then
		return
	end
	openPanel = want
	for name, panel in panels do
		panel.Visible = name == want
	end
	if want then
		highlight()
	end
end

function BoothsUI.start()
	local _, root = Kit.screen("Booths", 4)
	buildSkinPanel(root)
	buildBodyPanel(root)
	for _, descendant in Workspace:GetDescendants() do
		trackZone(descendant)
	end
	Workspace.DescendantAdded:Connect(trackZone)
	State.DataChanged:Connect(highlight)
	task.spawn(function()
		while true do
			task.wait(0.15)
			update()
		end
	end)
end

return BoothsUI
