--!strict
-- Game pass ownership, cached per player. Never trust the client about ownership:
-- everything that gives a pass perk asks this module.

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Signal = require(ReplicatedStorage.Shared.Signal)

local Passes = {}

-- Fires (player) when a player's pass ownership changes (e.g. bought one mid-game).
Passes.Changed = Signal.new() :: Signal.Signal<Player>

local cache: { [Player]: { [string]: boolean } } = {}

local function passKeyForId(passId: number): string?
	for key, pass in Config.GamePasses do
		if pass.id ~= 0 and pass.id == passId then
			return key
		end
	end
	return nil
end

function Passes.owns(player: Player, key: string): boolean
	local pass = Config.GamePasses[key]
	if not pass or pass.id == 0 then
		return false
	end
	local playerCache = cache[player]
	if not playerCache then
		playerCache = {}
		cache[player] = playerCache
	end
	local cached = playerCache[key]
	if cached ~= nil then
		return cached
	end
	-- UserOwnsGamePassAsync is a web call and can fail; don't cache failures so we retry later.
	local ok, owns =
		pcall(MarketplaceService.UserOwnsGamePassAsync, MarketplaceService, player.UserId, pass.id)
	if not ok then
		warn(`[Passes] ownership check failed for {player.Name} / {key}: {owns}`)
		return false
	end
	if player.Parent == Players then
		playerCache[key] = owns
	end
	return owns
end

function Passes.all(player: Player): { [string]: boolean }
	local result = {}
	for key in Config.GamePasses do
		result[key] = Passes.owns(player, key)
	end
	return result
end

function Passes.start()
	MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(player, passId, purchased)
		if not purchased then
			return
		end
		local key = passKeyForId(passId)
		if key and cache[player] then
			cache[player][key] = true
			Passes.Changed:Fire(player)
		elseif key then
			cache[player] = { [key] = true }
			Passes.Changed:Fire(player)
		end
	end)
	Players.PlayerRemoving:Connect(function(player)
		cache[player] = nil
	end)
end

return Passes
