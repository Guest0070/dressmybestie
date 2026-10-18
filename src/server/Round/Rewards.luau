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
local Passes = require(script.Parent.Parent.Monetization.Passes)
local Badges = require(script.Parent.Parent.Badges)

local Rewards = {}

export type LookResult = {
	wearer: Player?,
	wearerUserId: number,
	stylists: { Player },
	hearts: number,
	place: number?, -- 1..3 if on the podium
}

-- participants: everyone who played this round (still in the server).
-- areFriends: cached friend check (RoundManager's), for the friend bonus.
function Rewards.grant(
	participants: { Player },
	results: { LookResult },
	areFriends: ((Player, Player) -> boolean)?
)
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
		-- Fixed, disclosed bonuses on round coins, all worked out from the base amount.
		local base = s.coins
		local bonuses = {}
		if Passes.owns(player, "DoubleCoins") then
			s.coins += base * (Config.PassPerks.DoubleCoinsMultiplier - 1)
			table.insert(bonuses, "2x Coins pass")
		end
		if player.MembershipType == Enum.MembershipType.Premium then
			s.coins += math.floor(base * Config.Rewards.PremiumCoinBonus)
			table.insert(bonuses, `Premium +{math.floor(Config.Rewards.PremiumCoinBonus * 100)}%`)
		end
		if areFriends then
			for _, other in participants do
				if other ~= player and areFriends(player, other) then
					s.coins += math.floor(base * Config.Rewards.FriendCoinBonus)
					table.insert(bonuses, `Friend bonus +{math.floor(Config.Rewards.FriendCoinBonus * 100)}%`)
					break
				end
			end
		end
		local event = Config.activeEvent(os.time())
		if event then
			s.coins += base * (event.coinMultiplier - 1)
			table.insert(bonuses, `{event.name} x{event.coinMultiplier}`)
		end
		s.bonuses = if #bonuses > 0 then bonuses else nil
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
		Badges.award(player, "FirstRound")
		if (podiums[player] or 0) > 0 then
			Badges.award(player, "FirstPodium")
		end
		if rankAfter >= 5 then
			Badges.award(player, "Rank5")
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
