--!strict
-- Draws bought "lobby moments" for everyone: confetti rain or disco mode, with the buyer's name.

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

local function confetti(duration: number)
	-- An invisible part that follows the camera, raining confetti around the player.
	local emitterPart = Instance.new("Part")
	emitterPart.Anchored = true
	emitterPart.CanCollide = false
	emitterPart.CanQuery = false
	emitterPart.CanTouch = false
	emitterPart.Transparency = 1
	emitterPart.Size = Vector3.new(60, 1, 60)
	emitterPart.Parent = Workspace

	local particles = Instance.new("ParticleEmitter")
	particles.Rate = 150
	particles.Lifetime = NumberRange.new(4, 6)
	particles.Speed = NumberRange.new(2, 5)
	particles.EmissionDirection = Enum.NormalId.Bottom
	particles.Acceleration = Vector3.new(0, -6, 0)
	particles.Size = NumberSequence.new(0.35)
	particles.Rotation = NumberRange.new(0, 360)
	particles.RotSpeed = NumberRange.new(-180, 180)
	particles.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 90, 160)),
		ColorSequenceKeypoint.new(0.5, Color3.fromRGB(90, 200, 255)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 220, 80)),
	})
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
			confetti(duration)
		elseif moment == "Disco" then
			Moments.onAnnounce(`{buyerName} turned on DISCO MODE!`)
			disco(duration)
		end
	end)
end

return Moments
