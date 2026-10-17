--!strict
-- One-time rewards that come with a game pass (the Starter Pack's coins). Game passes can't be
-- bought twice, but we check on every join and every purchase, so the grant is recorded in the
-- player's profile (passGrants) in the same change as the coins: it can never be given twice.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Analytics = require(script.Parent.Parent.Analytics)
local PlayerData = require(script.Parent.Parent.Data.PlayerData)
local Passes = require(script.Parent.Passes)

local PassGrants = {}

local function check(player: Player)
	local data = PlayerData.get(player)
	if not data or data.passGrants.StarterPack or not Passes.owns(player, "StarterPack") then
		return
	end
	local coins = Config.PassPerks.StarterCoins
	local granted = false
	PlayerData.update(player, function(d)
		if d.passGrants.StarterPack then
			return -- granted while Passes.owns was checking
		end
		d.passGrants.StarterPack = true
		d.coins += coins
		granted = true
	end)
	if granted then
		Analytics.coinsBought(player, coins, "StarterPack")
		Remotes.Events.Toast:FireClient(
			player,
			`Starter Pack unlocked! +{coins} coins, Rising Star trail and title.`
		)
	end
end

function PassGrants.start()
	PlayerData.Loaded:Connect(check)
	Passes.Changed:Connect(check)
end

return PassGrants
