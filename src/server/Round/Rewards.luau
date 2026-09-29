--!strict
-- Hands out coins + style XP at the end of a round. Fixed amounts from Config; nothing random.
-- Hearts a look receives are credited to the stylist(s) who made it, not the wearer.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Types = require(ReplicatedStorage.Shared.Types)
local PlayerData = require(script.Parent.Parent.Data.PlayerData)
local Analytics = require(script.Parent.Parent.Analytics)

local Rewards = {}

export type LookResult = {
	wearer: Player?,
	wearerUserId: number,
	stylists: { Player },
	hearts: number,
	place: number?, -- 1..3 if on the podium
}

-- participants: everyone who played this round (still in the server).
function Rewards.grant(participants: { Player }, results: { LookResult })
	local summaries: { [Player]: Types.RewardSummary } = {}
	local function summary(player: Player): Types.RewardSummary
		local s = summaries[player]
		if not s then
			s = { coins = 0, xp = 0, heartsForYourStyling = 0 }
			summaries[player] = s
		end
		return s
	end

	for _, player in participants do
		local s = summary(player)
		s.coins += Config.Rewards.CoinsPerRoundPlayed
		s.xp += Config.Rewards.XpPerRoundPlayed
	end

	for _, result in results do
		for _, stylist in result.stylists do
			if not table.find(participants, stylist) then
				continue -- left the game
			end
			local s = summary(stylist)
			s.heartsForYourStyling += result.hearts
			s.coins += result.hearts * Config.Rewards.CoinsPerHeartReceived
			s.xp += result.hearts * Config.Rewards.XpPerHeartReceived
			if result.place then
				s.coins += Config.Rewards.PodiumCoins[result.place] or 0
				s.xp += Config.Rewards.PodiumXp[result.place] or 0
			end
		end
	end

	for player, s in summaries do
		local data = PlayerData.get(player)
		if not data then
			continue
		end
		local rankBefore = PlayerData.getRank(data.styleXp)
		local ok = PlayerData.update(player, function(d)
			d.coins += s.coins
			d.styleXp += s.xp
			d.heartsReceived += s.heartsForYourStyling
			d.roundsPlayed += 1
		end)
		if not ok then
			continue
		end
		local rankAfter = PlayerData.getRank(data.styleXp)
		if rankAfter > rankBefore then
			s.rankUp = rankAfter
		end
		Analytics.coins(player, s.coins, true, "RoundReward")
		Analytics.roundFinished(player)
		Remotes.Events.RewardSummary:FireClient(player, s)
	end
end

return Rewards
