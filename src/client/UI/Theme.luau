--!strict
-- Design tokens for the "premium fashion" look (lobby UI first; other screens can move over later).
-- Change a colour or radius here and every component built with Components.luau follows.

local Theme = {}

Theme.Colors = {
	Background = Color3.fromHex("#121212"), -- deep charcoal
	Panel = Color3.fromHex("#1B1B1F"),
	PanelRaised = Color3.fromHex("#26262C"),
	Stroke = Color3.fromHex("#3A3A42"),
	Primary = Color3.fromHex("#00E5FF"), -- electric cyan
	PrimaryDark = Color3.fromHex("#00A9C4"),
	PrimaryText = Color3.fromHex("#04161A"), -- dark text on cyan buttons
	Secondary = Color3.fromHex("#2E2E36"),
	SecondaryHover = Color3.fromHex("#3A3A44"),
	Text = Color3.fromHex("#FFFFFF"),
	Silver = Color3.fromHex("#C9CCD3"),
	Muted = Color3.fromHex("#8A8D96"),
	Disabled = Color3.fromHex("#2A2A2F"),
	DisabledText = Color3.fromHex("#5C5E66"),
	Gold = Color3.fromHex("#F5C84C"),
	Danger = Color3.fromHex("#FF5A6E"),
}

Theme.Radius = 10 -- px, inside the 8-12 range of the brief
Theme.RadiusLarge = 14
Theme.StrokeThickness = 1.5
Theme.MinTouch = 44 -- px; smallest comfortable tap target on phones

Theme.Fonts = {
	Heading = Font.new("rbxasset://fonts/families/Montserrat.json", Enum.FontWeight.ExtraBold),
	Button = Font.new("rbxasset://fonts/families/Montserrat.json", Enum.FontWeight.Bold),
	Body = Font.new("rbxasset://fonts/families/GothamSSm.json", Enum.FontWeight.Medium),
	Number = Font.new("rbxasset://fonts/families/GothamSSm.json", Enum.FontWeight.Bold),
}

Theme.Tween = TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

return Theme
