--!strict
-- Coin purchases and equipping cosmetics. Prices come only from Config (never from the client),
-- and every item has a fixed, disclosed outcome.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Analytics = require(script.Parent.Parent.Analytics)
local PlayerData = require(script.Parent.Parent.Data.PlayerData)

local Shop = {}

local VALID_SLOTS = { Entrance = true, Walk = true, Pose = true, Trail = true, Title = true }
local THROTTLE_SECONDS = 0.25

local lastRequest: { [Player]: number } = {}

-- Ignore requests that arrive faster than a human could tap (stops remote spam).
local function throttled(player: Player): boolean
	local now = os.clock()
	if now - (lastRequest[player] or 0) < THROTTLE_SECONDS then
		return true
	end
	lastRequest[player] = now
	return false
end

local function buyWithCoins(player: Player, cosmeticId: any)
	if type(cosmeticId) ~= "string" or throttled(player) then
		return
	end
	local cosmetic = Config.getCosmetic(cosmeticId)
	local data = PlayerData.get(player)
	if not cosmetic or not cosmetic.coinPrice or not data then
		return
	end
	local price = cosmetic.coinPrice
	if data.ownedCosmetics[cosmetic.id] then
		return
	end
	if data.coins < price then
		Remotes.Events.Toast:FireClient(player, "Not enough coins yet. Play a round to earn more!")
		return
	end
	-- Spend and grant in one change so they can't get out of sync.
	PlayerData.update(player, function(d)
		d.coins -= price
		d.ownedCosmetics[cosmetic.id] = true
		d.equipped[cosmetic.slot] = cosmetic.id
	end)
	Analytics.coins(player, price, false, cosmetic.id)
	Remotes.Events.Toast:FireClient(player, `Unlocked {cosmetic.displayName}!`)
end

local function equip(player: Player, slot: any, cosmeticId: any)
	if type(slot) ~= "string" or not VALID_SLOTS[slot] or throttled(player) then
		return
	end
	if cosmeticId == nil then
		PlayerData.update(player, function(d)
			d.equipped[slot] = nil
		end)
		return
	end
	if type(cosmeticId) ~= "string" then
		return
	end
	local cosmetic = Config.getCosmetic(cosmeticId)
	if not cosmetic or cosmetic.slot ~= slot or not PlayerData.ownsCosmetic(player, cosmeticId) then
		return
	end
	PlayerData.update(player, function(d)
		d.equipped[slot] = cosmeticId
	end)
end

function Shop.start()
	Remotes.Events.BuyWithCoins.OnServerEvent:Connect(buyWithCoins)
	Remotes.Events.EquipCosmetic.OnServerEvent:Connect(equip)
	Players.PlayerRemoving:Connect(function(player)
		lastRequest[player] = nil
	end)
end

return Shop
