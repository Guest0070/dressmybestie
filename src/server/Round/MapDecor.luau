--!strict
-- Decorations for the auto-built placeholder map: neon catwalk, spotlights, a backdrop that
-- shows the current theme, bleachers, and a lobby title sign + how-to-play board.
-- Everything lives in "Decor" models, so a hand-built map can simply delete them.

local MapDecor = {}

local PINK = Color3.fromRGB(255, 110, 180)
local DARK = Color3.fromRGB(35, 30, 50)
local WHITE = Color3.fromRGB(250, 245, 250)

local function part(
	parent: Instance,
	name: string,
	size: Vector3,
	cframe: CFrame,
	color: Color3,
	neon: boolean?
): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.Size = size
	p.CFrame = cframe
	p.Color = color
	p.Material = if neon then Enum.Material.Neon else Enum.Material.SmoothPlastic
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = parent
	return p
end

-- Big text on one face of a part. Returns the label so it can be updated later.
local function sign(
	target: BasePart,
	face: Enum.NormalId,
	lines: { { text: string, color: Color3, size: number, name: string? } }
)
	local gui = Instance.new("SurfaceGui")
	gui.Face = face
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 40
	gui.LightInfluence = 0
	gui.Parent = target
	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Vertical
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	layout.VerticalAlignment = Enum.VerticalAlignment.Center
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = gui
	for index, line in lines do
		local label = Instance.new("TextLabel")
		label.Name = line.name or `Line{index}`
		label.LayoutOrder = index
		label.BackgroundTransparency = 1
		label.Size = UDim2.fromScale(0.95, line.size)
		label.Font = Enum.Font.FredokaOne
		label.TextScaled = true
		label.TextColor3 = line.color
		label.Text = line.text
		local stroke = Instance.new("UIStroke")
		stroke.Thickness = 3
		stroke.Parent = label
		label.Parent = gui
	end
end

local function lamp(parent: Instance, position: Vector3)
	part(parent, "LampPost", Vector3.new(1, 12, 1), CFrame.new(position + Vector3.new(0, 6, 0)), DARK)
	local bulb = part(
		parent,
		"LampBulb",
		Vector3.new(2.5, 2.5, 2.5),
		CFrame.new(position + Vector3.new(0, 13, 0)),
		PINK,
		true
	)
	bulb.Shape = Enum.PartType.Ball
	local light = Instance.new("PointLight")
	light.Color = PINK
	light.Range = 24
	light.Brightness = 1.5
	light.Parent = bulb
end

function MapDecor.buildLobby(lobby: Instance, hasOwnFloor: boolean)
	if lobby:FindFirstChild("Decor") then
		return
	end
	local decor = Instance.new("Model")
	decor.Name = "Decor"

	-- Title sign behind the spawn, readable from the spawn pad (faces +Z).
	local title = part(decor, "TitleSign", Vector3.new(48, 16, 1), CFrame.new(0, 12, -45), DARK)
	part(decor, "TitleGlow", Vector3.new(50, 18, 0.5), CFrame.new(0, 12, -45.8), PINK, true)
	sign(title, Enum.NormalId.Back, {
		{ text = "STYLE MY BESTIE", color = PINK, size = 0.5 },
		{ text = "Style your bestie. Blind. Then walk the runway!", color = WHITE, size = 0.25 },
	})

	-- How-to-play board on the left side (faces +X, toward the spawn).
	local board = part(decor, "HowToBoard", Vector3.new(1, 16, 30), CFrame.new(-45, 9, 0), DARK)
	sign(board, Enum.NormalId.Right, {
		{ text = "HOW TO PLAY", color = PINK, size = 0.2 },
		{ text = "1. You secretly style your partner's mannequin", color = WHITE, size = 0.15 },
		{ text = "2. Match the theme (or don't!)", color = WHITE, size = 0.15 },
		{ text = "3. Walk the runway in what THEY picked for you", color = WHITE, size = 0.15 },
		{ text = "4. Give hearts to your favorite looks", color = WHITE, size = 0.15 },
	})

	for _, corner in
		{ Vector3.new(-36, 0, -36), Vector3.new(36, 0, -36), Vector3.new(-36, 0, 36), Vector3.new(36, 0, 36) }
	do
		lamp(decor, corner)
	end

	if hasOwnFloor then
		-- Neon border around the auto-built lobby floor.
		for _, spec in
			{
				{ Vector3.new(120, 0.4, 0.6), Vector3.new(0, 0.2, 60) },
				{ Vector3.new(120, 0.4, 0.6), Vector3.new(0, 0.2, -60) },
				{ Vector3.new(0.6, 0.4, 120), Vector3.new(60, 0.2, 0) },
				{ Vector3.new(0.6, 0.4, 120), Vector3.new(-60, 0.2, 0) },
			}
		do
			part(decor, "Border", spec[1], CFrame.new(spec[2]), PINK, true)
		end
	end
	decor.Parent = lobby
end

function MapDecor.buildRunway(runway: Instance)
	if runway:FindFirstChild("Decor") then
		return
	end
	local decor = Instance.new("Model")
	decor.Name = "Decor"

	-- Neon edges along the catwalk (catwalk: 12 wide, top at y=3.5, z 165..255).
	part(decor, "EdgeLeft", Vector3.new(0.5, 0.5, 90), CFrame.new(-6.25, 3.6, 210), PINK, true)
	part(decor, "EdgeRight", Vector3.new(0.5, 0.5, 90), CFrame.new(6.25, 3.6, 210), PINK, true)
	part(decor, "StageEdge", Vector3.new(60, 0.5, 0.5), CFrame.new(0, 3.6, 275.25), PINK, true)

	-- Backdrop behind the start of the walk, facing the camera. Shows the current theme.
	local backdrop = part(decor, "Backdrop", Vector3.new(56, 26, 2), CFrame.new(0, 14, 158), DARK)
	part(decor, "BackdropGlow", Vector3.new(58, 28, 1), CFrame.new(0, 14, 156.8), PINK, true)
	sign(backdrop, Enum.NormalId.Back, {
		{ text = "STYLE MY BESTIE", color = PINK, size = 0.35 },
		{ text = "", color = WHITE, size = 0.3, name = "ThemeText" },
	})

	-- Spotlights on a rig above the catwalk.
	for _, z in { 180, 210, 240 } do
		part(decor, "Rig", Vector3.new(30, 1, 1), CFrame.new(0, 24, z), DARK)
		local lampHead = part(decor, "SpotLamp", Vector3.new(2, 2, 2), CFrame.new(0, 23, z), WHITE, true)
		local light = Instance.new("SpotLight")
		light.Face = Enum.NormalId.Bottom
		light.Range = 40
		light.Angle = 60
		light.Brightness = 3
		light.Color = Color3.fromRGB(255, 240, 230)
		light.Parent = lampHead
	end

	-- Bleachers behind the audience area (left) and a mirror set on the right for looks.
	for step = 1, 3 do
		local height = step * 2
		for _, side in { -1, 1 } do
			local x = side * (41 + step * 4)
			part(
				decor,
				"Bleacher",
				Vector3.new(4, height, 70),
				CFrame.new(x, 1 + height / 2, 210),
				Color3.fromRGB(90, 80, 120)
			)
		end
	end
	decor.Parent = runway
end

-- Put text on the runway backdrop (e.g. the current theme). Safe if the backdrop doesn't exist.
function MapDecor.setBackdropText(runway: Instance?, text: string)
	local decor = if runway then runway:FindFirstChild("Decor") else nil
	local backdrop = if decor then decor:FindFirstChild("Backdrop") else nil
	local gui = if backdrop then backdrop:FindFirstChildOfClass("SurfaceGui") else nil
	local label = if gui then gui:FindFirstChild("ThemeText") else nil
	if label and label:IsA("TextLabel") then
		label.Text = text
	end
end

return MapDecor
