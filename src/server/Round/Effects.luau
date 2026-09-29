--!strict
-- Entrance effects for the runway, built from built-in particle/light objects (no assets needed).
-- Made on the server so every player sees them.

local Debris = game:GetService("Debris")

local Effects = {}

local DURATION = 4

local function emitter(parent: Instance, props: { [string]: any }): ParticleEmitter
	local particles = Instance.new("ParticleEmitter")
	for key, value in props do
		(particles :: any)[key] = value
	end
	particles.Parent = parent
	return particles
end

local builders: { [string]: (BasePart) -> () } = {
	Sparkles = function(root)
		local sparkles = Instance.new("Sparkles")
		sparkles.SparkleColor = Color3.fromRGB(255, 230, 120)
		sparkles.Parent = root
		Debris:AddItem(sparkles, DURATION)
	end,
	Confetti = function(root)
		local particles = emitter(root, {
			Rate = 60,
			Lifetime = NumberRange.new(1.5, 2.5),
			Speed = NumberRange.new(8, 14),
			SpreadAngle = Vector2.new(60, 60),
			Acceleration = Vector3.new(0, -20, 0),
			Size = NumberSequence.new(0.3),
			Rotation = NumberRange.new(0, 360),
			RotSpeed = NumberRange.new(-200, 200),
			Color = ColorSequence.new({
				ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 90, 160)),
				ColorSequenceKeypoint.new(0.33, Color3.fromRGB(90, 200, 255)),
				ColorSequenceKeypoint.new(0.66, Color3.fromRGB(255, 220, 80)),
				ColorSequenceKeypoint.new(1, Color3.fromRGB(120, 255, 140)),
			}),
			EmissionDirection = Enum.NormalId.Top,
		})
		Debris:AddItem(particles, DURATION)
	end,
	Spotlight = function(root)
		local light = Instance.new("SpotLight")
		light.Brightness = 8
		light.Range = 30
		light.Angle = 45
		light.Face = Enum.NormalId.Top
		light.Color = Color3.fromRGB(255, 245, 220)
		light.Parent = root
		Debris:AddItem(light, DURATION * 2)
	end,
	Bubbles = function(root)
		local particles = emitter(root, {
			Rate = 25,
			Lifetime = NumberRange.new(2, 3),
			Speed = NumberRange.new(2, 4),
			SpreadAngle = Vector2.new(180, 180),
			Size = NumberSequence.new(0.8),
			Transparency = NumberSequence.new(0.5),
			Color = ColorSequence.new(Color3.fromRGB(180, 230, 255)),
			LightEmission = 0.4,
		})
		Debris:AddItem(particles, DURATION)
	end,
	Smoke = function(root)
		local smoke = Instance.new("Smoke")
		smoke.Color = Color3.fromRGB(230, 220, 255)
		smoke.Opacity = 0.3
		smoke.RiseVelocity = 3
		smoke.Parent = root
		Debris:AddItem(smoke, 2)
	end,
	Stars = function(root)
		local particles = emitter(root, {
			Rate = 30,
			Lifetime = NumberRange.new(1, 1.6),
			Speed = NumberRange.new(10, 16),
			SpreadAngle = Vector2.new(80, 80),
			Size = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 0.6),
				NumberSequenceKeypoint.new(1, 0),
			}),
			Color = ColorSequence.new(Color3.fromRGB(255, 240, 150), Color3.fromRGB(255, 255, 255)),
			LightEmission = 1,
			EmissionDirection = Enum.NormalId.Top,
		})
		Debris:AddItem(particles, DURATION)
	end,
	Petals = function(root)
		local particles = emitter(root, {
			Rate = 40,
			Lifetime = NumberRange.new(2, 3),
			Speed = NumberRange.new(3, 6),
			SpreadAngle = Vector2.new(180, 180),
			Acceleration = Vector3.new(0, -3, 0),
			Size = NumberSequence.new(0.4),
			Rotation = NumberRange.new(0, 360),
			RotSpeed = NumberRange.new(-120, 120),
			Color = ColorSequence.new(Color3.fromRGB(230, 40, 80), Color3.fromRGB(255, 130, 170)),
		})
		Debris:AddItem(particles, DURATION)
	end,
	Fire = function(root)
		local fire = Instance.new("Fire")
		fire.Heat = 6
		fire.Size = 6
		fire.Color = Color3.fromRGB(255, 120, 40)
		fire.SecondaryColor = Color3.fromRGB(255, 220, 80)
		fire.Parent = root
		Debris:AddItem(fire, DURATION)
	end,
	Snow = function(root)
		local particles = emitter(root, {
			Rate = 50,
			Lifetime = NumberRange.new(2.5, 3.5),
			Speed = NumberRange.new(1, 3),
			SpreadAngle = Vector2.new(180, 180),
			Acceleration = Vector3.new(0, -2, 0),
			Size = NumberSequence.new(0.3),
			Color = ColorSequence.new(Color3.fromRGB(255, 255, 255)),
			LightEmission = 0.4,
		})
		Debris:AddItem(particles, DURATION)
	end,
	Hearts = function(root)
		local particles = emitter(root, {
			Rate = 20,
			Lifetime = NumberRange.new(1.5, 2),
			Speed = NumberRange.new(4, 6),
			SpreadAngle = Vector2.new(40, 40),
			Size = NumberSequence.new(0.6),
			Color = ColorSequence.new(Color3.fromRGB(255, 80, 140)),
			LightEmission = 0.6,
			EmissionDirection = Enum.NormalId.Top,
		})
		Debris:AddItem(particles, DURATION)
	end,
}

function Effects.playEntrance(character: Model, cosmeticId: string?)
	local builder = if cosmeticId then builders[cosmeticId] else nil
	local root = character:FindFirstChild("HumanoidRootPart")
	if builder and root and root:IsA("BasePart") then
		builder(root)
	end
end

-- One-off confetti burst at a spot (used when the podium is revealed).
function Effects.burst(position: Vector3)
	local anchor = Instance.new("Part")
	anchor.Anchored = true
	anchor.CanCollide = false
	anchor.CanQuery = false
	anchor.CanTouch = false
	anchor.Transparency = 1
	anchor.Size = Vector3.new(1, 1, 1)
	anchor.Position = position
	anchor.Parent = workspace
	local particles = emitter(anchor, {
		Rate = 0,
		Lifetime = NumberRange.new(2, 3),
		Speed = NumberRange.new(20, 35),
		SpreadAngle = Vector2.new(50, 50),
		Acceleration = Vector3.new(0, -25, 0),
		Size = NumberSequence.new(0.4),
		Rotation = NumberRange.new(0, 360),
		RotSpeed = NumberRange.new(-300, 300),
		Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 90, 160)),
			ColorSequenceKeypoint.new(0.5, Color3.fromRGB(255, 220, 80)),
			ColorSequenceKeypoint.new(1, Color3.fromRGB(90, 200, 255)),
		}),
		EmissionDirection = Enum.NormalId.Top,
	})
	particles:Emit(250)
	Debris:AddItem(anchor, 4)
end

return Effects
