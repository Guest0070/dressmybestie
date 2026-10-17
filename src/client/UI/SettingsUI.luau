--!strict
-- Settings window: Music and Sound effects on/off (see Audio.luau).
-- Designable in Studio: a ScreenGui "SettingsUI" in StarterGui is used instead (see README).

local GuiService = game:GetService("GuiService")
local UserInputService = game:GetService("UserInputService")

local Audio = require(script.Parent.Parent.Audio)
local Components = require(script.Parent.Components)
local Theme = require(script.Parent.Theme)

local SettingsUI = {}

local gui: ScreenGui
local closeButton: Components.ButtonHandle

function SettingsUI.open()
	gui.Enabled = true
	if UserInputService.PreferredInput == Enum.PreferredInput.Gamepad then
		GuiService.SelectedObject = closeButton.instance
	end
end

function SettingsUI.close()
	gui.Enabled = false
	if GuiService.SelectedObject and GuiService.SelectedObject:IsDescendantOf(gui) then
		GuiService.SelectedObject = nil
	end
end

function SettingsUI.toggle()
	if gui.Enabled then
		SettingsUI.close()
	else
		SettingsUI.open()
	end
end

local function build(): ScreenGui
	local root = Components.screen("SettingsUI", 20)

	-- Dimmed backdrop; tapping it closes the window.
	local backdrop = Instance.new("TextButton")
	backdrop.Name = "Backdrop"
	backdrop.Text = ""
	backdrop.AutoButtonColor = false
	backdrop.BackgroundColor3 = Color3.new(0, 0, 0)
	backdrop.BackgroundTransparency = 0.45
	backdrop.Size = UDim2.fromScale(1, 1)
	backdrop.Selectable = false
	backdrop.Parent = root

	local window = Components.panel({
		Name = "Window",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(0.36, 0.5),
		Parent = root,
	})
	Components.sizeLimit(Vector2.new(300, 220), Vector2.new(460, 320)).Parent = window
	Components.padding(16, 16).Parent = window

	Components.text({
		Name = "Title",
		Text = "SETTINGS",
		Size = UDim2.new(1, -56, 0.18, 0),
		FontFace = Theme.Fonts.Heading,
		TextXAlignment = Enum.TextXAlignment.Left,
		MaxTextSize = 24,
		Parent = window,
	})
	Components.styleButton({
		Name = "Close",
		Text = "X", -- the UI font has no ✕ glyph
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.fromScale(1, 0),
		Size = UDim2.fromOffset(Theme.MinTouch, Theme.MinTouch),
		MaxTextSize = 24,
		Parent = window,
	})

	local rows = Instance.new("Frame")
	rows.Name = "Rows"
	rows.BackgroundTransparency = 1
	rows.Position = UDim2.fromScale(0, 0.3)
	rows.Size = UDim2.fromScale(1, 0.7)
	rows.Parent = window
	Components.list(Enum.FillDirection.Vertical, 8, nil, Enum.VerticalAlignment.Top).Parent = rows
	Components.styleToggle({
		Name = "Music",
		Text = "Music",
		Size = UDim2.new(1, 0, 0.4, 0),
		LayoutOrder = 1,
		Parent = rows,
	})
	Components.styleToggle({
		Name = "SoundEffects",
		Text = "Sound effects",
		Size = UDim2.new(1, 0, 0.4, 0),
		LayoutOrder = 2,
		Parent = rows,
	})
	return root
end

-- Needs: Close (TextButton), Music + SoundEffects (each with Switch > Knob). Optional: Backdrop
-- (a TextButton that closes the window when tapped).
local function wire(root: ScreenGui): { string }
	local missing: { string } = {}
	local find = Components.finder(missing)
	local close = find(root, "Close", "TextButton")
	local music = find(root, "Music", "GuiObject")
	local sfx = find(root, "SoundEffects", "GuiObject")
	if #missing > 0 then
		return missing
	end
	if not Components.attachToggle(music, Audio.musicOn, Audio.setMusic) then
		table.insert(missing, "Music > Switch > Knob")
	end
	if not Components.attachToggle(sfx, Audio.sfxOn, Audio.setSfx) then
		table.insert(missing, "SoundEffects > Switch > Knob")
	end
	if #missing > 0 then
		return missing
	end
	closeButton = Components.attachButton(close, SettingsUI.close)
	local backdrop = root:FindFirstChild("Backdrop")
	if backdrop and backdrop:IsA("GuiButton") then
		backdrop.Activated:Connect(SettingsUI.close)
	end
	return missing
end

function SettingsUI.start()
	gui = Components.designable("SettingsUI", build, wire)
	gui.Enabled = false

	-- Gamepad B closes the window.
	UserInputService.InputBegan:Connect(function(input)
		if gui.Enabled and input.KeyCode == Enum.KeyCode.ButtonB then
			SettingsUI.close()
		end
	end)
end

return SettingsUI
