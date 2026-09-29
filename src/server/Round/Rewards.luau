--!strict
-- Hands out coins + style XP at the end of a round. Fixed amounts from Config; nothing random.
-- Hearts a look receives are credited to the stylist(s) who made it, not the wearer.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Types = require(ReplicatedStorage.Shared.Types)
local PlayerData = require(script.Parent.Parent.Data.PlayerData)
local Analytics = require(script.Parent.Parent.Analytics)
local Quests = require(script.Parent.Parent.Quests)

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
	local podiums: { [Player]: number } = {}
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
			-- result.hearts = hearts (Hearts mode) or total stars (Stars mode).
			local stars = Config.VotingMode == "Stars"
			s.coins += result.hearts * (if stars
				then Config.Rewards.CoinsPerStar
				else Config.Rewards.CoinsPerHeartReceived)
			s.xp += result.hearts * (if stars
				then Config.Rewards.XpPerStar
				else Config.Rewards.XpPerHeartReceived)
			-- Podium bonus only for looks that actually got hearts (no free coins for a 0-heart tie).
			if result.place and result.hearts > 0 then
				s.coins += Config.Rewards.PodiumCoins[result.place] or 0
				s.xp += Config.Rewards.PodiumXp[result.place] or 0
				podiums[stylist] = (podiums[stylist] or 0) + 1
			end
		end
	end

	for player, s in summaries do
		local data = PlayerData.get(player)
		if not data then
			continue
		end
		-- Roblox Premium perk: a fixed, disclosed bonus on round coins.
		if player.MembershipType == Enum.MembershipType.Premium then
			s.coins += math.floor(s.coins * Config.Rewards.PremiumCoinBonus)
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
		Quests.bump(player, "rounds", 1)
		Quests.bump(player, "heartsReceived", s.heartsForYourStyling)
		Quests.bump(player, "podiums", podiums[player] or 0)
		Analytics.coins(player, s.coins, true, "RoundReward")
		Analytics.roundFinished(player)
		Remotes.Events.RewardSummary:FireClient(player, s)
	end
end

return Rewards
