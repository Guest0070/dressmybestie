--!strict
-- Finds the important spots on the map. If a spot is missing, a simple placeholder is built,
-- so the game works on an empty Baseplate. Divyansh can build a decorated map later:
-- keep the same names (see README "Map contract") and the code uses the new spots automatically.
--
-- Workspace.Map
--   Lobby.Spawn                       where players return after a round
--   Runway.Start / Runway.End          walk path
--   Runway.Lineup                      centre of the voting lineup (players spread along its X axis)
--   Runway.Camera                      runway camera position (looks at the walker)
--   Runway.Audience                    big flat part; players stand on it while watching
--   Podium.First / Second / Third      results podium spots
--   Booths.Booth_<n>.Stand / .Mannequin   private styling booths (built on demand)

local Workspace = game:GetService("Workspace")

local Map = {}

local BOOTH_ORIGIN = Vector3.new(600, 0, 0)
local BOOTH_SPACING = 60
local BOOTH_SIZE = Vector3.new(28, 16, 28)

local root: Model

local function getOrCreate(parent: Instance, name: string, className: string): Instance
	local existing = parent:FindFirstChild(name)
	if existing then
		return existing
	end
	local instance = Instance.new(className)
	instance.Name = name
	instance.Parent = parent
	return instance
end

local function block(
	parent: Instance,
	name: string,
	size: Vector3,
	cframe: CFrame,
	color: Color3,
	props: { [string]: any }?
): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Anchored = true
	part.Size = size
	part.CFrame = cframe
	part.Color = color
	part.Material = Enum.Material.SmoothPlastic
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	if props then
		for key, value in props do
			(part :: any)[key] = value
		end
	end
	part.Parent = parent
	return part
end

-- Invisible, non-colliding marker part.
local function marker(parent: Instance, name: string, cframe: CFrame): Part
	return block(parent, name, Vector3.new(2, 1, 2), cframe, Color3.new(1, 1, 1), {
		Transparency = 1,
		CanCollide = false,
		CanQuery = false,
		CanTouch = false,
	})
end

local function findPart(path: { string }): BasePart?
	local current: Instance? = root
	for _, name in path do
		current = if current then current:FindFirstChild(name) else nil
	end
	return if current and current:IsA("BasePart") then current else nil
end

local function buildLobby()
	local lobby = getOrCreate(root, "Lobby", "Model")
	if not lobby:FindFirstChild("Spawn") then
		marker(lobby, "Spawn", CFrame.new(0, 4, 0))
	end
	-- An empty place (no Baseplate) has nothing to stand on: players fall and never count as
	-- ready. Build a floor + spawn pad if the place has no SpawnLocation of its own.
	if not Workspace:FindFirstChildWhichIsA("SpawnLocation", true) then
		block(lobby, "Floor", Vector3.new(120, 2, 120), CFrame.new(0, -1, 0), Color3.fromRGB(250, 225, 240))
		local spawnPad = Instance.new("SpawnLocation")
		spawnPad.Name = "SpawnPad"
		spawnPad.Anchored = true
		spawnPad.Size = Vector3.new(12, 1, 12)
		spawnPad.CFrame = CFrame.new(0, 0.5, 0)
		spawnPad.Color = Color3.fromRGB(255, 110, 180)
		spawnPad.Duration = 0 -- no forcefield bubble
		spawnPad.Parent = lobby
	end
end

local function buildRunway()
	local runway = getOrCreate(root, "Runway", "Model")
	if runway:FindFirstChild("Start") then
		return -- a hand-built runway exists
	end
	local pink = Color3.fromRGB(255, 120, 190)
	block(runway, "Floor", Vector3.new(120, 1, 140), CFrame.new(0, 0.5, 220), Color3.fromRGB(45, 40, 60))
	block(runway, "Catwalk", Vector3.new(12, 3, 90), CFrame.new(0, 2, 210), pink)
	-- Stage at the far end for the lineup + podium.
	block(runway, "Stage", Vector3.new(60, 3, 20), CFrame.new(0, 2, 265), Color3.fromRGB(250, 240, 250))
	marker(runway, "Start", CFrame.new(0, 6, 168))
	marker(runway, "End", CFrame.new(0, 6, 250))
	marker(runway, "Lineup", CFrame.new(0, 6, 260))
	-- Camera sits beyond the end looking back down the catwalk.
	marker(runway, "Camera", CFrame.lookAt(Vector3.new(0, 14, 285), Vector3.new(0, 6, 220)))
	local audience = block(
		runway,
		"Audience",
		Vector3.new(30, 1, 70),
		CFrame.new(-26, 1.5, 210),
		Color3.fromRGB(90, 80, 120)
	)
	audience.CanCollide = true

	local podium = getOrCreate(root, "Podium", "Model")
	if not podium:FindFirstChild("First") then
		block(podium, "Step1", Vector3.new(8, 6, 8), CFrame.new(0, 6.5, 268), Color3.fromRGB(255, 215, 90))
		block(podium, "Step2", Vector3.new(8, 4, 8), CFrame.new(-9, 5.5, 268), Color3.fromRGB(200, 200, 215))
		block(podium, "Step3", Vector3.new(8, 2, 8), CFrame.new(9, 4.5, 268), Color3.fromRGB(215, 150, 90))
		local face = CFrame.Angles(0, math.pi, 0) -- face the camera
		marker(podium, "First", CFrame.new(0, 13, 268) * face)
		marker(podium, "Second", CFrame.new(-9, 11, 268) * face)
		marker(podium, "Third", CFrame.new(9, 9, 268) * face)
	end
end

local function buildBooth(index: number): Model
	local booths = getOrCreate(root, "Booths", "Folder")
	local booth = Instance.new("Model")
	booth.Name = `Booth_{index}`
	local center = BOOTH_ORIGIN + Vector3.new(0, 0, (index - 1) * BOOTH_SPACING)
	local size = BOOTH_SIZE
	local wallColor = Color3.fromRGB(255, 225, 240)

	block(
		booth,
		"Floor",
		Vector3.new(size.X, 1, size.Z),
		CFrame.new(center + Vector3.new(0, 0.5, 0)),
		Color3.fromRGB(240, 200, 220)
	)
	block(
		booth,
		"Roof",
		Vector3.new(size.X, 1, size.Z),
		CFrame.new(center + Vector3.new(0, size.Y, 0)),
		wallColor
	)
	local half = size / 2
	block(
		booth,
		"WallN",
		Vector3.new(size.X, size.Y, 1),
		CFrame.new(center + Vector3.new(0, half.Y, half.Z)),
		wallColor
	)
	block(
		booth,
		"WallS",
		Vector3.new(size.X, size.Y, 1),
		CFrame.new(center + Vector3.new(0, half.Y, -half.Z)),
		wallColor
	)
	block(
		booth,
		"WallE",
		Vector3.new(1, size.Y, size.Z),
		CFrame.new(center + Vector3.new(half.X, half.Y, 0)),
		wallColor
	)
	block(
		booth,
		"WallW",
		Vector3.new(1, size.Y, size.Z),
		CFrame.new(center + Vector3.new(-half.X, half.Y, 0)),
		wallColor
	)
	local pedestal = block(
		booth,
		"Pedestal",
		Vector3.new(6, 1, 6),
		CFrame.new(center + Vector3.new(0, 1.5, 0)),
		Color3.fromRGB(255, 120, 190)
	)
	pedestal.Shape = Enum.PartType.Cylinder
	pedestal.CFrame = CFrame.new(center + Vector3.new(0, 1.5, 0)) * CFrame.Angles(0, 0, math.pi / 2)

	local light = Instance.new("PointLight")
	light.Range = 30
	light.Brightness = 2
	light.Parent = booth:FindFirstChild("Roof")

	-- Mannequin in the middle so the orbiting camera (radius 9) never leaves the room;
	-- the stylist stands in a corner, behind the camera, so they never block the view.
	local mannequinPos = center + Vector3.new(0, 5, 0)
	local standPos = center + Vector3.new(-9, 4, -9)
	marker(
		booth,
		"Mannequin",
		CFrame.lookAt(mannequinPos, Vector3.new(standPos.X, mannequinPos.Y, standPos.Z))
	)
	marker(booth, "Stand", CFrame.lookAt(standPos, Vector3.new(mannequinPos.X, standPos.Y, mannequinPos.Z)))
	booth.Parent = booths
	return booth
end

function Map.ensure()
	root = getOrCreate(Workspace, "Map", "Model") :: Model
	buildLobby()
	buildRunway()
	getOrCreate(root, "Booths", "Folder")
end

function Map.lobbyCFrame(): CFrame
	local spawn = findPart({ "Lobby", "Spawn" })
	local base = if spawn then spawn.CFrame else CFrame.new(0, 4, 0)
	-- Spread players out a little so they don't stack.
	return base + Vector3.new(math.random(-8, 8), 0, math.random(-8, 8))
end

export type Booth = { stand: CFrame, mannequin: CFrame }

function Map.booth(index: number): Booth
	local booths = root:FindFirstChild("Booths") :: Instance
	local booth = booths:FindFirstChild(`Booth_{index}`) or buildBooth(index)
	local stand = booth:FindFirstChild("Stand") :: BasePart
	local mannequin = booth:FindFirstChild("Mannequin") :: BasePart
	return { stand = stand.CFrame, mannequin = mannequin.CFrame }
end

function Map.runwayStart(): CFrame
	return (findPart({ "Runway", "Start" }) :: BasePart).CFrame
end

function Map.runwayEnd(): CFrame
	return (findPart({ "Runway", "End" }) :: BasePart).CFrame
end

function Map.runwayCamera(): CFrame
	return (findPart({ "Runway", "Camera" }) :: BasePart).CFrame
end

-- A random spot on the audience area.
function Map.audienceCFrame(): CFrame
	local area = findPart({ "Runway", "Audience" }) :: BasePart
	local half = area.Size / 2
	local offset = Vector3.new(math.random() * 2 - 1, 0, math.random() * 2 - 1)
		* Vector3.new(half.X - 2, 0, half.Z - 2)
	local position = area.Position + offset + Vector3.new(0, half.Y + 3, 0)
	local target = Map.runwayStart().Position
	return CFrame.lookAt(position, Vector3.new(target.X, position.Y, target.Z))
end

-- Lineup spots in a row across the stage for voting (index of count), facing the camera.
function Map.lineupCFrame(index: number, count: number): CFrame
	local lineup = findPart({ "Runway", "Lineup" })
	local center = if lineup then lineup.CFrame else Map.runwayEnd()
	local spacing = 5
	local offset = (index - (count + 1) / 2) * spacing
	local position = center.Position + center.RightVector * offset
	local cameraPos = Map.runwayCamera().Position
	return CFrame.lookAt(position, Vector3.new(cameraPos.X, position.Y, cameraPos.Z))
end

function Map.podiumCFrame(place: number): CFrame?
	local names = { "First", "Second", "Third" }
	local part = findPart({ "Podium", names[place] })
	return if part then part.CFrame else nil
end

return Map
