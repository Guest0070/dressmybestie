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

function Voting.start()
	Remotes.Events.CastHearts.OnServerEvent:Connect(cast)
end

return Voting
