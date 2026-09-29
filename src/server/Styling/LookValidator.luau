--!strict
-- Turns an untrusted look from a client into a safe, classified look.
-- Anything invalid (wrong type, body parts, over the slot limit, not a real asset) is dropped
-- silently: the stylist just sees that item not appear.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Types = require(ReplicatedStorage.Shared.Types)
local AssetInfo = require(script.Parent.AssetInfo)

export type AccessorySpec = {
	AssetId: number,
	AccessoryType: Enum.AccessoryType,
	IsLayered: boolean,
	Order: number?,
}

export type ValidatedLook = {
	look: Types.Look, -- only the IDs that passed; used for "Buy this look"
	accessories: { AccessorySpec },
	classic: { [string]: number }, -- HumanoidDescription property -> asset ID
	emoteId: number?,
}

local LookValidator = {}

local function isValidId(value: any): boolean
	return type(value) == "number" and value == value and value > 0 and value < 2 ^ 53 and value % 1 == 0
end

function LookValidator.empty(): ValidatedLook
	return { look = { assetIds = {} }, accessories = {}, classic = {} }
end

-- May yield (catalog lookups). isVip gives the extra slots from the VIP pass.
function LookValidator.validate(raw: any, isVip: boolean): ValidatedLook
	local result = LookValidator.empty()
	if type(raw) ~= "table" then
		return result
	end
	local rawIds = raw.assetIds
	if type(rawIds) ~= "table" or #rawIds > Config.Limits.MaxIdsPerLook then
		return result
	end

	local slotCounts: { [string]: number } = {}
	local layeredCount = 0
	local maxLayered = Config.Limits.MaxLayeredClothing + (if isVip then Config.Limits.VipBonusLayered else 0)
	local bonus = if isVip then Config.Limits.VipBonusAccessories else 0
	local seen: { [number]: boolean } = {}

	-- Numeric loop: only the array part counts, so extra junk keys are ignored.
	for i = 1, #rawIds do
		local id = rawIds[i]
		if not isValidId(id) or seen[id] then
			continue
		end
		seen[id] = true

		local typeName = AssetInfo.getAssetType(id)
		local rule = if typeName then Config.AssetRules[typeName] else nil
		if not rule then
			continue
		end

		local accepted = false
		if rule.kind == "Rigid" and rule.accessoryType then
			local limit = (Config.Limits.AccessoriesPerSlot[rule.accessoryType] or 0) + bonus
			local count = slotCounts[rule.accessoryType] or 0
			if count < limit then
				slotCounts[rule.accessoryType] = count + 1
				table.insert(result.accessories, {
					AssetId = id,
					AccessoryType = (Enum.AccessoryType :: any)[rule.accessoryType],
					IsLayered = false,
				})
				accepted = true
			end
		elseif rule.kind == "Layered" and rule.accessoryType then
			if layeredCount < maxLayered then
				layeredCount += 1
				table.insert(result.accessories, {
					AssetId = id,
					AccessoryType = (Enum.AccessoryType :: any)[rule.accessoryType],
					IsLayered = true,
					Order = Config.LayerOrder[rule.accessoryType] or 1,
				})
				accepted = true
			end
		elseif rule.kind == "Classic" and rule.property then
			-- One per property; a later pick replaces the earlier one.
			local previous = result.classic[rule.property]
			if previous then
				local index = table.find(result.look.assetIds, previous)
				if index then
					table.remove(result.look.assetIds, index)
				end
			end
			result.classic[rule.property] = id
			accepted = true
		elseif rule.kind == "Emote" then
			if result.emoteId == nil then
				result.emoteId = id
				accepted = true
			end
		end

		if accepted then
			table.insert(result.look.assetIds, id)
		end
	end

	-- Shoes arrive as one bundle containing a left and a right shoe.
	local bundleId = raw.shoeBundleId
	if isValidId(bundleId) then
		local shoeIds = AssetInfo.getBundleAssets(bundleId, "Shoes")
		local shoes: { AccessorySpec } = {}
		if shoeIds then
			for _, shoeId in shoeIds do
				local typeName = AssetInfo.getAssetType(shoeId)
				if typeName == "LeftShoeAccessory" or typeName == "RightShoeAccessory" then
					local rule = Config.AssetRules[typeName]
					table.insert(shoes, {
						AssetId = shoeId,
						AccessoryType = (Enum.AccessoryType :: any)[rule.accessoryType :: string],
						IsLayered = true,
						Order = Config.LayerOrder[rule.accessoryType :: string] or 6,
					})
				end
			end
		end
		if #shoes > 0 then
			for _, shoe in shoes do
				table.insert(result.accessories, shoe)
			end
			result.look.shoeBundleId = bundleId
		end
	end

	return result
end

return LookValidator
