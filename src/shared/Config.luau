--!strict
-- Single source of truth for tunable numbers and content lists.
-- Content updates (new themes, price tweaks, timing changes) should only touch this file.

local Config = {}

-- Round timings, in seconds.
Config.Timings = {
	Lobby = 30,
	Pairing = 3,
	ThemeReveal = 5,
	Styling = 240,
	SwapAt = 120, -- "Swap Mid-Round" chaos: seconds into styling when stylists swap
	RunwayPerPlayer = 9,
	Voting = 30,
	Results = 15,
	LobbyMoment = 30, -- length of a bought confetti/disco moment
}

Config.MinPlayersToStart = 2
-- In Studio you can test the whole loop alone: you style your own mannequin.
Config.StudioMinPlayers = 1

-- Every Nth round is eligible for chaos; a coin flip decides whether it actually happens.
Config.ChaosEveryRounds = 4
Config.ChaosChance = 0.6

Config.DefaultWalkSpeed = 16
Config.RunwayWalkSpeed = 12

-- Look limits. The server enforces these; the client uses them only for friendlier UI.
Config.Limits = {
	MaxHeartsPerVoter = 3,
	-- Max rigid accessories per Enum.AccessoryType name. VIP gets VipBonusAccessories extra per slot.
	AccessoriesPerSlot = {
		Hat = 2,
		Hair = 2,
		Face = 1,
		Neck = 1,
		Shoulder = 1,
		Front = 1,
		Back = 1,
		Waist = 1,
	} :: { [string]: number },
	VipBonusAccessories = 1,
	-- Layered clothing pieces in total (jackets, sweaters, pants, dresses, shoes...).
	MaxLayeredClothing = 6,
	VipBonusLayered = 2,
	MaxEmotes = 1,
	-- Hard cap on IDs in one request, checked before any network lookups (anti-spam).
	MaxIdsPerLook = 24,
	-- Seconds between look updates a client may send. Extra updates are merged, not dropped.
	LookUpdateInterval = 0.4,
}

-- Rewards. Coins are only ever earned by playing.
Config.Rewards = {
	CoinsPerRoundPlayed = 10,
	CoinsPerHeartReceived = 2,
	PodiumCoins = { 30, 20, 10 }, -- 1st, 2nd, 3rd (goes to the stylist)
	XpPerRoundPlayed = 20,
	XpPerHeartReceived = 5,
	PodiumXp = { 40, 25, 15 },
	DailyRewardCoins = 50,
}

-- Style rank thresholds: total XP needed to reach rank N is RankXp[N]. Rank 1 is the start.
Config.RankXp = { 0, 100, 250, 500, 900, 1500, 2400, 3600, 5200, 7500 }
Config.RankNames = {
	"Newbie",
	"Trendsetter",
	"Stylist",
	"Fashionista",
	"Icon",
	"Style Star",
	"Runway Legend",
	"Couture Queen",
	"Fashion Oracle",
	"Style Deity",
}

-- Catalog browser tabs. assetTypes are Enum.AvatarAssetType names; bundleTypes are Enum.BundleType names.
export type CatalogCategory = {
	id: string,
	assetTypes: { string }?,
	bundleTypes: { string }?,
}
Config.CatalogCategories = {
	{ id = "Hair", assetTypes = { "HairAccessory" } },
	{ id = "Hats", assetTypes = { "Hat" } },
	{
		id = "Tops",
		assetTypes = { "TShirtAccessory", "ShirtAccessory", "SweaterAccessory", "JacketAccessory", "Shirt" },
	},
	{ id = "Bottoms", assetTypes = { "PantsAccessory", "ShortsAccessory", "Pants" } },
	{ id = "Dresses", assetTypes = { "DressSkirtAccessory" } },
	{ id = "Shoes", bundleTypes = { "Shoes" } },
	{
		id = "Extras",
		assetTypes = {
			"FaceAccessory",
			"NeckAccessory",
			"ShoulderAccessory",
			"FrontAccessory",
			"BackAccessory",
			"WaistAccessory",
		},
	},
	{ id = "Faces", assetTypes = { "Face" } },
	{ id = "Emotes", assetTypes = { "EmoteAnimation" } },
} :: { CatalogCategory }

-- How the server treats each allowed Enum.AssetType name. Anything not listed here is rejected,
-- which blocks body parts, heads, skin tones and animations other than emotes.
export type AssetRule = {
	kind: "Rigid" | "Layered" | "Classic" | "Emote",
	accessoryType: string?, -- Enum.AccessoryType name for Rigid/Layered
	property: string?, -- HumanoidDescription property for Classic
}
Config.AssetRules = {
	Hat = { kind = "Rigid", accessoryType = "Hat" },
	HairAccessory = { kind = "Rigid", accessoryType = "Hair" },
	FaceAccessory = { kind = "Rigid", accessoryType = "Face" },
	NeckAccessory = { kind = "Rigid", accessoryType = "Neck" },
	ShoulderAccessory = { kind = "Rigid", accessoryType = "Shoulder" },
	FrontAccessory = { kind = "Rigid", accessoryType = "Front" },
	BackAccessory = { kind = "Rigid", accessoryType = "Back" },
	WaistAccessory = { kind = "Rigid", accessoryType = "Waist" },
	TShirtAccessory = { kind = "Layered", accessoryType = "TShirt" },
	ShirtAccessory = { kind = "Layered", accessoryType = "Shirt" },
	SweaterAccessory = { kind = "Layered", accessoryType = "Sweater" },
	JacketAccessory = { kind = "Layered", accessoryType = "Jacket" },
	PantsAccessory = { kind = "Layered", accessoryType = "Pants" },
	ShortsAccessory = { kind = "Layered", accessoryType = "Shorts" },
	DressSkirtAccessory = { kind = "Layered", accessoryType = "DressSkirt" },
	LeftShoeAccessory = { kind = "Layered", accessoryType = "LeftShoe" },
	RightShoeAccessory = { kind = "Layered", accessoryType = "RightShoe" },
	Shirt = { kind = "Classic", property = "Shirt" },
	Pants = { kind = "Classic", property = "Pants" },
	TShirt = { kind = "Classic", property = "GraphicTShirt" },
	Face = { kind = "Classic", property = "Face" },
	EmoteAnimation = { kind = "Emote" },
} :: { [string]: AssetRule }

-- Layering order for layered clothing: lower = closer to the body.
Config.LayerOrder = {
	TShirt = 1,
	Shirt = 2,
	Pants = 2,
	Shorts = 2,
	DressSkirt = 3,
	Sweater = 4,
	Jacket = 5,
	LeftShoe = 6,
	RightShoe = 6,
} :: { [string]: number }

-- Themes. Picked server-side; no free text anywhere. Add weekly packs by appending here.
-- vip = true themes only show up in rounds where at least one VIP is playing.
export type Theme = { name: string, vip: boolean? }
Config.Themes = {
	{ name = "First Date" },
	{ name = "Villain Era" },
	{ name = "Grandma at a Rave" },
	{ name = "Beach Day Gone Wrong" },
	{ name = "Main Character Energy" },
	{ name = "School Picture Day" },
	{ name = "Space Tourist" },
	{ name = "Pirate on Vacation" },
	{ name = "Rainy Monday" },
	{ name = "Wedding Guest (Uninvited)" },
	{ name = "Superhero Day Off" },
	{ name = "Cozy Winter Cabin" },
	{ name = "Job Interview at a Circus" },
	{ name = "Camping But Make It Fancy" },
	{ name = "Lost Tourist in the Snow" },
	{ name = "Pop Star Airport Look" },
	{ name = "Detective Undercover" },
	{ name = "Farmer's Market Chic" },
	{ name = "Retro Arcade Kid" },
	{ name = "Dragon Tamer" },
	{ name = "Chef in a Hurry" },
	{ name = "Sleepover Legend" },
	{ name = "Sports Day Champion" },
	{ name = "Fairy Tale Remix" },
	{ name = "Robot Learning Fashion" },
	{ name = "Birthday Party Chaos" },
	{ name = "Museum Night Guard" },
	{ name = "Jungle Explorer" },
	{ name = "Ice Cream Truck Driver" },
	{ name = "Wizard Graduation" },
	{ name = "Rock Band Reunion" },
	{ name = "Road Trip Snack Captain" },
	{ name = "Red Carpet Royalty", vip = true },
	{ name = "Haunted Gala", vip = true },
	{ name = "Billionaire on a Yacht", vip = true },
} :: { Theme }
-- Don't repeat any of the last N themes.
Config.ThemeNoRepeat = 8

-- Weekly featured theme: rotates automatically every Monday (UTC) through this list and
-- shows up more often that week. Add names from Config.Themes.
Config.FeaturedThemes = { "Villain Era", "Grandma at a Rave", "Space Tourist", "Main Character Energy" }
Config.FeaturedThemeChance = 0.3

function Config.featuredTheme(): string?
	local list = Config.FeaturedThemes
	if #list == 0 then
		return nil
	end
	-- os.time() // 604800 counts weeks since 1 Jan 1970 (a Thursday); +3 days shifts to Mondays.
	local week = (os.time() + 3 * 86400) // 604800
	return list[(week % #list) + 1]
end

-- Colors for the "One Color Only" chaos round. The name is added to catalog searches.
export type ChaosColor = { name: string, color: Color3 }
Config.ChaosColors = {
	{ name = "Red", color = Color3.fromRGB(230, 60, 60) },
	{ name = "Pink", color = Color3.fromRGB(255, 120, 190) },
	{ name = "Blue", color = Color3.fromRGB(70, 130, 240) },
	{ name = "Green", color = Color3.fromRGB(70, 190, 100) },
	{ name = "Yellow", color = Color3.fromRGB(250, 210, 60) },
	{ name = "Purple", color = Color3.fromRGB(150, 90, 220) },
	{ name = "Black", color = Color3.fromRGB(40, 40, 45) },
	{ name = "White", color = Color3.fromRGB(240, 240, 240) },
} :: { ChaosColor }

-- Chaos modifiers are data; the round system reads these flags instead of branching per mode.
export type ChaosModifier = {
	id: string,
	displayName: string,
	description: string,
	minPlayers: number, -- skipped if fewer participants
	reverseVoting: boolean?, -- hearts go to the "worst" look (still just hearts; wording changes)
	swapMidRound: boolean?,
	oneColor: boolean?,
}
Config.ChaosModifiers = {
	{
		id = "WorstOutfitWins",
		displayName = "Worst Outfit Wins",
		description = "Give hearts to the most gloriously terrible look!",
		minPlayers = 2,
		reverseVoting = true,
	},
	{
		id = "SwapMidRound",
		displayName = "Swap Mid-Round",
		description = "Halfway through, you take over someone else's look!",
		minPlayers = 3,
		swapMidRound = true,
	},
	{
		id = "OneColorOnly",
		displayName = "One Color Only",
		description = "Style using only one color!",
		minPlayers = 2,
		oneColor = true,
	},
} :: { ChaosModifier }

-- Monetization. id = 0 means "not created yet in Creator Dashboard"; those buttons hide themselves.
-- price is for display only; Roblox always charges the price set on the dashboard.
Config.GamePasses = {
	VIP = { id = 0, price = 399, displayName = "VIP" },
	PosePack = { id = 0, price = 149, displayName = "Pose Pack" },
} :: { [string]: { id: number, price: number, displayName: string } }

-- Developer products. kind "Moment" = one-time lobby moment; "Unlock" = permanent cosmetic.
export type DevProduct = {
	id: number,
	price: number,
	displayName: string,
	kind: "Moment" | "Unlock",
	cosmeticId: string?, -- for Unlock
	moment: string?, -- for Moment: "Confetti" | "Disco"
}
Config.DevProducts = {
	MomentConfetti = {
		id = 0,
		price = 49,
		displayName = "Confetti Rain",
		kind = "Moment",
		moment = "Confetti",
	},
	MomentDisco = { id = 0, price = 49, displayName = "Disco Mode", kind = "Moment", moment = "Disco" },
	EntranceSparkles = {
		id = 0,
		price = 99,
		displayName = "Sparkles Entrance",
		kind = "Unlock",
		cosmeticId = "Sparkles",
	},
	EntranceConfetti = {
		id = 0,
		price = 99,
		displayName = "Confetti Entrance",
		kind = "Unlock",
		cosmeticId = "Confetti",
	},
	EntranceSpotlight = {
		id = 0,
		price = 99,
		displayName = "Spotlight Entrance",
		kind = "Unlock",
		cosmeticId = "Spotlight",
	},
	WalkStrut = { id = 0, price = 99, displayName = "Strut Walk", kind = "Unlock", cosmeticId = "Strut" },
	WalkGlide = { id = 0, price = 149, displayName = "Glide Walk", kind = "Unlock", cosmeticId = "Glide" },
} :: { [string]: DevProduct }

-- Cosmetics. Every one has a fixed, disclosed outcome. Ways to own one:
--   coinPrice  -> buy with coins earned by playing
--   productKey -> buy with Robux (Config.DevProducts), saved forever
--   pass       -> included with a game pass
--   rank       -> unlocked for free at this style rank
-- animationId: a catalog animation asset ID (walks: the "Walk" animation from an animation pack;
-- poses: an emote). 0 = not picked yet, so it's hidden.
export type Cosmetic = {
	id: string,
	slot: "Entrance" | "Walk" | "Pose" | "Trail" | "Title",
	displayName: string,
	coinPrice: number?,
	productKey: string?,
	pass: string?,
	rank: number?,
	animationId: number?,
	color: Color3?, -- trails + titles
	color2: Color3?, -- trails: end colour (gradient)
}
Config.Cosmetics = {
	-- Entrance effects (built from particles/lights, no assets needed)
	{ id = "Smoke", slot = "Entrance", displayName = "Smoke Puff", coinPrice = 150 },
	{ id = "Bubbles", slot = "Entrance", displayName = "Bubbles", coinPrice = 250 },
	{ id = "Stars", slot = "Entrance", displayName = "Shooting Stars", coinPrice = 400 },
	{ id = "Petals", slot = "Entrance", displayName = "Rose Petals", coinPrice = 600 },
	{ id = "Fire", slot = "Entrance", displayName = "Hot Stuff (Fire)", coinPrice = 1000 },
	{ id = "Hearts", slot = "Entrance", displayName = "Hearts", rank = 3 },
	{ id = "Sparkles", slot = "Entrance", displayName = "Sparkles", productKey = "EntranceSparkles" },
	{ id = "Confetti", slot = "Entrance", displayName = "Confetti", productKey = "EntranceConfetti" },
	{ id = "Spotlight", slot = "Entrance", displayName = "Spotlight", productKey = "EntranceSpotlight" },
	-- Trails (follow you around the lobby and down the runway)
	{
		id = "TrailPink",
		slot = "Trail",
		displayName = "Bubblegum Trail",
		coinPrice = 200,
		color = Color3.fromRGB(255, 120, 190),
		color2 = Color3.fromRGB(255, 200, 230),
	},
	{
		id = "TrailOcean",
		slot = "Trail",
		displayName = "Ocean Trail",
		coinPrice = 350,
		color = Color3.fromRGB(60, 160, 255),
		color2 = Color3.fromRGB(120, 255, 230),
	},
	{
		id = "TrailSunset",
		slot = "Trail",
		displayName = "Sunset Trail",
		coinPrice = 600,
		color = Color3.fromRGB(255, 150, 60),
		color2 = Color3.fromRGB(200, 60, 200),
	},
	{
		id = "TrailMint",
		slot = "Trail",
		displayName = "Mint Trail",
		rank = 4,
		color = Color3.fromRGB(120, 240, 170),
		color2 = Color3.fromRGB(230, 255, 240),
	},
	{
		id = "TrailGold",
		slot = "Trail",
		displayName = "Golden Trail",
		pass = "VIP",
		color = Color3.fromRGB(255, 215, 80),
		color2 = Color3.fromRGB(255, 250, 200),
	},
	-- Titles (shown over your head and on the runway)
	{
		id = "TitleCute",
		slot = "Title",
		displayName = "Certified Cutie",
		coinPrice = 150,
		color = Color3.fromRGB(255, 150, 200),
	},
	{
		id = "TitleDrip",
		slot = "Title",
		displayName = "Drip Detected",
		coinPrice = 300,
		color = Color3.fromRGB(100, 200, 255),
	},
	{
		id = "TitleChaos",
		slot = "Title",
		displayName = "Chaos Stylist",
		coinPrice = 500,
		color = Color3.fromRGB(255, 120, 80),
	},
	{
		id = "TitleRoyal",
		slot = "Title",
		displayName = "Runway Royalty",
		coinPrice = 1200,
		color = Color3.fromRGB(255, 215, 80),
	},
	{
		id = "TitleIcon",
		slot = "Title",
		displayName = "Style Icon",
		rank = 6,
		color = Color3.fromRGB(200, 140, 255),
	},
	{
		id = "TitleVIP",
		slot = "Title",
		displayName = "VIP",
		pass = "VIP",
		color = Color3.fromRGB(255, 215, 80),
	},
	-- Runway walks
	{ id = "Strut", slot = "Walk", displayName = "Strut", productKey = "WalkStrut", animationId = 0 },
	{ id = "Glide", slot = "Walk", displayName = "Glide", productKey = "WalkGlide", animationId = 0 },
	-- Poses at the end of the runway
	{ id = "PoseHands", slot = "Pose", displayName = "Hands on Hips", pass = "PosePack", animationId = 0 },
	{ id = "PoseWave", slot = "Pose", displayName = "Royal Wave", pass = "PosePack", animationId = 0 },
	{ id = "PoseBlow", slot = "Pose", displayName = "Blow a Kiss", pass = "PosePack", animationId = 0 },
} :: { Cosmetic }

-- Sound effect asset IDs from the Creator Store (Toolbox -> Audio). 0 = silent until picked.
Config.Sounds = {
	Click = "rbxasset://sounds/electronicpingshort.wav", -- built into every Roblox client
	PhaseChange = 0,
	RunwayMusic = 0,
	Heart = 0,
	Podium = 0,
	LobbyMoment = 0,
} :: { [string]: number | string }

-- Lobby activities. Coin rewards are small and capped so the lobby is fun, not a coin farm.
Config.Lobby = {
	GemCoins = 2, -- per gem
	GemRespawnSeconds = 45,
	GemCoinCapPerVisit = 120, -- max gem coins per player per server visit
	ObbyReward = 40,
	ObbyCooldownSeconds = 600, -- one obby reward per 10 minutes
	BounceVelocity = 110,
	LeaderboardRefreshSeconds = 10,
}

-- Admins: the game owner is always an admin, and so is everyone in Studio playtests.
-- Add friends' user IDs here (the number in their profile URL), e.g. { 12345678 }.
Config.AdminUserIds = {} :: { number }
Config.Admin = {
	CoinsGrant = 1000,
	XpGrant = 500,
}

-- ProfileStore settings. Bump the store name only for a deliberate data wipe.
Config.Data = {
	StoreName = "PlayerData_v1",
	-- How many processed purchase IDs to remember per player (for receipt idempotency).
	MaxRememberedPurchases = 100,
	-- Seconds ProcessReceipt waits for a confirmed save before asking Roblox to retry later.
	ReceiptSaveTimeout = 15,
}

function Config.getCosmetic(id: string): Cosmetic?
	for _, cosmetic in Config.Cosmetics do
		if cosmetic.id == id then
			return cosmetic
		end
	end
	return nil
end

return Config
