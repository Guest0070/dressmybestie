--!strict
-- Decides who styles whom. Pure logic (no Roblox services) apart from the optional friend check,
-- so it is easy to reason about.
--
-- Result is a map stylist -> target. Rules:
--   * Pairs style each other (A->B, B->A).
--   * Odd count: the last three form a trio rotation (A->B, B->C, C->A).
--   * One player (Studio testing only): styles themselves.
--   * Friends in the server are paired together when possible.

local Pairing = {}

export type Assignments<T> = { [T]: T }

local function shuffle<T>(list: { T }): { T }
	local copy = table.clone(list)
	for i = #copy, 2, -1 do
		local j = math.random(1, i)
		copy[i], copy[j] = copy[j], copy[i]
	end
	return copy
end

-- Build pairs (friends first), then turn the odd player out into a trio.
function Pairing.pair<T>(players: { T }, areFriends: ((T, T) -> boolean)?): Assignments<T>
	local assignments: Assignments<T> = {}
	local n = #players
	if n == 0 then
		return assignments
	elseif n == 1 then
		assignments[players[1]] = players[1]
		return assignments
	end

	local pool = shuffle(players)
	local used: { [T]: boolean } = {}
	local friendGroups: { { T } } = {}
	local otherGroups: { { T } } = {}

	if areFriends then
		for _, a in pool do
			if used[a] then
				continue
			end
			for _, b in pool do
				if b ~= a and not used[b] and areFriends(a, b) then
					used[a] = true
					used[b] = true
					table.insert(friendGroups, { a, b })
					break
				end
			end
		end
	end

	local singles: { T } = {}
	for _, player in pool do
		if not used[player] then
			table.insert(singles, player)
		end
	end
	for i = 1, #singles - 1, 2 do
		table.insert(otherGroups, { singles[i], singles[i + 1] })
	end
	if #singles % 2 == 1 then
		-- Odd player out joins a pair to make a trio; prefer breaking up strangers, not friends.
		local leftover = singles[#singles]
		local host = otherGroups[#otherGroups] or friendGroups[#friendGroups]
		table.insert(host, leftover)
	end

	local groups: { { T } } = table.clone(friendGroups)
	for _, group in otherGroups do
		table.insert(groups, group)
	end

	-- Within each group, everyone styles the next person (wrapping around).
	for _, group in groups do
		for index, stylist in group do
			assignments[stylist] = group[(index % #group) + 1]
		end
	end
	return assignments
end

-- "Swap Mid-Round": give every target a new stylist who is neither the target nor their
-- current stylist. Returns nil if impossible (fewer than 3 players).
function Pairing.swap<T>(current: Assignments<T>): Assignments<T>?
	local stylists: { T } = {}
	local targets: { T } = {}
	local currentStylistOf: { [T]: T } = {}
	for stylist, target in current do
		table.insert(stylists, stylist)
		table.insert(targets, target)
		currentStylistOf[target] = stylist
	end
	if #stylists < 3 then
		return nil
	end

	for _ = 1, 200 do
		local shuffled = shuffle(stylists)
		local ok = true
		for index, target in targets do
			local stylist = shuffled[index]
			if stylist == target or stylist == currentStylistOf[target] then
				ok = false
				break
			end
		end
		if ok then
			local result: Assignments<T> = {}
			for index, target in targets do
				result[shuffled[index]] = target
			end
			return result
		end
	end
	return nil
end

return Pairing
