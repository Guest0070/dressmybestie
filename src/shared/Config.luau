--!strict
-- Single source of truth for tunable numbers and content lists.
-- Content updates (new themes, price tweaks, timing changes) should only touch this file.

local Config = {}

-- Round timings, in seconds.
Config.Timings = {
	Lobby = 30,
	ThemeReveal = 5,
	Styling = 240,
	SwapAt = 120, -- "Swap Mid-Round" chaos: seconds into styling when stylists swap
	RunwayPerPlayer = 8,
	Voting = 30,
	Results = 15,
}

Config.MinPlayersToStart = 2

-- Every Nth round is *eligible* for chaos; a coin flip decides whether it actually happens.
Config.ChaosEveryRounds = 4

-- Look limits. The server enforces these; the client only uses them for nicer UI.
Config.Limits = {
	MaxHeartsPerVoter = 3,
	-- Max accessories per slot. VIP gets bonus slots on top.
	AccessoriesPerSlot = {
		Hat = 2,
		Hair = 2,
		Face = 1,
		Neck = 1,
		Shoulder = 1,
		Front = 1,
		Back = 1,
		Waist = 1,
	},
	VipBonusAccessories = 2,
	-- Layered clothing pieces (jackets, sweaters, pants, dresses, shoes...).
	MaxLayeredClothing = 6,
	VipBonusLayered = 2,
}

-- Rewards. Coins are only ever earned by playing.
Config.Rewards = {
	CoinsPerRoundPlayed = 10,
	CoinsPerHeartReceived = 2,
	PodiumCoins = { 30, 20, 10 }, -- 1st, 2nd, 3rd
	XpPerRoundPlayed = 20,
	XpPerHeartReceived = 5,
	DailyRewardCoins = 50,
}

-- Style rank thresholds: total XP needed to reach rank N is RankXp[N]. Rank 1 is the start.
Config.RankXp = { 0, 100, 250, 500, 900, 1500, 2400, 3600, 5200, 7500 }

-- Catalog browser categories (client UI tabs). Mapped to AvatarEditorService enums in the UI code.
Config.CatalogCategories = {
	"Hair",
	"Hats",
	"Tops",
	"Bottoms",
	"Dresses",
	"Shoes",
	"Accessories",
	"Faces",
	"Emotes",
}

-- Themes. Plain strings, picked server-side. Add weekly packs by appending here.
-- Vip = true themes only show up in rounds where at least one VIP is playing.
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
	{ name = "Red Carpet Royalty", vip = true },
	{ name = "Haunted Gala", vip = true },
} :: { Theme }

-- Chaos modifiers are data; the round system reads these flags instead of branching per mode.
export type ChaosModifier = {
	id: string,
	displayName: string,
	description: string,
}
Config.ChaosModifiers = {
	{
		id = "WorstOutfitWins",
		displayName = "Worst Outfit Wins",
		description = "Most hearts goes to the most hilariously bad look!",
	},
	{
		id = "SwapMidRound",
		displayName = "Swap Mid-Round",
		description = "Halfway through, you swap to a new partner's look!",
	},
	{
		id = "OneColorOnly",
		displayName = "One Color Only",
		description = "Only items in the chosen color are allowed.",
	},
} :: { ChaosModifier }

-- Monetization IDs. 0 = not created yet in Creator Dashboard (Day 8-9).
-- Prices here are for display only; Roblox charges the price set on the dashboard.
Config.GamePasses = {
	VIP = { id = 0, price = 399 },
	PosePack = { id = 0, price = 149 },
}
Config.DevProducts = {
	LobbyConfetti = { id = 0, price = 49 },
	LobbyDisco = { id = 0, price = 49 },
}

-- ProfileStore settings. Bump the store name only for a deliberate data wipe.
Config.Data = {
	StoreName = "PlayerData_v1",
	-- How many processed purchase IDs to remember per player (for receipt idempotency).
	MaxRememberedPurchases = 100,
}

return Config
