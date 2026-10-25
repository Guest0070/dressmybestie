--!strict
-- Runway Dash: a timed obstacle course floating over a glowing pool, east of the plaza. Always
-- open (no rounds). Climb the stairs, step off the green pad and the clock starts:
--   hurdles -> vanishing tiles -> CHECKPOINT -> spinning bar -> jump pad -> CHECKPOINT ->
--   sliding blockers on a beam -> the finish catwalk (cameras flash) -> gold FINISH pad.
-- Fall in the pool and you're back at your last checkpoint (the clock keeps running).
-- Finish under the medal times for coins (Gold / Silver / Bronze, once per 10 minutes); personal
-- bests are saved, and the boards show this server's best and the all-time global top 10.

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage.Shared.Config)
local Arena = require(script.Parent.Arena)
local Analytics = require(script.Parent.Parent.Parent.Analytics)
local PlayerData = require(script.Parent.Parent.Parent.Data.PlayerData)
local Quests = require(script.Parent.Parent.Parent.Quests)
local Badges = require(script.Parent.Parent.Parent.Badges)

local C = Arena.Colors
local S = Arena.Sounds

local RunwayDash = {}

type Run = { started: number, checkpoint: number }
type BoardRow = { name: string, seconds: number }

local MEDAL_ORDER = { "Gold", "Silver", "Bronze" }
local MEDAL_COLORS =
	{ Gold = C.Gold, Silver = Color3.fromRGB(210, 215, 230), Bronze = Color3.fromRGB(220, 140, 80) }

function RunwayDash.build(parent: Instance): Arena.Game
	local rd = Config.Minigames.RunwayDash
	local model = Instance.new("Model")
	model.Name = "RunwayDash"
	local origin = rd.Start
	local H = rd.Height
	local function at(x: number, y: number, z: number): Vector3
		return origin + Vector3.new(x, y, z)
	end
	local function slab(
		name: string,
		size: Vector3,
		position: Vector3,
		color: Color3?,
		material: Enum.Material?
	): Part
		return Arena.part(
			model,
			name,
			size,
			CFrame.new(position),
			color or C.White,
			material or Enum.Material.Marble
		)
	end
	-- Warm LED strips along both sides of a straight section.
	local function edges(fromX: number, toX: number, width: number, y: number)
		for _, z in { -width / 2 - 0.1, width / 2 + 0.1 } do
			Arena.glow(
				model,
				"EdgeLed",
				Vector3.new(toX - fromX, 0.25, 0.25),
				CFrame.new(at((fromX + toX) / 2, y, z)),
				C.Warm
			)
		end
	end

	-- Stairs (a ramp) from the plaza up to the start deck.
	local rampLength = 30
	local rampCenter = at(rampLength / 2, H / 2, 0)
	local ramp = Instance.new("WedgePart")
	ramp.Name = "Stairs"
	ramp.Anchored = true
	ramp.Size = Vector3.new(10, H, rampLength)
	ramp.CFrame = CFrame.lookAt(rampCenter, rampCenter + Vector3.new(-1, 0, 0))
	ramp.Color = C.Black
	ramp.Material = Enum.Material.Marble
	ramp.Parent = model
	-- Start deck with the green start pad and a START arch.
	slab("StartDeck", Vector3.new(14, 1, 14), at(rampLength + 7, H - 0.5, 0))
	edges(rampLength, rampLength + 14, 14, H + 0.05)
	local startPad =
		slab("StartPad", Vector3.new(6, 0.3, 6), at(rampLength + 8, H + 0.15, 0), C.Lime, Enum.Material.Neon)
	local x0 = rampLength + 14 -- where the course begins
	for _, z in { -6, 6 } do
		Arena.pillar(model, at(x0, H, z), 9)
	end
	local startArch = Arena.part(
		model,
		"StartArch",
		Vector3.new(1.2, 2.4, 14),
		CFrame.new(at(x0, H + 9.6, 0)),
		C.Black,
		Enum.Material.Marble
	)
	for _, face in { Enum.NormalId.Left, Enum.NormalId.Right } do
		Arena.label(
			Arena.surface(startArch, face),
			"START",
			UDim2.fromScale(0.05, 0.05),
			UDim2.fromScale(0.9, 0.9),
			C.Lime
		)
	end

	-- 1. Hurdles.
	slab("HurdleLane", Vector3.new(18, 1, 10), at(x0 + 9, H - 0.5, 0))
	edges(x0, x0 + 18, 10, H + 0.05)
	for i, dx in { 4, 9, 14 } do
		local hurdle = Arena.part(
			model,
			`Hurdle{i}`,
			Vector3.new(0.8, 1.6 + i * 0.35, 10),
			CFrame.new(at(x0 + dx, H + 0.8 + i * 0.17, 0)),
			C.Pink,
			Enum.Material.Neon
		)
		hurdle.CanCollide = true
	end
	-- 2. Vanishing tiles: they fade half a second after you step on them, then come back.
	local x1 = x0 + 20
	local vanishing: { Part } = {}
	for row = 0, 3 do
		for _, z in { -2.2, 2.2 } do
			local tile = slab(
				"VanishTile",
				Vector3.new(3.4, 0.8, 3.4),
				at(x1 + 1.8 + row * 4.2, H - 0.4, z + (if row % 2 == 0 then 0 else 0.6)),
				C.Cyan,
				Enum.Material.Glass
			)
			tile.Transparency = 0.2
			tile:SetAttribute("Gone", false)
			tile:AddTag("DashVanish") -- the client animates the fade
			table.insert(vanishing, tile)
		end
	end
	-- Checkpoint 1.
	local x2 = x1 + 18
	slab("Checkpoint1Deck", Vector3.new(8, 1, 10), at(x2 + 4, H - 0.5, 0))
	local cp1 =
		slab("Checkpoint1", Vector3.new(4, 0.3, 6), at(x2 + 4, H + 0.15, 0), C.Cyan, Enum.Material.Neon)
	-- 3. Spinning bar platform.
	local x3 = x2 + 8
	local barCenter = at(x3 + 9, 0, 0)
	Arena.disc(model, "BarDisc", 1, 18, barCenter + Vector3.new(0, H - 0.5, 0), C.Black, Enum.Material.Marble)
	local barRing = Arena.disc(
		model,
		"BarRing",
		0.3,
		19,
		barCenter + Vector3.new(0, H - 0.6, 0),
		C.Pink,
		Enum.Material.Neon
	)
	barRing.CanCollide = false
	local barHeight = H + 1.3
	local barPivot = Arena.part(
		model,
		"BarPivot",
		Vector3.new(1, 1, 1),
		CFrame.new(barCenter + Vector3.new(0, barHeight, 0)),
		C.Cyan
	)
	barPivot.Transparency = 1
	barPivot.CanCollide = false
	barPivot.CanQuery = false
	barPivot.CanTouch = false
	Arena.disc(model, "BarHub", 2.4, 2, barCenter + Vector3.new(0, H + 1.2, 0), C.Gold, Enum.Material.Neon)
	local bar = Arena.part(
		model,
		"Bar",
		Vector3.new(0.8, 0.8, 16),
		CFrame.new(barCenter + Vector3.new(0, barHeight, 0)),
		C.Gold,
		Enum.Material.Neon
	)
	bar.Anchored = false
	bar.CanCollide = false
	bar.CanTouch = false
	bar.CanQuery = false
	bar.Massless = true
	bar:AddTag("SweepArm")
	local a0 = Instance.new("Attachment")
	a0.CFrame = CFrame.Angles(0, 0, math.rad(90))
	a0.Parent = barPivot
	local a1 = Instance.new("Attachment")
	a1.CFrame = CFrame.Angles(0, 0, math.rad(90))
	a1.Parent = bar
	local barMotor = Instance.new("HingeConstraint")
	barMotor.ActuatorType = Enum.ActuatorType.Motor
	barMotor.MotorMaxTorque = math.huge
	barMotor.MotorMaxAcceleration = math.huge
	barMotor.AngularVelocity = 1.7
	barMotor.Attachment0 = a0
	barMotor.Attachment1 = a1
	barMotor.Parent = barPivot
	-- 4. Jump pad over the gap.
	local x4 = x3 + 18
	slab("PadDeck", Vector3.new(6, 1, 8), at(x4 + 3, H - 0.5, 0))
	local launch =
		slab("LaunchPad", Vector3.new(4, 0.3, 4), at(x4 + 3.5, H + 0.15, 0), C.Gold, Enum.Material.Neon)
	launch:SetAttribute("Velocity", Vector3.new(90, 70, 0)) -- the client launches you (tuned: lands mid-deck)
	launch:AddTag("LaunchPad")
	for i = 1, 3 do
		Arena.glow(
			model,
			"Arrow",
			Vector3.new(1.2, 0.06, 0.4),
			CFrame.new(at(x4 + 0.8 + i * 0.9, H + 0.32, 0)),
			C.Plum
		)
	end
	-- Checkpoint 2 (the landing).
	local x5 = x4 + 26
	slab("Checkpoint2Deck", Vector3.new(10, 1, 12), at(x5 + 5, H - 0.5, 0))
	local cp2 =
		slab("Checkpoint2", Vector3.new(4, 0.3, 6), at(x5 + 5, H + 0.15, 0), C.Cyan, Enum.Material.Neon)
	-- 5. Beam with sliding blockers.
	local x6 = x5 + 10
	slab("Beam", Vector3.new(20, 1, 3), at(x6 + 10, H - 0.5, 0), C.Black)
	edges(x6, x6 + 20, 3, H + 0.05)
	for i, dx in { 6, 14 } do
		local blocker = Arena.part(
			model,
			`Blocker{i}`,
			Vector3.new(2, 3.5, 3),
			CFrame.new(at(x6 + dx, H + 1.75, -4)),
			C.Purple,
			Enum.Material.Neon
		)
		TweenService:Create(
			blocker,
			TweenInfo.new(1 + i * 0.3, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
			{ CFrame = CFrame.new(at(x6 + dx, H + 1.75, 4)) }
		):Play()
	end
	-- 6. Finish catwalk with flashing cameras, and the gold FINISH pad.
	local x7 = x6 + 20
	local catwalk =
		slab("Catwalk", Vector3.new(16, 1, 6), at(x7 + 8, H - 0.5, 0), C.Pink, Enum.Material.SmoothPlastic)
	catwalk.Name = "FinishCatwalk"
	for i = 0, 3 do
		for _, z in { -4, 4 } do
			local pole = at(x7 + 2 + i * 4, H, z)
			Arena.part(
				model,
				"FlashPole",
				Vector3.new(0.3, 4, 0.3),
				CFrame.new(pole + Vector3.new(0, 2, 0)),
				C.Black,
				Enum.Material.Metal
			)
			local flash = Arena.glow(
				model,
				"Flash",
				Vector3.new(0.8, 0.4, 0.4),
				CFrame.new(pole + Vector3.new(0, 4.2, 0)),
				Color3.fromRGB(90, 90, 110)
			)
			flash:AddTag("PapFlash")
		end
	end
	local x8 = x7 + 16
	slab("FinishDeck", Vector3.new(10, 1, 12), at(x8 + 5, H - 0.5, 0), C.Black)
	local finishPad =
		slab("FinishPad", Vector3.new(6, 0.3, 8), at(x8 + 5, H + 0.15, 0), C.Gold, Enum.Material.Neon)
	for _, z in { -6, 6 } do
		Arena.pillar(model, at(x8, H, z), 9)
	end
	local finishArch = Arena.part(
		model,
		"FinishArch",
		Vector3.new(1.2, 2.4, 14),
		CFrame.new(at(x8, H + 9.6, 0)),
		C.Black,
		Enum.Material.Marble
	)
	for _, face in { Enum.NormalId.Left, Enum.NormalId.Right } do
		Arena.label(
			Arena.surface(finishArch, face),
			"FINISH",
			UDim2.fromScale(0.05, 0.05),
			UDim2.fromScale(0.9, 0.9),
			C.Gold
		)
	end
	-- The pool: glowing water under the whole course. Touch it and you're back at your checkpoint.
	local poolLength = x8 + 12 - rampLength + 6
	local pool = Arena.part(
		model,
		"Pool",
		Vector3.new(poolLength, 0.4, 30),
		CFrame.new(at(rampLength - 3 + poolLength / 2, 0.2, 0)),
		Color3.fromRGB(40, 170, 255),
		Enum.Material.Glass
	)
	pool.Transparency = 0.25
	pool.CanCollide = false -- you sink into it a little, then get pulled out
	local poolGlow = Arena.glow(
		model,
		"PoolGlow",
		Vector3.new(poolLength, 0.1, 30),
		CFrame.new(at(rampLength - 3 + poolLength / 2, 0.02, 0)),
		Color3.fromRGB(60, 190, 255)
	)
	poolGlow.Transparency = 0.45
	-- Neon rim around the pool.
	for _, z in { -15.2, 15.2 } do
		Arena.glow(
			model,
			"PoolRim",
			Vector3.new(poolLength, 0.5, 0.4),
			CFrame.new(at(rampLength - 3 + poolLength / 2, 0.25, z)),
			Arena.Colors.Cyan
		)
	end
	local poolFloor = Arena.part(
		model,
		"PoolFloor",
		Vector3.new(poolLength, 0.2, 30),
		CFrame.new(at(rampLength - 3 + poolLength / 2, -0.3, 0)),
		C.Plum
	)
	poolFloor.CanCollide = true

	-- Boards on the start deck: this server's best and the all-time global top 10.
	local function board(name: string, title: string, z: number, rows: number): { TextLabel }
		local cf = CFrame.new(at(rampLength + 1, H + 6, z)) * CFrame.Angles(0, math.rad(90), 0)
		Arena.part(model, `{name}Frame`, Vector3.new(11, 11, 0.4), cf, C.Champagne, Enum.Material.Metal)
		local panel = Arena.part(model, name, Vector3.new(10, 10, 0.6), cf, C.Black, Enum.Material.Marble)
		local gui = Arena.surface(panel, Enum.NormalId.Front, 30) -- faces the stairs (west)
		Arena.label(gui, title, UDim2.fromScale(0.05, 0.03), UDim2.fromScale(0.9, 0.12), C.Pink)
		local lines = {}
		for i = 1, rows do
			local label = Arena.label(
				gui,
				"",
				UDim2.fromScale(0.06, 0.17 + (i - 1) * (0.8 / rows)),
				UDim2.fromScale(0.88, 0.8 / rows - 0.01),
				Color3.new(1, 1, 1)
			)
			label.TextXAlignment = Enum.TextXAlignment.Left
			table.insert(lines, label)
		end
		return lines
	end
	local serverLines = board("ServerBoard", "TODAY'S BEST", -6.5, 6)
	local globalLines = board("GlobalBoard", "ALL-TIME TOP 10", 6.5, 10)
	local medalBoard = Arena.part(
		model,
		"MedalBoard",
		Vector3.new(0.6, 4, 12),
		CFrame.new(at(rampLength + 13, H + 7.4, 0)),
		C.Black,
		Enum.Material.Marble
	)
	local medalGui = Arena.surface(medalBoard, Enum.NormalId.Left, 30)
	Arena.label(
		medalGui,
		`🥇 {rd.Medals.Gold}s   🥈 {rd.Medals.Silver}s   🥉 {rd.Medals.Bronze}s`,
		UDim2.fromScale(0.03, 0.15),
		UDim2.fromScale(0.94, 0.7),
		C.Gold
	)
	model.Parent = parent
	task.defer(function()
		pcall(function()
			bar:SetNetworkOwner(nil)
		end)
	end)

	---------------------------------------------------------------------------------------------
	-- Runs
	---------------------------------------------------------------------------------------------

	local runs: { [Player]: Run } = {}
	local lastReward: { [Player]: number } = {}
	local lastReset: { [Player]: number } = {}
	local serverBest: { BoardRow } = {}
	local checkpoints = {
		CFrame.lookAt(at(rampLength + 8, H + 3.5, 0), at(rampLength + 30, H + 3.5, 0)),
		CFrame.lookAt(at(x2 + 4, H + 3.5, 0), at(x2 + 30, H + 3.5, 0)),
		CFrame.lookAt(at(x5 + 5, H + 3.5, 0), at(x5 + 30, H + 3.5, 0)),
	}
	local besideStart = CFrame.lookAt(at(-4, 3.5, 0), at(10, 3.5, 0))

	local store: OrderedDataStore? = nil
	pcall(function()
		store = DataStoreService:GetOrderedDataStore("RunwayDashBest_v1")
	end)
	local names: { [number]: string } = {}

	local g: Arena.Game
	g = {
		rounds = false,
		state = {
			id = "RunwayDash",
			name = "Runway Dash",
			phase = "Idle",
			headline = "Open: run it!",
			players = {},
			center = at(x0 + 60, H, 0),
		},
		isOn = function()
			return false
		end,
		joinSpot = function(): CFrame
			return besideStart
		end,
		play = function()
			return {}
		end,
	}

	local function refreshServerBoard()
		for i, label in serverLines do
			local row = serverBest[i]
			label.Text = if row then `{i}. {row.name}  {string.format("%.2f", row.seconds)}s` else ""
		end
		local best = serverBest[1]
		Arena.setState(g, {
			phase = "Idle",
			headline = if best then `Best: {string.format("%.2f", best.seconds)}s` else "Open: run it!",
			detail = if best then `by {best.name}` else nil,
			players = {},
		})
	end

	local function refreshGlobalBoard()
		local s = store
		if not s then
			globalLines[1].Text = "(Saving is off in this place)"
			return
		end
		local ok, pages = pcall(function()
			return s:GetSortedAsync(true, 10)
		end)
		if not ok or not pages then
			return
		end
		local entries = (pages :: DataStorePages):GetCurrentPage()
		for i, label in globalLines do
			local entry = entries[i]
			if entry then
				local userId = tonumber(entry.key) or 0
				local name = names[userId]
				if not name then
					local okName, fetched = pcall(Players.GetNameFromUserIdAsync, Players, userId)
					name = if okName then fetched else "?"
					names[userId] = name
				end
				label.Text = `{i}. {name}  {string.format("%.2f", (entry.value :: number) / 1000)}s`
			else
				label.Text = if i == 1 then "Be the first!" else ""
			end
		end
	end

	local function medalFor(seconds: number): string?
		for _, medal in MEDAL_ORDER do
			if seconds <= rd.Medals[medal] then
				return medal
			end
		end
		return nil
	end

	startPad.Touched:Connect(function(hit)
		local player = Arena.playerFromHit(hit)
		if not player or not Arena.eligible(player) then
			return
		end
		local run = runs[player]
		if not run or run.checkpoint > 0 or os.clock() - run.started > 1 then
			Arena.fx({ player }, { kind = "dash", action = "ready" })
		end
		-- The last touch is when you left the pad: that's when the clock starts.
		runs[player] = { started = os.clock(), checkpoint = 0 }
	end)

	for index, pad in { cp1, cp2 } do
		pad.Touched:Connect(function(hit)
			local player = Arena.playerFromHit(hit)
			local run = if player then runs[player] else nil
			if player and run and run.checkpoint < index then
				run.checkpoint = index
				local split = os.clock() - run.started
				Arena.fx({ player }, { kind = "dash", action = "split", checkpoint = index, time = split })
				Arena.sound(S.Switch, nil, { player }, 0.8)
			end
		end)
	end

	pool.Touched:Connect(function(hit)
		local player, character = Arena.playerFromHit(hit)
		if not player or not character then
			return
		end
		local t = os.clock()
		if t - (lastReset[player] or 0) < 1 then
			return -- several body parts touch at once
		end
		lastReset[player] = t
		local run = runs[player]
		local spot = if run then checkpoints[run.checkpoint + 1] else besideStart
		character:PivotTo(spot)
		Arena.sound(S.Splash, nil, { player }, 0.7)
		if run then
			Arena.fx({ player }, { kind = "dash", action = "fall" })
			Arena.toast(
				player,
				if run.checkpoint > 0
					then "Splash! Back to your checkpoint."
					else "Splash! Back to the start."
			)
		end
	end)

	finishPad.Touched:Connect(function(hit)
		local player, character = Arena.playerFromHit(hit)
		local run = if player then runs[player] else nil
		if not player or not character or not run then
			return
		end
		runs[player] = nil
		local seconds = os.clock() - run.started
		if seconds < 8 then
			return -- not a real run
		end
		local medal = medalFor(seconds)
		local ms = math.floor(seconds * 1000)

		-- Personal best (saved), server board, global board.
		local previous = nil
		PlayerData.update(player, function(data)
			previous = data.lifetime.dashBestMs
			if not previous or ms < previous then
				data.lifetime.dashBestMs = ms
			end
		end)
		local personalBest = previous == nil or ms < (previous :: number)
		local existing = nil
		for _, row in serverBest do
			if row.name == player.DisplayName then
				existing = row
			end
		end
		if existing then
			existing.seconds = math.min(existing.seconds, seconds)
		else
			table.insert(serverBest, { name = player.DisplayName, seconds = seconds })
		end
		table.sort(serverBest, function(a, b)
			return a.seconds < b.seconds
		end)
		while #serverBest > #serverLines do
			table.remove(serverBest)
		end
		refreshServerBoard()
		if personalBest and store then
			task.spawn(function()
				pcall(function()
					(store :: OrderedDataStore):UpdateAsync(tostring(player.UserId), function(old)
						return (if type(old) == "number" and old <= ms then nil else ms) :: any -- nil keeps the old best
					end)
				end)
				refreshGlobalBoard()
			end)
		end

		-- Rewards: medal coins (cooldown), quest progress.
		local text = `Runway Dash: {string.format("%.2f", seconds)}s`
		if medal then
			text ..= ` · {string.upper(medal)}!`
			Quests.bump(player, "minigameWins", 1)
			Quests.bump(player, "dashMedals", 1)
			if medal == "Gold" then
				Badges.award(player, "DashGold")
			end
			local waitLeft = (lastReward[player] or 0) + rd.CooldownSeconds - os.clock()
			if waitLeft <= 0 then
				lastReward[player] = os.clock()
				local coins = rd.MedalCoins[medal]
				PlayerData.update(player, function(data)
					data.coins += coins
				end)
				Analytics.coins(player, coins, true, "Minigame_RunwayDash")
				text ..= ` +{coins} coins`
			end
		else
			text ..= ` · Beat {rd.Medals.Bronze}s for a medal!`
		end
		if personalBest and previous then
			text ..= " NEW PERSONAL BEST!"
		end
		Arena.toast(player, text)
		Arena.fx({ player }, {
			kind = "dash",
			action = "finish",
			time = seconds,
			medal = medal,
			best = personalBest,
		})
		Arena.fx(Arena.near(finishPad.Position, 80), { kind = "paparazzi", position = finishPad.Position })
		Arena.fx(nil, {
			kind = "celebrate",
			position = finishPad.Position + Vector3.new(0, 3, 0),
			color = if medal then MEDAL_COLORS[medal] else C.Pink,
		})
		Arena.sound(S.Win, finishPad.Position, nil, 0.8)
		task.delay(2.5, function()
			if character.Parent then
				character:PivotTo(besideStart)
			end
		end)
	end)

	-- Spinning bar hits: fling off the platform (into the pool).
	task.spawn(function()
		local hitAt: { [Player]: number } = {}
		while model.Parent do
			task.wait(0.08)
			for player in runs do
				local root = Arena.rootOf(player)
				if not root then
					continue
				end
				local rel = root.Position - barCenter
				local flat = Vector3.new(rel.X, 0, rel.Z)
				if flat.Magnitude > 9 or root.Position.Y - 3 > barHeight + 0.4 or root.Position.Y < H then
					continue
				end
				local dir = bar.CFrame.LookVector
				dir = Vector3.new(dir.X, 0, dir.Z).Unit
				local along = flat:Dot(dir)
				local across = (flat - dir * along).Magnitude
				if math.abs(along) <= 8 and across < 1.2 and os.clock() - (hitAt[player] or 0) > 1 then
					hitAt[player] = os.clock()
					local away = Vector3.new(0, 0, if rel.Z >= 0 then 1 else -1)
					Arena.fx({ player }, { kind = "knock", velocity = away * 55 + Vector3.new(0, 35, 0) })
					Arena.sound(S.Hit, root.Position, nil, 1)
				end
			end
		end
	end)

	-- Vanishing tiles.
	for _, tile in vanishing do
		local busy = false
		tile.Touched:Connect(function(hit)
			if busy or not Arena.playerFromHit(hit) then
				return
			end
			busy = true
			tile:SetAttribute("Warn", true)
			task.wait(0.5)
			tile:SetAttribute("Gone", true)
			tile.CanCollide = false
			task.wait(2.5)
			tile:SetAttribute("Gone", false)
			tile:SetAttribute("Warn", false)
			tile.CanCollide = true
			busy = false
		end)
	end

	Players.PlayerRemoving:Connect(function(player)
		runs[player] = nil
		lastReward[player] = nil
		lastReset[player] = nil
	end)
	task.defer(function()
		refreshServerBoard()
		while model.Parent do
			refreshGlobalBoard()
			task.wait(rd.GlobalBoardRefresh)
		end
	end)
	return g
end

return RunwayDash
