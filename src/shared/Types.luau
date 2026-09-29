--!strict
-- Shared type definitions used by both server and client.

local Types = {}

export type RoundPhase = "Lobby" | "Pairing" | "ThemeReveal" | "Styling" | "Runway" | "Voting" | "Results"

-- What a stylist sends for their partner's mannequin. Server re-validates every ID.
export type LookRequest = {
	accessoryIds: { number },
	layeredClothingIds: { number },
	shirtId: number?,
	pantsId: number?,
	faceId: number?,
	emoteIds: { number }?,
}

-- Saved per player by ProfileStore. Add new fields with defaults in the template;
-- Reconcile() fills them in for existing players automatically.
export type PlayerData = {
	coins: number,
	styleXp: number,
	roundsPlayed: number,
	heartsReceived: number,
	ownedUnlocks: { [string]: boolean },
	lastDailyRewardDay: number, -- days since epoch (UTC)
	-- Purchase IDs already granted, newest last. Bounded by Config.Data.MaxRememberedPurchases.
	processedPurchases: { string },
}

-- Subset of PlayerData safe to send to that player's own client.
export type PublicData = {
	coins: number,
	styleXp: number,
	rank: number,
	ownedUnlocks: { [string]: boolean },
	canClaimDaily: boolean,
}

return Types
