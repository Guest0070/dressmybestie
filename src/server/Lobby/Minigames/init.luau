--!strict
-- Lobby minigames in the Play Zone (the plaza outside the building's foyer doors): drop-in games
-- for the wait between rounds. Each game lives in its own module:
--   ColorRush    a colour is called, every other tile drops (with twists and a shrinking field)
--   FreezeFrame  a paparazzi shoot: DANCE, then FREEZE or JUMP FOR THE CAMERA
--   SpinSweep    jump the sparking arm or get flung off (REVERSE! SURGE! a second arm)
--   RunwayDash   a timed course over a glowing pool: checkpoints, medals, global leaderboard
-- plus the Sky Obby (Lobby/Activities), listed so the Games panel can take you there.
--
-- Round games: step on to join. When someone's on, a countdown starts (3-2-1-GO on screen);
-- everyone on it then plays. The server decides every elimination. Winners get fireworks, a
-- toast for everyone nearby, coins (capped per hour), streaks, quest progress and a spot on the
-- PLAY ZONE CHAMPIONS board.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Arena = require(script.Arena)
local ColorRush = require(script.ColorRush)
local FreezeFrame = require(script.FreezeFrame)
local RunwayDash = require(script.RunwayDash)
local SpinSweep = require(script.SpinSweep)

local Minigames = {}

local SETTINGS = Config.Minigames
local C = Arena.Colors
local S = Arena.Sounds

local games: { [string]: Arena.Game } = {}
local lastGo: { [Player]: number } = {}

local function winnerText(winners: { Player }): string
	if #winners == 0 then
		return "No winner!"
	elseif #winners == 1 then
		return `👑 {winners[1].DisplayName} wins!`
	elseif #winners <= 3 then
		local names = {}
		for _, player in winners do
			table.insert(names, player.DisplayName)
		end
		return `👑 {table.concat(names, ", ")} win!`
	end
	return `👑 {#winners} winners!`
end

local function playersOn(g: Arena.Game): { Player }
	local list = {}
	for _, player in Players:GetPlayers() do
		if Arena.eligible(player) and g.isOn(player) then
			table.insert(list, player)
		end
	end
	return list
end

-- Idle -> countdown -> play -> celebrate, forever.
local function runLoop(g: Arena.Game)
	while true do
		Arena.setState(g, { phase = "Idle", headline = "Step on to play!", players = {} })
		local onNow: { Player } = {}
		repeat
			task.wait(0.4)
			onNow = playersOn(g)
		until #onNow > 0

		local startAt = Arena.now() + SETTINGS.CountdownSeconds
		local lastCount = -1
		local cancelled = false
		local lastTick = math.huge
		while Arena.now() < startAt do
			onNow = playersOn(g)
			if #onNow == 0 then
				cancelled = true
				break
			end
			if #onNow ~= lastCount then
				lastCount = #onNow
				Arena.setState(g, {
					phase = "Countdown",
					headline = "Get ready!",
					detail = `{#onNow} player{if #onNow == 1 then "" else "s"} in · more can hop on`,
					endsAt = startAt,
					players = Arena.userIds(onNow),
				})
			end
			-- Beeps for the last three seconds (the client shows 3, 2, 1).
			local left = math.ceil(startAt - Arena.now())
			if left <= 3 and left < lastTick then
				lastTick = left
				Arena.sound(S.Tick, nil, onNow, 0.7, 1 + (3 - left) * 0.12)
			end
			task.wait(0.1)
		end
		if not cancelled then
			Arena.sound(S.Go, nil, onNow, 0.9, 1.2)
			local ok, result = pcall(g.play, g, onNow)
			local winners: { Player } = if ok then result else {}
			if not ok then
				warn(`[Minigames] {g.state.id} failed: {result}`)
			end
			local winnerSet: { [Player]: boolean } = {}
			for _, winner in winners do
				winnerSet[winner] = true
				if winner.Parent == Players then
					Arena.reward(winner, g.state.name)
					local root = Arena.rootOf(winner)
					if root then
						Arena.fx(nil, { kind = "celebrate", position = root.Position, color = C.Gold })
					end
					Arena.sound(S.Win, nil, { winner }, 1)
				end
			end
			for _, player in onNow do
				if not winnerSet[player] then
					Arena.breakStreak(player, g.state.name)
				end
			end
			if g.onWin then
				g.onWin(g, winners)
			end
			local headline = winnerText(winners)
			if #winners > 0 then
				for _, player in Arena.near(g.state.center, SETTINGS.CelebrateRadius) do
					if not winnerSet[player] then
						Arena.toast(player, `{(headline:gsub("👑 ", ""))} ({g.state.name})`)
					end
				end
			end
			Arena.setState(g, {
				phase = "Result",
				headline = headline,
				color = C.Gold,
				endsAt = Arena.now() + SETTINGS.ResultSeconds,
				players = Arena.userIds(winners),
			})
			task.wait(SETTINGS.ResultSeconds)
		end
	end
end

-- PLAY ZONE CHAMPIONS: most minigame wins on this server, in front of the Hall of Fame.
local function buildChampionsBoard(parent: Instance)
	local cf = CFrame.new(0, 7, 58)
	Arena.part(parent, "ChampionsFrame", Vector3.new(19, 11, 0.4), cf, C.Champagne, Enum.Material.Metal)
	local board = Arena.part(parent, "Champions", Vector3.new(18, 10, 0.7), cf, C.Black, Enum.Material.Marble)
	local gui = Arena.surface(board, Enum.NormalId.Front, 30) -- faces -Z, towards the plaza
	Arena.label(gui, "PLAY ZONE CHAMPIONS", UDim2.fromScale(0.04, 0.04), UDim2.fromScale(0.92, 0.18), C.Pink)
	local lines = {}
	for i = 1, 5 do
		local label = Arena.label(
			gui,
			"",
			UDim2.fromScale(0.08, 0.25 + (i - 1) * 0.145),
			UDim2.fromScale(0.84, 0.13),
			if i == 1 then C.Gold else Color3.new(1, 1, 1)
		)
		label.TextXAlignment = Enum.TextXAlignment.Left
		table.insert(lines, label)
	end
	Arena.part(
		parent,
		"ChampionsPost",
		Vector3.new(1, 2, 1),
		CFrame.new(0, 1, 58),
		C.Black,
		Enum.Material.Marble
	)
	local function refresh()
		local list = Arena.champions()
		for i, label in lines do
			local row = list[i]
			label.Text = if row
				then `{i}. {row.name}  ·  {row.wins} win{if row.wins == 1 then "" else "s"}`
				elseif i == 1 then "Win a minigame to get on the board!"
				else ""
		end
	end
	Arena.ChampionsChanged.Event:Connect(refresh)
	refresh()
end

-- Take a player to a game (from the Games panel).
local function go(player: Player, gameId: any)
	local g = if type(gameId) == "string" then games[gameId] else nil
	if not g or not Arena.eligible(player) then
		return
	end
	local t = os.clock()
	if t - (lastGo[player] or 0) < 1 then
		return
	end
	lastGo[player] = t
	local playing = g.state.phase == "Playing" or g.state.phase == "Result"
	local character = player.Character
	if character then
		character:PivotTo(g.joinSpot(playing))
	end
	if playing then
		Arena.toast(player, `{g.state.name} is in progress. Watch, then hop on when it ends!`)
	end
end

function Minigames.start()
	local map = Workspace:FindFirstChild("Map")
	local lobby = if map then map:FindFirstChild("Lobby") else nil
	if not lobby or lobby:FindFirstChild("Minigames") then
		return
	end
	local folder = Instance.new("Folder")
	folder.Name = "Minigames"
	games.ColorRush = ColorRush.build(folder)
	games.FreezeFrame = FreezeFrame.build(folder)
	games.SpinSweep = SpinSweep.build(folder)
	games.RunwayDash = RunwayDash.build(folder)
	-- The Sky Obby lives in Lobby/Activities; listed here so the Games panel can take you there.
	games.Obby = {
		rounds = false,
		state = {
			id = "Obby",
			name = "Sky Obby",
			phase = "Idle",
			headline = "Open: climb it!",
			players = {},
			center = Vector3.new(-62, 0, 30),
		},
		isOn = function()
			return false
		end,
		joinSpot = function(): CFrame
			return CFrame.lookAt(Vector3.new(-56, 3.5, 30), Vector3.new(-70, 3.5, 30))
		end,
		play = function()
			return {}
		end,
	}
	buildChampionsBoard(folder)
	folder.Parent = lobby

	Remotes.Events.MinigameGo.OnServerEvent:Connect(go)
	-- Late joiners get every game's current state.
	Players.PlayerAdded:Connect(function(player)
		for _, g in games do
			Remotes.Events.MinigameState:FireClient(player, g.state)
		end
	end)
	Players.PlayerRemoving:Connect(function(player)
		lastGo[player] = nil
	end)
	for _, g in games do
		if g.rounds then
			task.spawn(runLoop, g)
		else
			task.defer(function()
				Remotes.Events.MinigameState:FireAllClients(g.state)
			end)
		end
	end
end

return Minigames
