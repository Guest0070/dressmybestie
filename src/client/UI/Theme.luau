--!strict
-- Design tokens for every screen: "after-party runway" look. Deep plum glass panels, hot pink for
-- what you can tap, gold for coins and rewards, a rounded playful display font for headings and a
-- clean sans for everything you read. Both UI toolkits (Components.luau and the older Kit.luau)
-- take their colours and fonts from here, so changing a token restyles the whole game.

local Theme = {}

Theme.Colors = {
	Background = Color3.fromHex("#140D1F"), -- deep plum, almost black
	Panel = Color3.fromHex("#1E1530"),
	PanelRaised = Color3.fromHex("#2A1F42"),
	Stroke = Color3.fromHex("#45355F"),
	Primary = Color3.fromHex("#FF4FA3"), -- hot pink: everything tappable
	PrimaryDark = Color3.fromHex("#C92A7A"),
	PrimaryText = Color3.fromHex("#FFFFFF"), -- text on pink buttons
	Accent = Color3.fromHex("#62E2FF"), -- icy cyan: live / selected / freeze
	Secondary = Color3.fromHex("#2C2144"),
	SecondaryHover = Color3.fromHex("#3A2C58"),
	Text = Color3.fromHex("#FFFFFF"),
	Silver = Color3.fromHex("#E6DDF5"),
	Muted = Color3.fromHex("#A897C7"),
	Disabled = Color3.fromHex("#231A33"),
	DisabledText = Color3.fromHex("#6B5D88"),
	Gold = Color3.fromHex("#FFC94A"),
	Success = Color3.fromHex("#3EE08F"),
	Info = Color3.fromHex("#5AA9FF"),
	Danger = Color3.fromHex("#FF5A6E"),
}

-- The pink-to-violet sheen used on panel borders and highlights.
Theme.Gradient = ColorSequence.new(Color3.fromHex("#FF4FA3"), Color3.fromHex("#9B6BFF"))

Theme.Radius = 12 -- px
Theme.RadiusLarge = 18
Theme.StrokeThickness = 1.5
Theme.MinTouch = 36 -- px; smallest tap target (kept compact so the lobby UI stays out of the way)

Theme.Fonts = {
	Heading = Font.new("rbxasset://fonts/families/FredokaOne.json"),
	Button = Font.new("rbxasset://fonts/families/FredokaOne.json"),
	Body = Font.new("rbxasset://fonts/families/BuilderSans.json", Enum.FontWeight.Medium),
	Number = Font.new("rbxasset://fonts/families/BuilderSans.json", Enum.FontWeight.ExtraBold),
}
-- The same fonts as Enum.Font, for code that sets TextLabel.Font.
Theme.EnumFonts = {
	Heading = Enum.Font.FredokaOne,
	Body = Enum.Font.BuilderSansBold,
}

Theme.Tween = TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
Theme.TweenSlow = TweenInfo.new(0.28, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)

return Theme
