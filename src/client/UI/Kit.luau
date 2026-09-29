--!strict
-- Small UI toolkit so every screen looks the same and works on phones.
--
-- Mobile-first trick: each ScreenGui has one "Root" frame drawn in DESIGN units (roughly 900x450,
-- a phone in landscape). A UIScale grows/shrinks it to fit the real screen, so a 56-unit button
-- stays thumb-sized on phones and doesn't look huge on a PC monitor.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage.Shared.Config)

local Kit = {}

Kit.Colors = {
	Pink = Color3.fromRGB(255, 110, 180),
	PinkDark = Color3.fromRGB(200, 60, 135),
	Panel = Color3.fromRGB(35, 30, 50),
	PanelLight = Color3.fromRGB(58, 50, 80),
	Text = Color3.fromRGB(255, 255, 255),
	TextDim = Color3.fromRGB(200, 190, 220),
	Gold = Color3.fromRGB(255, 210, 80),
	Green = Color3.fromRGB(80, 200, 120),
	Blue = Color3.fromRGB(80, 150, 255),
	Grey = Color3.fromRGB(110, 105, 125),
}
Kit.Font = Enum.Font.FredokaOne
Kit.BodyFont = Enum.Font.GothamBold
Kit.ButtonHeight = 56 -- design units; ~48pt on a phone, comfortable for thumbs

local DESIGN_WIDTH = 900
local DESIGN_HEIGHT = 450

export type Props = { [string]: any }

-- Create an instance with properties and children in one call.
function Kit.new(className: string, props: Props?, children: { any }?): any
	local instance = Instance.new(className)
	if props then
		for key, value in props do
			if key ~= "Parent" then
				(instance :: any)[key] = value
			end
		end
	end
	if children then
		for _, child in children do
			child.Parent = instance
		end
	end
	if props and props.Parent then
		instance.Parent = props.Parent
	end
	return instance
end

function Kit.corner(radius: number?): Instance
	return Kit.new("UICorner", { CornerRadius = UDim.new(0, radius or 12) })
end

function Kit.stroke(color: Color3?, thickness: number?): Instance
	return Kit.new("UIStroke", {
		Color = color or Color3.new(0, 0, 0),
		Thickness = thickness or 2,
		Transparency = 0.3,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
	})
end

function Kit.padding(pixels: number): Instance
	local p = UDim.new(0, pixels)
	return Kit.new("UIPadding", { PaddingTop = p, PaddingBottom = p, PaddingLeft = p, PaddingRight = p })
end

function Kit.list(direction: Enum.FillDirection, spacing: number, align: Enum.HorizontalAlignment?): Instance
	return Kit.new("UIListLayout", {
		FillDirection = direction,
		Padding = UDim.new(0, spacing),
		SortOrder = Enum.SortOrder.LayoutOrder,
		HorizontalAlignment = align or Enum.HorizontalAlignment.Left,
		VerticalAlignment = Enum.VerticalAlignment.Center,
	})
end

function Kit.label(props: Props): TextLabel
	local merged: Props = {
		BackgroundTransparency = 1,
		Font = Kit.Font,
		TextColor3 = Kit.Colors.Text,
		TextScaled = true,
		Text = "",
	}
	for key, value in props do
		if key ~= "MaxTextSize" then -- ours, not a real TextLabel property
			merged[key] = value
		end
	end
	local label = Kit.new("TextLabel", merged)
	Kit.new(
		"UITextSizeConstraint",
		{ MaxTextSize = props.MaxTextSize or 40, MinTextSize = 10, Parent = label }
	)
	Kit.new("UIStroke", { Thickness = 1.5, Transparency = 0.4, Parent = label })
	return label
end

function Kit.playSound(key: string)
	local id = Config.Sounds[key]
	if not id or id == 0 then
		return
	end
	local soundId = if type(id) == "string" then id else `rbxassetid://{id}`
	local sound = Kit.new("Sound", { SoundId = soundId, Volume = 0.6, Parent = SoundService })
	sound.Ended:Once(function()
		sound:Destroy()
	end)
	sound:Play()
end

-- Big, rounded, thumb-friendly button. onClick is wired for mouse, touch and gamepad.
function Kit.button(props: Props, onClick: (() -> ())?): TextButton
	local merged: Props = {
		BackgroundColor3 = Kit.Colors.Pink,
		Font = Kit.Font,
		TextColor3 = Kit.Colors.Text,
		TextScaled = true,
		AutoButtonColor = true,
		Size = UDim2.new(0, 160, 0, Kit.ButtonHeight),
		Text = "",
	}
	for key, value in props do
		if key ~= "MaxTextSize" then -- ours, not a real TextButton property
			merged[key] = value
		end
	end
	local button = Kit.new("TextButton", merged, {
		Kit.corner(14),
		Kit.stroke(Color3.new(0, 0, 0), 2),
		Kit.padding(8),
	})
	Kit.new(
		"UITextSizeConstraint",
		{ MaxTextSize = props.MaxTextSize or 28, MinTextSize = 10, Parent = button }
	)
	-- Soft top-to-bottom shine.
	Kit.new("UIGradient", {
		Rotation = 90,
		Color = ColorSequence.new(Color3.new(1, 1, 1), Color3.fromRGB(205, 205, 215)),
		Parent = button,
	})
	-- Squish on press, grow a touch on hover: makes every button feel alive.
	local scale = Kit.new("UIScale", { Parent = button })
	local function tweenTo(value: number)
		TweenService:Create(scale, TweenInfo.new(0.08, Enum.EasingStyle.Quad), { Scale = value }):Play()
	end
	button.MouseEnter:Connect(function()
		tweenTo(1.04)
	end)
	button.MouseLeave:Connect(function()
		tweenTo(1)
	end)
	button.MouseButton1Down:Connect(function()
		tweenTo(0.93)
	end)
	button.MouseButton1Up:Connect(function()
		tweenTo(1)
	end)
	if onClick then
		button.Activated:Connect(function()
			Kit.playSound("Click")
			onClick()
		end)
	end
	return button
end

function Kit.panel(props: Props): Frame
	local merged: Props = {
		BackgroundColor3 = Kit.Colors.Panel,
		BackgroundTransparency = 0.1,
		BorderSizePixel = 0,
	}
	for key, value in props do
		merged[key] = value
	end
	return Kit.new("Frame", merged, {
		Kit.corner(16),
		Kit.stroke(Kit.Colors.Pink, 2),
		Kit.new("UIGradient", {
			Rotation = 90,
			Color = ColorSequence.new(Color3.new(1, 1, 1), Color3.fromRGB(175, 165, 195)),
		}),
	})
end

-- A ScreenGui plus a scaled Root frame that always covers the whole screen.
function Kit.screen(name: string, displayOrder: number?): (ScreenGui, Frame)
	local playerGui = (Players.LocalPlayer :: Player):WaitForChild("PlayerGui")
	local gui = Kit.new("ScreenGui", {
		Name = name,
		ResetOnSpawn = false,
		IgnoreGuiInset = false,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		DisplayOrder = displayOrder or 0,
		Parent = playerGui,
	})
	local root = Kit.new("Frame", { Name = "Root", BackgroundTransparency = 1, Parent = gui })
	local scale = Kit.new("UIScale", { Parent = root })

	local function update()
		local size = gui.AbsoluteSize
		if size.X <= 0 or size.Y <= 0 then
			local camera = Workspace.CurrentCamera
			size = if camera then camera.ViewportSize else Vector2.new(DESIGN_WIDTH, DESIGN_HEIGHT)
		end
		local s = math.clamp(math.min(size.X / DESIGN_WIDTH, size.Y / DESIGN_HEIGHT), 0.8, 1.6)
		scale.Scale = s
		-- Undo the scale on the root's own size so it still fills the screen exactly.
		root.Size = UDim2.fromScale(1 / s, 1 / s)
	end
	gui:GetPropertyChangedSignal("AbsoluteSize"):Connect(update)
	update()
	return gui, root
end

function Kit.formatTime(seconds: number): string
	seconds = math.max(0, math.ceil(seconds))
	return string.format("%d:%02d", seconds // 60, seconds % 60)
end

-- Catalog thumbnail URLs (no web calls needed; Roblox resolves these itself).
function Kit.assetThumb(assetId: number): string
	return `rbxthumb://type=Asset&id={assetId}&w=150&h=150`
end

function Kit.bundleThumb(bundleId: number): string
	return `rbxthumb://type=BundleThumbnail&id={bundleId}&w=150&h=150`
end

return Kit
