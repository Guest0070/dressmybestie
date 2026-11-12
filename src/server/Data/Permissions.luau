--!strict
-- Who counts as an admin. Kept separate so both PlayerData and Admin can use it without a loop.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config)

local Permissions = {}

-- Group-owned game: the group's owner (rank 255) is the admin. The rank is a web call, so it is
-- looked up once per player (may yield the first time) and a failed lookup is retried next time.
local groupOwner: { [Player]: boolean } = setmetatable({}, { __mode = "k" }) :: any
local function isGroupOwner(player: Player): boolean
	local cached = groupOwner[player]
	if cached ~= nil then
		return cached
	end
	local ok, rank = pcall(function()
		return (player :: any):GetRankInGroupAsync(game.CreatorId)
	end)
	if not ok then
		ok, rank = pcall(function()
			return (player :: any):GetRankInGroup(game.CreatorId)
		end)
	end
	if ok and type(rank) == "number" then
		groupOwner[player] = rank == 255
		return rank == 255
	end
	return false
end

function Permissions.isAdmin(player: Player): boolean
	if RunService:IsStudio() then
		return true -- everyone testing in Studio
	end
	if game.CreatorType == Enum.CreatorType.User and player.UserId == game.CreatorId then
		return true -- the game owner
	end
	if game.CreatorType == Enum.CreatorType.Group and isGroupOwner(player) then
		return true -- the owner of the group that owns the game
	end
	return table.find(Config.AdminUserIds, player.UserId) ~= nil
end

return Permissions
