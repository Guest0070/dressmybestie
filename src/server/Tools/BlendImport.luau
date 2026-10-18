--!strict
-- One-time Studio setup for the Blender building (Style_My_Bestie_Final.blend).
--
-- 1. Studio: File > Import 3D, import every assets/models/SMB_*.glb (Scale unit: Stud).
--    Leave the imported models wherever they land; this tool puts them in the right place.
-- 2. Command bar (View > Command Bar), paste and press Enter:
--        require(game.ServerScriptService.Server.Tools.BlendImport).apply()
-- 3. File > Save to Roblox.
--
-- What apply() does (one undo step; safe to run again):
--   * moves the SMB_* models into Workspace.Map.Imported, at their Blender positions + OFFSET
--     (north of the lobby plaza, so the plaza, obby, dance floor and gems keep working)
--   * colours / materials / glass / neon from the .blend materials, collisions for floors, walls,
--     furniture (everything else is walk-through), and the Blender lights
--   * game markers: Runway (Start/End/Camera/Audience/Lineup) + Podium on the runway stage,
--     skin tone + body type booths in the Customize capsules, shop kiosks in the shop bays,
--     VIP kiosk in the VIP lounge, Dressing Room kiosk at the Team Up console
--   * the private dressing room becomes ServerStorage.SMB_BoothTemplate: every styling booth is
--     a copy of it
--   * moves an old Workspace.LobbyEnvironment to ServerStorage (not deleted) so it doesn't overlap

local ChangeHistoryService = game:GetService("ChangeHistoryService")
local RunService = game:GetService("RunService")
local ServerStorage = game:GetService("ServerStorage")
local Workspace = game:GetService("Workspace")

local BlendData = require(script.Parent.BlendData)
local BlendPieces = require(script.Parent.BlendPieces)

local BlendImport = {}

-- Where the building goes, relative to its Blender position. -70 on Z puts the foyer doors just
-- past the north edge of the 120x120 lobby plaza.
BlendImport.OFFSET = Vector3.new(0, 0, -70)

-- Mesh name prefixes/parts that players should collide with. Everything else is walk-through
-- (lights, signs, ceilings, glass capsules, plants...).
local SOLID_PATTERNS = {
	"^FLR_",
	"_Floor",
	"Walls_Shell",
	"^WALL_",
	"Wall_Finishes",
	"^PIL_",
	"_Frame$",
	"Counter",
	"Platform",
	"Podium",
	"STAGE_Walls",
	"STAGE_Runway",
	"STAGE_Seating",
	"Ramp",
	"Sofa",
	"Armchair",
	"Pouf",
	"Table",
	"Planter",
	"Bench",
	"Stair",
	"Step",
}
local FLAT_PATTERNS = { "^FLR_", "_Floor" } -- simple slabs: a box collider is exact and cheap

local function matches(name: string, patterns: { string }): boolean
	for _, pattern in patterns do
		if string.find(name, pattern) then
			return true
		end
	end
	return false
end

-- "SHOP_Counter__MAT_SHOP_Gloss_Black" -> "SHOP_Counter", "MAT_SHOP_Gloss_Black"
local function splitName(name: string): (string, string?)
	local object, material = string.match(name, "^(.-)__(.+)$")
	if not object then
		return name, nil
	end
	-- duplicate pieces get a "__<n>" suffix
	local trimmed = string.match(material :: string, "^(.-)__%d+$")
	return object, trimmed or material
end

-- True while the game runs the setup itself (BlendImport.autoSetup): CollisionFidelity can only be
-- set in Studio, so walls stay walk-through instead of using a blocky default collision.
local runtimeMode = false

local function applyLook(part: BasePart, objectName: string, materialName: string?)
	local info = if materialName then BlendData.materials[materialName] else nil
	for _, child in part:GetChildren() do
		if child:IsA("SurfaceAppearance") then
			child:Destroy() -- the .blend has no texture images; colour comes from the material below
		end
	end
	part.Anchored = true
	part.Reflectance = 0
	part.Transparency = 0
	if info then
		local lower = string.lower(materialName :: string)
		part.Color = info.color
		if info.emission >= 2 then
			part.Material = Enum.Material.Neon
		elseif info.alpha < 0.5 then
			part.Material = Enum.Material.Glass
			part.Transparency = math.clamp(1 - info.alpha, 0.5, 0.9)
		elseif string.find(lower, "marble") then
			part.Material = Enum.Material.Marble
		elseif string.find(lower, "foliage") then
			part.Material = Enum.Material.Grass
		elseif string.find(lower, "soil") then
			part.Material = Enum.Material.Ground
		elseif
			string.find(lower, "velvet")
			or string.find(lower, "upholstery")
			or string.find(lower, "rug")
		then
			part.Material = Enum.Material.Fabric
		elseif info.metallic >= 0.5 and info.roughness >= 0.3 then
			part.Material = Enum.Material.Metal
		else
			part.Material = Enum.Material.SmoothPlastic
			-- glossy / polished-metal surfaces get a little shine
			if info.roughness < 0.15 or info.metallic >= 0.5 then
				part.Reflectance = 0.12
			end
		end
		part.CastShadow = part.Material ~= Enum.Material.Neon and part.Material ~= Enum.Material.Glass
	end
	local solid = matches(objectName, SOLID_PATTERNS)
	if runtimeMode and not matches(objectName, FLAT_PATTERNS) then
		solid = false
	end
	part.CanCollide = solid
	part.CanTouch = solid
	part.CanQuery = solid
	if solid and part:IsA("MeshPart") then
		local fidelity = if matches(objectName, FLAT_PATTERNS)
			then Enum.CollisionFidelity.Box
			else Enum.CollisionFidelity.PreciseConvexDecomposition
		-- Only Studio (command bar / plugins) may set this; fine here.
		pcall(function()
			part.CollisionFidelity = fidelity
		end)
	end
	-- The Cover Star frame stands over its platform: players walk in through it.
	if objectName == "ARC_Cover_Star_Frame" then
		part.CanCollide = false
	end
	-- Entrance glass doors: let players walk through (they act like automatic doors).
	if string.find(objectName, "DOOR_Entrance_Doors") then
		part.CanCollide = false
		part.Transparency = math.max(part.Transparency, 0.55)
	end
end

local function marker(parent: Instance, name: string, cframe: CFrame, size: Vector3?): Part
	local existing = parent:FindFirstChild(name)
	if existing then
		existing:Destroy()
	end
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.Transparency = 1
	p.Size = size or Vector3.new(2, 1, 2)
	p.CFrame = cframe
	p.Parent = parent
	return p
end

local function getOrCreate(parent: Instance, name: string, className: string): Instance
	local existing = parent:FindFirstChild(name)
	if existing and existing.ClassName == className then
		return existing
	end
	local instance = Instance.new(className)
	instance.Name = name
	instance.Parent = parent
	return instance
end

local function at(name: string): Vector3
	local position = BlendData.markers[name]
	assert(position, `BlendData has no marker {name}`)
	return position + BlendImport.OFFSET
end

local function addLights(folder: Instance)
	for _, light in BlendData.lights do
		local position = light.pos + BlendImport.OFFSET
		local holder = marker(
			folder,
			light.name,
			CFrame.lookAt(position, position + light.dir),
			Vector3.new(0.2, 0.2, 0.2)
		)
		local energy = light.energy
		local object: Light
		if light.kind == "SPOT" then
			local spot = Instance.new("SpotLight")
			spot.Face = Enum.NormalId.Front
			spot.Angle = math.clamp((light.angle or 45) * 0.6, 15, 90)
			spot.Range = math.clamp(math.sqrt(energy) * 1.2, 12, 60)
			spot.Brightness = math.clamp(energy / 800, 0.5, 3)
			object = spot
		elseif light.kind == "AREA" then
			local area = Instance.new("SurfaceLight")
			area.Face = Enum.NormalId.Front
			area.Angle = 90
			area.Range = math.clamp(math.sqrt(energy) * 0.8, 8, 40)
			area.Brightness = math.clamp(energy / 1000, 0.3, 2)
			object = area
		else
			local point = Instance.new("PointLight")
			point.Range = math.clamp(math.sqrt(energy) * 1.2, 6, 40)
			point.Brightness = math.clamp(energy / 400, 0.3, 2)
			object = point
		end
		object.Color = light.color
		object.Shadows = false
		object.Parent = holder
	end
end

-- Studio may rename imported parts (case, spaces, "_1" suffixes...), so pieces are matched on a
-- loose key: lower-case letters and digits only, trailing copy numbers ignored.
local function looseKey(name: string): string
	return string.lower((string.gsub(name, "[^%w]", "")))
end
local pieceByKey: { [string]: string } = {}
for name in BlendPieces do
	pieceByKey[looseKey(name)] = name
end

-- Studio cuts names over 50 characters to "<first 23>...<last 24>". Finds the piece whose full
-- name starts and ends that way.
local function shortenedPiece(name: string): string?
	local head, tail = string.match(name, "^(.-)%.%.%.(.+)$")
	if not head then
		return nil
	end
	local headKey, tailKey = looseKey(head), looseKey(tail :: string)
	local found: string? = nil
	for key, piece in pieceByKey do
		if
			#key >= #headKey + #tailKey
			and string.sub(key, 1, #headKey) == headKey
			and string.sub(key, -#tailKey) == tailKey
		then
			if found then
				return nil -- more than one piece fits; don't guess
			end
			found = piece
		end
	end
	return found
end

-- The Blender piece name this part is, or nil if it isn't part of the building.
local function pieceName(part: BasePart): string?
	if string.find(part.Name, "...", 1, true) then
		return shortenedPiece(part.Name)
	end
	local key = looseKey(part.Name)
	local exact = pieceByKey[key]
	if exact then
		return exact
	end
	-- Drop a copy number Studio may have added ("...swatch07" + "1"), one digit at a time.
	for _ = 1, 3 do
		if not string.match(key, "%d$") then
			break
		end
		key = string.sub(key, 1, -2)
		local found = pieceByKey[key]
		if found then
			return found
		end
	end
	return nil
end

-- Puts one imported piece exactly where it is in Blender (+ OFFSET), at its Blender size, and
-- anchors it. Works however Studio imported it (anywhere, scaled, or already fallen over).
-- Studio's 3D importer turns every mesh half a turn around Y (signs read backwards, room openings face
-- outwards), so each piece is turned back.
local IMPORT_TURN = CFrame.Angles(0, math.pi, 0)
local function snap(part: BasePart, name: string)
	local data = BlendPieces[name]
	part.Anchored = true
	part.AssemblyLinearVelocity = Vector3.zero
	part.AssemblyAngularVelocity = Vector3.zero
	part.Size = Vector3.new(data[4], data[5], data[6])
	part.CFrame = CFrame.new(Vector3.new(data[1], data[2], data[3]) + BlendImport.OFFSET) * IMPORT_TURN
end

-- Top-level things in Workspace that can hold imported pieces (not the game's own map, players,
-- terrain or camera).
local function candidates(): { Instance }
	local list = {}
	for _, child in Workspace:GetChildren() do
		if
			child:IsA("Terrain")
			or child:IsA("Camera")
			or child.Name == "Map"
			or (child:IsA("Model") and child:FindFirstChildOfClass("Humanoid"))
		then
			continue
		end
		table.insert(list, child)
	end
	local map = Workspace:FindFirstChild("Map")
	local imported = if map then map:FindFirstChild("Imported") else nil
	if imported then
		table.insert(list, imported)
	end
	return list
end

local function kiosk(
	parent: Instance,
	name: string,
	position: Vector3,
	title: string,
	tab: string,
	action: string?
)
	local spot = marker(parent, name, CFrame.new(position + Vector3.new(0, 3, 0)), Vector3.new(4, 6, 4))
	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = action or "Shop"
	prompt.ObjectText = title
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = 12
	prompt.RequiresLineOfSight = false
	prompt:SetAttribute("ShopTab", tab)
	prompt.Parent = spot
end

-- A point a few studs in front of a shop bay (toward the middle of the shop).
local function inFrontOf(bay: Vector3, toward: Vector3, distance: number): Vector3
	local flat = Vector3.new(toward.X - bay.X, 0, toward.Z - bay.Z)
	return Vector3.new(bay.X, 0, bay.Z) + flat.Unit * distance
end

export type Options = { stashOld: boolean?, lights: boolean?, runtime: boolean? }

function BlendImport.apply(options: Options?)
	local stashOld = if options and options.stashOld ~= nil then options.stashOld else true
	local withLights = if options and options.lights ~= nil then options.lights else true
	local runtime = options ~= nil and options.runtime == true
	print("[BlendImport v5] starting (building + arcade hall)")
	if RunService:IsRunning() and not runtime then
		warn(
			"[BlendImport] Stop the game first (red Stop button), then run this again. Changes made during Play are thrown away."
		)
		return
	end
	runtimeMode = runtime
	local recording = if runtime
		then nil
		else select(
			2,
			pcall(
				ChangeHistoryService.TryBeginRecording,
				ChangeHistoryService,
				"Import Style My Bestie building"
			)
		) :: string?

	local ok, err = pcall(function()
		local map = getOrCreate(Workspace, "Map", "Model")
		local imported = getOrCreate(map, "Imported", "Model")

		-- 1. Find every imported piece (anywhere in Workspace, however Studio named the models),
		-- snap it into place and style it. The private dressing room's pieces (PMD_*) are gathered
		-- into their own model; everything else goes under Map.Imported.
		local room = Instance.new("Model")
		room.Name = "SMB_DressingRoom"
		local matched, loose, roomPieces = 0, 0, 0
		local unknownNames: { string } = {}
		local tops: { [Instance]: boolean } = {}
		local emptied: { [Instance]: boolean } = {} -- models the dressing room pieces came out of
		for _, holder in candidates() do
			local parts = holder:GetDescendants()
			table.insert(parts, holder) -- a part dropped straight into Workspace
			for _, part in parts do
				if not part:IsA("BasePart") then
					continue
				end
				local name = pieceName(part)
				if not name then
					if not part.Anchored then
						part.Anchored = true -- whatever it is, don't let it fall
						loose += 1
						if #unknownNames < 8 then
							table.insert(unknownNames, part:GetFullName())
						end
					end
					continue
				end
				matched += 1
				snap(part, name)
				local objectName, materialName = splitName(name)
				applyLook(part, objectName, materialName)
				if string.sub(name, 1, 4) == "PMD_" then
					part.Parent = room
					roomPieces += 1
					if holder ~= part then
						emptied[holder] = true
					end
				elseif part == holder then
					part.Parent = imported
				elseif holder ~= imported then
					tops[holder] = true
				end
			end
		end
		for holder in tops do
			holder.Parent = imported
		end
		-- The dressing room's imported model is left with only empty "_Node" models: remove it.
		for holder in emptied do
			if
				not tops[holder]
				and holder ~= imported
				and not holder:FindFirstChildWhichIsA("BasePart", true)
			then
				holder:Destroy()
			end
		end
		if roomPieces > 0 then
			room.Parent = Workspace
		end
		local total = 0
		for _ in BlendPieces do
			total += 1
		end
		print(
			`[BlendImport] matched {matched} of {total} building pieces ({roomPieces} in the dressing room)`
		)
		if matched == 0 then
			warn("[BlendImport] No building pieces found. Import the .glb files from assets/models first.")
		end
		if loose > 0 then
			warn(
				`[BlendImport] anchored {loose} other loose part(s) so they don't fall, e.g.: {table.concat(
					unknownNames,
					", "
				)}`
			)
		end

		-- 2. Lights.
		if withLights then
			local lights = getOrCreate(imported, "Lights", "Folder")
			lights:ClearAllChildren()
			addLights(lights)
			print(`[BlendImport] added {#BlendData.lights} lights`)
		end

		-- 3. Runway + podium on the stage. The catwalk runs west -> east at Blender Y 141.
		local backup = getOrCreate(ServerStorage, "MapBackup", "Folder")
		for _, name in { "Runway", "Podium" } do
			local old = map:FindFirstChild(name)
			if old and not old:FindFirstChild("ImportedMarker") then
				old.Parent = backup
			end
		end
		local runway = getOrCreate(map, "Runway", "Model")
		local podium = getOrCreate(map, "Podium", "Model")
		marker(runway, "ImportedMarker", CFrame.new(at("STAGE_Performer_Spawn")))
		marker(podium, "ImportedMarker", CFrame.new(at("STAGE_Performer_Spawn")))
		local start = at("STAGE_Performer_Spawn") + Vector3.new(0, 3, 0)
		local walkEnd = Vector3.new(20, start.Y, start.Z)
		local east = Vector3.new(1, 0, 0)
		marker(runway, "Start", CFrame.lookAt(start, start + east))
		marker(runway, "End", CFrame.lookAt(walkEnd, walkEnd + east))
		local cameraPos = Vector3.new(29, start.Y + 6, start.Z)
		marker(runway, "Camera", CFrame.lookAt(cameraPos, start))
		-- Lineup and podium face the camera (east); players spread along Z.
		local lineup = Vector3.new(16, start.Y, start.Z)
		marker(runway, "Lineup", CFrame.lookAt(lineup, lineup + east))
		local podiumX = 9
		marker(
			podium,
			"First",
			CFrame.lookAt(Vector3.new(podiumX, start.Y + 1, start.Z), Vector3.new(29, start.Y + 1, start.Z))
		)
		marker(
			podium,
			"Second",
			CFrame.lookAt(Vector3.new(podiumX, start.Y, start.Z - 6), Vector3.new(29, start.Y, start.Z - 6))
		)
		marker(
			podium,
			"Third",
			CFrame.lookAt(Vector3.new(podiumX, start.Y, start.Z + 6), Vector3.new(29, start.Y, start.Z + 6))
		)
		-- Audience: the floor by the spectator entrance (seats on both sides of the catwalk).
		local spectators = at("STAGE_Spectator_Arrival")
		marker(runway, "Audience", CFrame.new(spectators + Vector3.new(5, 0.5, -4)), Vector3.new(28, 1, 6))

		-- 4. Lobby markers: booths, kiosks, approach floor.
		local lobby = getOrCreate(map, "Lobby", "Model")
		lobby:SetAttribute("ImportedMap", true)
		local O = BlendImport.OFFSET
		marker(lobby, "SkinToneBooth", CFrame.new(Vector3.new(-41.5, 0.2, -78.8) + O))
		marker(lobby, "BodyTypeBooth", CFrame.new(Vector3.new(-52, 0.2, -78.8) + O))
		local shopMiddle = Vector3.new(-46.6, 0, -51.5) + O
		type Bay = { name: string, at: Vector3, title: string, tab: string }
		local bays: { Bay } = {
			{
				name = "Kiosk_Passes",
				at = Vector3.new(-42, 0, -32.4),
				title = "VIP & PASSES",
				tab = "Passes",
			},
			{ name = "Kiosk_Trails", at = Vector3.new(-51.5, 0, -32.4), title = "TRAILS", tab = "Trails" },
			{
				name = "Kiosk_Effects",
				at = Vector3.new(-62.1, 0, -41.5),
				title = "ENTRANCES",
				tab = "Effects",
			},
			{ name = "Kiosk_Titles", at = Vector3.new(-62.1, 0, -61.5), title = "TITLES", tab = "Titles" },
			{
				name = "Kiosk_Walks",
				at = Vector3.new(-51.5, 0, -70.6),
				title = "WALKS & POSES",
				tab = "Walks",
			},
			{ name = "Kiosk_Auras", at = Vector3.new(-42, 0, -70.6), title = "AURAS", tab = "Auras" },
		}
		for _, bay in bays do
			kiosk(lobby, bay.name, inFrontOf(bay.at + O, shopMiddle, 4), bay.title, bay.tab)
		end
		kiosk(lobby, "Kiosk_VIPLounge", Vector3.new(41, 0, -51.5) + O, "VIP LOUNGE", "Passes")
		kiosk(
			lobby,
			"Kiosk_DressingRoom",
			Vector3.new(-47.8, 0, -97.5) + O,
			"DRESSING ROOM",
			"DressingRoom",
			"Dress up"
		)
		-- Floor from the plaza's north edge (Z -60) to the foyer doors.
		local approach = lobby:FindFirstChild("ApproachFloor")
		if approach then
			approach:Destroy()
		end
		local floor = Instance.new("Part")
		floor.Name = "ApproachFloor"
		floor.Anchored = true
		floor.Size = Vector3.new(40, 1, 32)
		floor.CFrame = CFrame.new(0, -0.5, -70)
		floor.Material = Enum.Material.Marble
		floor.Color = BlendData.materials.MAT_Black_Marble.color
		floor.Parent = lobby

		-- 5. Private dressing room -> booth template (styling booths are copies of it).
		if roomPieces > 0 then
			local anchor = at("PMD_Avatar_Stand_Point")
			local front = at("CAM_PMD_Front")
			local mannequinPos = anchor + Vector3.new(0, 4, 0)
			local standPos = Vector3.new(anchor.X, anchor.Y + 3, anchor.Z + 9)
			marker(
				room,
				"Mannequin",
				CFrame.lookAt(mannequinPos, Vector3.new(front.X, mannequinPos.Y, front.Z))
			)
			marker(room, "Stand", CFrame.lookAt(standPos, Vector3.new(anchor.X, standPos.Y, anchor.Z)))
			room:SetAttribute("Anchor", Vector3.new(anchor.X, 0, anchor.Z))
			room.Name = "SMB_BoothTemplate"
			local oldTemplate = ServerStorage:FindFirstChild("SMB_BoothTemplate")
			if oldTemplate then
				oldTemplate.Parent = backup
			end
			room.Parent = ServerStorage
			print("[BlendImport] private dressing room -> ServerStorage.SMB_BoothTemplate")
		end
		-- A template made by an earlier run isn't in Workspace any more: re-snap its pieces too.
		local template = ServerStorage:FindFirstChild("SMB_BoothTemplate")
		if template and roomPieces == 0 then
			for _, part in template:GetDescendants() do
				local name = if part:IsA("BasePart") then pieceName(part) else nil
				if name then
					snap(part :: BasePart, name)
					local objectName, materialName = splitName(name)
					applyLook(part :: BasePart, objectName, materialName)
				end
			end
		end

		-- 6. The old part-built lobby would overlap; keep it, but out of the world.
		if stashOld then
			local old = Workspace:FindFirstChild("LobbyEnvironment")
			if old then
				old.Parent = backup
				print("[BlendImport] moved Workspace.LobbyEnvironment to ServerStorage.MapBackup")
			end
		end
	end)

	if recording then
		pcall(
			ChangeHistoryService.FinishRecording,
			ChangeHistoryService,
			recording,
			if ok then Enum.FinishRecordingOperation.Commit else Enum.FinishRecordingOperation.Cancel
		)
	end
	runtimeMode = false
	if not ok then
		warn(`[BlendImport] failed: {err}`)
	else
		print(
			if runtime
				then "[BlendImport] set up the building for this play session only. Stop, run the command in Edit mode and save to keep it."
				else "[BlendImport] done. Press Play to try it, then File > Save to Roblox."
		)
	end
end

-- Called by the server at start. If imported building pieces sit loose in Workspace (the setup was
-- never run in Studio, or not saved), set them up now so nothing falls apart. This server only.
function BlendImport.autoSetup()
	local map = Workspace:FindFirstChild("Map")
	local imported = if map then map:FindFirstChild("Imported") else nil
	for _, holder in candidates() do
		if holder == imported then
			continue
		end
		local parts = holder:GetDescendants()
		table.insert(parts, holder)
		for _, part in parts do
			if part:IsA("BasePart") and pieceName(part) then
				BlendImport.apply({ runtime = true })
				return
			end
		end
	end
	-- Already set up: just make sure nothing in the building is unanchored.
	if imported then
		for _, part in imported:GetDescendants() do
			if part:IsA("BasePart") then
				part.Anchored = true
			end
		end
	end
end

return BlendImport
