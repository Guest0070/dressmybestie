--!strict
-- Per-player spam guard for remote handlers. A hacked client can fire a RemoteEvent thousands of
-- times a second; handlers that save data, apply avatars or toast call RateLimit.allow first and
-- drop anything faster than a human could tap.

local Players = game:GetService("Players")

local RateLimit = {}

local lastCall: { [Player]: { [string]: number } } = {}

-- True if `player` may run `key` now (at most once per `interval` seconds).
function RateLimit.allow(player: Player, key: string, interval: number): boolean
	local now = os.clock()
	local calls = lastCall[player]
	if not calls then
		calls = {}
		lastCall[player] = calls
	end
	local last = calls[key]
	if last and now - last < interval then
		return false
	end
	calls[key] = now
	return true
end

function RateLimit.start()
	Players.PlayerRemoving:Connect(function(player)
		lastCall[player] = nil
	end)
end

return RateLimit
