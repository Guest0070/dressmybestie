--!strict
-- Cached lookups of catalog asset types and shoe bundle contents.
-- GetProductInfoAsync and GetBundleDetailsAsync are rate-limited web calls, so every answer is cached
-- for the life of the server and concurrent requests for the same ID share one call.

local AssetService = game:GetService("AssetService")
local MarketplaceService = game:GetService("MarketplaceService")
local RunService = game:GetService("RunService")

local IS_STUDIO = RunService:IsStudio()

local AssetInfo = {}

-- Enum.AssetType value -> name, e.g. 41 -> "HairAccessory"
local assetTypeNames: { [number]: string } = {}
for _, item in Enum.AssetType:GetEnumItems() do
	assetTypeNames[item.Value] = item.Name
end

-- assetId -> AssetType name, or false if the asset doesn't exist / isn't usable.
local typeCache: { [number]: string | false } = {}
-- bundleId -> list of asset IDs inside it, or false if invalid.
local bundleCache: { [number]: { number } | false } = {}
local inFlight: { [string]: boolean } = {}

local function waitForInFlight(key: string)
	while inFlight[key] do
		task.wait(0.05)
	end
end

-- Returns the Enum.AssetType name for a catalog asset, or nil if unknown/invalid.
-- A nil caused by a web error is not cached, so it is retried on the next request.
function AssetInfo.getAssetType(assetId: number): string?
	local cached = typeCache[assetId]
	if cached == false then
		return nil
	elseif cached ~= nil then
		return cached :: string
	end
	local key = `a{assetId}`
	if inFlight[key] then
		waitForInFlight(key)
		local after = typeCache[assetId]
		return if type(after) == "string" then after else nil
	end

	inFlight[key] = true
	local ok, info =
		pcall(MarketplaceService.GetProductInfoAsync, MarketplaceService, assetId, Enum.InfoType.Asset)
	inFlight[key] = nil
	if not ok then
		if IS_STUDIO then
			warn(`[AssetInfo] GetProductInfoAsync({assetId}) failed: {info}`)
		end
		-- Could be rate limiting or a bad ID. Only "not found"-style failures are worth caching,
		-- but we can't tell them apart reliably, so just don't cache.
		return nil
	end
	local typeName = if type(info) == "table" then assetTypeNames[(info :: any).AssetTypeId] else nil
	typeCache[assetId] = typeName or false
	return typeName
end

-- Returns the asset IDs inside a bundle of the given Enum.BundleType name, or nil if invalid.
function AssetInfo.getBundleAssets(bundleId: number, expectedBundleType: string): { number }?
	local cached = bundleCache[bundleId]
	if cached == false then
		return nil
	elseif cached ~= nil then
		return cached :: { number }
	end
	local key = `b{bundleId}`
	if inFlight[key] then
		waitForInFlight(key)
		local after = bundleCache[bundleId]
		return if type(after) == "table" then after else nil
	end

	inFlight[key] = true
	local ok, details = pcall(AssetService.GetBundleDetailsAsync, AssetService, bundleId)
	inFlight[key] = nil
	if not ok or type(details) ~= "table" then
		if IS_STUDIO then
			warn(`[AssetInfo] GetBundleDetailsAsync({bundleId}) failed: {details}`)
		end
		return nil
	end

	local bundleType = (details :: any).BundleType
	if bundleType ~= expectedBundleType then
		bundleCache[bundleId] = false
		return nil
	end
	local assetIds = {}
	for _, item in (details :: any).Items do
		if item.Type == "Asset" and type(item.Id) == "number" then
			table.insert(assetIds, item.Id)
		end
	end
	bundleCache[bundleId] = assetIds
	return assetIds
end

return AssetInfo
