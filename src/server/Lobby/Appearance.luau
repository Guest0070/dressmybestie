--!strict
-- Skin Tone + Body Type booths.
-- Walk into a booth in the lobby and a panel opens (the client watches the booth's zone);
-- picking a swatch / body type is sent here, checked, saved in your profile and applied with
-- HumanoidDescription, so layered clothing re-wraps to the new body automatically.
-- Your choice is re-applied when you respawn and is exactly what walks the runway: rounds take
-- a snapshot of your current avatar (LookApplier.saveOriginal) and keep its body.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Types = require(ReplicatedStorage.Shared.Types)
local PlayerData = require(script.Parent.Parent.Data.PlayerData)
local LookApplier = require(script.Parent.Parent.Styling.LookApplier)
local RoundManager = require(script.Parent.Parent.Round.RoundManager)

local Appearance = {}

local BODY_COLOR_PROPS =
	{ "HeadColor", "TorsoColor", "LeftArmColor", "RightArmColor", "LeftLegColor", "RightLegColor" }
local SCALE_PROPS = { "HeightScale", "WidthScale", "DepthScale", "BodyTypeScale", "ProportionScale" }
local BODY_PART_PROPS = { "Torso", "LeftArm", "RightArm", "LeftLeg", "RightLeg" }

local realAvatars: { [Player]: HumanoidDescription } = {}
local busy: { [Player]: boolean } = {}

local function findBodyType(id: string): Config.BodyType?
	for _, bodyType in Config.BodyTypes do
		if bodyType.id == id then
			return bodyType
		end
	end
	return nil
end

-- The player's real avatar from their profile (used to undo a booth choice).
local function realAvatar(player: Player): HumanoidDescription?
	local cached = realAvatars[player]
	if cached then
		return cached
	end
	local ok, desc = pcall(Players.GetHumanoidDescriptionFromUserIdAsync, Players, player.UserId)
	if ok and desc then
		realAvatars[player] = desc
		return desc
	end
	return nil
end

-- Writes the saved skin tone / body type into a description (in place) and returns it.
-- Choices of 0 / "" copy the player's real avatar values back.
function Appearance.applyTo(
	player: Player,
	desc: HumanoidDescription,
	data: Types.PlayerData
): HumanoidDescription
	local real = realAvatar(player)
	local tone = Config.SkinTones[data.skinTone]
	for _, prop in BODY_COLOR_PROPS do
		if tone then
			(desc :: any)[prop] = tone
		elseif real then
			(desc :: any)[prop] = (real :: any)[prop]
		end
	end
	local bodyType = findBodyType(data.bodyType)
	if bodyType then
		desc.HeightScale = bodyType.height
		desc.WidthScale = bodyType.width
		desc.DepthScale = bodyType.depth
		desc.BodyTypeScale = bodyType.bodyType
		desc.ProportionScale = bodyType.proportion
		if bodyType.bodyParts then
			for part, id in bodyType.bodyParts do
				if table.find(BODY_PART_PROPS, part) and id > 0 then
					(desc :: any)[part] = id
				end
			end
		end
	elseif real then
		for _, prop in SCALE_PROPS do
			(desc :: any)[prop] = (real :: any)[prop]
		end
		for _, part in BODY_PART_PROPS do
			(desc :: any)[part] = (real :: any)[part]
		end
	end
	return desc
end

local function getHumanoid(player: Player): Humanoid?
	local character = player.Character
	local humanoid = if character then character:FindFirstChildOfClass("Humanoid") else nil
	return if humanoid and humanoid.Health > 0 then humanoid else nil
end

-- Re-apply the saved choices to the current character. clearOutfit: remove accessories and
-- clothing first (used for body swaps when Config.BodySwapClearsOutfit is on).
local function refresh(player: Player, clearOutfit: boolean)
	local humanoid = getHumanoid(player)
	local data = PlayerData.get(player)
	if not humanoid or not data or busy[player] then
		return
	end
	busy[player] = true
	local ok, current = pcall(humanoid.GetAppliedDescription, humanoid)
	if ok and current then
		local desc = Appearance.applyTo(player, current, data)
		if clearOutfit then
			desc = LookApplier.blankFrom(desc)
		end
		LookApplier.apply(humanoid, desc)
	end
	busy[player] = nil
end

local function onSetSkinTone(player: Player, index: any)
	if type(index) ~= "number" or index % 1 ~= 0 or index < 0 or index > #Config.SkinTones then
		return
	end
	if RoundManager.isInRound(player) then
		return -- your avatar belongs to the round right now
	end
	PlayerData.update(player, function(data)
		data.skinTone = index
	end)
	refresh(player, false)
end

local function onSetBodyType(player: Player, id: any)
	if type(id) ~= "string" or (id ~= "" and not findBodyType(id)) then
		return
	end
	if RoundManager.isInRound(player) then
		return
	end
	PlayerData.update(player, function(data)
		data.bodyType = id
	end)
	refresh(player, Config.BodySwapClearsOutfit)
end

---------------------------------------------------------------------------------------------------
-- Booth models (walk-in zones). The client opens the panel named in the Zone's "BoothPanel"
-- attribute while your character is inside the zone's radius, and closes it when you leave.
---------------------------------------------------------------------------------------------------

local function booth(parent: Instance, position: Vector3, title: string, panel: string, color: Color3)
	local model = Instance.new("Model")
	model.Name = `{panel}Booth`
	local function cylinder(name: string, height: number, radius: number, y: number, props: { [string]: any })
		local p = Instance.new("Part")
		p.Name = name
		p.Shape = Enum.PartType.Cylinder
		p.Anchored = true
		p.Size = Vector3.new(height, radius * 2, radius * 2)
		p.CFrame = CFrame.new(position + Vector3.new(0, y, 0)) * CFrame.Angles(0, 0, math.pi / 2)
		for key, value in props do
			(p :: any)[key] = value
		end
		p.Parent = model
		return p
	end
	local zone = cylinder("Zone", 0.4, 5, 0.2, { Color = color, Material = Enum.Material.Neon })
	zone:SetAttribute("BoothPanel", panel)
	zone:SetAttribute("Radius", 5)
	cylinder("Tube", 10, 5, 5.2, {
		Color = color,
		Material = Enum.Material.Glass,
		Transparency = 0.8,
		CanCollide = false,
		CanQuery = false,
	})
	local ring = cylinder("TopRing", 0.6, 5.3, 10.4, { Color = color, Material = Enum.Material.Neon })
	local sign = Instance.new("BillboardGui")
	sign.Size = UDim2.fromOffset(260, 60)
	sign.StudsOffset = Vector3.new(0, 2.5, 0)
	sign.MaxDistance = 120
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1, 1)
	label.Font = Enum.Font.FredokaOne
	label.TextScaled = true
	label.TextColor3 = color
	label.TextStrokeTransparency = 0
	label.Text = title
	label.Parent = sign
	sign.Parent = ring
	model.Parent = parent
end

function Appearance.build(parent: Instance)
	booth(parent, Vector3.new(-14, 0, -18), "SKIN TONES", "SkinTone", Color3.fromRGB(255, 190, 140))
	booth(parent, Vector3.new(14, 0, -18), "BODY TYPES", "BodyType", Color3.fromRGB(150, 200, 255))
end

function Appearance.start()
	Remotes.Events.SetSkinTone.OnServerEvent:Connect(onSetSkinTone)
	Remotes.Events.SetBodyType.OnServerEvent:Connect(onSetBodyType)

	-- Re-apply saved choices on every spawn (and once the profile loads).
	local function onCharacter(player: Player)
		local data = PlayerData.get(player)
		if data and (data.skinTone > 0 or data.bodyType ~= "") then
			task.wait(1) -- let the default avatar finish loading first
			refresh(player, false)
		end
	end
	local function watch(player: Player)
		player.CharacterAdded:Connect(function()
			onCharacter(player)
		end)
	end
	for _, player in Players:GetPlayers() do
		watch(player)
	end
	Players.PlayerAdded:Connect(watch)
	PlayerData.Loaded:Connect(onCharacter)
	Players.PlayerRemoving:Connect(function(player)
		realAvatars[player] = nil
		busy[player] = nil
	end)
end

return Appearance
