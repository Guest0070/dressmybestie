--!strict
-- Reusable building blocks for the premium-fashion UI (see Theme.luau).
--
-- Layout rule: sizes and positions use Scale, with UISizeConstraint / UITextSizeConstraint so things
-- stay readable on phones and don't balloon on 4K. Offsets are only used for padding and strokes.
-- Every button is a real TextButton wired through .Activated (mouse, touch and gamepad).

local Players = game:GetService("Players")
local StarterGui = game:GetService("StarterGui")
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
	local stroke = Components.stroke(Color3.new(1, 1, 1))
	-- Raised cards inside a panel keep a quiet border; top-level panels get the brand sheen.
	if props.Raised then
		(stroke :: UIStroke).Color = Theme.Colors.Stroke
	else
		new("UIGradient", { Color = Theme.Gradient, Rotation = 30, Parent = stroke })
	end
	return new("Frame", merged, {
		Components.corner(Theme.RadiusLarge),
		stroke,
	})
end

---------------------------------------------------------------------------------------------------
-- Buttons
---------------------------------------------------------------------------------------------------

type Look = { bg: Color3, text: Color3, stroke: Color3, strokeThickness: number }

-- Starting colours for a freshly built button of each variant.
local function variantLook(variant: ButtonVariant): Look
	local c = Theme.Colors
	if variant == "Primary" then
		return { bg = c.Primary, text = c.PrimaryText, stroke = c.PrimaryDark, strokeThickness = 2 }
	elseif variant == "Special" then
		return { bg = c.Panel, text = c.Primary, stroke = c.Primary, strokeThickness = 1.5 }
	end
	return { bg = c.Secondary, text = c.Silver, stroke = c.Stroke, strokeThickness = Theme.StrokeThickness }
end

-- Creates a styled TextButton (no behaviour). Pair with attachButton, or use Components.button.
-- options: Text, Variant, MaxTextSize, plus any TextButton props (Size, Position, Name, Parent...).
function Components.styleButton(options: Props): TextButton
	local look = variantLook(options.Variant or "Secondary")
	local props: Props = {
		AutoButtonColor = false,
		BorderSizePixel = 0,
		FontFace = Theme.Fonts.Button,
		TextScaled = true,
		Text = "",
		Size = UDim2.fromScale(0.2, 0.1),
		BackgroundColor3 = look.bg,
		TextColor3 = look.text,
	}
	for key, value in options do
		if key ~= "Variant" and key ~= "State" and key ~= "onClick" and key ~= "MaxTextSize" then
			props[key] = value
		end
	end
	local button: TextButton = new("TextButton", props)
	Components.stroke(look.stroke, look.strokeThickness).Parent = button
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
	return button
end

-- Adds hover / press / focus / state behaviour to any TextButton, including one you designed in
-- Studio. Its current colours become the Normal look, so edits made in Studio are kept.
-- Taps are ignored while Disabled or Locked.
function Components.attachButton(button: TextButton, onClick: (() -> ())?, state: ButtonState?): ButtonHandle
	button.AutoButtonColor = false
	local existing = button:FindFirstChildOfClass("UIStroke")
	local strokeRef: UIStroke = if existing
		then existing
		else Components.stroke(button.BackgroundColor3, 0) :: UIStroke
	strokeRef.Parent = button
	local scale = button:FindFirstChildOfClass("UIScale") or new("UIScale", { Parent = button }) :: UIScale
	scale.Scale = 1
	local normal: Look = {
		bg = button.BackgroundColor3,
		text = button.TextColor3,
		stroke = strokeRef.Color,
		strokeThickness = strokeRef.Thickness,
	}

	local label = button.Text
	local hovered = false
	local focused = false -- gamepad / keyboard selection
	local handle = {} :: ButtonHandle
	handle.instance = button
	handle.state = state or "Normal"

	local function lookNow(): Look
		local c = Theme.Colors
		if handle.state == "Disabled" or handle.state == "Locked" then
			return { bg = c.Disabled, text = c.DisabledText, stroke = c.Stroke, strokeThickness = 1 }
		elseif handle.state == "Active" then
			return { bg = c.Panel, text = c.Primary, stroke = c.Primary, strokeThickness = 2.5 }
		elseif hovered then
			return {
				bg = normal.bg:Lerp(c.Text, 0.15),
				text = normal.text,
				stroke = normal.stroke,
				strokeThickness = normal.strokeThickness + 1,
			}
		end
		return normal
	end
	local function paint()
		local look = lookNow()
		TweenService:Create(button, Theme.Tween, { BackgroundColor3 = look.bg, TextColor3 = look.text })
			:Play()
		-- Focus ring: white and thick, so it reads without relying on colour alone.
		strokeRef.Color = if focused then Theme.Colors.Text else look.stroke
		strokeRef.Thickness = if focused then 3 else look.strokeThickness
		button.Text = if handle.state == "Locked" then `🔒 {label}` else label
	end
	local function scaleTo(value: number)
		TweenService:Create(scale, Theme.Tween, { Scale = value }):Play()
	end
	local function usable(): boolean
		return handle.state ~= "Disabled" and handle.state ~= "Locked"
	end

	function handle.setState(self: ButtonHandle, newState: ButtonState)
		self.state = newState
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

-- Styled + working button in one call. options: as styleButton, plus onClick and State.
function Components.button(options: Props): ButtonHandle
	return Components.attachButton(Components.styleButton(options), options.onClick, options.State)
end

---------------------------------------------------------------------------------------------------
-- Stat pill (coins, XP): icon + value, optional progress bar along the bottom.
---------------------------------------------------------------------------------------------------

-- Creates the pill instances (no behaviour). options: Glyph (placeholder text shown until Image is
-- set), Image (rbxassetid), IconColor, HasProgress, plus Frame props (Size, Name, Parent...).
function Components.styleStatPill(options: Props): Frame
	local props: Props = {
		BackgroundColor3 = Theme.Colors.Panel,
		BackgroundTransparency = 0.04,
		BorderSizePixel = 0,
	}
	for key, value in options do
		if key ~= "Glyph" and key ~= "Image" and key ~= "IconColor" and key ~= "HasProgress" then
			props[key] = value
		end
	end
	local pill: Frame = new("Frame", props, {
		Components.corner(Theme.Radius),
		Components.stroke(Theme.Colors.Stroke),
	})
	local iconColor: Color3 = options.IconColor or Theme.Colors.Primary
	-- Placeholder icon: a coloured disc with a glyph. Set Icon.Image to a real PNG and the glyph
	-- hides itself.
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
	Components.text({
		Name = "Glyph",
		Size = UDim2.fromScale(1, 1),
		FontFace = Theme.Fonts.Heading,
		TextColor3 = Theme.Colors.PrimaryText,
		Text = options.Glyph or "",
		MaxTextSize = 14,
		MinTextSize = 8,
		Parent = icon,
	})
	local hasProgress = options.HasProgress == true
	Components.text({
		Name = "Value",
		AnchorPoint = Vector2.new(0, 0.5),
		-- With a progress bar the number sits a little higher so they never overlap.
		Position = UDim2.new(0.3, 4, if hasProgress then 0.42 else 0.5, 0),
		Size = UDim2.new(0.7, -12, if hasProgress then 0.5 else 0.6, 0),
		FontFace = Theme.Fonts.Number,
		TextXAlignment = Enum.TextXAlignment.Left,
		Text = "...",
		MaxTextSize = 18,
		Parent = pill,
	})
	if hasProgress then
		local barBack = new("Frame", {
			Name = "Progress",
			AnchorPoint = Vector2.new(0, 1),
			Position = UDim2.new(0.3, 4, 1, -5),
			Size = UDim2.new(0.7, -14, 0, 4),
			BackgroundColor3 = Theme.Colors.Stroke,
			BorderSizePixel = 0,
			Parent = pill,
		}, { Components.corner(2) })
		new("Frame", {
			Name = "Fill",
			Size = UDim2.fromScale(0, 1),
			BackgroundColor3 = iconColor,
			BorderSizePixel = 0,
			Parent = barBack,
		}, { Components.corner(2) })
	end
	return pill
end

-- Wires a pill (built here or designed in Studio). Needs a TextLabel "Value"; optional ImageLabel
-- "Icon" (with TextLabel "Glyph") and Frame "Progress" (with Frame "Fill"). Nil if Value is missing.
function Components.attachStatPill(pill: Frame): PillHandle?
	local value = pill:FindFirstChild("Value", true)
	if not (value and value:IsA("TextLabel")) then
		return nil
	end
	local icon = pill:FindFirstChild("Icon", true)
	if icon and icon:IsA("ImageLabel") then
		local glyph = icon:FindFirstChild("Glyph")
		local tint = icon.BackgroundColor3
		local function syncGlyph()
			if glyph and glyph:IsA("GuiObject") then
				glyph.Visible = icon.Image == ""
			end
			icon.BackgroundTransparency = if icon.Image == "" then 0 else 1
			icon.BackgroundColor3 = tint
		end
		icon:GetPropertyChangedSignal("Image"):Connect(syncGlyph)
		syncGlyph()
	end
	local bar = pill:FindFirstChild("Progress", true)
	local fill = if bar then bar:FindFirstChild("Fill") else nil

	local handle = {} :: PillHandle
	handle.instance = pill
	function handle.setValue(_self: PillHandle, text: string)
		value.Text = text
	end
	function handle.setProgress(_self: PillHandle, fraction: number?)
		if bar and bar:IsA("GuiObject") then
			bar.Visible = fraction ~= nil
		end
		if fraction and fill and fill:IsA("GuiObject") then
			TweenService:Create(fill, Theme.Tween, { Size = UDim2.fromScale(math.clamp(fraction, 0, 1), 1) })
				:Play()
		end
	end
	return handle
end

function Components.statPill(options: Props): PillHandle
	return Components.attachStatPill(Components.styleStatPill(options)) :: PillHandle
end

---------------------------------------------------------------------------------------------------
-- On/off switch row for settings.
---------------------------------------------------------------------------------------------------

-- Creates a toggle row (no behaviour): a "Label" plus a "Switch" button holding a "Knob".
-- options: Text, plus Frame props.
function Components.styleToggle(options: Props): Frame
	local props: Props = { BackgroundTransparency = 1 }
	for key, value in options do
		if key ~= "Text" then
			props[key] = value
		end
	end
	local row: Frame = new("Frame", props)
	Components.text({
		Name = "Label",
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
	local switch: TextButton = new("TextButton", {
		Name = "Switch",
		Text = "",
		AutoButtonColor = false,
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.fromScale(1, 0.5),
		Size = UDim2.fromScale(0.3, 0.9),
		BackgroundColor3 = Theme.Colors.Secondary, -- the "off" colour
		BorderSizePixel = 0,
		Parent = row,
	}, {
		Components.corner(999),
		Components.stroke(Theme.Colors.Stroke),
		Components.sizeLimit(Vector2.new(64, Theme.MinTouch), Vector2.new(96, 52)),
	})
	new("Frame", {
		Name = "Knob",
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.fromScale(0.04, 0.5),
		Size = UDim2.fromScale(0.42, 0.78),
		BackgroundColor3 = Theme.Colors.Text,
		BorderSizePixel = 0,
		Parent = switch,
	}, { Components.corner(999) })
	return row
end

-- Makes a toggle row work (built here or designed in Studio). Needs a TextButton "Switch" with a
-- GuiObject "Knob" inside. The switch's current colour is the "off" colour; "on" is Theme Primary.
-- Returns false if the pieces are missing; otherwise true and a setter that moves the switch
-- without calling onChanged (e.g. when saved settings arrive).
function Components.attachToggle(
	row: Instance,
	value: boolean,
	onChanged: (boolean) -> ()
): (boolean, (boolean) -> ())
	local switch = row:FindFirstChild("Switch", true)
	local knob = if switch then switch:FindFirstChild("Knob") else nil
	if not (switch and switch:IsA("TextButton") and knob and knob:IsA("GuiObject")) then
		return false, function() end
	end
	local offColor = switch.BackgroundColor3
	local knobY = knob.Position.Y
	local on = value
	local function paint(animate: boolean)
		local goalPos = UDim2.new(if on then 0.54 else 0.04, 0, knobY.Scale, knobY.Offset)
		local goalColor = if on then Theme.Colors.Primary else offColor
		if animate then
			TweenService:Create(knob, Theme.Tween, { Position = goalPos }):Play()
			TweenService:Create(switch, Theme.Tween, { BackgroundColor3 = goalColor }):Play()
		else
			knob.Position = goalPos
			switch.BackgroundColor3 = goalColor
		end
	end
	switch.AutoButtonColor = false
	switch.Activated:Connect(function()
		on = not on
		paint(true)
		Kit.playSound("Click")
		onChanged(on)
	end)
	paint(false)
	return true,
		function(newValue: boolean)
			if newValue ~= on then
				on = newValue
				paint(true)
			end
		end
end

---------------------------------------------------------------------------------------------------
-- Studio-designable screens
---------------------------------------------------------------------------------------------------

-- Use the ScreenGui named `name` from StarterGui if someone designed one in Studio and `wire` finds
-- every piece it needs; otherwise build the default with `build` and wire that.
-- `wire` returns the names it couldn't find (empty = success). Returns the ScreenGui in use.
function Components.designable(
	name: string,
	build: () -> ScreenGui,
	wire: (ScreenGui) -> { string }
): ScreenGui
	local player = Players.LocalPlayer :: Player
	local playerGui = player:WaitForChild("PlayerGui")
	local chosen: ScreenGui? = nil
	local template = StarterGui:FindFirstChild(name)
	if template and template:IsA("ScreenGui") then
		local copy = playerGui:WaitForChild(name, 10)
		if copy and copy:IsA("ScreenGui") then
			local missing = wire(copy)
			if #missing == 0 then
				copy.ResetOnSpawn = false -- keep the wired copy across respawns
				chosen = copy
			else
				warn(
					`[UI] StarterGui.{name} is missing: {table.concat(missing, ", ")}. Using the built-in one.`
				)
				copy:Destroy()
			end
		end
	end
	if not chosen then
		local built = build()
		local missing = wire(built)
		assert(#missing == 0, `built-in {name} is missing {table.concat(missing, ", ")}`)
		chosen = built
	end
	local gui = chosen :: ScreenGui
	-- A designed template with ResetOnSpawn on gets re-added (unwired) on every respawn; remove
	-- those so only the working copy shows.
	playerGui.ChildAdded:Connect(function(child: Instance)
		if child.Name == name and child ~= (gui :: Instance) then
			child:Destroy()
		end
	end)
	return gui
end

-- Finder used by wire functions: looks anywhere under `parent` and records what's missing.
function Components.finder(missing: { string }): (parent: Instance?, name: string, className: string) -> any
	return function(parent: Instance?, name: string, className: string): any
		local found = if parent then parent:FindFirstChild(name, true) else nil
		if found and found:IsA(className) then
			return found
		end
		table.insert(missing, `{name} ({className})`)
		return nil
	end
end

return Components
