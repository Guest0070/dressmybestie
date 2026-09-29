--!strict
-- The ONLY place that touches saved data. Everything else calls these functions.
-- ProfileStore session-locks each player's data so two servers can't overwrite each other.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerScriptService = game:GetService("ServerScriptService")

local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Signal = require(ReplicatedStorage.Shared.Signal)
local Types = require(ReplicatedStorage.Shared.Types)
local Passes = require(script.Parent.Parent.Monetization.Passes)
local Permissions = require(script.Parent.Permissions)

-- ProfileStore ships without strict types we can rely on, so treat it as `any`.
local ProfileStore = require(ServerScriptService.ServerPackages.ProfileStore) :: any

type PlayerData = Types.PlayerData
type PublicData = Types.PublicData

local TEMPLATE: PlayerData = {
	coins = 0,
	styleXp = 0,
	roundsPlayed = 0,
	heartsReceived = 0,
	ownedCosmetics = {},
	equipped = {},
	lastDailyRewardDay = 0,
	processedPurchases = {},
	funnelStep = 0,
}

local store = ProfileStore.New(Config.Data.StoreName, TEMPLATE)
local profiles: { [Player]: any } = {}

local PlayerData = {}

-- Fires (player) once their profile is loaded and ready.
PlayerData.Loaded = Signal.new() :: Signal.Signal<Player>

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

-- Returns the live data table, or nil if the profile isn't loaded (yet / anymore).
-- Callers must handle nil: the player may have just left.
function PlayerData.get(player: Player): PlayerData?
	local profile = profiles[player]
	return if profile then profile.Data else nil
end

function PlayerData.isLoaded(player: Player): boolean
	return profiles[player] ~= nil
end

-- Wait (up to timeout seconds) for a player's profile. Used by ProcessReceipt.
function PlayerData.waitForProfile(player: Player, timeout: number): boolean
	local deadline = os.clock() + timeout
	while not profiles[player] and player.Parent == Players and os.clock() < deadline do
		task.wait(0.25)
	end
	return profiles[player] ~= nil
end

-- True if the player may use this cosmetic: bought it, has the pass, or reached the rank.
function PlayerData.ownsCosmetic(player: Player, cosmeticId: string): boolean
	local cosmetic = Config.getCosmetic(cosmeticId)
	local data = PlayerData.get(player)
	if not cosmetic or not data then
		return false
	end
	if data.ownedCosmetics[cosmeticId] then
		return true
	end
	if cosmetic.pass and Passes.owns(player, cosmetic.pass) then
		return true
	end
	if cosmetic.rank and PlayerData.getRank(data.styleXp) >= cosmetic.rank then
		return true
	end
	return false
end

local function toPublic(player: Player, data: PlayerData): PublicData
	local owned = {}
	for _, cosmetic in Config.Cosmetics do
		if PlayerData.ownsCosmetic(player, cosmetic.id) then
			owned[cosmetic.id] = true
		end
	end
	return {
		coins = data.coins,
		styleXp = data.styleXp,
		rank = PlayerData.getRank(data.styleXp),
		ownedCosmetics = owned,
		equipped = table.clone(data.equipped),
		ownedPasses = Passes.all(player),
		canClaimDaily = data.lastDailyRewardDay < currentDay(),
		roundsPlayed = data.roundsPlayed,
		isAdmin = Permissions.isAdmin(player),
	}
end

function PlayerData.pushToClient(player: Player)
	local profile = profiles[player]
	if profile then
		Remotes.Events.DataChanged:FireClient(player, toPublic(player, profile.Data))
	end
end

-- Mutate a player's data through a callback, then sync their client.
-- Returns false if the profile isn't loaded, so callers never silently lose rewards.
function PlayerData.update(player: Player, mutator: (PlayerData) -> ()): boolean
	local profile = profiles[player]
	if not profile then
		return false
	end
	mutator(profile.Data)
	task.spawn(PlayerData.pushToClient, player) -- Passes.owns may yield; don't block the caller
	return true
end

function PlayerData.spendCoins(player: Player, amount: number): boolean
	local data = PlayerData.get(player)
	if not data or amount < 0 or data.coins < amount then
		return false
	end
	return PlayerData.update(player, function(d)
		d.coins -= amount
	end)
end

function PlayerData.hasPurchase(player: Player, purchaseId: string): boolean
	local data = PlayerData.get(player)
	return data ~= nil and table.find(data.processedPurchases, purchaseId) ~= nil
end

-- Record a purchase ID in the same change as the grant, so a retry can never grant twice.
function PlayerData.recordPurchase(data: PlayerData, purchaseId: string)
	table.insert(data.processedPurchases, purchaseId)
	while #data.processedPurchases > Config.Data.MaxRememberedPurchases do
		table.remove(data.processedPurchases, 1)
	end
end

-- Ask ProfileStore to save now and wait until the save is confirmed.
-- ProcessReceipt only returns PurchaseGranted after this succeeds.
function PlayerData.saveAndWait(player: Player, timeout: number): boolean
	local profile = profiles[player]
	if not profile or not profile:IsActive() then
		return false
	end
	local saved = false
	local connection = profile.OnAfterSave:Connect(function()
		saved = true
	end)
	profile:Save()
	local deadline = os.clock() + timeout
	while not saved and profile:IsActive() and os.clock() < deadline do
		task.wait(0.1)
	end
	connection:Disconnect()
	return saved
end

local function deepCopy(value: any): any
	if type(value) ~= "table" then
		return value
	end
	local copy = {}
	for key, inner in value do
		copy[key] = deepCopy(inner)
	end
	return copy
end

-- Admin tool: back to a brand-new player. Purchase history is kept so receipts are never re-granted.
function PlayerData.resetToTemplate(player: Player): boolean
	return PlayerData.update(player, function(data)
		local purchases = data.processedPurchases
		for key in TEMPLATE do
			(data :: any)[key] = deepCopy((TEMPLATE :: any)[key])
		end
		data.processedPurchases = purchases
	end)
end

local function claimDaily(player: Player)
	local granted = false
	PlayerData.update(player, function(data)
		local today = currentDay()
		if data.lastDailyRewardDay >= today then
			return -- already claimed; silently ignore spam
		end
		data.lastDailyRewardDay = today
		data.coins += Config.Rewards.DailyRewardCoins
		granted = true
	end)
	if granted then
		Remotes.Events.Toast:FireClient(player, `Daily reward: +{Config.Rewards.DailyRewardCoins} coins!`)
	end
end

local function onPlayerAdded(player: Player)
	local profile = store:StartSessionAsync(`Player_{player.UserId}`, {
		-- In Studio, take over a lock left behind by a previous playtest instead of waiting for it
		-- to expire. Live servers never steal: that is what protects data between servers.
		Steal = RunService:IsStudio(),
		-- Stop waiting for a session lock if the player already left.
		Cancel = function()
			return player.Parent ~= Players
		end,
	})

	if profile == nil then
		-- Roblox servers or another session lock blocked us. Safer to kick than play without saving.
		if player.Parent == Players then
			player:Kick("Couldn't load your data. Please rejoin!")
		end
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
	PlayerData.pushToClient(player)
	PlayerData.Loaded:Fire(player)
end

function PlayerData.start()
	Remotes.Functions.GetMyData.OnServerInvoke = function(player: Player): PublicData?
		local profile = profiles[player]
		return if profile then toPublic(player, profile.Data) else nil
	end
	Remotes.Events.ClaimDailyReward.OnServerEvent:Connect(claimDaily)
	Passes.Changed:Connect(PlayerData.pushToClient)

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
