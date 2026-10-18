--!strict
-- Roblox badges for milestones (Config.Badges). A badge with ID 0 isn't created yet and is skipped.
-- Awarding is a web call that can fail; each badge is tried at most once per player per server
-- (Roblox remembers the ones they already have, so a repeat is harmless anyway).

local BadgeService = game:GetService("BadgeService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)

local Badges = {}

local tried: { [Player]: { [string]: boolean } } = {}

function Badges.award(player: Player, key: string)
	local id = Config.Badges[key]
	if not id or id == 0 or player.Parent ~= Players then
		return
	end
	local mine = tried[player] or {}
	tried[player] = mine
	if mine[key] then
		return
	end
	mine[key] = true
	task.spawn(function()
		local okHas, has = pcall(BadgeService.UserHasBadgeAsync, BadgeService, player.UserId, id)
		if okHas and has then
			return
		end
		local ok, err = pcall(BadgeService.AwardBadge, BadgeService, player.UserId, id)
		if not ok then
			warn(`[Badges] couldn't award {key} to {player.Name}: {err}`)
			mine[key] = nil -- try again next time
		end
	end)
end

function Badges.start()
	Players.PlayerAdded:Connect(function(player)
		Badges.award(player, "Welcome")
	end)
	for _, player in Players:GetPlayers() do
		Badges.award(player, "Welcome")
	end
	Players.PlayerRemoving:Connect(function(player)
		tried[player] = nil
	end)
end

return Badges
