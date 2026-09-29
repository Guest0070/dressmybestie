--!strict
-- Who counts as an admin. Kept separate so both PlayerData and Admin can use it without a loop.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config)

local Permissions = {}

function Permissions.isAdmin(player: Player): boolean
	if RunService:IsStudio() then
		return true -- everyone testing in Studio
	end
	if game.CreatorType == Enum.CreatorType.User and player.UserId == game.CreatorId then
		return true -- the game owner
	end
	return table.find(Config.AdminUserIds, player.UserId) ~= nil
end

return Permissions
