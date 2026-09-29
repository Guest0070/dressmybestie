--!strict
-- Hearts-only voting. Each voter picks up to Config.Limits.MaxHeartsPerVoter looks.
-- Voters can change their picks until time runs out (each cast replaces the previous one).
-- Who voted for whom is never sent to any client; only totals leave this module.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)

local Voting = {}

local open = false
local candidates: { [number]: boolean } = {}
local picks: { [Player]: { number } } = {}
-- Returns user IDs this voter may not heart (their own look, the look they styled).
local getExcluded: (Player) -> { [number]: boolean } = function()
	return {}
end

function Voting.begin(candidateIds: { number }, excluded: (Player) -> { [number]: boolean })
	candidates = {}
	for _, id in candidateIds do
		candidates[id] = true
	end
	picks = {}
	getExcluded = excluded
	open = true
end

local function cast(voter: Player, raw: any)
	if not open or type(raw) ~= "table" or #raw > Config.Limits.MaxHeartsPerVoter then
		return
	end
	local excluded = getExcluded(voter)
	local clean: { number } = {}
	for i = 1, #raw do
		local id = raw[i]
		if type(id) == "number" and candidates[id] and not excluded[id] and not table.find(clean, id) then
			table.insert(clean, id)
		end
	end
	picks[voter] = clean
end

-- Closes voting and returns userId -> hearts, plus how many hearts each voter gave.
function Voting.finish(): ({ [number]: number }, { [Player]: number })
	open = false
	local given: { [Player]: number } = {}
	for voter, list in picks do
		given[voter] = #list
	end
	local totals: { [number]: number } = {}
	for id in candidates do
		totals[id] = 0
	end
	for _, list in picks do
		for _, id in list do
			if candidates[id] then
				totals[id] += 1
			end
		end
	end
	picks = {}
	return totals, given
end

-- A candidate left: their look can't win anymore.
function Voting.removeCandidate(userId: number)
	candidates[userId] = nil
end

---------------------------------------------------------------------------------------------------
-- Stars mode: while each look walks the runway, the audience rates it 1-5 stars.
-- Ratings stay private: only totals/averages leave this module.
---------------------------------------------------------------------------------------------------

export type Rating = { sum: number, count: number, average: number }

local ratings: { [number]: { [Player]: number } } = {} -- wearer userId -> voter -> stars
local ratable: { [number]: boolean } = {}
local ratingExcluded: (Player, number) -> boolean = function()
	return false
end

-- excluded(voter, wearerUserId): true if this voter may not rate this look (walker, stylists).
function Voting.beginRatings(excluded: (Player, number) -> boolean)
	ratings = {}
	ratable = {}
	ratingExcluded = excluded
end

function Voting.openRating(wearerUserId: number)
	ratable[wearerUserId] = true
	ratings[wearerUserId] = ratings[wearerUserId] or {}
end

local function rate(voter: Player, wearerUserId: any, stars: any)
	if type(wearerUserId) ~= "number" or type(stars) ~= "number" then
		return
	end
	if stars % 1 ~= 0 or stars < 1 or stars > 5 or not ratable[wearerUserId] then
		return
	end
	if ratingExcluded(voter, wearerUserId) then
		return
	end
	ratings[wearerUserId][voter] = stars -- re-rating replaces your earlier rating
end

-- Closes rating. Returns wearer -> {sum, count, average}, and how many looks each voter rated.
function Voting.finishRatings(): ({ [number]: Rating }, { [Player]: number })
	local results: { [number]: Rating } = {}
	local given: { [Player]: number } = {}
	for wearer, byVoter in ratings do
		local sum, count = 0, 0
		for voter, stars in byVoter do
			sum += stars
			count += 1
			given[voter] = (given[voter] or 0) + 1
		end
		results[wearer] = { sum = sum, count = count, average = if count > 0 then sum / count else 0 }
	end
	ratings = {}
	ratable = {}
	return results, given
end

function Voting.removeRatable(userId: number)
	ratable[userId] = nil
	ratings[userId] = nil
end

function Voting.start()
	Remotes.Events.RateLook.OnServerEvent:Connect(rate)
	Remotes.Events.CastHearts.OnServerEvent:Connect(cast)
end

return Voting
