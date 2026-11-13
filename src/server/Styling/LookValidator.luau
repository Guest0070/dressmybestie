--!strict
-- Turns an untrusted look from a client into a safe, classified look.
-- Anything invalid (wrong type, body parts, over the slot limit, not a real asset) is dropped
-- silently: the stylist just sees that item not appear.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

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

-- New catalog lookups one player may cause per window. Normal styling needs about one per tap
-- (everything already seen is cached); a hacked client sending made-up IDs runs out at once.
local LOOKUP_WINDOW_SECONDS = 10
local LOOKUPS_PER_WINDOW = 40
local lookups: { [Player]: { startedAt: number, count: number } } = setmetatable({}, { __mode = "k" }) :: any

local function budgetFor(player: Player?): (() -> boolean)?
	if not player then
		return nil
	end
	local who: Player = player
	return function(): boolean
		local now = os.clock()
		local existing = lookups[who]
		local window = if existing and now - existing.startedAt < LOOKUP_WINDOW_SECONDS
			then existing
			else { startedAt = now, count = 0 }
		lookups[who] = window
		if window.count >= LOOKUPS_PER_WINDOW then
			return false
		end
		window.count += 1
		return true
	end
end

-- In Studio, say why an item was dropped (live servers stay silent).
local function reject(id: number, reason: string)
	if RunService:IsStudio() then
		warn(`[LookValidator] Dropped {id}: {reason}`)
	end
end

local function isValidId(value: any): boolean
	return type(value) == "number" and value == value and value > 0 and value < 2 ^ 53 and value % 1 == 0
end

function LookValidator.empty(): ValidatedLook
	return { look = { assetIds = {} }, accessories = {}, classic = {} }
end

-- May yield (catalog lookups). isVip gives the extra slots from the VIP pass.
-- sender: the player who sent the look; their new catalog lookups are rate limited.
function LookValidator.validate(raw: any, isVip: boolean, sender: Player?): ValidatedLook
	local result = LookValidator.empty()
	local mayFetch = budgetFor(sender)
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

	-- Walk from the newest pick (end of the list) to the oldest, so when a slot is full the
	-- newest item wins and the oldest is dropped. Numeric loop: only the array part counts.
	for i = #rawIds, 1, -1 do
		local id = rawIds[i]
		if not isValidId(id) or seen[id] then
			continue
		end
		seen[id] = true

		local typeName = AssetInfo.getAssetType(id, mayFetch)
		local rule = if typeName then Config.AssetRules[typeName] else nil
		if not rule then
			reject(id, if typeName then `asset type {typeName} not allowed` else "couldn't read asset type")
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
			-- One per property (shirt, pants, t-shirt, face); the newest one was seen first.
			if result.classic[rule.property] == nil then
				result.classic[rule.property] = id
				accepted = true
			end
		elseif rule.kind == "Emote" then
			if result.emoteId == nil then
				result.emoteId = id
				accepted = true
			end
		end

		if accepted then
			table.insert(result.look.assetIds, id)
		else
			reject(id, `replaced by a newer {typeName}`)
		end
	end

	-- We collected newest-first; put things back in the order they were picked.
	local function reverse<T>(list: { T })
		local n = #list
		for i = 1, n // 2 do
			list[i], list[n - i + 1] = list[n - i + 1], list[i]
		end
	end
	reverse(result.look.assetIds)
	reverse(result.accessories)

	-- Shoes arrive as one bundle containing a left and a right shoe.
	local bundleId = raw.shoeBundleId
	if isValidId(bundleId) then
		local shoeIds = AssetInfo.getBundleAssets(bundleId, "Shoes")
		local shoes: { AccessorySpec } = {}
		if shoeIds then
			for _, shoeId in shoeIds do
				local typeName = AssetInfo.getAssetType(shoeId, mayFetch)
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
