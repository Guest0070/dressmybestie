--!strict
-- Server-wide "lobby moments" (confetti rain, disco mode, heart rain, snow day, coin shower)
-- bought as developer products. They play one after another so two purchases never overlap;
-- clients draw the effects. A Coin Shower also gives everyone in the server a few coins.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Analytics = require(script.Parent.Parent.Analytics)
local PlayerData = require(script.Parent.Parent.Data.PlayerData)

local LobbyMoments = {}

local queue: { { moment: string, buyerName: string } } = {}
local playing = false

local function coinShower(buyerName: string)
	local coins = Config.CoinShowerCoins
	for _, player in Players:GetPlayers() do
		if PlayerData.update(player, function(data)
			data.coins += coins
		end) then
			Analytics.coinsBought(player, coins, "CoinShower")
			Remotes.Events.Toast:FireClient(player, `{buyerName}'s Coin Shower: +{coins} coins!`)
		end
	end
end

local function playQueue()
	playing = true
	while #queue > 0 do
		local nextMoment = table.remove(queue, 1) :: { moment: string, buyerName: string }
		Remotes.Events.LobbyMoment:FireAllClients(nextMoment.moment, nextMoment.buyerName)
		if nextMoment.moment == "CoinShower" then
			coinShower(nextMoment.buyerName)
		end
		task.wait(Config.Timings.LobbyMoment)
	end
	playing = false
end

-- buyerName is the buyer's Roblox display name (already moderated by Roblox).
function LobbyMoments.queue(moment: string, buyerName: string)
	table.insert(queue, { moment = moment, buyerName = buyerName })
	if not playing then
		task.spawn(playQueue)
	end
end

return LobbyMoments
