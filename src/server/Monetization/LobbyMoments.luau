--!strict
-- Server-wide "lobby moments" (confetti rain, disco mode) bought as developer products.
-- They play one after another so two purchases never overlap; clients draw the effects.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)

local LobbyMoments = {}

local queue: { { moment: string, buyerName: string } } = {}
local playing = false

local function playQueue()
	playing = true
	while #queue > 0 do
		local nextMoment = table.remove(queue, 1) :: { moment: string, buyerName: string }
		Remotes.Events.LobbyMoment:FireAllClients(nextMoment.moment, nextMoment.buyerName)
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
