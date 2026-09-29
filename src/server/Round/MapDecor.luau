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

-- A shop kiosk: counter, pillars, striped awning, glowing sign and a "press E / tap" prompt.
-- The prompt's ShopTab attribute tells the client which shop tab to open.
local function kiosk(parent: Instance, position: Vector3, name: string, tab: string, accent: Color3)
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
	prompt.ActionText = "Shop"
	prompt.ObjectText = name
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = 14
	prompt.RequiresLineOfSight = false
	prompt:SetAttribute("ShopTab", tab)
	prompt.Parent = counter
	model.Parent = parent
end

local function palm(parent: Instance, position: Vector3)
	local trunk = part(
		parent,
		"PalmTrunk",
		Vector3.new(1.6, 16, 1.6),
		CFrame.new(position + Vector3.new(0, 8, 0)),
		Color3.fromRGB(140, 95, 60)
	)
	trunk.Material = Enum.Material.Wood
	local top = position + Vector3.new(0, 16, 0)
	for i = 0, 5 do
		local angle = math.rad(i * 60)
		local leaf = part(
			parent,
			"PalmLeaf",
			Vector3.new(2.4, 0.4, 9),
			CFrame.new(top)
				* CFrame.Angles(0, angle, 0)
				* CFrame.new(0, -1, -4)
				* CFrame.Angles(math.rad(-25), 0, 0),
			Color3.fromRGB(70, 190, 100)
		)
		leaf.Material = Enum.Material.Grass
	end
end

local function fountain(parent: Instance, position: Vector3)
	local rim = part(
		parent,
		"FountainRim",
		Vector3.new(2, 16, 16),
		CFrame.new(position + Vector3.new(0, 1, 0)) * CFrame.Angles(0, 0, math.pi / 2),
		WHITE
	)
	rim.Shape = Enum.PartType.Cylinder
	local water = part(
		parent,
		"FountainWater",
		Vector3.new(0.4, 14, 14),
		CFrame.new(position + Vector3.new(0, 2.1, 0)) * CFrame.Angles(0, 0, math.pi / 2),
		Color3.fromRGB(110, 200, 255)
	)
	water.Shape = Enum.PartType.Cylinder
	water.Material = Enum.Material.Glass
	water.Transparency = 0.3
	water.CanCollide = false
	local pillar = part(
		parent,
		"FountainPillar",
		Vector3.new(2, 7, 2),
		CFrame.new(position + Vector3.new(0, 4.5, 0)),
		PINK,
		true
	)
	local spray = Instance.new("ParticleEmitter")
	spray.Rate = 60
	spray.Lifetime = NumberRange.new(1.2, 1.6)
	spray.Speed = NumberRange.new(14, 18)
	spray.SpreadAngle = Vector2.new(15, 15)
	spray.Acceleration = Vector3.new(0, -30, 0)
	spray.Size = NumberSequence.new(0.5, 0.1)
	spray.Transparency = NumberSequence.new(0.2, 1)
	spray.Color = ColorSequence.new(Color3.fromRGB(200, 240, 255))
	spray.EmissionDirection = Enum.NormalId.Top
	spray.Parent = pillar
end

-- Strings of coloured bulbs between two points.
local function stringLights(parent: Instance, from: Vector3, to: Vector3)
	local colors = { PINK, Color3.fromRGB(255, 220, 80), Color3.fromRGB(110, 200, 255), WHITE }
	local count = math.floor((to - from).Magnitude / 4)
	for i = 0, count do
		local t = i / count
		local sag = math.sin(t * math.pi) * 2
		local bulb = part(
			parent,
			"Bulb",
			Vector3.new(0.8, 0.8, 0.8),
			CFrame.new(from:Lerp(to, t) - Vector3.new(0, sag, 0)),
			colors[i % #colors + 1],
			true
		)
		bulb.Shape = Enum.PartType.Ball
		bulb.CanCollide = false
	end
end

local function plaza(parent: Instance)
	-- Pink/white checker tiles, 10x10 studs each, just above the ground.
	for x = -4, 3 do
		for z = -4, 3 do
			local color = if (x + z) % 2 == 0 then Color3.fromRGB(255, 190, 220) else WHITE
			local tile =
				part(parent, "Tile", Vector3.new(10, 0.2, 10), CFrame.new(x * 10 + 5, 0.1, z * 10 + 5), color)
			tile.CanCollide = false
		end
	end
end

local function arch(parent: Instance, position: Vector3, text: string)
	part(parent, "ArchL", Vector3.new(2, 18, 2), CFrame.new(position + Vector3.new(-10, 9, 0)), PINK, true)
	part(parent, "ArchR", Vector3.new(2, 18, 2), CFrame.new(position + Vector3.new(10, 9, 0)), PINK, true)
	local top =
		part(parent, "ArchTop", Vector3.new(22, 4, 2), CFrame.new(position + Vector3.new(0, 19, 0)), DARK)
	sign(top, Enum.NormalId.Front, { { text = text, color = PINK, size = 0.8 } })
	sign(top, Enum.NormalId.Back, { { text = text, color = PINK, size = 0.8 } })
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

	-- The plaza: checker floor, fountain, shops, palms, lights and an arch.
	plaza(decor)
	fountain(decor, Vector3.new(0, 0, 22))
	kiosk(decor, Vector3.new(-30, 0, 22), "BOUTIQUE", "Effects", PINK)
	kiosk(decor, Vector3.new(30, 0, 22), "TRAIL BAR", "Trails", Color3.fromRGB(110, 200, 255))
	kiosk(decor, Vector3.new(30, 0, -22), "TITLE STUDIO", "Titles", Color3.fromRGB(200, 140, 255))
	kiosk(decor, Vector3.new(-30, 0, -22), "VIP LOUNGE", "Passes", Color3.fromRGB(255, 210, 80))
	for _, spot in
		{
			Vector3.new(-50, 0, -50),
			Vector3.new(50, 0, -50),
			Vector3.new(-50, 0, 50),
			Vector3.new(50, 0, 50),
			Vector3.new(0, 0, -54),
		}
	do
		palm(decor, spot)
	end
	stringLights(decor, Vector3.new(-36, 12.5, -36), Vector3.new(36, 12.5, -36))
	stringLights(decor, Vector3.new(-36, 12.5, 36), Vector3.new(36, 12.5, 36))
	stringLights(decor, Vector3.new(-36, 12.5, -36), Vector3.new(-36, 12.5, 36))
	stringLights(decor, Vector3.new(36, 12.5, -36), Vector3.new(36, 12.5, 36))
	arch(decor, Vector3.new(0, 0, 55), "TO THE RUNWAY")

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
