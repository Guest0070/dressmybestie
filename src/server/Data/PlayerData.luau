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
local RateLimit = require(script.Parent.Parent.RateLimit)

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
	dailyStreak = 0,
	questDay = 0,
	questProgress = {},
	questClaimed = {},
	achievementsClaimed = {},
	lifetime = {},
	skinTone = 0,
	bodyType = "",
	passGrants = {},
	savedOutfits = {},
	settings = { music = true, sfx = true, flashes = true },
}

local store = ProfileStore.New(Config.Data.StoreName, TEMPLATE)
local profiles: { [Player]: any } = {}

local PlayerData = {}

-- Fires (player) once their profile is loaded and ready.
PlayerData.Loaded = Signal.new() :: Signal.Signal<Player>
-- Fires (player) after their data changes (coins, equipped items, ...).
PlayerData.Changed = Signal.new() :: Signal.Signal<Player>

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

-- Streak day the next daily claim would be (1..#DailyStreak).
local function nextStreakDay(data: PlayerData): number
	local today = currentDay()
	local streak = if data.lastDailyRewardDay == today - 1 then data.dailyStreak + 1 else 1
	return if streak > #Config.Rewards.DailyStreak then 1 else streak
end

-- Coins the next daily claim gives, VIP bonus included.
local function dailyReward(player: Player, data: PlayerData): number
	local reward = Config.Rewards.DailyStreak[nextStreakDay(data)]
	if Passes.owns(player, "VIP") then
		reward += math.floor(reward * Config.PassPerks.VipDailyBonus)
	end
	return reward
end

-- Lifetime value of a quest stat (some live in older fields).
function PlayerData.lifetimeStat(data: PlayerData, stat: string): number
	if stat == "rounds" then
		return data.roundsPlayed
	elseif stat == "heartsReceived" then
		return data.heartsReceived
	end
	return data.lifetime[stat] or 0
end

local function questViews(data: PlayerData): { Types.QuestView }
	local views: { Types.QuestView } = {}
	local isToday = data.questDay == currentDay()
	for _, quest in Config.DailyQuests do
		local progress = if isToday then data.questProgress[quest.stat] or 0 else 0
		table.insert(views, {
			kind = "daily",
			id = quest.id,
			text = quest.text,
			progress = math.min(progress, quest.target),
			target = quest.target,
			reward = quest.reward,
			claimed = isToday and data.questClaimed[quest.id] == true,
		})
	end
	for _, quest in Config.Achievements do
		table.insert(views, {
			kind = "achievement",
			id = quest.id,
			text = quest.text,
			progress = math.min(PlayerData.lifetimeStat(data, quest.stat), quest.target),
			target = quest.target,
			reward = quest.reward,
			claimed = data.achievementsClaimed[quest.id] == true,
		})
	end
	return views
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
		nextDailyReward = dailyReward(player, data),
		dailyStreak = data.dailyStreak,
		quests = questViews(data),
		skinTone = data.skinTone,
		bodyType = data.bodyType,
		outfits = data.savedOutfits,
		outfitSlots = PlayerData.outfitSlots(player),
		settings = data.settings,
	}
end

-- Wardrobe slots this player has (VIP gets more).
function PlayerData.outfitSlots(player: Player): number
	return if Passes.owns(player, "VIP") then Config.Wardrobe.VipSlots else Config.Wardrobe.Slots
end

function PlayerData.pushToClient(player: Player)
	local profile = profiles[player]
	if profile then
		Remotes.Events.DataChanged:FireClient(player, toPublic(player, profile.Data))
		PlayerData.Changed:Fire(player)
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
	if not RateLimit.allow(player, "ClaimDaily", 1) then
		return
	end
	local current = PlayerData.get(player)
	if not current or current.lastDailyRewardDay >= currentDay() then
		return -- not loaded, or already claimed; silently ignore spam
	end
	local amount = dailyReward(player, current) -- may yield (pass check), so before the update
	local reward, streak = 0, 0
	PlayerData.update(player, function(data)
		local today = currentDay()
		if data.lastDailyRewardDay >= today then
			return -- already claimed; silently ignore spam
		end
		streak = nextStreakDay(data)
		reward = amount
		data.dailyStreak = streak
		data.lastDailyRewardDay = today
		data.coins += reward
	end)
	if reward > 0 then
		Remotes.Events.Toast:FireClient(
			player,
			`Day {streak} streak! +{reward} coins. Come back tomorrow for more!`
		)
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
	-- Settings follow the player to every server. Only the three known on/off switches are kept.
	Remotes.Events.SaveSettings.OnServerEvent:Connect(function(player, settings: any)
		if not RateLimit.allow(player, "SaveSettings", 0.5) then
			return
		end
		if type(settings) ~= "table" then
			return
		end
		local data = PlayerData.get(player)
		if not data then
			return
		end
		for _, key in { "music", "sfx", "flashes" } do
			if type(settings[key]) == "boolean" then
				(data.settings :: any)[key] = settings[key]
			end
		end
	end)
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
