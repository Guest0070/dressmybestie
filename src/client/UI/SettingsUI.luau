--!strict
-- Settings window: Music and Sound effects on/off (see Audio.luau).

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

function SettingsUI.start()
	gui = Components.screen("SettingsUI", 20)
	gui.Enabled = false

	-- Dimmed backdrop; tapping it closes the window.
	local backdrop = Instance.new("TextButton")
	backdrop.Name = "Backdrop"
	backdrop.Text = ""
	backdrop.AutoButtonColor = false
	backdrop.BackgroundColor3 = Color3.new(0, 0, 0)
	backdrop.BackgroundTransparency = 0.45
	backdrop.Size = UDim2.fromScale(1, 1)
	backdrop.Selectable = false
	backdrop.Activated:Connect(SettingsUI.close)
	backdrop.Parent = gui

	local window = Components.panel({
		Name = "Window",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(0.36, 0.5),
		Parent = gui,
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
	closeButton = Components.button({
		Name = "Close",
		Text = "✕",
		Variant = "Secondary",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.fromScale(1, 0),
		Size = UDim2.fromOffset(Theme.MinTouch, Theme.MinTouch),
		MaxTextSize = 24,
		Parent = window,
		onClick = SettingsUI.close,
	})

	local rows = Instance.new("Frame")
	rows.Name = "Rows"
	rows.BackgroundTransparency = 1
	rows.Position = UDim2.fromScale(0, 0.3)
	rows.Size = UDim2.fromScale(1, 0.7)
	rows.Parent = window
	Components.list(Enum.FillDirection.Vertical, 8, nil, Enum.VerticalAlignment.Top).Parent = rows

	Components.toggle({
		Name = "Music",
		Text = "Music",
		Value = Audio.musicOn,
		Size = UDim2.new(1, 0, 0.4, 0),
		LayoutOrder = 1,
		Parent = rows,
		onChanged = Audio.setMusic,
	})
	Components.toggle({
		Name = "SoundEffects",
		Text = "Sound effects",
		Value = Audio.sfxOn,
		Size = UDim2.new(1, 0, 0.4, 0),
		LayoutOrder = 2,
		Parent = rows,
		onChanged = Audio.setSfx,
	})

	-- Gamepad B closes the window.
	UserInputService.InputBegan:Connect(function(input)
		if gui.Enabled and input.KeyCode == Enum.KeyCode.ButtonB then
			SettingsUI.close()
		end
	end)
end

return SettingsUI
