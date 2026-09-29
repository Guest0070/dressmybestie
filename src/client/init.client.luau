--!strict
-- Client entry point. Day 1: just proves remotes + data load. Real UI arrives Day 2+.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Types = require(ReplicatedStorage.Shared.Types)

Remotes.Events.DataChanged.OnClientEvent:Connect(function(data: Types.PublicData)
	print(
		`[StyleMyBestie] Coins: {data.coins}  XP: {data.styleXp}  Rank: {data.rank}  Daily ready: {data.canClaimDaily}`
	)
end)

print("[StyleMyBestie] Client started")
