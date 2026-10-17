--!strict
-- Server entry point. Boots each system in order; systems never start themselves.

local Admin = require(script.Admin)
local Activities = require(script.Lobby.Activities)
local Analytics = require(script.Analytics)
local Cosmetics = require(script.Cosmetics)
local Appearance = require(script.Lobby.Appearance)
local DressingRoom = require(script.Lobby.DressingRoom)
local LookApplier = require(script.Styling.LookApplier)
local BlendImport = require(script.Tools.BlendImport)
local Map = require(script.Round.Map)
local Minigames = require(script.Lobby.Minigames)
local PassGrants = require(script.Monetization.PassGrants)
local Passes = require(script.Monetization.Passes)
local Quests = require(script.Quests)
local PlayerData = require(script.Data.PlayerData)
local Receipts = require(script.Monetization.Receipts)
local RoundManager = require(script.Round.RoundManager)
local Shop = require(script.Monetization.Shop)
local Voting = require(script.Voting.Voting)

-- Imported Blender building (assets/models) that was never set up in Studio: set it up now so
-- it doesn't fall apart. Must run before Map.ensure (it adds the map markers).
BlendImport.autoSetup()
Map.ensure()
Passes.start()
Analytics.start() -- before PlayerData so it sees every Loaded event
PassGrants.start() -- same: Starter Pack coins for players already in the server
PlayerData.start()
LookApplier.start()
Voting.start()
Cosmetics.start()
Quests.start()
Shop.start()
Receipts.start()
RoundManager.start()
Admin.start()
DressingRoom.start()
Appearance.start()
Activities.start()
Minigames.start()

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
