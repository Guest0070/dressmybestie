--!strict
-- Developer product purchases. Roblox may call ProcessReceipt several times for one purchase
-- (retries, server crashes), so this is idempotent:
--   1. The purchase ID is recorded in the player's profile in the SAME change as the grant.
--   2. We only return PurchaseGranted after ProfileStore confirms the save.
--   3. If the ID is already recorded, we don't grant again, just make sure it's saved.

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Analytics = require(script.Parent.Parent.Analytics)
local PlayerData = require(script.Parent.Parent.Data.PlayerData)
local LobbyMoments = require(script.Parent.LobbyMoments)

local Receipts = {}

local productsById: { [number]: Config.DevProduct } = {}

-- Gives the player what the product is, once per purchase ID. False if it couldn't be saved yet.
local function grant(player: Player, product: Config.DevProduct, purchaseId: string, robux: number): boolean
	if PlayerData.hasPurchase(player, purchaseId) then
		return true -- already granted (Roblox retried); just make sure it's saved
	end
	local granted = PlayerData.update(player, function(data)
		PlayerData.recordPurchase(data, purchaseId)
		if (product.kind == "Unlock" or product.kind == "Tip") and product.cosmeticId then
			data.ownedCosmetics[product.cosmeticId] = true
		elseif product.kind == "Coins" and product.coins then
			data.coins += product.coins
		end
	end)
	if not granted then
		return false
	end
	if product.kind == "Coins" and product.coins then
		Analytics.coinsBought(player, product.coins, product.displayName)
		Remotes.Events.Toast:FireClient(player, `Thanks! +{product.coins} coins.`)
	elseif product.kind == "Tip" then
		Remotes.Events.Toast:FireClient(
			player,
			"Thank you for supporting the game! Supporter title unlocked."
		)
	elseif product.kind == "Moment" then
		Remotes.Events.Toast:FireClient(player, `Thanks! {product.displayName} is on its way.`)
	else
		Remotes.Events.Toast:FireClient(player, `Thanks! {product.displayName} unlocked.`)
	end
	Analytics.purchase(player, product.displayName, robux)
	-- Moments aren't saved state, so they fire only when the purchase is first recorded.
	if product.kind == "Moment" and product.moment then
		LobbyMoments.queue(product.moment, player.DisplayName)
	end
	return true
end

local function processReceipt(receipt: { [string]: any }): Enum.ProductPurchaseDecision
	local player = Players:GetPlayerByUserId(receipt.PlayerId)
	if not player then
		-- They left; Roblox retries next time they join a server.
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	if not PlayerData.waitForProfile(player, 15) then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	local product = productsById[receipt.ProductId]
	if not product then
		warn(`[Receipts] Unknown product {receipt.ProductId}; add it to Config.DevProducts`)
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end

	if not grant(player, product, tostring(receipt.PurchaseId), receipt.CurrencySpent or product.price) then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end

	if PlayerData.saveAndWait(player, Config.Data.ReceiptSaveTimeout) then
		return Enum.ProductPurchaseDecision.PurchaseGranted
	end
	return Enum.ProductPurchaseDecision.NotProcessedYet
end

-- Studio only (Admin panel): run a product's grant without Robux, to test it before it has an ID.
function Receipts.testGrant(player: Player, key: string): string
	local product = Config.DevProducts[key]
	if not RunService:IsStudio() then
		return "Test purchases only work in Studio."
	elseif not product then
		return `No product {key}.`
	end
	grant(player, product, `studio-test-{key}-{os.clock()}`, 0)
	return `Test-granted {product.displayName}.`
end

function Receipts.start()
	for _, product in Config.DevProducts do
		if product.id ~= 0 then
			productsById[product.id] = product
		end
	end
	MarketplaceService.ProcessReceipt = processReceipt
end

return Receipts
