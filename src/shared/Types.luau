--!strict
-- Shared type definitions used by both server and client.

local Types = {}

export type RoundPhase = "Lobby" | "Pairing" | "ThemeReveal" | "Styling" | "Runway" | "Voting" | "Results"

-- A look is just catalog IDs. Clients send it; the server re-validates every ID before use.
-- assetIds: individual catalog assets (accessories, clothing, face, emote).
-- shoeBundleId: shoes are sold as bundles (left + right shoe), so they travel as one bundle ID.
export type Look = {
	assetIds: { number },
	shoeBundleId: number?,
	seq: number?, -- client edit counter, echoed back in LookSync (not saved)
}

export type ChaosInfo = {
	id: string,
	displayName: string,
	description: string,
	colorName: string?, -- One Color Only
	reverseVoting: boolean?,
}

export type PodiumEntry = {
	place: number,
	wearerUserId: number,
	wearerName: string,
	stylistNames: { string },
	hearts: number,
}

-- Items shown in the "Buy this look" panel, grouped per wearer.
export type ShopLook = {
	wearerUserId: number,
	wearerName: string,
	look: Look,
}

-- Broadcast to every client whenever anything about the round changes.
-- Tables keyed by user ID use string keys: remotes can't reliably send sparse number keys.
export type RoundState = {
	phase: RoundPhase,
	roundNumber: number,
	endsAt: number?, -- workspace:GetServerTimeNow() when the phase ends
	theme: string?,
	chaos: ChaosInfo?,
	-- stylist userId -> target userId they are styling right now
	assignments: { [string]: number }?,
	-- userId -> display name for everyone in the round (for banners and cards)
	names: { [string]: string }?,
	-- Runway: who is walking now, and who styled them
	runwayWearer: number?,
	runwayStylists: { string }?,
	-- Voting: user IDs whose looks can receive hearts
	candidates: { number }?,
	-- Results
	podium: { PodiumEntry }?,
	shopLooks: { ShopLook }?,
	message: string?, -- e.g. "Waiting for 1 more player..."
}

-- Saved per player by ProfileStore. Add new fields with defaults in the template;
-- Reconcile() fills them in for existing players automatically.
export type PlayerData = {
	coins: number,
	styleXp: number,
	roundsPlayed: number,
	heartsReceived: number,
	ownedCosmetics: { [string]: boolean },
	equipped: { [string]: string }, -- slot -> cosmetic id
	lastDailyRewardDay: number, -- days since epoch (UTC)
	-- Purchase IDs already granted, newest last. Bounded by Config.Data.MaxRememberedPurchases.
	processedPurchases: { string },
	funnelStep: number, -- highest onboarding funnel step logged (analytics)
}

-- Subset of PlayerData safe to send to that player's own client.
export type PublicData = {
	coins: number,
	styleXp: number,
	rank: number,
	ownedCosmetics: { [string]: boolean }, -- includes pass/rank unlocks
	equipped: { [string]: string },
	ownedPasses: { [string]: boolean },
	canClaimDaily: boolean,
	roundsPlayed: number, -- 0 = brand new player (shows How to Play)
}

export type RewardSummary = {
	coins: number,
	xp: number,
	heartsForYourStyling: number,
	rankUp: number?,
}

return Types
