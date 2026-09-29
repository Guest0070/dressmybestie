--!strict
-- Plain-Luau tests for the pairing logic (no Roblox needed).
-- Run with the standalone Luau CLI:  luau tests/Pairing.spec.luau

local Pairing = require("../src/server/Round/Pairing")

local failures = 0
local function check(condition: boolean, message: string)
	if not condition then
		failures += 1
		print("FAIL: " .. message)
	end
end

local function names(n: number): { string }
	local list = {}
	for i = 1, n do
		table.insert(list, "P" .. i)
	end
	return list
end

-- Every player styles exactly one person, is styled by exactly one person, and never themselves
-- (except the 1-player Studio test).
for n = 1, 12 do
	for _ = 1, 200 do
		local players = names(n)
		local assignments = Pairing.pair(players)
		local styledCount: { [string]: number } = {}
		local stylists = 0
		for stylist, target in assignments do
			stylists += 1
			styledCount[target] = (styledCount[target] or 0) + 1
			if n > 1 then
				check(stylist ~= target, `n={n}: {stylist} styles themselves`)
			end
		end
		check(stylists == n, `n={n}: expected {n} stylists, got {stylists}`)
		for _, p in players do
			check(styledCount[p] == 1, `n={n}: {p} styled {styledCount[p] or 0} times`)
		end
		-- Pairs are mutual; at most one trio.
		local trios = 0
		for stylist, target in assignments do
			if assignments[target] ~= stylist then
				trios += 1
			end
		end
		check(trios == 0 or (n % 2 == 1 and trios == 3), `n={n}: {trios} players outside mutual pairs`)
	end
end

-- Friends get paired together when possible.
for _ = 1, 200 do
	local players = names(6)
	local assignments = Pairing.pair(players, function(a, b)
		return (a == "P1" and b == "P4") or (a == "P4" and b == "P1")
	end)
	check(assignments["P1"] == "P4" and assignments["P4"] == "P1", "friends P1/P4 not paired")
end

-- Swap: new stylist is never the target and never their previous stylist.
for n = 3, 12 do
	for _ = 1, 200 do
		local current = Pairing.pair(names(n))
		local swapped = Pairing.swap(current)
		check(swapped ~= nil, `n={n}: swap returned nil`)
		if swapped then
			local previousStylist: { [string]: string } = {}
			for stylist, target in current do
				previousStylist[target] = stylist
			end
			local count = 0
			for stylist, target in swapped do
				count += 1
				check(stylist ~= target, `n={n}: swap made {stylist} style themselves`)
				check(previousStylist[target] ~= stylist, `n={n}: swap kept {stylist} on {target}`)
			end
			check(count == n, `n={n}: swap has {count} stylists`)
		end
	end
end
check(Pairing.swap(Pairing.pair(names(2))) == nil, "swap with 2 players should be impossible")

if failures == 0 then
	print("Pairing tests passed")
else
	error(`{failures} pairing test failure(s)`)
end
