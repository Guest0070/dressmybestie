--!strict
-- The world around the building and the Play Zone, so it no longer floats in the sky: a paved
-- ground with boulevards and street lamps, rows of trees, and a ring of city towers with lit
-- windows on the horizon, plus dusk lighting so the neon pops.
-- Built once at server start (Config.Environment), only around the imported building.

local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage.Shared.Config)

local Environment = {}

local PAVING = Color3.fromRGB(150, 140, 148)
local ROAD = Color3.fromRGB(40, 38, 46)
local CURB = Color3.fromRGB(214, 190, 150) -- champagne, like the building trims
local WARM = Color3.fromRGB(255, 214, 160)
local TOWER = Color3.fromRGB(34, 30, 46)
local WINDOW_COLORS = {
	Color3.fromRGB(255, 214, 160),
	Color3.fromRGB(255, 120, 190),
	Color3.fromRGB(110, 210, 255),
	Color3.fromRGB(255, 236, 200),
}

local function part(
	parent: Instance,
	name: string,
	size: Vector3,
	cframe: CFrame,
	color: Color3,
	material: Enum.Material?
): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.Size = size
	p.CFrame = cframe
	p.Color = color
	p.Material = material or Enum.Material.SmoothPlastic
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.CastShadow = false
	p.Parent = parent
	return p
end

local function decor(p: Part): Part
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	return p
end

local function streetLamp(parent: Instance, position: Vector3)
	part(
		parent,
		"LampPost",
		Vector3.new(0.6, 14, 0.6),
		CFrame.new(position + Vector3.new(0, 7, 0)),
		CURB,
		Enum.Material.Metal
	)
	part(
		parent,
		"LampArm",
		Vector3.new(3, 0.4, 0.4),
		CFrame.new(position + Vector3.new(1.3, 13.8, 0)),
		CURB,
		Enum.Material.Metal
	)
	local head = decor(
		part(
			parent,
			"LampHead",
			Vector3.new(1.6, 0.6, 1.2),
			CFrame.new(position + Vector3.new(2.6, 13.5, 0)),
			WARM,
			Enum.Material.Neon
		)
	)
	local light = Instance.new("SpotLight")
	light.Face = Enum.NormalId.Bottom
	light.Range = 28
	light.Angle = 80
	light.Brightness = 1.4
	light.Color = WARM
	light.Parent = head
end

local function tree(parent: Instance, position: Vector3, scale: number)
	part(
		parent,
		"Trunk",
		Vector3.new(1.2, 7, 1.2) * scale,
		CFrame.new(position + Vector3.new(0, 3.5 * scale, 0)),
		Color3.fromRGB(90, 66, 50),
		Enum.Material.Wood
	)
	local crown = part(
		parent,
		"Crown",
		Vector3.new(8, 8, 8) * scale,
		CFrame.new(position + Vector3.new(0, 8.5 * scale, 0)),
		Color3.fromRGB(56, 128, 74),
		Enum.Material.Grass
	)
	crown.Shape = Enum.PartType.Ball
	decor(crown)
end

local function tower(
	parent: Instance,
	position: Vector3,
	width: number,
	depth: number,
	height: number,
	rng: Random
)
	local body = part(
		parent,
		"Tower",
		Vector3.new(width, height, depth),
		CFrame.new(position + Vector3.new(0, height / 2, 0)) * CFrame.Angles(0, rng:NextNumber() * math.pi, 0),
		TOWER,
		Enum.Material.SmoothPlastic
	)
	decor(body)
	-- Lit window bands.
	local bands = math.floor(height / 14)
	for b = 1, bands do
		if rng:NextNumber() < 0.75 then
			local color = WINDOW_COLORS[rng:NextInteger(1, #WINDOW_COLORS)]
			local band = decor(
				part(
					parent,
					"Windows",
					Vector3.new(width + 0.2, 1.4, depth + 0.2),
					body.CFrame * CFrame.new(0, -height / 2 + b * 14 - 4, 0),
					color,
					Enum.Material.Neon
				)
			)
			band.Transparency = 0.35
		end
	end
	-- A blinking aircraft light on the tall ones.
	if height > 140 then
		decor(
			part(
				parent,
				"Beacon",
				Vector3.new(1.5, 1.5, 1.5),
				body.CFrame * CFrame.new(0, height / 2 + 1, 0),
				Color3.fromRGB(255, 60, 90),
				Enum.Material.Neon
			)
		)
	end
end

function Environment.start()
	local settings = Config.Environment
	local map = Workspace:FindFirstChild("Map")
	local lobby = if map then map:FindFirstChild("Lobby") else nil
	if not settings.Enabled or not lobby or lobby:GetAttribute("ImportedMap") ~= true then
		return
	end
	if Workspace:FindFirstChild("Environment") then
		return
	end
	local folder = Instance.new("Folder")
	folder.Name = "Environment"
	local rng = Random.new(20261017) -- same city every time

	-- Ground (just below the floors at y = 0) and two boulevards crossing at the plaza.
	part(
		folder,
		"Ground",
		Vector3.new(2048, 2, 2048),
		CFrame.new(0, -1.15, -60),
		PAVING,
		Enum.Material.Pavement
	)
	for _, spec in
		{
			{ Vector3.new(2048, 0.1, 26), Vector3.new(0, -0.1, 92) }, -- east-west, south of the plaza
			{ Vector3.new(26, 0.1, 2048), Vector3.new(-96, -0.1, -60) }, -- north-south, west of the obby start
		}
	do
		decor(part(folder, "Road", spec[1], CFrame.new(spec[2]), ROAD, Enum.Material.Asphalt))
	end
	for _, spec in
		{
			{ Vector3.new(2048, 0.3, 0.8), Vector3.new(0, -0.05, 78.6) },
			{ Vector3.new(2048, 0.3, 0.8), Vector3.new(0, -0.05, 105.4) },
		}
	do
		decor(part(folder, "Curb", spec[1], CFrame.new(spec[2]), CURB, Enum.Material.Metal))
	end
	-- Street lamps and trees along the boulevard and around the plaza.
	for x = -260, 260, 40 do
		streetLamp(folder, Vector3.new(x, 0, 76))
		tree(folder, Vector3.new(x + 20, 0, 112), 1 + rng:NextNumber() * 0.4)
	end
	for _, spot in
		{
			Vector3.new(-70, 0, -70),
			Vector3.new(-70, 0, -40),
			Vector3.new(-70, 0, -10),
			Vector3.new(70, 0, 60),
			Vector3.new(90, 0, 40),
			Vector3.new(-40, 0, 70),
			Vector3.new(40, 0, 70),
			Vector3.new(110, 0, -40),
			Vector3.new(130, 0, 40),
			Vector3.new(-120, 0, 60),
		}
	do
		tree(folder, spot, 1 + rng:NextNumber() * 0.5)
	end

	-- Skyline: two rings of towers around everything. Kept within ~400 studs: further out, phones
	-- (and lower graphics settings) don't draw them at all.
	local centre = Vector3.new(0, 0, -60)
	for ring, spec in
		{
			{ radius = 300, count = 40, minH = 40, maxH = 115 },
			{ radius = 390, count = 40, minH = 80, maxH = 170 },
		}
	do
		for i = 1, spec.count do
			local angle = (i / spec.count) * math.pi * 2 + rng:NextNumber() * 0.08
			local r = spec.radius + rng:NextNumber() * 40
			local position = centre + Vector3.new(math.cos(angle) * r, -1, math.sin(angle) * r)
			tower(
				folder,
				position,
				rng:NextInteger(24, 44),
				rng:NextInteger(24, 44),
				rng:NextInteger(spec.minH, spec.maxH) + (ring - 1) * 20,
				rng
			)
		end
	end
	folder.Parent = Workspace

	-- Dusk: the sun just set, soft haze, so neon and LEDs glow.
	Lighting.ClockTime = settings.ClockTime
	Lighting.GeographicLatitude = 35
	local atmosphere = Lighting:FindFirstChildOfClass("Atmosphere") or Instance.new("Atmosphere")
	atmosphere.Density = 0.2
	atmosphere.Offset = 0
	atmosphere.Color = Color3.fromRGB(255, 200, 190)
	atmosphere.Decay = Color3.fromRGB(150, 110, 170)
	atmosphere.Glare = 0.4
	atmosphere.Haze = 0.8
	atmosphere.Parent = Lighting
end

return Environment
