--!strict
-- Aura templates: one Folder per aura in ReplicatedStorage.Auras, holding ParticleEmitters,
-- Trails and lights. Cosmetics clones the equipped one onto the character; the client clones
-- the same template for shop previews.
--
-- To design your own in Studio: while playing, copy ReplicatedStorage.Auras into the place,
-- tweak the emitters, and keep the folder names equal to the aura ids in Config.Cosmetics.
-- A folder that already exists is never overwritten.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Auras = {}

-- Particle textures that ship with every Roblox client.
local SPARKLE = "rbxasset://textures/particles/sparkles_main.dds"
local FIRE = "rbxasset://textures/particles/fire_main.dds"

local function emitter(parent: Instance, props: { [string]: any })
	local particles = Instance.new("ParticleEmitter")
	particles.Rate = 15
	particles.Lifetime = NumberRange.new(1, 1.6)
	particles.Speed = NumberRange.new(1, 2)
	particles.SpreadAngle = Vector2.new(180, 180)
	particles.LightEmission = 0.6
	for key, value in props do
		(particles :: any)[key] = value
	end
	particles.Parent = parent
end

local function trail(parent: Instance, a: Color3, b: Color3)
	local t = Instance.new("Trail")
	t.Lifetime = 0.6
	t.LightEmission = 0.8
	t.FaceCamera = true
	t.Color = ColorSequence.new(a, b)
	t.Transparency = NumberSequence.new(0.2, 1)
	t.Parent = parent
end

local function light(parent: Instance, color: Color3, brightness: number)
	local l = Instance.new("PointLight")
	l.Color = color
	l.Range = 10
	l.Brightness = brightness
	l.Parent = parent
end

local BUILDERS: { [string]: (Folder) -> () } = {
	AuraAngel = function(f)
		emitter(f, {
			Texture = SPARKLE,
			Color = ColorSequence.new(Color3.fromRGB(255, 250, 220)),
			Size = NumberSequence.new(0.5, 0),
			Rate = 20,
		})
		light(f, Color3.fromRGB(255, 245, 210), 1.5)
	end,
	AuraHearts = function(f)
		emitter(f, {
			Color = ColorSequence.new(Color3.fromRGB(255, 110, 170)),
			Size = NumberSequence.new(0.5, 0),
			Speed = NumberRange.new(2, 3),
			EmissionDirection = Enum.NormalId.Top,
			SpreadAngle = Vector2.new(30, 30),
			Rate = 10,
		})
	end,
	AuraGalaxy = function(f)
		emitter(f, {
			Texture = SPARKLE,
			Color = ColorSequence.new(Color3.fromRGB(150, 90, 255), Color3.fromRGB(80, 170, 255)),
			Size = NumberSequence.new(0.6, 0),
			RotSpeed = NumberRange.new(-180, 180),
			Rate = 25,
		})
		trail(f, Color3.fromRGB(140, 80, 255), Color3.fromRGB(60, 180, 255))
	end,
	AuraFlame = function(f)
		emitter(f, {
			Texture = FIRE,
			Color = ColorSequence.new(Color3.fromRGB(255, 150, 40), Color3.fromRGB(255, 60, 20)),
			Size = NumberSequence.new(1.2, 0),
			Speed = NumberRange.new(3, 5),
			EmissionDirection = Enum.NormalId.Top,
			SpreadAngle = Vector2.new(20, 20),
			Rate = 30,
			LightEmission = 1,
		})
		light(f, Color3.fromRGB(255, 140, 60), 2)
	end,
	AuraElectric = function(f)
		emitter(f, {
			Texture = SPARKLE,
			Color = ColorSequence.new(Color3.fromRGB(110, 210, 255)),
			Size = NumberSequence.new(0.8, 0),
			Speed = NumberRange.new(4, 8),
			Lifetime = NumberRange.new(0.15, 0.3),
			Rate = 40,
			LightEmission = 1,
		})
		light(f, Color3.fromRGB(110, 200, 255), 2)
	end,
	AuraBubbles = function(f)
		emitter(f, {
			Color = ColorSequence.new(Color3.fromRGB(170, 230, 255)),
			Transparency = NumberSequence.new(0.5),
			Size = NumberSequence.new(0.6),
			Speed = NumberRange.new(1, 2),
			EmissionDirection = Enum.NormalId.Top,
			Lifetime = NumberRange.new(2, 3),
			Rate = 8,
		})
	end,
	AuraGolden = function(f)
		emitter(f, {
			Texture = SPARKLE,
			Color = ColorSequence.new(Color3.fromRGB(255, 215, 80)),
			Size = NumberSequence.new(0.6, 0),
			Rate = 25,
		})
		trail(f, Color3.fromRGB(255, 215, 80), Color3.fromRGB(255, 250, 200))
		light(f, Color3.fromRGB(255, 215, 120), 1.5)
	end,
	AuraSparkle = function(f)
		emitter(f, {
			Texture = SPARKLE,
			Color = ColorSequence.new(Color3.fromRGB(255, 245, 180)),
			Size = NumberSequence.new(0.4, 0),
			Rate = 12,
		})
	end,
}

function Auras.buildTemplates()
	local folder = ReplicatedStorage:FindFirstChild("Auras")
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = "Auras"
		folder.Parent = ReplicatedStorage
	end
	for id, build in BUILDERS do
		if not (folder :: Instance):FindFirstChild(id) then
			local template = Instance.new("Folder")
			template.Name = id
			build(template)
			template.Parent = folder
		end
	end
end

-- Clone every effect in an aura template onto a root part, tagging each with `tag`.
local function addClones(root: BasePart, auraId: string, tag: string)
	local folder = ReplicatedStorage:FindFirstChild("Auras")
	local template = if folder then folder:FindFirstChild(auraId) else nil
	if not template then
		return
	end
	for _, source in template:GetChildren() do
		local clone = source:Clone()
		clone:SetAttribute(tag, true)
		if clone:IsA("Trail") then
			-- Trails need two attachments on the body.
			local top = Instance.new("Attachment")
			top.Name = "AuraTop"
			top.Position = Vector3.new(0, 1, 0)
			top:SetAttribute(tag, true)
			top.Parent = root
			local bottom = Instance.new("Attachment")
			bottom.Name = "AuraBottom"
			bottom.Position = Vector3.new(0, -1, 0)
			bottom:SetAttribute(tag, true)
			bottom.Parent = root
			clone.Attachment0 = top
			clone.Attachment1 = bottom
		end
		clone.Parent = root
	end
end

local function removeTagged(root: Instance, tag: string)
	for _, child in root:GetChildren() do
		if child:GetAttribute(tag) then
			child:Destroy()
		end
	end
end

-- SERVER: put the equipped aura on a character. The old aura's effects are destroyed first, so
-- equipping a new one or unequipping (auraId = nil) never leaves effects behind.
function Auras.attach(character: Model, auraId: string?)
	local root = character:FindFirstChild("HumanoidRootPart")
	if not root or not root:IsA("BasePart") then
		return
	end
	removeTagged(root, "AuraFx")
	if auraId then
		addClones(root, auraId, "AuraFx")
	end
end

-- CLIENT: try an aura on for a few seconds (only you see it). Your real aura is paused, not
-- removed, and comes back afterwards.
function Auras.preview(character: Model, auraId: string, seconds: number)
	local root = character:FindFirstChild("HumanoidRootPart")
	if not root or not root:IsA("BasePart") then
		return
	end
	removeTagged(root, "AuraPreview")
	local paused: { Instance } = {}
	for _, child in root:GetChildren() do
		if
			child:GetAttribute("AuraFx")
			and (child:IsA("ParticleEmitter") or child:IsA("Trail") or child:IsA("Light"))
		then
			if (child :: any).Enabled then
				(child :: any).Enabled = false
				table.insert(paused, child)
			end
		end
	end
	addClones(root, auraId, "AuraPreview")
	task.delay(seconds, function()
		removeTagged(root, "AuraPreview")
		for _, child in paused do
			if child.Parent then
				(child :: any).Enabled = true
			end
		end
	end)
end

return Auras
