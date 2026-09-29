--!strict
-- The ONLY place that touches saved data. Everything else calls these functions.
-- ProfileStore session-locks each player's data so two servers can't overwrite each other.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Types = require(ReplicatedStorage.Shared.Types)

-- ProfileStore ships without strict types we can rely on, so treat it as `any`.
local ProfileStore = require(ServerScriptService.ServerPackages.ProfileStore) :: any

type PlayerData = Types.PlayerData
type PublicData = Types.PublicData

local TEMPLATE: PlayerData = {
	coins = 0,
	styleXp = 0,
	roundsPlayed = 0,
	heartsReceived = 0,
	ownedUnlocks = {},
	lastDailyRewardDay = 0,
	processedPurchases = {},
}

local store = ProfileStore.New(Config.Data.StoreName, TEMPLATE)
local profiles: { [Player]: any } = {}

local PlayerData = {}

local function currentDay(): number
	return os.time() // 86400
end

function PlayerData.getRank(xp: number): number
	local rank = 1
	for i, needed in Config.RankXp do
		if xp >= needed then
			rank = i
		end
	end
	return rank
end

local function toPublic(data: PlayerData): PublicData
	return {
		coins = data.coins,
		styleXp = data.styleXp,
		rank = PlayerData.getRank(data.styleXp),
		ownedUnlocks = table.clone(data.ownedUnlocks),
		canClaimDaily = data.lastDailyRewardDay < currentDay(),
	}
end

local function pushToClient(player: Player)
	local profile = profiles[player]
	if profile then
		Remotes.Events.DataChanged:FireClient(player, toPublic(profile.Data))
	end
end

-- Returns the live data table, or nil if the profile isn't loaded (yet / anymore).
-- Callers must handle nil: the player may have just left.
function PlayerData.get(player: Player): PlayerData?
	local profile = profiles[player]
	return if profile then profile.Data else nil
end

function PlayerData.isLoaded(player: Player): boolean
	return profiles[player] ~= nil
end

-- Mutate a player's data through a callback, then sync their client.
-- Returns false if the profile isn't loaded, so callers never silently lose rewards.
function PlayerData.update(player: Player, mutator: (PlayerData) -> ()): boolean
	local profile = profiles[player]
	if not profile then
		return false
	end
	mutator(profile.Data)
	pushToClient(player)
	return true
end

function PlayerData.addCoins(player: Player, amount: number): boolean
	assert(amount >= 0, "use spendCoins to remove coins")
	return PlayerData.update(player, function(data)
		data.coins += amount
	end)
end

function PlayerData.spendCoins(player: Player, amount: number): boolean
	local data = PlayerData.get(player)
	if not data or data.coins < amount then
		return false
	end
	return PlayerData.update(player, function(d)
		d.coins -= amount
	end)
end

function PlayerData.addXp(player: Player, amount: number): boolean
	return PlayerData.update(player, function(data)
		data.styleXp += amount
	end)
end

function PlayerData.hasPurchase(player: Player, purchaseId: string): boolean
	local data = PlayerData.get(player)
	return data ~= nil and table.find(data.processedPurchases, purchaseId) ~= nil
end

-- Used by ProcessReceipt (Day 8-9). Record the ID in the same change as the grant.
function PlayerData.recordPurchase(data: PlayerData, purchaseId: string)
	table.insert(data.processedPurchases, purchaseId)
	while #data.processedPurchases > Config.Data.MaxRememberedPurchases do
		table.remove(data.processedPurchases, 1)
	end
end

-- Day 8-9: add saveAndWait() here for ProcessReceipt (Save + OnAfterSave with timeout).

local function claimDaily(player: Player)
	PlayerData.update(player, function(data)
		local today = currentDay()
		if data.lastDailyRewardDay >= today then
			return -- already claimed; silently ignore spam
		end
		data.lastDailyRewardDay = today
		data.coins += Config.Rewards.DailyRewardCoins
	end)
end

local function onPlayerAdded(player: Player)
	local profile = store:StartSessionAsync(`Player_{player.UserId}`, {
		-- Stop waiting for a session lock if the player already left.
		Cancel = function()
			return player.Parent ~= Players
		end,
	})

	if profile == nil then
		-- Roblox servers or another session lock blocked us. Safer to kick than play without saving.
		player:Kick("Couldn't load your data. Please rejoin!")
		return
	end

	profile:AddUserId(player.UserId) -- GDPR compliance
	profile:Reconcile() -- fill in fields added to TEMPLATE since this player's last visit

	profile.OnSessionEnd:Connect(function()
		profiles[player] = nil
		if player.Parent == Players then
			player:Kick("Your data was opened on another server. Please rejoin!")
		end
	end)

	if player.Parent ~= Players then
		profile:EndSession() -- left while loading
		return
	end

	profiles[player] = profile
	pushToClient(player)
end

function PlayerData.start()
	Remotes.Functions.GetMyData.OnServerInvoke = function(player: Player): PublicData?
		local profile = profiles[player]
		return if profile then toPublic(profile.Data) else nil
	end
	Remotes.Events.ClaimDailyReward.OnServerEvent:Connect(claimDaily)

	-- Players who joined before this ran (possible in Studio).
	for _, player in Players:GetPlayers() do
		task.spawn(onPlayerAdded, player)
	end
	Players.PlayerAdded:Connect(onPlayerAdded)
	Players.PlayerRemoving:Connect(function(player)
		local profile = profiles[player]
		if profile then
			profile:EndSession()
		end
	end)
end

return PlayerData
