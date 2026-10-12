--!strict
-- Reusable building blocks for the premium-fashion UI (see Theme.luau).
--
-- Layout rule: sizes and positions use Scale, with UISizeConstraint / UITextSizeConstraint so things
-- stay readable on phones and don't balloon on 4K. Offsets are only used for padding and strokes.
-- Every button is a real TextButton wired through .Activated (mouse, touch and gamepad).

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")

local Kit = require(script.Parent.Kit)
local Theme = require(script.Parent.Theme)

local Components = {}

export type Props = { [string]: any }
export type ButtonVariant = "Primary" | "Secondary" | "Special"
-- Normal: usable. Active: selected / equipped (cyan glow). Disabled: greyed, ignores taps.
-- Locked: like Disabled, with a lock glyph. Hover and Pressed are handled automatically.
export type ButtonState = "Normal" | "Active" | "Disabled" | "Locked"

export type ButtonHandle = {
	instance: TextButton,
	state: ButtonState,
	setState: (self: ButtonHandle, state: ButtonState) -> (),
	setText: (self: ButtonHandle, text: string) -> (),
}

export type PillHandle = {
	instance: Frame,
	icon: ImageLabel,
	setValue: (self: PillHandle, text: string) -> (),
	setProgress: (self: PillHandle, fraction: number?) -> (),
}

local new = Kit.new

function Components.corner(radius: number?): Instance
	return new("UICorner", { CornerRadius = UDim.new(0, radius or Theme.Radius) })
end

function Components.stroke(color: Color3?, thickness: number?, transparency: number?): Instance
	return new("UIStroke", {
		Color = color or Theme.Colors.Stroke,
		Thickness = thickness or Theme.StrokeThickness,
		Transparency = transparency or 0,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
	})
end

function Components.padding(top: number, side: number?): Instance
	local s = UDim.new(0, side or top)
	return new("UIPadding", {
		PaddingTop = UDim.new(0, top),
		PaddingBottom = UDim.new(0, top),
		PaddingLeft = s,
		PaddingRight = s,
	})
end

function Components.list(
	direction: Enum.FillDirection,
	spacing: number,
	hAlign: Enum.HorizontalAlignment?,
	vAlign: Enum.VerticalAlignment?
): UIListLayout
	return new("UIListLayout", {
		FillDirection = direction,
		Padding = UDim.new(0, spacing),
		HorizontalAlignment = hAlign or Enum.HorizontalAlignment.Center,
		VerticalAlignment = vAlign or Enum.VerticalAlignment.Center,
		SortOrder = Enum.SortOrder.LayoutOrder,
	})
end

function Components.sizeLimit(minSize: Vector2?, maxSize: Vector2?): Instance
	return new("UISizeConstraint", {
		MinSize = minSize or Vector2.zero,
		MaxSize = maxSize or Vector2.new(math.huge, math.huge),
	})
end

-- ScreenGui that stays clear of notches and the Roblox top bar.
function Components.screen(name: string, displayOrder: number?): ScreenGui
	local playerGui = (Players.LocalPlayer :: Player):WaitForChild("PlayerGui")
	return new("ScreenGui", {
		Name = name,
		ResetOnSpawn = false,
		IgnoreGuiInset = false,
		ScreenInsets = Enum.ScreenInsets.CoreUISafeInsets,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		DisplayOrder = displayOrder or 0,
		Parent = playerGui,
	})
end

-- Text that scales with its box but never gets tiny or huge. Extra props: MaxTextSize, MinTextSize.
function Components.text(props: Props): TextLabel
	local merged: Props = {
		BackgroundTransparency = 1,
		FontFace = Theme.Fonts.Body,
		TextColor3 = Theme.Colors.Text,
		TextScaled = true,
		Text = "",
	}
	for key, value in props do
		if key ~= "MaxTextSize" and key ~= "MinTextSize" then
			merged[key] = value
		end
	end
	local label = new("TextLabel", merged)
	new("UITextSizeConstraint", {
		MaxTextSize = props.MaxTextSize or 32,
		MinTextSize = props.MinTextSize or 12,
		Parent = label,
	})
	return label
end

-- Dark rounded panel. Extra prop: Raised (lighter background).
function Components.panel(props: Props): Frame
	local merged: Props = {
		BackgroundColor3 = if props.Raised then Theme.Colors.PanelRaised else Theme.Colors.Panel,
		BackgroundTransparency = 0.04,
		BorderSizePixel = 0,
	}
	for key, value in props do
		if key ~= "Raised" then
			merged[key] = value
		end
	end
	return new("Frame", merged, {
		Components.corner(Theme.RadiusLarge),
		Components.stroke(Theme.Colors.Stroke),
	})
end

---------------------------------------------------------------------------------------------------
-- Buttons
---------------------------------------------------------------------------------------------------

type Look = { bg: Color3, text: Color3, stroke: Color3, strokeThickness: number }

local function lookFor(variant: ButtonVariant, state: ButtonState, hovered: boolean): Look
	local c = Theme.Colors
	if state == "Disabled" or state == "Locked" then
		return { bg = c.Disabled, text = c.DisabledText, stroke = c.Stroke, strokeThickness = 1 }
	elseif state == "Active" then
		return { bg = c.Panel, text = c.Primary, stroke = c.Primary, strokeThickness = 2.5 }
	elseif variant == "Primary" then
		return {
			bg = if hovered then c.Primary:Lerp(c.Text, 0.25) else c.Primary,
			text = c.PrimaryText,
			stroke = c.PrimaryDark,
			strokeThickness = 2,
		}
	elseif variant == "Special" then
		return {
			bg = if hovered then c.PanelRaised else c.Panel,
			text = c.Primary,
			stroke = c.Primary,
			strokeThickness = if hovered then 2.5 else 1.5,
		}
	end
	return {
		bg = if hovered then c.SecondaryHover else c.Secondary,
		text = if hovered then c.Text else c.Silver,
		stroke = if hovered then c.Primary else c.Stroke,
		strokeThickness = Theme.StrokeThickness,
	}
end

-- options: Text, Variant, State, onClick, MaxTextSize, plus any TextButton props (Size, Position,
-- LayoutOrder, Name, Parent...). Taps are ignored while Disabled or Locked.
function Components.button(options: Props): ButtonHandle
	local variant: ButtonVariant = options.Variant or "Secondary"
	local onClick: (() -> ())? = options.onClick
	local props: Props = {
		AutoButtonColor = false,
		BorderSizePixel = 0,
		FontFace = Theme.Fonts.Button,
		TextScaled = true,
		Text = "",
		Size = UDim2.fromScale(0.2, 0.1),
	}
	for key, value in options do
		if key ~= "Variant" and key ~= "State" and key ~= "onClick" and key ~= "MaxTextSize" then
			props[key] = value
		end
	end
	local button: TextButton = new("TextButton", props)
	local stroke = Components.stroke() :: UIStroke
	stroke.Parent = button
	Components.corner(Theme.Radius).Parent = button
	Components.padding(4, 12).Parent = button
	Components.sizeLimit(Vector2.new(Theme.MinTouch, Theme.MinTouch)).Parent = button
	new(
		"UITextSizeConstraint",
		{ MaxTextSize = options.MaxTextSize or 18, MinTextSize = 11, Parent = button }
	)
	-- Subtle top sheen so buttons read as chunky/raised.
	new("UIGradient", {
		Rotation = 90,
		Color = ColorSequence.new(Color3.new(1, 1, 1), Color3.fromRGB(200, 200, 205)),
		Parent = button,
	})
	local scale = new("UIScale", { Parent = button }) :: UIScale

	local label = options.Text or ""
	local hovered = false
	local focused = false -- gamepad / keyboard selection
	local handle = {} :: ButtonHandle
	handle.instance = button
	handle.state = options.State or "Normal"

	local function paint()
		local look = lookFor(variant, handle.state, hovered)
		TweenService:Create(button, Theme.Tween, { BackgroundColor3 = look.bg, TextColor3 = look.text })
			:Play()
		-- Focus ring: white and thick, so it reads without relying on colour alone.
		stroke.Color = if focused then Theme.Colors.Text else look.stroke
		stroke.Thickness = if focused then 3 else look.strokeThickness
		button.Text = if handle.state == "Locked" then `🔒 {label}` else label
	end
	local function scaleTo(value: number)
		TweenService:Create(scale, Theme.Tween, { Scale = value }):Play()
	end
	local function usable(): boolean
		return handle.state ~= "Disabled" and handle.state ~= "Locked"
	end

	function handle.setState(self: ButtonHandle, state: ButtonState)
		self.state = state
		button.Selectable = usable()
		button.Active = usable()
		paint()
	end
	function handle.setText(_self: ButtonHandle, text: string)
		label = text
		paint()
	end

	button.SelectionGained:Connect(function()
		focused = true
		paint()
	end)
	button.SelectionLost:Connect(function()
		focused = false
		paint()
	end)
	button.MouseEnter:Connect(function()
		hovered = usable()
		paint()
		if hovered then
			scaleTo(1.03)
		end
	end)
	button.MouseLeave:Connect(function()
		hovered = false
		paint()
		scaleTo(1)
	end)
	button.MouseButton1Down:Connect(function()
		if usable() then
			scaleTo(0.94)
		end
	end)
	button.MouseButton1Up:Connect(function()
		scaleTo(if hovered then 1.03 else 1)
	end)
	button.Activated:Connect(function()
		if not usable() then
			return
		end
		Kit.playSound("Click")
		if onClick then
			onClick()
		end
	end)

	handle:setState(handle.state)
	return handle
end

---------------------------------------------------------------------------------------------------
-- Stat pill (coins, XP): icon + value, optional progress bar along the bottom.
---------------------------------------------------------------------------------------------------

-- options: Glyph (placeholder text shown until Image is set), Image (rbxassetid), IconColor,
-- plus Frame props (Size, LayoutOrder, Parent...).
function Components.statPill(options: Props): PillHandle
	local props: Props = {
		BackgroundColor3 = Theme.Colors.Panel,
		BackgroundTransparency = 0.04,
		BorderSizePixel = 0,
	}
	for key, value in options do
		if key ~= "Glyph" and key ~= "Image" and key ~= "IconColor" then
			props[key] = value
		end
	end
	local pill: Frame = new("Frame", props, {
		Components.corner(Theme.Radius),
		Components.stroke(Theme.Colors.Stroke),
	})
	local iconColor: Color3 = options.IconColor or Theme.Colors.Primary
	-- Placeholder icon: a coloured disc with a glyph. Set Icon.Image to a real PNG later and the
	-- glyph hides itself.
	local icon: ImageLabel = new("ImageLabel", {
		Name = "Icon",
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 6, 0.5, 0),
		Size = UDim2.fromScale(0.7, 0.7),
		SizeConstraint = Enum.SizeConstraint.RelativeYY,
		BackgroundColor3 = iconColor,
		BackgroundTransparency = 0,
		Image = options.Image or "",
		Parent = pill,
	}, { Components.corner(999) })
	local glyph = Components.text({
		Name = "Glyph",
		Size = UDim2.fromScale(1, 1),
		FontFace = Theme.Fonts.Heading,
		TextColor3 = Theme.Colors.PrimaryText,
		Text = options.Glyph or "",
		MaxTextSize = 14,
		MinTextSize = 8,
		Parent = icon,
	})
	local function syncGlyph()
		glyph.Visible = icon.Image == ""
		icon.BackgroundTransparency = if icon.Image == "" then 0 else 1
	end
	icon:GetPropertyChangedSignal("Image"):Connect(syncGlyph)
	syncGlyph()

	local value = Components.text({
		Name = "Value",
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0.3, 4, 0.5, 0),
		Size = UDim2.new(0.7, -12, 0.6, 0),
		FontFace = Theme.Fonts.Number,
		TextXAlignment = Enum.TextXAlignment.Left,
		Text = "...",
		MaxTextSize = 18,
		Parent = pill,
	})
	local barBack = new("Frame", {
		Name = "Progress",
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0.3, 4, 1, -5),
		Size = UDim2.new(0.7, -14, 0, 4),
		BackgroundColor3 = Theme.Colors.Stroke,
		BorderSizePixel = 0,
		Visible = false,
		Parent = pill,
	}, { Components.corner(2) })
	local barFill = new("Frame", {
		Size = UDim2.fromScale(0, 1),
		BackgroundColor3 = iconColor,
		BorderSizePixel = 0,
		Parent = barBack,
	}, { Components.corner(2) })

	local handle = {} :: PillHandle
	handle.instance = pill
	handle.icon = icon
	function handle.setValue(_self: PillHandle, text: string)
		value.Text = text
	end
	function handle.setProgress(_self: PillHandle, fraction: number?)
		barBack.Visible = fraction ~= nil
		-- Lift the number above the bar so they never overlap.
		value.Position = UDim2.new(0.3, 4, if fraction then 0.42 else 0.5, 0)
		value.Size = UDim2.new(0.7, -12, if fraction then 0.5 else 0.6, 0)
		if fraction then
			TweenService
				:Create(barFill, Theme.Tween, { Size = UDim2.fromScale(math.clamp(fraction, 0, 1), 1) })
				:Play()
		end
	end
	return handle
end

---------------------------------------------------------------------------------------------------
-- On/off switch row for settings.
---------------------------------------------------------------------------------------------------

-- options: Text, Value, onChanged(value), plus Frame props.
function Components.toggle(options: Props): Frame
	local props: Props = { BackgroundTransparency = 1 }
	for key, value in options do
		if key ~= "Text" and key ~= "Value" and key ~= "onChanged" then
			props[key] = value
		end
	end
	local row: Frame = new("Frame", props)
	Components.text({
		Text = options.Text or "",
		Size = UDim2.fromScale(0.65, 0.8),
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.fromScale(0, 0.5),
		FontFace = Theme.Fonts.Button,
		TextColor3 = Theme.Colors.Silver,
		TextXAlignment = Enum.TextXAlignment.Left,
		MaxTextSize = 18,
		Parent = row,
	})
	local on: boolean = options.Value == true
	local switch: TextButton = new("TextButton", {
		Name = "Switch",
		Text = "",
		AutoButtonColor = false,
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.fromScale(1, 0.5),
		Size = UDim2.fromScale(0.3, 0.9),
		BorderSizePixel = 0,
		Parent = row,
	}, {
		Components.corner(999),
		Components.stroke(Theme.Colors.Stroke),
		Components.sizeLimit(Vector2.new(64, Theme.MinTouch), Vector2.new(96, 52)),
	})
	local knob: Frame = new("Frame", {
		AnchorPoint = Vector2.new(0, 0.5),
		Size = UDim2.fromScale(0.42, 0.78),
		BackgroundColor3 = Theme.Colors.Text,
		BorderSizePixel = 0,
		Parent = switch,
	}, { Components.corner(999) })
	local function paint(animate: boolean)
		local goalPos = if on then UDim2.fromScale(0.54, 0.5) else UDim2.fromScale(0.04, 0.5)
		local goalColor = if on then Theme.Colors.Primary else Theme.Colors.Secondary
		if animate then
			TweenService:Create(knob, Theme.Tween, { Position = goalPos }):Play()
			TweenService:Create(switch, Theme.Tween, { BackgroundColor3 = goalColor }):Play()
		else
			knob.Position = goalPos
			switch.BackgroundColor3 = goalColor
		end
	end
	switch.Activated:Connect(function()
		on = not on
		paint(true)
		Kit.playSound("Click")
		if options.onChanged then
			options.onChanged(on)
		end
	end)
	paint(false)
	return row
end

return Components
