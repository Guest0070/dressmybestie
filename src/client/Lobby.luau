--!strict
-- Client side of the lobby activities: spinning gems, the colour-cycling dance floor and the
-- bounce pads (a player's own computer moves their character, so launching happens here).

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config)
local State = require(script.Parent.State)

local Lobby = {}

local DANCE_COLORS = {
	Color3.fromRGB(255, 110, 180),
	Color3.fromRGB(110, 200, 255),
	Color3.fromRGB(255, 220, 80),
	Color3.fromRGB(180, 120, 255),
	Color3.fromRGB(120, 240, 170),
}

local lastBounce = 0

local function spinGems(dt: number)
	for _, gem in CollectionService:GetTagged("Gem") do
		if gem:IsA("BasePart") then
			gem.CFrame = gem.CFrame * CFrame.Angles(0, dt * 2, 0)
		end
	end
end

local function checkBouncePads()
	local character = State.player.Character
	local root = if character then character:FindFirstChild("HumanoidRootPart") else nil
	if not root or not root:IsA("BasePart") or os.clock() - lastBounce < 0.6 then
		return
	end
	for _, pad in CollectionService:GetTagged("BouncePad") do
		if pad:IsA("BasePart") then
			local offset = root.Position - pad.Position
			local flat = Vector3.new(offset.X, 0, offset.Z).Magnitude
			if flat < 4 and offset.Y > 0 and offset.Y < 5 then
				lastBounce = os.clock()
				local velocity = root.AssemblyLinearVelocity
				root.AssemblyLinearVelocity = Vector3.new(velocity.X, Config.Lobby.BounceVelocity, velocity.Z)
				return
			end
		end
	end
end

local function danceLoop()
	local step = 0
	while true do
		task.wait(0.45)
		step += 1
		for index, tile in CollectionService:GetTagged("DanceTile") do
			if tile:IsA("BasePart") then
				tile.Color = DANCE_COLORS[(index + step) % #DANCE_COLORS + 1]
			end
		end
	end
end

function Lobby.start()
	RunService.RenderStepped:Connect(function(dt)
		spinGems(dt)
		if State.round.phase == "Lobby" then
			checkBouncePads()
		end
	end)
	task.spawn(danceLoop)
end

return Lobby
