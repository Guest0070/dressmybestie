--!strict
-- Decorations for the auto-built map: the Play Zone plaza outside the building (marble, champagne,
-- warm LEDs, fountain, planters, how-to-play board) and the placeholder runway (neon catwalk,
-- spotlights, a backdrop that shows the current theme, bleachers).
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

-- A shop kiosk: counter, pillars, striped awning, glowing sign and a "press E / tap" prompt.
-- The prompt's ShopTab attribute tells the client which shop tab to open.
local function kiosk(
	parent: Instance,
	position: Vector3,
	name: string,
	tab: string,
	accent: Color3,
	actionText: string?
)
	local model = Instance.new("Model")
	model.Name = `Kiosk_{tab}`
	local facing = CFrame.lookAt(position, Vector3.new(0, position.Y, 0)) -- face the plaza centre
	local function at(offset: Vector3): CFrame
		return facing * CFrame.new(offset)
	end
	local counter = part(model, "Counter", Vector3.new(12, 4, 4), at(Vector3.new(0, 2, 0)), WHITE)
	part(model, "CounterStripe", Vector3.new(12.2, 0.6, 4.2), at(Vector3.new(0, 3.2, 0)), accent, true)
	part(model, "PillarL", Vector3.new(1, 12, 1), at(Vector3.new(-5.5, 6, 2)), DARK)
	part(model, "PillarR", Vector3.new(1, 12, 1), at(Vector3.new(5.5, 6, 2)), DARK)
	for i = 0, 5 do
		local color = if i % 2 == 0 then accent else WHITE
		part(
			model,
			"Awning",
			Vector3.new(2, 0.6, 7),
			at(Vector3.new(-5 + i * 2, 12, -0.5)) * CFrame.Angles(math.rad(-15), 0, 0),
			color
		)
	end
	local board = part(model, "Sign", Vector3.new(12, 3.5, 0.6), at(Vector3.new(0, 14.4, 2)), DARK)
	sign(board, Enum.NormalId.Front, { { text = name, color = accent, size = 0.8 } })
	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = actionText or "Shop"
	prompt.ObjectText = name
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = 14
	prompt.RequiresLineOfSight = false
	prompt:SetAttribute("ShopTab", tab)
	prompt.Parent = counter
	model.Parent = parent
end

-- Play Zone palette: the same materials as the imported Blender building.
local MARBLE_BLACK = Color3.fromRGB(28, 26, 30)
local CHAMPAGNE = Color3.fromRGB(214, 190, 150)
local LED_WARM = Color3.fromRGB(255, 214, 160)
local FOLIAGE = Color3.fromRGB(60, 140, 80)

local function material(p: BasePart, mat: Enum.Material): BasePart
	p.Material = mat
	return p
end

-- Decorative part players walk over (inlays, trims, LED lines).
local function flat(p: BasePart): BasePart
	p.CanCollide = false
	p.CanQuery = false
	return p
end

-- Black marble planter box with a shrub and a warm LED strip.
local function planter(parent: Instance, position: Vector3)
	material(
		part(
			parent,
			"Planter",
			Vector3.new(6, 3, 6),
			CFrame.new(position + Vector3.new(0, 1.5, 0)),
			MARBLE_BLACK
		),
		Enum.Material.Marble
	)
	flat(
		part(
			parent,
			"PlanterLed",
			Vector3.new(6.2, 0.3, 6.2),
			CFrame.new(position + Vector3.new(0, 2.9, 0)),
			LED_WARM,
			true
		)
	)
	local shrub =
		part(parent, "Shrub", Vector3.new(5, 5, 5), CFrame.new(position + Vector3.new(0, 5, 0)), FOLIAGE)
	shrub.Shape = Enum.PartType.Ball
	shrub.Material = Enum.Material.Grass
end

-- Slim champagne light post with a warm glowing head.
local function lightPost(parent: Instance, position: Vector3)
	material(
		part(
			parent,
			"Post",
			Vector3.new(0.6, 10, 0.6),
			CFrame.new(position + Vector3.new(0, 5, 0)),
			CHAMPAGNE
		),
		Enum.Material.Metal
	)
	local head = part(
		parent,
		"PostLight",
		Vector3.new(1.4, 1.4, 1.4),
		CFrame.new(position + Vector3.new(0, 10.6, 0)),
		LED_WARM,
		true
	)
	head.Shape = Enum.PartType.Ball
	local light = Instance.new("PointLight")
	light.Color = LED_WARM
	light.Range = 20
	light.Brightness = 1.2
	light.Parent = head
end

-- Black marble fountain with a champagne rim and a soft spray.
local function fountain(parent: Instance, position: Vector3)
	local basin = part(
		parent,
		"FountainBasin",
		Vector3.new(2, 16, 16),
		CFrame.new(position + Vector3.new(0, 1, 0)) * CFrame.Angles(0, 0, math.pi / 2),
		MARBLE_BLACK
	)
	basin.Shape = Enum.PartType.Cylinder
	basin.Material = Enum.Material.Marble
	local rim = flat(
		part(
			parent,
			"FountainRim",
			Vector3.new(0.4, 16.6, 16.6),
			CFrame.new(position + Vector3.new(0, 2.05, 0)) * CFrame.Angles(0, 0, math.pi / 2),
			CHAMPAGNE
		)
	)
	rim.Shape = Enum.PartType.Cylinder
	rim.Material = Enum.Material.Metal
	local water = flat(
		part(
			parent,
			"FountainWater",
			Vector3.new(0.4, 14, 14),
			CFrame.new(position + Vector3.new(0, 2.15, 0)) * CFrame.Angles(0, 0, math.pi / 2),
			Color3.fromRGB(110, 200, 255)
		)
	)
	water.Shape = Enum.PartType.Cylinder
	water.Material = Enum.Material.Glass
	water.Transparency = 0.35
	local pillar = material(
		part(
			parent,
			"FountainPillar",
			Vector3.new(2, 7, 2),
			CFrame.new(position + Vector3.new(0, 4.5, 0)),
			CHAMPAGNE
		),
		Enum.Material.Metal
	)
	local spray = Instance.new("ParticleEmitter")
	spray.Rate = 60
	spray.Lifetime = NumberRange.new(1.2, 1.6)
	spray.Speed = NumberRange.new(14, 18)
	spray.SpreadAngle = Vector2.new(15, 15)
	spray.Acceleration = Vector3.new(0, -30, 0)
	spray.Size = NumberSequence.new(0.5, 0.1)
	spray.Transparency = NumberSequence.new(0.2, 1)
	spray.Color = ColorSequence.new(Color3.fromRGB(220, 245, 255))
	spray.EmissionDirection = Enum.NormalId.Top
	spray.Parent = pillar
end

local function arch(parent: Instance, position: Vector3, text: string)
	for _, side in { -1, 1 } do
		material(
			part(
				parent,
				"ArchPillar",
				Vector3.new(2, 16, 2),
				CFrame.new(position + Vector3.new(side * 9, 8, 0)),
				MARBLE_BLACK
			),
			Enum.Material.Marble
		)
		flat(
			part(
				parent,
				"ArchLed",
				Vector3.new(0.3, 15, 0.3),
				CFrame.new(position + Vector3.new(side * 7.9, 8, 0)),
				LED_WARM,
				true
			)
		)
	end
	local top = material(
		part(
			parent,
			"ArchTop",
			Vector3.new(22, 4, 2),
			CFrame.new(position + Vector3.new(0, 17, 0)),
			MARBLE_BLACK
		),
		Enum.Material.Marble
	)
	material(
		part(
			parent,
			"ArchTrim",
			Vector3.new(22.4, 0.4, 2.4),
			CFrame.new(position + Vector3.new(0, 15, 0)),
			CHAMPAGNE
		),
		Enum.Material.Metal
	)
	sign(top, Enum.NormalId.Front, { { text = text, color = PINK, size = 0.8 } })
	sign(top, Enum.NormalId.Back, { { text = text, color = PINK, size = 0.8 } })
end

local function buildPlazaKiosks(decor: Instance)
	kiosk(decor, Vector3.new(-30, 0, 22), "BOUTIQUE", "Effects", PINK)
	kiosk(decor, Vector3.new(30, 0, 22), "TRAIL BAR", "Trails", Color3.fromRGB(110, 200, 255))
	kiosk(decor, Vector3.new(30, 0, -22), "TITLE STUDIO", "Titles", Color3.fromRGB(200, 140, 255))
	kiosk(decor, Vector3.new(-30, 0, -22), "VIP LOUNGE", "Passes", Color3.fromRGB(255, 210, 80))
	-- Dress your own avatar (client opens the catalog in "self" mode for this tab name).
	kiosk(
		decor,
		Vector3.new(0, 0, -32),
		"DRESSING ROOM",
		"DressingRoom",
		Color3.fromRGB(80, 220, 160),
		"Dress up"
	)
end

-- The plaza outside the building's foyer doors: the "Play Zone". White marble with a black marble
-- path from the doors to a fountain, champagne + warm LED trim (the building's own materials),
-- planters and light posts. The minigames (Lobby/Minigames) and activities (Lobby/Activities) sit
-- around the path.
function MapDecor.buildLobby(lobby: Instance, hasOwnFloor: boolean)
	if lobby:FindFirstChild("Decor") then
		return
	end
	local decor = Instance.new("Model")
	decor.Name = "Decor"
	local imported = lobby:GetAttribute("ImportedMap") == true

	-- Black marble path from the foyer doors (north, z = -60) to the fountain, champagne edges.
	material(
		flat(part(decor, "Path", Vector3.new(10, 0.1, 58), CFrame.new(0, 0.05, -31), MARBLE_BLACK)),
		Enum.Material.Marble
	)
	for _, x in { -5.2, 5.2 } do
		material(
			flat(part(decor, "PathEdge", Vector3.new(0.4, 0.12, 58), CFrame.new(x, 0.06, -31), CHAMPAGNE)),
			Enum.Material.Metal
		)
	end
	-- Medallion around the fountain.
	for _, spec in { { 27, CHAMPAGNE, 0.04 }, { 26, MARBLE_BLACK, 0.05 } } do
		local disc = flat(
			part(
				decor,
				"Medallion",
				Vector3.new(0.1, spec[1], spec[1]),
				CFrame.new(0, spec[3], 8) * CFrame.Angles(0, 0, math.pi / 2),
				spec[2]
			)
		)
		disc.Shape = Enum.PartType.Cylinder
		disc.Material = if spec[2] == CHAMPAGNE then Enum.Material.Metal else Enum.Material.Marble
	end
	fountain(decor, Vector3.new(0, 0, 8))

	arch(decor, Vector3.new(0, 0, -56), if imported then "PLAY ZONE" else "STYLE MY BESTIE")
	for _, z in { -46, -30, -14 } do
		lightPost(decor, Vector3.new(-8, 0, z))
		lightPost(decor, Vector3.new(8, 0, z))
	end
	for _, spot in
		{
			Vector3.new(-55, 0, -55),
			Vector3.new(55, 0, -55),
			Vector3.new(-55, 0, 55),
			Vector3.new(55, 0, 55),
			Vector3.new(-12, 0, 20),
			Vector3.new(12, 0, 20),
		}
	do
		planter(decor, spot)
	end

	-- How-to-play board on the west edge (faces +X, into the plaza).
	local board = material(
		part(decor, "HowToBoard", Vector3.new(1, 14, 26), CFrame.new(-59, 8, 0), MARBLE_BLACK),
		Enum.Material.Marble
	)
	material(
		part(decor, "HowToFrame", Vector3.new(0.8, 14.6, 26.6), CFrame.new(-59.4, 8, 0), CHAMPAGNE),
		Enum.Material.Metal
	)
	sign(board, Enum.NormalId.Right, {
		{ text = "HOW TO PLAY", color = PINK, size = 0.2 },
		{ text = "1. You secretly style your partner's mannequin", color = WHITE, size = 0.15 },
		{ text = "2. Match the theme (or don't!)", color = WHITE, size = 0.15 },
		{ text = "3. Walk the runway in what THEY picked for you", color = WHITE, size = 0.15 },
		{ text = "4. Rate the looks. Best stylist wins!", color = WHITE, size = 0.15 },
	})

	if not imported then
		buildPlazaKiosks(decor)
	end

	if hasOwnFloor then
		-- Black marble band and a warm LED line around the plaza floor.
		for _, spec in
			{
				{ Vector3.new(120, 0.1, 3), Vector3.new(0, 0.05, 58.5) },
				{ Vector3.new(120, 0.1, 3), Vector3.new(0, 0.05, -58.5) },
				{ Vector3.new(3, 0.1, 120), Vector3.new(58.5, 0.05, 0) },
				{ Vector3.new(3, 0.1, 120), Vector3.new(-58.5, 0.05, 0) },
			}
		do
			material(
				flat(part(decor, "Border", spec[1], CFrame.new(spec[2]), MARBLE_BLACK)),
				Enum.Material.Marble
			)
		end
		for _, spec in
			{
				{ Vector3.new(114, 0.12, 0.3), Vector3.new(0, 0.06, 56.8) },
				{ Vector3.new(114, 0.12, 0.3), Vector3.new(0, 0.06, -56.8) },
				{ Vector3.new(0.3, 0.12, 114), Vector3.new(56.8, 0.06, 0) },
				{ Vector3.new(0.3, 0.12, 114), Vector3.new(-56.8, 0.06, 0) },
			}
		do
			flat(part(decor, "BorderLed", spec[1], CFrame.new(spec[2]), LED_WARM, true))
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
