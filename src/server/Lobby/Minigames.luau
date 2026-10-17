--!strict
-- Lobby minigames: short drop-in games for the wait between rounds, on a deck east of the plaza.
--
--   Color Rush:   floating tiles change colour; a colour is called; every other tile vanishes.
--                 Fall and you're out. Waves get faster. Last one standing (or everyone who
--                 survives every wave) wins.
--   Freeze Frame: DANCE! on the stage, then FREEZE! Move while frozen and you're out.
--
-- Step onto a game to join. When someone is on it, a short countdown starts; everyone on it when
-- the countdown ends plays. The server decides everything (who fell, who moved); clients only show
-- the state. Wins pay a few coins, capped per hour (Config.Minigames), and count for quests.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Types = require(ReplicatedStorage.Shared.Types)
local Analytics = require(script.Parent.Parent.Analytics)
local PlayerData = require(script.Parent.Parent.Data.PlayerData)
local Quests = require(script.Parent.Parent.Quests)
local RoundManager = require(script.Parent.Parent.Round.RoundManager)

local Minigames = {}

local SETTINGS = Config.Minigames
local DECK_COLOR = Color3.fromRGB(250, 225, 240)
local DARK = Color3.fromRGB(30, 24, 42)
local PINK = Color3.fromRGB(255, 79, 163)
local CYAN = Color3.fromRGB(70, 220, 255)

type Game = {
	state: Types.MinigameState,
	sign: TextLabel?,
	subSign: TextLabel?,
	isOn: (Player) -> boolean, -- standing on the game right now
	play: (Game, { Player }) -> { Player }, -- runs one game, returns the winners
	joinSpot: (playing: boolean) -> CFrame,
}

local games: { [string]: Game } = {}
local rewardTimes: { [Player]: { number } } = {}
local lastGo: { [Player]: number } = {}

---------------------------------------------------------------------------------------------------
-- Helpers
---------------------------------------------------------------------------------------------------

local function part(
	parent: Instance,
	name: string,
	size: Vector3,
	cframe: CFrame,
	color: Color3,
	neon: boolean?
): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.Size = size
	p.CFrame = cframe
	p.Color = color
	p.Material = if neon then Enum.Material.Neon else Enum.Material.SmoothPlastic
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = parent
	return p
end

-- A sign with a title line and a status line, readable from both sides.
local function sign(parent: Instance, name: string, cframe: CFrame, title: string): (TextLabel, TextLabel)
	local board = part(parent, `{name}Sign`, Vector3.new(26, 9, 0.6), cframe, DARK)
	local status: TextLabel? = nil
	local detail: TextLabel? = nil
	for _, face in { Enum.NormalId.Front, Enum.NormalId.Back } do
		local gui = Instance.new("SurfaceGui")
		gui.Face = face
		gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
		gui.PixelsPerStud = 30
		gui.LightInfluence = 0
		gui.Parent = board
		local function line(text: string, y: number, height: number, color: Color3): TextLabel
			local label = Instance.new("TextLabel")
			label.BackgroundTransparency = 1
			label.Position = UDim2.fromScale(0.04, y)
			label.Size = UDim2.fromScale(0.92, height)
			label.Font = Enum.Font.FredokaOne
			label.TextScaled = true
			label.TextColor3 = color
			label.Text = text
			local stroke = Instance.new("UIStroke")
			stroke.Thickness = 3
			stroke.Parent = label
			label.Parent = gui
			return label
		end
		line(title, 0.06, 0.34, PINK)
		local s = line("", 0.42, 0.32, Color3.new(1, 1, 1))
		local d = line("", 0.76, 0.18, Color3.fromRGB(220, 210, 240))
		-- Both faces show the same text: keep the labels in sync.
		if status then
			local first, firstDetail = status, detail :: TextLabel
			first:GetPropertyChangedSignal("Text"):Connect(function()
				s.Text = first.Text
			end)
			first:GetPropertyChangedSignal("TextColor3"):Connect(function()
				s.TextColor3 = first.TextColor3
			end)
			firstDetail:GetPropertyChangedSignal("Text"):Connect(function()
				d.Text = firstDetail.Text
			end)
		else
			status, detail = s, d
		end
	end
	return status :: TextLabel, detail :: TextLabel
end

local function rootOf(player: Player): BasePart?
	local character = player.Character
	local humanoid = if character then character:FindFirstChildOfClass("Humanoid") else nil
	if not humanoid or humanoid.Health <= 0 then
		return nil
	end
	local root = character and character:FindFirstChild("HumanoidRootPart")
	return if root and root:IsA("BasePart") then root else nil
end

-- May this player take part right now? (Not in a round, alive, data loaded.)
local function eligible(player: Player): boolean
	return player.Parent == Players
		and rootOf(player) ~= nil
		and PlayerData.isLoaded(player)
		and not RoundManager.isInRound(player)
end

local function userIds(players: { Player }): { number }
	local ids = {}
	for _, player in players do
		table.insert(ids, player.UserId)
	end
	return ids
end

local function setState(g: Game, changes: { [string]: any })
	for key, value in changes do
		(g.state :: any)[key] = value
	end
	-- Keys set to nil in `changes` don't show up in the loop above.
	if changes.endsAt == nil then
		g.state.endsAt = nil
	end
	if changes.color == nil then
		g.state.color = nil
	end
	if changes.detail == nil then
		g.state.detail = nil
	end
	if g.sign then
		g.sign.Text = g.state.headline
		g.sign.TextColor3 = g.state.color or Color3.new(1, 1, 1)
	end
	if g.subSign then
		g.subSign.Text = g.state.detail or ""
	end
	Remotes.Events.MinigameState:FireAllClients(g.state)
end

local function toast(player: Player, text: string)
	Remotes.Events.Toast:FireClient(player, text)
end

local function now(): number
	return Workspace:GetServerTimeNow()
end

-- Keep only the players still eligible and on the game.
local function stillIn(g: Game, players: { Player }): ({ Player }, { Player })
	local kept, dropped = {}, {}
	for _, player in players do
		if eligible(player) and g.isOn(player) then
			table.insert(kept, player)
		else
			table.insert(dropped, player)
		end
	end
	return kept, dropped
end

local function reward(player: Player, gameName: string)
	Quests.bump(player, "minigameWins", 1)
	local times = rewardTimes[player] or {}
	local cutoff = os.clock() - 3600
	local recent = {}
	for _, t in times do
		if t > cutoff then
			table.insert(recent, t)
		end
	end
	rewardTimes[player] = recent
	if #recent >= SETTINGS.MaxRewardedWinsPerHour then
		toast(player, `You won {gameName}! (Coin limit reached for this hour.)`)
		return
	end
	table.insert(recent, os.clock())
	PlayerData.update(player, function(data)
		data.coins += SETTINGS.WinCoins
	end)
	Analytics.coins(player, SETTINGS.WinCoins, true, `Minigame_{gameName}`)
	toast(player, `You won {gameName}! +{SETTINGS.WinCoins} coins`)
end

local function winnerText(winners: { Player }): string
	if #winners == 0 then
		return "No winner!"
	elseif #winners == 1 then
		return `{winners[1].DisplayName} wins!`
	elseif #winners <= 3 then
		local names = {}
		for _, player in winners do
			table.insert(names, player.DisplayName)
		end
		return `{table.concat(names, ", ")} win!`
	end
	return `{#winners} winners!`
end

-- Idle -> countdown -> play -> result, forever.
local function runLoop(g: Game)
	while true do
		setState(g, { phase = "Idle", headline = "Step on to play!", players = {} })
		local onNow: { Player } = {}
		repeat
			task.wait(0.5)
			onNow = {}
			for _, player in Players:GetPlayers() do
				if eligible(player) and g.isOn(player) then
					table.insert(onNow, player)
				end
			end
		until #onNow > 0

		local startAt = now() + SETTINGS.CountdownSeconds
		local lastCount = -1
		local cancelled = false
		while now() < startAt do
			onNow = {}
			for _, player in Players:GetPlayers() do
				if eligible(player) and g.isOn(player) then
					table.insert(onNow, player)
				end
			end
			if #onNow == 0 then
				cancelled = true
				break
			end
			if #onNow ~= lastCount then
				lastCount = #onNow
				setState(g, {
					phase = "Countdown",
					headline = "Starting soon!",
					detail = `{#onNow} player{if #onNow == 1 then "" else "s"} ready`,
					endsAt = startAt,
					players = userIds(onNow),
				})
			end
			task.wait(0.25)
		end
		if not cancelled then
			local ok, winners = pcall(g.play, g, onNow)
			if not ok then
				warn(`[Minigames] {g.state.id} failed: {winners}`)
				winners = {}
			end
			for _, winner in winners do
				if winner.Parent == Players then
					reward(winner, g.state.name)
				end
			end
			setState(g, {
				phase = "Result",
				headline = winnerText(winners),
				color = Color3.fromRGB(255, 215, 80),
				endsAt = now() + SETTINGS.ResultSeconds,
				players = userIds(winners),
			})
			task.wait(SETTINGS.ResultSeconds)
		end
	end
end

---------------------------------------------------------------------------------------------------
-- Color Rush
---------------------------------------------------------------------------------------------------

local TILE_COLORS = {
	{ name = "PINK", color = Color3.fromRGB(255, 79, 163) },
	{ name = "BLUE", color = Color3.fromRGB(60, 150, 255) },
	{ name = "YELLOW", color = Color3.fromRGB(255, 214, 60) },
	{ name = "GREEN", color = Color3.fromRGB(70, 220, 120) },
	{ name = "PURPLE", color = Color3.fromRGB(165, 90, 255) },
}

local function buildColorRush(parent: Instance): Game
	local cr = SETTINGS.ColorRush
	local model = Instance.new("Model")
	model.Name = "ColorRush"
	local half = cr.Grid * cr.TileSize / 2
	local center = cr.Center
	local tiles: { Part } = {}
	for i = 1, cr.Grid do
		for j = 1, cr.Grid do
			local offset =
				Vector3.new((i - 0.5) * cr.TileSize - half, cr.Height - 0.5, (j - 0.5) * cr.TileSize - half)
			local tile = part(
				model,
				"Tile",
				Vector3.new(cr.TileSize - 0.3, 1, cr.TileSize - 0.3),
				CFrame.new(center + offset),
				TILE_COLORS[(i + j) % 4 + 1].color
			)
			tile.Material = Enum.Material.SmoothPlastic
			table.insert(tiles, tile)
		end
	end
	-- Where you land when you fall: dark "out" floor under the tiles.
	local pit = part(
		model,
		"Pit",
		Vector3.new(half * 2, 0.2, half * 2),
		CFrame.new(center + Vector3.new(0, 0.1, 0)),
		DARK
	)
	pit.CanCollide = false -- the deck under it is the floor; this is just paint
	-- Neon frame around the tile field.
	for _, spec in
		{
			{ Vector3.new(half * 2 + 1, 0.6, 0.6), Vector3.new(0, cr.Height - 0.7, half + 0.3) },
			{ Vector3.new(half * 2 + 1, 0.6, 0.6), Vector3.new(0, cr.Height - 0.7, -half - 0.3) },
			{ Vector3.new(0.6, 0.6, half * 2 + 1), Vector3.new(half + 0.3, cr.Height - 0.7, 0) },
			{ Vector3.new(0.6, 0.6, half * 2 + 1), Vector3.new(-half - 0.3, cr.Height - 0.7, 0) },
		}
	do
		local edge = part(model, "Edge", spec[1], CFrame.new(center + spec[2]), PINK, true)
		edge.CanCollide = false
	end
	-- Ramp up from the deck on the plaza side (west). A wedge's low edge is its front (-Z).
	local rampLength = cr.Height * 2.2
	local rampCenter = Vector3.new(center.X - half - rampLength / 2, cr.Height / 2, center.Z)
	local ramp = Instance.new("WedgePart")
	ramp.Name = "Ramp"
	ramp.Anchored = true
	ramp.Size = Vector3.new(8, cr.Height, rampLength)
	ramp.CFrame = CFrame.lookAt(rampCenter, rampCenter + Vector3.new(-1, 0, 0))
	ramp.Color = Color3.fromRGB(240, 200, 225)
	ramp.Material = Enum.Material.SmoothPlastic
	ramp.Parent = model
	-- Closed while a game runs, so nobody walks onto the tiles mid-game.
	local gate = part(
		model,
		"Gate",
		Vector3.new(0.6, 6, 8),
		CFrame.new(center.X - half - 0.4, cr.Height + 3, center.Z),
		PINK,
		true
	)
	gate.Transparency = 1
	gate.CanCollide = false
	local status, detail =
		sign(model, "ColorRush", CFrame.new(center + Vector3.new(0, cr.Height + 9, -half - 3)), "COLOR RUSH")
	model.Parent = parent

	local g: Game
	g = {
		state = {
			id = "ColorRush",
			name = "Color Rush",
			phase = "Idle",
			headline = "",
			players = {},
			center = center + Vector3.new(0, cr.Height, 0),
		},
		sign = status,
		subSign = detail,
		isOn = function(player: Player): boolean
			local root = rootOf(player)
			if not root then
				return false
			end
			local p = root.Position - center
			return math.abs(p.X) <= half
				and math.abs(p.Z) <= half
				and p.Y > cr.Height + 0.5
				and p.Y < cr.Height + 12
		end,
		joinSpot = function(playing: boolean): CFrame
			if playing then
				return CFrame.new(rampCenter - Vector3.new(rampLength, cr.Height / 2 - 3, 0))
			end
			return CFrame.new(center + Vector3.new(0, cr.Height + 3, 0))
		end,
		play = function(self: Game, participants: { Player }): { Player }
			gate.CanCollide = true
			gate.Transparency = 0.6
			local alive = table.clone(participants)
			local solo = #participants == 1
			local winners: { Player } = {}
			for wave = 1, cr.Waves do
				local paletteSize = if wave <= 3 then 3 elseif wave <= 7 then 4 else 5
				local target = TILE_COLORS[math.random(paletteSize)]
				local targetTiles = 0
				for _, tile in tiles do
					local pick = TILE_COLORS[math.random(paletteSize)]
					tile.Color = pick.color
					tile:SetAttribute("Safe", pick == target)
					if pick == target then
						targetTiles += 1
					end
				end
				-- Always enough safe tiles to share.
				while targetTiles < math.max(3, #alive) do
					local tile = tiles[math.random(#tiles)]
					if not tile:GetAttribute("Safe") then
						tile.Color = target.color
						tile:SetAttribute("Safe", true)
						targetTiles += 1
					end
				end
				local progress = (wave - 1) / math.max(1, cr.Waves - 1)
				local seconds = cr.FirstWaveSeconds + (cr.LastWaveSeconds - cr.FirstWaveSeconds) * progress
				setState(self, {
					phase = "Playing",
					headline = `{target.name}!`,
					color = target.color,
					detail = if solo
						then `Wave {wave}/{cr.Waves}`
						else `Wave {wave}/{cr.Waves}  ·  {#alive} left`,
					endsAt = now() + seconds,
					players = userIds(alive),
				})
				task.wait(seconds)
				for _, tile in tiles do
					if not tile:GetAttribute("Safe") then
						tile.Transparency = 1
						tile.CanCollide = false
					end
				end
				task.wait(cr.GoneSeconds)
				local kept, dropped = stillIn(self, alive)
				for _, player in dropped do
					if player.Parent == Players then
						toast(player, `Out on wave {wave}! Step back on for the next game.`)
					end
				end
				for _, tile in tiles do
					tile.Transparency = 0
					tile.CanCollide = true
				end
				if #kept == 0 then
					winners = {}
					break
				end
				alive = kept
				if not solo and #alive == 1 then
					winners = alive
					break
				end
				if wave == cr.Waves then
					winners = alive
				end
			end
			gate.CanCollide = false
			gate.Transparency = 1
			return winners
		end,
	}
	return g
end

---------------------------------------------------------------------------------------------------
-- Freeze Frame
---------------------------------------------------------------------------------------------------

local function buildFreezeFrame(parent: Instance): Game
	local ff = SETTINGS.FreezeFrame
	local model = Instance.new("Model")
	model.Name = "FreezeFrame"
	local center = ff.Center
	local diameter = ff.Radius * 2
	local stage = part(
		model,
		"Stage",
		Vector3.new(1, diameter, diameter),
		CFrame.new(center + Vector3.new(0, 0.5, 0)) * CFrame.Angles(0, 0, math.rad(90)),
		Color3.fromRGB(45, 36, 62)
	)
	stage.Shape = Enum.PartType.Cylinder
	local ring = part(
		model,
		"Ring",
		Vector3.new(0.8, diameter + 1.6, diameter + 1.6),
		CFrame.new(center + Vector3.new(0, 0.4, 0)) * CFrame.Angles(0, 0, math.rad(90)),
		PINK,
		true
	)
	ring.Shape = Enum.PartType.Cylinder
	-- Four light posts; their colour shows the phase (party colours = dance, icy blue = freeze).
	local lights: { Part } = {}
	for k = 0, 3 do
		local angle = k * math.pi / 2 + math.pi / 4
		local base = center + Vector3.new(math.cos(angle), 0, math.sin(angle)) * (ff.Radius + 2.5)
		part(model, "Post", Vector3.new(0.6, 9, 0.6), CFrame.new(base + Vector3.new(0, 4.5, 0)), DARK)
		local lamp = part(
			model,
			"Lamp",
			Vector3.new(1.6, 1.6, 1.6),
			CFrame.new(base + Vector3.new(0, 9.5, 0)),
			PINK,
			true
		)
		lamp.Shape = Enum.PartType.Ball
		local light = Instance.new("PointLight")
		light.Range = 22
		light.Brightness = 2
		light.Color = PINK
		light.Parent = lamp
		table.insert(lights, lamp)
	end
	local function paint(color: Color3)
		ring.Color = color
		for _, lamp in lights do
			lamp.Color = color
			local light = lamp:FindFirstChildOfClass("PointLight")
			if light then
				light.Color = color
			end
		end
	end
	local status, detail = sign(
		model,
		"FreezeFrame",
		CFrame.new(center + Vector3.new(0, 11, ff.Radius + 4)) * CFrame.Angles(0, math.pi, 0),
		"FREEZE FRAME"
	)
	model.Parent = parent

	local outSpot = center + Vector3.new(ff.Radius + 5, 3, 0)
	local function isOn(player: Player): boolean
		local root = rootOf(player)
		if not root then
			return false
		end
		local p = root.Position - center
		return Vector2.new(p.X, p.Z).Magnitude <= ff.Radius - 0.5 and p.Y > 1 and p.Y < 14
	end
	local function kickOff(player: Player, why: string)
		local character = player.Character
		if character and player.Parent == Players then
			character:PivotTo(CFrame.new(outSpot))
			toast(player, why)
		end
	end
	local partyColors = { PINK, CYAN, Color3.fromRGB(255, 214, 60), Color3.fromRGB(165, 90, 255) }

	local g: Game
	g = {
		state = {
			id = "FreezeFrame",
			name = "Freeze Frame",
			phase = "Idle",
			headline = "",
			players = {},
			center = center + Vector3.new(0, 1, 0),
		},
		sign = status,
		subSign = detail,
		isOn = isOn,
		joinSpot = function(playing: boolean): CFrame
			return if playing then CFrame.new(outSpot) else CFrame.new(center + Vector3.new(0, 4, 0))
		end,
		play = function(self: Game, participants: { Player }): { Player }
			local alive = table.clone(participants)
			local solo = #participants == 1
			local winners: { Player } = {}
			for round = 1, ff.Rounds do
				local roundText = if solo
					then `Round {round}/{ff.Rounds}`
					else `Round {round}/{ff.Rounds}  ·  {#alive} left`
				-- Dance: party lights; leaving the stage still counts as out.
				setState(self, {
					phase = "Playing",
					headline = "DANCE!",
					color = PINK,
					detail = roundText,
					players = userIds(alive),
				})
				local danceFor = ff.DanceSeconds[1]
					+ math.random() * (ff.DanceSeconds[2] - ff.DanceSeconds[1])
				local danceEnd = os.clock() + danceFor
				local step = 0
				while os.clock() < danceEnd do
					step += 1
					paint(partyColors[step % #partyColors + 1])
					task.wait(0.3)
				end
				-- Freeze: snapshot after a short grace, then anyone who moves is out.
				local freezeFor = ff.FreezeSeconds[1]
					+ math.random() * (ff.FreezeSeconds[2] - ff.FreezeSeconds[1])
				paint(CYAN)
				setState(self, {
					phase = "Playing",
					headline = "FREEZE!",
					color = CYAN,
					detail = roundText,
					endsAt = now() + freezeFor,
					players = userIds(alive),
				})
				task.wait(ff.Grace)
				local snapshot: { [Player]: Vector3 } = {}
				for _, player in alive do
					local root = rootOf(player)
					if root then
						snapshot[player] = root.Position
					end
				end
				local freezeEnd = os.clock() + freezeFor - ff.Grace
				local out: { [Player]: string } = {}
				while os.clock() < freezeEnd do
					task.wait(0.15)
					for _, player in alive do
						if out[player] then
							continue
						end
						local root = rootOf(player)
						local start = snapshot[player]
						if not root or not start or not eligible(player) then
							out[player] = "Out! You left the game."
							continue
						end
						local moved = root.Position - start
						if
							Vector2.new(moved.X, moved.Z).Magnitude > ff.MoveTolerance
							or math.abs(moved.Y) > 1.5
						then
							out[player] = `You moved! Out in round {round}.`
						end
					end
				end
				local kept = {}
				for _, player in alive do
					if out[player] then
						kickOff(player, out[player])
					elseif isOn(player) then
						table.insert(kept, player)
					else
						kickOff(player, "Out! You left the stage.")
					end
				end
				if #kept == 0 then
					winners = {}
					break
				end
				alive = kept
				if not solo and #alive == 1 then
					winners = alive
					break
				end
				if round == ff.Rounds then
					winners = alive
				end
			end
			paint(PINK)
			return winners
		end,
	}
	return g
end

---------------------------------------------------------------------------------------------------
-- Deck + start
---------------------------------------------------------------------------------------------------

local function buildDeck(parent: Instance)
	-- Joins the plaza's east edge (x = 60), with a neon trim around the outside.
	local minX, maxX, minZ, maxZ = 60, 140, -50, 74
	local size = Vector3.new(maxX - minX, 2, maxZ - minZ)
	local mid = Vector3.new((minX + maxX) / 2, -1, (minZ + maxZ) / 2)
	part(parent, "Deck", size, CFrame.new(mid), DECK_COLOR)
	for _, spec in
		{
			{ Vector3.new(size.X, 0.4, 0.6), Vector3.new(mid.X, 0.2, maxZ) },
			{ Vector3.new(size.X, 0.4, 0.6), Vector3.new(mid.X, 0.2, minZ) },
			{ Vector3.new(0.6, 0.4, size.Z), Vector3.new(maxX, 0.2, mid.Z) },
		}
	do
		local trim = part(parent, "Trim", spec[1], CFrame.new(spec[2]), PINK, true)
		trim.CanCollide = false
	end
	-- Arch at the entrance from the plaza.
	local archX = minX + 4
	part(parent, "ArchL", Vector3.new(1, 12, 1), CFrame.new(archX, 6, 14), DARK)
	part(parent, "ArchR", Vector3.new(1, 12, 1), CFrame.new(archX, 6, -14), DARK)
	local top = part(parent, "ArchTop", Vector3.new(1.4, 3, 30), CFrame.new(archX, 12.5, 0), DARK)
	for _, face in { Enum.NormalId.Left, Enum.NormalId.Right } do
		local gui = Instance.new("SurfaceGui")
		gui.Face = face
		gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
		gui.PixelsPerStud = 30
		gui.LightInfluence = 0
		gui.Parent = top
		local label = Instance.new("TextLabel")
		label.BackgroundTransparency = 1
		label.Size = UDim2.fromScale(1, 1)
		label.Font = Enum.Font.FredokaOne
		label.TextScaled = true
		label.TextColor3 = PINK
		label.Text = "MINIGAMES"
		label.Parent = gui
	end
end

-- Take a player to a game (from the Games panel).
local function go(player: Player, gameId: any)
	local g = if type(gameId) == "string" then games[gameId] else nil
	if not g or not eligible(player) then
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
		toast(player, `{g.state.name} is in progress. Hop on when it ends!`)
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
	buildDeck(folder)
	games.ColorRush = buildColorRush(folder)
	games.FreezeFrame = buildFreezeFrame(folder)
	folder.Parent = lobby

	Remotes.Events.MinigameGo.OnServerEvent:Connect(go)
	-- Late joiners get every game's current state.
	Players.PlayerAdded:Connect(function(player)
		for _, g in games do
			Remotes.Events.MinigameState:FireClient(player, g.state)
		end
	end)
	Players.PlayerRemoving:Connect(function(player)
		rewardTimes[player] = nil
		lastGo[player] = nil
	end)
	for _, g in games do
		task.spawn(runLoop, g)
	end
end

return Minigames
