--!strict
-- Developer product purchases. Roblox may call ProcessReceipt several times for one purchase
-- (retries, server crashes), so this is idempotent:
--   1. The purchase ID is recorded in the player's profile in the SAME change as the grant.
--   2. We only return PurchaseGranted after ProfileStore confirms the save.
--   3. If the ID is already recorded, we don't grant again, just make sure it's saved.

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Analytics = require(script.Parent.Parent.Analytics)
local PlayerData = require(script.Parent.Parent.Data.PlayerData)
local LobbyMoments = require(script.Parent.LobbyMoments)

local Receipts = {}

local productsById: { [number]: Config.DevProduct } = {}

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

	local purchaseId = tostring(receipt.PurchaseId)
	if not PlayerData.hasPurchase(player, purchaseId) then
		local granted = PlayerData.update(player, function(data)
			PlayerData.recordPurchase(data, purchaseId)
			if product.kind == "Unlock" and product.cosmeticId then
				data.ownedCosmetics[product.cosmeticId] = true
			end
		end)
		if not granted then
			return Enum.ProductPurchaseDecision.NotProcessedYet
		end
		-- Moments aren't saved state, so they fire only when the purchase is first recorded.
		if product.kind == "Moment" and product.moment then
			LobbyMoments.queue(product.moment, player.DisplayName)
		end
		Remotes.Events.Toast:FireClient(player, `Thanks! {product.displayName} unlocked.`)
		Analytics.purchase(player, product.displayName, receipt.CurrencySpent or product.price)
	end

	if PlayerData.saveAndWait(player, Config.Data.ReceiptSaveTimeout) then
		return Enum.ProductPurchaseDecision.PurchaseGranted
	end
	return Enum.ProductPurchaseDecision.NotProcessedYet
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
