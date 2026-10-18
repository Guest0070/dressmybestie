--!strict
-- Runway reactions: while a look walks, anyone watching can tap an emoji (Config.Reactions). The
-- server checks it's runway time, rate-limits each player and sends the reaction to everyone, who
-- see it float up over the walker. Nothing is scored: it's cheering, not voting.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Quests = require(script.Parent.Parent.Quests)
local RoundManager = require(script.Parent.RoundManager)

local Reactions = {}

local recent: { [Player]: { number } } = {}

local function allowed(player: Player): boolean
	local now = os.clock()
	local list = recent[player] or {}
	local kept = {}
	for _, t in list do
		if now - t < 1 then
			table.insert(kept, t)
		end
	end
	if #kept >= Config.Reactions.PerSecond then
		recent[player] = kept
		return false
	end
	table.insert(kept, now)
	recent[player] = kept
	return true
end

function Reactions.start()
	Remotes.Events.React.OnServerEvent:Connect(function(player, index: any)
		if type(index) ~= "number" or not Config.Reactions.Emojis[index] then
			return
		end
		local wearer = RoundManager.currentWearer()
		if not wearer or wearer == player.UserId or not allowed(player) then
			return
		end
		Remotes.Events.Reaction:FireAllClients(wearer, index)
		Quests.bump(player, "reactions", 1)
	end)
	Players.PlayerRemoving:Connect(function(player)
		recent[player] = nil
	end)
end

return Reactions
