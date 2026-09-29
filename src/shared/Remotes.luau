--!strict
-- All remotes live here by name so a typo is a loud error, not a silent nil at runtime.
-- The server creates them on boot; clients wait for them. Clients only send *intents*;
-- the server validates every payload.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local EVENT_NAMES = {
	-- Server -> client
	"RoundState", -- (state: RoundState) on every phase/round change
	"DataChanged", -- (data: PublicData) the player's own coins/xp/unlocks
	"Toast", -- (text: string) short message at the top of the screen
	"RewardSummary", -- (summary: RewardSummary) after results
	"LobbyMoment", -- (moment: string, buyerName: string) confetti/disco for everyone
	"RunwayEffect", -- (userId: number, isVip: boolean) at the start of each runway walk
	"LookSync", -- (targetUserId: number, look: Look, seq: number?) accepted look, sent to its stylist
	-- Client -> server
	"SetMannequinLook", -- (look: Look) stylist edits their target's mannequin
	"CastHearts", -- ({ number }) user IDs, up to MaxHeartsPerVoter
	"ClaimDailyReward", -- ()
	"BuyWithCoins", -- (cosmeticId: string)
	"EquipCosmetic", -- (slot: string, cosmeticId: string?)
	"AdminCommand", -- (command: string, arg: any) admins only, checked on the server
	"SetOwnLook", -- (look: Look) Dressing Room: dress your own avatar (lobby only)
	"ResetOwnLook", -- () Dressing Room: back to your real avatar
}

local FUNCTION_NAMES = {
	"GetMyData", -- () -> PublicData?
	"GetRoundState", -- () -> RoundState  (for players who join mid-round)
}

local FOLDER_NAME = "Remotes"

export type Remotes = {
	Events: { [string]: RemoteEvent },
	Functions: { [string]: RemoteFunction },
}

local function build(): Remotes
	local isServer = RunService:IsServer()
	local folder: Instance
	if isServer then
		folder = ReplicatedStorage:FindFirstChild(FOLDER_NAME) or Instance.new("Folder")
		folder.Name = FOLDER_NAME
		folder.Parent = ReplicatedStorage
	else
		folder = ReplicatedStorage:WaitForChild(FOLDER_NAME)
	end

	local function get(name: string, className: string): Instance
		if isServer then
			local existing = folder:FindFirstChild(name)
			if existing then
				return existing
			end
			local remote = Instance.new(className)
			remote.Name = name
			remote.Parent = folder
			return remote
		end
		return folder:WaitForChild(name)
	end

	local remotes: Remotes = { Events = {}, Functions = {} }
	for _, name in EVENT_NAMES do
		remotes.Events[name] = get(name, "RemoteEvent") :: RemoteEvent
	end
	for _, name in FUNCTION_NAMES do
		remotes.Functions[name] = get(name, "RemoteFunction") :: RemoteFunction
	end

	-- Fail loudly on typos like Remotes.Events.CastHeart.
	setmetatable(remotes.Events, {
		__index = function(_, key)
			error(`Unknown RemoteEvent '{key}'`, 2)
		end,
	})
	setmetatable(remotes.Functions, {
		__index = function(_, key)
			error(`Unknown RemoteFunction '{key}'`, 2)
		end,
	})
	return remotes
end

return build()
