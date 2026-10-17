--!strict
-- Color Rush: a 7x7 field of floating tiles in five colours. A colour is called on the big screen;
-- the other tiles blink, then drop. Fall and you're out. Waves speed up, and from wave 4 they get
-- twists: SHUFFLE (colours change mid-wave), MEMORY (colours hide before the call), FAKE OUT (the
-- call changes) and TWO COLORS (a breather). From wave 11 the outer ring is gone for good.
--
-- The server decides everything (colours, who fell). Tiles carry attributes the client animates:
-- Warn (blinking), Gone (dropped), Hidden (memory wave).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Arena = require(script.Parent.Arena)

local C = Arena.Colors
local S = Arena.Sounds

local COLORS = {
	{ name = "PINK", color = C.Pink },
	{ name = "BLUE", color = Color3.fromRGB(60, 150, 255) },
	{ name = "YELLOW", color = Color3.fromRGB(255, 214, 60) },
	{ name = "GREEN", color = C.Lime },
	{ name = "PURPLE", color = C.Purple },
}
local HIDDEN_COLOR = Color3.fromRGB(235, 232, 240)

type Tile = { base: Part, glow: Part, ring: number, color: typeof(COLORS[1])?, removed: boolean }

local ColorRush = {}

function ColorRush.build(parent: Instance): Arena.Game
	local cr = Config.Minigames.ColorRush
	local model = Instance.new("Model")
	model.Name = "ColorRush"
	local center = cr.Center
	local half = cr.Grid * cr.TileSize / 2
	local top = cr.Height

	-- Tiles: a solid base + a glowing inlay on top. Ring 0 is the middle, ring 3 the outer edge.
	local tiles: { Tile } = {}
	local mid = (cr.Grid + 1) / 2
	for i = 1, cr.Grid do
		for j = 1, cr.Grid do
			local offset =
				Vector3.new((i - 0.5) * cr.TileSize - half, top - 0.5, (j - 0.5) * cr.TileSize - half)
			local base = Arena.part(
				model,
				"Tile",
				Vector3.new(cr.TileSize - 0.35, 1, cr.TileSize - 0.35),
				CFrame.new(center + offset),
				COLORS[(i + j) % #COLORS + 1].color
			)
			local glow = Arena.glow(
				model,
				"TileGlow",
				Vector3.new(cr.TileSize - 1.6, 0.08, cr.TileSize - 1.6),
				CFrame.new(center + offset + Vector3.new(0, 0.54, 0)),
				base.Color
			)
			glow.Transparency = 0.15
			glow.Parent = base -- the client animates a tile and its glow together
			base:SetAttribute("Warn", false)
			base:SetAttribute("Gone", false)
			base:SetAttribute("Hidden", false)
			base:AddTag("ColorRushTile") -- the client animates these
			local ring = math.max(math.abs(i - mid), math.abs(j - mid))
			table.insert(tiles, { base = base, glow = glow, ring = ring, color = nil, removed = false })
		end
	end
	-- The "out" floor under the field: dark glass with a pink outline and OUT painted on it.
	local pit = Arena.part(
		model,
		"Pit",
		Vector3.new(half * 2, 0.2, half * 2),
		CFrame.new(center + Vector3.new(0, 0.1, 0)),
		C.Plum,
		Enum.Material.Glass
	)
	pit.CanCollide = false
	local pitGui = Arena.surface(pit, Enum.NormalId.Top, 8)
	Arena.label(
		pitGui,
		"OUT",
		UDim2.fromScale(0.1, 0.3),
		UDim2.fromScale(0.8, 0.4),
		Color3.fromRGB(90, 70, 120)
	)
	for _, spec in
		{
			{ Vector3.new(half * 2 + 1.2, 0.5, 0.5), Vector3.new(0, top - 0.75, half + 0.35) },
			{ Vector3.new(half * 2 + 1.2, 0.5, 0.5), Vector3.new(0, top - 0.75, -half - 0.35) },
			{ Vector3.new(0.5, 0.5, half * 2 + 1.2), Vector3.new(half + 0.35, top - 0.75, 0) },
			{ Vector3.new(0.5, 0.5, half * 2 + 1.2), Vector3.new(-half - 0.35, top - 0.75, 0) },
		}
	do
		Arena.glow(model, "Edge", spec[1], CFrame.new(center + spec[2]), C.Pink)
	end

	-- Frame: four pillars, a truss and a four-sided screen hanging over the middle.
	local pillarHeight = top + 16
	for _, corner in
		{ Vector3.new(1, 0, 1), Vector3.new(-1, 0, 1), Vector3.new(1, 0, -1), Vector3.new(-1, 0, -1) }
	do
		local base = center + corner * (half + 2.5)
		Arena.pillar(model, base, pillarHeight)
		-- Spotlight on each pillar, aimed at the middle of the field.
		local lamp = Arena.glow(
			model,
			"Spot",
			Vector3.new(1.2, 1.2, 1.2),
			CFrame.lookAt(base + Vector3.new(0, pillarHeight - 2, 0), center + Vector3.new(0, top, 0)),
			C.Warm
		)
		local spot = Instance.new("SpotLight")
		spot.Face = Enum.NormalId.Front
		spot.Range = 45
		spot.Angle = 50
		spot.Brightness = 2
		spot.Color = C.Warm
		spot.Parent = lamp
	end
	for _, spec in
		{
			{ Vector3.new(half * 2 + 7, 1.4, 1.4), Vector3.new(0, pillarHeight, half + 2.5) },
			{ Vector3.new(half * 2 + 7, 1.4, 1.4), Vector3.new(0, pillarHeight, -half - 2.5) },
			{ Vector3.new(1.4, 1.4, half * 2 + 7), Vector3.new(half + 2.5, pillarHeight, 0) },
			{ Vector3.new(1.4, 1.4, half * 2 + 7), Vector3.new(-half - 2.5, pillarHeight, 0) },
			{ Vector3.new(half * 2 + 5, 1, 1), Vector3.new(0, pillarHeight, 0) },
		}
	do
		Arena.part(model, "Truss", spec[1], CFrame.new(center + spec[2]), C.Black, Enum.Material.Marble)
	end
	local screenY = pillarHeight - 5
	Arena.part(
		model,
		"ScreenRod",
		Vector3.new(0.4, 3, 0.4),
		CFrame.new(center + Vector3.new(0, pillarHeight - 2, 0)),
		C.Champagne,
		Enum.Material.Metal
	)
	local screen = Arena.part(
		model,
		"Screen",
		Vector3.new(9, 6, 9),
		CFrame.new(center + Vector3.new(0, screenY, 0)),
		C.Black,
		Enum.Material.Marble
	)
	local screenSwatches: { Frame } = {}
	local screenLabels: { TextLabel } = {}
	for _, face in { Enum.NormalId.Front, Enum.NormalId.Back, Enum.NormalId.Left, Enum.NormalId.Right } do
		local gui = Arena.surface(screen, face, 40)
		local swatch = Instance.new("Frame")
		swatch.Size = UDim2.fromScale(0.9, 0.86)
		swatch.Position = UDim2.fromScale(0.05, 0.07)
		swatch.BackgroundColor3 = C.Plum
		swatch.BorderSizePixel = 0
		swatch.Parent = gui
		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0.08, 0)
		corner.Parent = swatch
		table.insert(screenSwatches, swatch)
		table.insert(
			screenLabels,
			Arena.label(
				swatch,
				"COLOR RUSH",
				UDim2.fromScale(0.05, 0.2),
				UDim2.fromScale(0.9, 0.6),
				Color3.new(1, 1, 1)
			)
		)
	end
	local function showScreen(text: string, color: Color3?)
		for index, swatch in screenSwatches do
			swatch.BackgroundColor3 = color or C.Plum
			screenLabels[index].Text = text
		end
	end

	-- Ramp up on the south side (towards the fountain). A wedge's low edge is its front (-Z).
	local rampLength = top * 2.2
	local rampCenter = Vector3.new(center.X, top / 2, center.Z + half + rampLength / 2)
	local ramp = Instance.new("WedgePart")
	ramp.Name = "Ramp"
	ramp.Anchored = true
	ramp.Size = Vector3.new(8, top, rampLength)
	ramp.CFrame = CFrame.lookAt(rampCenter, rampCenter + Vector3.new(0, 0, 1))
	ramp.Color = C.Black
	ramp.Material = Enum.Material.Marble
	ramp.Parent = model
	-- Closed while a game runs, so nobody walks onto the tiles mid-game.
	local gate = Arena.glow(
		model,
		"Gate",
		Vector3.new(8, 6, 0.4),
		CFrame.new(center.X, top + 3, center.Z + half + 0.4),
		C.Pink
	)
	gate.Transparency = 1

	local status, detail = Arena.sign(
		model,
		"ColorRush",
		CFrame.new(center + Vector3.new(-half - 4, top + 5, 0)) * CFrame.Angles(0, math.rad(90), 0),
		"COLOR RUSH"
	)
	model.Parent = parent

	---------------------------------------------------------------------------------------------
	-- Game
	---------------------------------------------------------------------------------------------

	local function isOn(player: Player): boolean
		local root = Arena.rootOf(player)
		if not root then
			return false
		end
		local p = root.Position - center
		return math.abs(p.X) <= half and math.abs(p.Z) <= half and p.Y > top + 0.5 and p.Y < top + 14
	end

	local function paint(tile: Tile, pick: typeof(COLORS[1]))
		tile.color = pick
		tile.base.Color = pick.color
		tile.glow.Color = pick.color
	end
	local function hide(tile: Tile, hidden: boolean)
		tile.base:SetAttribute("Hidden", hidden)
		local color = if hidden or not tile.color then HIDDEN_COLOR else tile.color.color
		tile.base.Color = color
		tile.glow.Color = color
	end
	local function setGone(tile: Tile, gone: boolean)
		tile.base:SetAttribute("Gone", gone)
		tile.base:SetAttribute("Warn", false)
		tile.base.CanCollide = not gone
	end
	local function resetField()
		for _, tile in tiles do
			tile.removed = false
			setGone(tile, false)
			hide(tile, false)
		end
	end

	local g: Arena.Game
	g = {
		rounds = true,
		state = {
			id = "ColorRush",
			name = "Color Rush",
			phase = "Idle",
			headline = "",
			players = {},
			center = center + Vector3.new(0, top, 0),
		},
		sign = status,
		subSign = detail,
		isOn = isOn,
		joinSpot = function(playing: boolean): CFrame
			if playing then
				return CFrame.lookAt(
					Vector3.new(center.X, 3, center.Z + half + rampLength + 4),
					Vector3.new(center.X, 3, center.Z)
				)
			end
			return CFrame.new(center + Vector3.new(0, top + 3, 0))
		end,
		play = function(self: Arena.Game, participants: { Player }): { Player }
			gate.CanCollide = true
			gate.Transparency = 0.55
			resetField()
			local alive = table.clone(participants)
			local solo = #participants == 1
			local winners: { Player } = {}

			-- Poll for falls while waiting: anyone who drops off is out at once.
			local function waitAndWatch(seconds: number, wave: number)
				local deadline = os.clock() + seconds
				repeat
					task.wait(0.12)
					local kept = {}
					for _, player in alive do
						if Arena.eligible(player) and isOn(player) then
							table.insert(kept, player)
						else
							local root = Arena.rootOf(player)
							if root then
								Arena.fx(nil, { kind = "burst", position = root.Position, color = C.Pink })
							end
							Arena.sound(S.Out, nil, { player }, 0.8)
							Arena.toast(player, `Out on wave {wave}! Step back on for the next game.`)
						end
					end
					if #kept ~= #alive then
						alive = kept
						self.state.players = Arena.userIds(alive)
					end
				until os.clock() >= deadline
			end

			for wave = 1, cr.Waves do
				local progress = (wave - 1) / math.max(1, cr.Waves - 1)
				local seconds = cr.FirstWaveSeconds + (cr.LastWaveSeconds - cr.FirstWaveSeconds) * progress
				local paletteSize = if wave <= 3 then 3 elseif wave <= 7 then 4 else 5
				local palette = table.move(COLORS, 1, paletteSize, 1, {})

				-- Shrink: from ShrinkFromWave the outer ring drops for good.
				if wave == cr.ShrinkFromWave then
					for _, tile in tiles do
						if tile.ring >= 3 then
							tile.removed = true
							tile.base:SetAttribute("Warn", true)
						end
					end
					Arena.setState(self, {
						phase = "Playing",
						headline = "THE EDGE IS FALLING!",
						color = C.Gold,
						detail = "Get to the middle!",
						endsAt = Arena.now() + 2,
						players = Arena.userIds(alive),
					})
					showScreen("MOVE IN!", C.Gold)
					waitAndWatch(2, wave)
					for _, tile in tiles do
						if tile.removed then
							setGone(tile, true)
						end
					end
					Arena.sound(S.Drop, center, nil, 0.7, 0.8)
				end

				-- Pick the twist for this wave.
				local twist = "Normal"
				if wave >= cr.TwistsFromWave then
					local roll = math.random()
					twist = if roll < 0.18
						then "Shuffle"
						elseif roll < 0.34 then "Memory"
						elseif roll < 0.5 then "FakeOut"
						elseif roll < 0.6 then "TwoColors"
						else "Normal"
				end

				-- Colour the tiles and pick the safe colour(s).
				local live: { Tile } = {}
				for _, tile in tiles do
					if not tile.removed then
						table.insert(live, tile)
						paint(tile, palette[math.random(#palette)])
					end
				end
				local target = palette[math.random(#palette)]
				local second = nil
				if twist == "TwoColors" then
					repeat
						second = palette[math.random(#palette)]
					until second ~= target
				end
				local function isSafe(tile: Tile): boolean
					return tile.color == target or (second ~= nil and tile.color == second)
				end
				local function ensureEnough()
					local safe = 0
					for _, tile in live do
						if isSafe(tile) then
							safe += 1
						end
					end
					local tries = 0
					while safe < math.max(3, #alive + 1) and tries < 200 do
						tries += 1
						local tile = live[math.random(#live)]
						if not isSafe(tile) then
							paint(tile, target)
							safe += 1
						end
					end
				end
				ensureEnough()

				local waveText = if solo
					then `Wave {wave}/{cr.Waves}`
					else `Wave {wave}/{cr.Waves}  ·  {#alive} left`
				local callText = if second then `{target.name} + {second.name}!` else `{target.name}!`

				if twist == "Memory" then
					-- Show the colours, then hide them all before the call.
					Arena.setState(self, {
						phase = "Playing",
						headline = "MEMORIZE!",
						color = C.Cyan,
						detail = waveText,
						endsAt = Arena.now() + 2.2,
						players = Arena.userIds(alive),
					})
					showScreen("MEMORIZE!", C.Cyan)
					waitAndWatch(2.2, wave)
					for _, tile in live do
						hide(tile, true)
					end
					Arena.sound(S.Switch, center, nil, 0.8)
				end

				local endsAt = Arena.now() + seconds
				Arena.setState(self, {
					phase = "Playing",
					headline = callText,
					color = target.color,
					detail = if twist == "Shuffle" then `{waveText}  ·  watch out...` else waveText,
					endsAt = endsAt,
					players = Arena.userIds(alive),
				})
				showScreen(callText, target.color)
				Arena.sound(S.Go, center, nil, 0.6, 1 + wave * 0.02)

				local warnAt = math.max(0.4, seconds - cr.WarnSeconds)
				if twist == "Shuffle" or twist == "FakeOut" then
					waitAndWatch(warnAt * 0.5, wave)
					if twist == "Shuffle" then
						for _, tile in live do
							paint(tile, palette[math.random(#palette)])
						end
						ensureEnough()
						Arena.setState(self, {
							phase = "Playing",
							headline = `SHUFFLE! {callText}`,
							color = target.color,
							detail = waveText,
							endsAt = endsAt,
							players = Arena.userIds(alive),
						})
						Arena.sound(S.Switch, center, nil, 0.9, 1.2)
					else
						local switched = target
						repeat
							switched = palette[math.random(#palette)]
						until switched ~= target
						target = switched
						ensureEnough()
						callText = `NO... {target.name}!`
						Arena.setState(self, {
							phase = "Playing",
							headline = callText,
							color = target.color,
							detail = waveText,
							endsAt = endsAt,
							players = Arena.userIds(alive),
						})
						showScreen(callText, target.color)
						Arena.sound(S.Go, center, nil, 0.7, 1.4)
					end
					waitAndWatch(warnAt * 0.5, wave)
				else
					waitAndWatch(warnAt, wave)
				end

				-- Warn: wrong tiles blink, with ticks.
				for _, tile in live do
					if not isSafe(tile) then
						tile.base:SetAttribute("Warn", true)
					end
				end
				for k = 1, 3 do
					Arena.sound(S.Tick, center, nil, 0.5, 1 + k * 0.15)
					waitAndWatch(cr.WarnSeconds / 3, wave)
				end

				-- Drop! (Memory waves show the real colours again as they go.)
				for _, tile in live do
					if twist == "Memory" then
						hide(tile, false)
					end
					if not isSafe(tile) then
						setGone(tile, true)
					end
				end
				Arena.sound(S.Drop, center, nil, 0.6)
				waitAndWatch(cr.GoneSeconds, wave)
				for _, tile in live do
					setGone(tile, false)
				end

				if #alive == 0 then
					winners = {}
					break
				end
				if not solo and #alive == 1 then
					winners = alive
					break
				end
				if wave == cr.Waves then
					winners = alive
				end
			end
			resetField()
			showScreen("COLOR RUSH", nil)
			gate.CanCollide = false
			gate.Transparency = 1
			return winners
		end,
	}
	return g
end

return ColorRush
