--!strict
-- Draws bought "lobby moments" for everyone (confetti, hearts, snow or coin rain, disco mode),
-- with the buyer's name.

local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Kit = require(script.Parent.UI.Kit)

local Moments = {}

-- Set by init.client so we can show a banner.
Moments.onAnnounce = function(_text: string) end

type RainStyle = {
	colors: { Color3 },
	rate: number?,
	size: number?,
	speed: number?, -- how fast it falls
	spin: boolean?,
	lightEmission: number?,
}

local CONFETTI: RainStyle = {
	colors = { Color3.fromRGB(255, 90, 160), Color3.fromRGB(90, 200, 255), Color3.fromRGB(255, 220, 80) },
}
local HEARTS: RainStyle = {
	colors = { Color3.fromRGB(255, 70, 130), Color3.fromRGB(255, 150, 200), Color3.fromRGB(255, 40, 90) },
	size = 0.6,
	rate = 90,
	lightEmission = 0.4,
}
local SNOW: RainStyle =
	{ colors = { Color3.new(1, 1, 1), Color3.fromRGB(220, 240, 255) }, size = 0.3, speed = 0.4, spin = false }
local COINS: RainStyle = {
	colors = { Color3.fromRGB(255, 215, 60), Color3.fromRGB(255, 240, 140) },
	size = 0.55,
	rate = 120,
	speed = 1.6,
	lightEmission = 0.6,
}

local function rain(duration: number, style: RainStyle)
	-- An invisible part that follows the camera, raining confetti around the player.
	local emitterPart = Instance.new("Part")
	emitterPart.Anchored = true
	emitterPart.CanCollide = false
	emitterPart.CanQuery = false
	emitterPart.CanTouch = false
	emitterPart.Transparency = 1
	emitterPart.Size = Vector3.new(60, 1, 60)
	emitterPart.Parent = Workspace

	local speed = style.speed or 1
	local particles = Instance.new("ParticleEmitter")
	particles.Rate = style.rate or 150
	particles.Lifetime = NumberRange.new(4 / speed, 6 / speed)
	particles.Speed = NumberRange.new(2 * speed, 5 * speed)
	particles.EmissionDirection = Enum.NormalId.Bottom
	particles.Acceleration = Vector3.new(0, -6 * speed, 0)
	particles.Size = NumberSequence.new(style.size or 0.35)
	particles.LightEmission = style.lightEmission or 0
	if style.spin ~= false then
		particles.Rotation = NumberRange.new(0, 360)
		particles.RotSpeed = NumberRange.new(-180, 180)
	end
	local keypoints = {}
	for index, color in style.colors do
		local at = if #style.colors == 1 then 0 else (index - 1) / (#style.colors - 1)
		table.insert(keypoints, ColorSequenceKeypoint.new(at, color))
	end
	if #keypoints == 1 then
		table.insert(keypoints, ColorSequenceKeypoint.new(1, style.colors[1]))
	end
	particles.Color = ColorSequence.new(keypoints)
	particles.Parent = emitterPart

	local connection = RunService.RenderStepped:Connect(function()
		local camera = Workspace.CurrentCamera
		if camera then
			emitterPart.CFrame = CFrame.new(camera.CFrame.Position + Vector3.new(0, 25, 0))
		end
	end)
	task.delay(duration, function()
		particles.Enabled = false
		task.wait(6)
		connection:Disconnect()
		emitterPart:Destroy()
	end)
end

local function disco(duration: number)
	local effect = Instance.new("ColorCorrectionEffect")
	effect.Saturation = 0.4
	effect.Parent = Lighting
	local started = os.clock()
	local connection
	connection = RunService.RenderStepped:Connect(function()
		local t = os.clock() - started
		if t > duration then
			connection:Disconnect()
			effect:Destroy()
			return
		end
		effect.TintColor = Color3.fromHSV((t * 0.5) % 1, 0.35, 1)
	end)
end

function Moments.start()
	Remotes.Events.LobbyMoment.OnClientEvent:Connect(function(moment: string, buyerName: string)
		local duration = Config.Timings.LobbyMoment
		Kit.playSound("LobbyMoment")
		if moment == "Confetti" then
			Moments.onAnnounce(`{buyerName} made it rain confetti!`)
			rain(duration, CONFETTI)
		elseif moment == "Hearts" then
			Moments.onAnnounce(`{buyerName} sent a Heart Rain!`)
			rain(duration, HEARTS)
		elseif moment == "Snow" then
			Moments.onAnnounce(`{buyerName} made it a Snow Day!`)
			rain(duration, SNOW)
		elseif moment == "CoinShower" then
			Moments.onAnnounce(`{buyerName} started a COIN SHOWER for everyone!`)
			rain(duration, COINS)
		elseif moment == "Disco" then
			Moments.onAnnounce(`{buyerName} turned on DISCO MODE!`)
			disco(duration)
		end
	end)
end

return Moments
