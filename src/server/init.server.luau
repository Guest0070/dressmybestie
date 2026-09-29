--!strict
-- Server entry point. Boots each system in order; systems never start themselves.

local Admin = require(script.Admin)
local Activities = require(script.Lobby.Activities)
local Analytics = require(script.Analytics)
local Cosmetics = require(script.Cosmetics)
local DressingRoom = require(script.Lobby.DressingRoom)
local LookApplier = require(script.Styling.LookApplier)
local Map = require(script.Round.Map)
local Passes = require(script.Monetization.Passes)
local PlayerData = require(script.Data.PlayerData)
local Receipts = require(script.Monetization.Receipts)
local RoundManager = require(script.Round.RoundManager)
local Shop = require(script.Monetization.Shop)
local Voting = require(script.Voting.Voting)

Map.ensure()
Passes.start()
Analytics.start() -- before PlayerData so it sees every Loaded event
PlayerData.start()
LookApplier.start()
Voting.start()
Cosmetics.start()
Shop.start()
Receipts.start()
RoundManager.start()
Admin.start()
DressingRoom.start()
Activities.start()

-- Layered clothing needs R15 avatars. Rig type is a Studio setting (File -> Avatar Settings),
-- so we can only warn loudly if it's wrong.
game:GetService("Players").PlayerAdded:Connect(function(player)
	player.CharacterAdded:Connect(function(character)
		local humanoid = character:WaitForChild("Humanoid", 10)
		if humanoid and humanoid:IsA("Humanoid") and humanoid.RigType ~= Enum.HumanoidRigType.R15 then
			warn(
				"[StyleMyBestie] Avatars are R6! Set R15 in File -> Avatar Settings, or layered clothing won't work."
			)
		end
	end)
end)

print("[StyleMyBestie] Server started")
