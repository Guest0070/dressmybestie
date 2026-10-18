--!strict
-- Shared building blocks for the lobby minigames: parts and signs in the Play Zone style, the
-- per-game state broadcast, effects sent to clients (MinigameFx), eligibility and rewards.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Types = require(ReplicatedStorage.Shared.Types)
local Analytics = require(script.Parent.Parent.Parent.Analytics)
local PlayerData = require(script.Parent.Parent.Parent.Data.PlayerData)
local Quests = require(script.Parent.Parent.Parent.Quests)
local Badges = require(script.Parent.Parent.Parent.Badges)
local RoundManager = require(script.Parent.Parent.Parent.Round.RoundManager)

local Arena = {}

local SETTINGS = Config.Minigames

Arena.Colors = {
	Pink = Color3.fromRGB(255, 79, 163),
	Cyan = Color3.fromRGB(70, 220, 255),
	Gold = Color3.fromRGB(255, 201, 74),
	Lime = Color3.fromRGB(70, 220, 120),
	Purple = Color3.fromRGB(165, 90, 255),
	White = Color3.fromRGB(240, 236, 232), -- white marble
	Black = Color3.fromRGB(28, 26, 30), -- black marble
	Champagne = Color3.fromRGB(214, 190, 150),
	Warm = Color3.fromRGB(255, 214, 160), -- warm LED
	Plum = Color3.fromRGB(30, 24, 42),
}
local C = Arena.Colors

-- Sounds that ship with every Roblox client (no uploads needed).
Arena.Sounds = {
	Tick = "rbxasset://sounds/electronicpingshort.wav",
	Go = "rbxasset://sounds/bass.wav",
	Drop = "rbxasset://sounds/glassbreak.wav",
	Out = "rbxasset://sounds/uuhhh.mp3",
	Win = "rbxasset://sounds/victory.wav",
	Flash = "rbxasset://sounds/flashbulb.wav",
	Hit = "rbxasset://sounds/hit.wav",
	Whoosh = "rbxasset://sounds/swordslash.wav",
	Launch = "rbxasset://sounds/Launching rocket.wav",
	Snap = "rbxasset://sounds/snap.mp3",
	Switch = "rbxasset://sounds/switch.wav",
	Boom = "rbxasset://sounds/impact_explosion_03.mp3",
	Splash = "rbxasset://sounds/impact_water.mp3",
}

export type Game = {
	state: Types.MinigameState,
	sign: TextLabel?,
	subSign: TextLabel?,
	isOn: (Player) -> boolean, -- standing on the game right now
	play: (Game, { Player }) -> { Player }, -- runs one game, returns the winners
	joinSpot: (playing: boolean) -> CFrame,
	onWin: ((Game, { Player }) -> ())?, -- extra celebration (e.g. Freeze Frame's cover board)
	rounds: boolean, -- false: always open (Runway Dash, Sky Obby), no countdown/play loop
}

---------------------------------------------------------------------------------------------------
-- Building
---------------------------------------------------------------------------------------------------

function Arena.part(
	parent: Instance,
	name: string,
	size: Vector3,
	cframe: CFrame,
	color: Color3,
	material: Enum.Material?
): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.Size = size
	p.CFrame = cframe
	p.Color = color
	p.Material = material or Enum.Material.SmoothPlastic
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = parent
	return p
end

-- Glowing strip / bulb you walk through (no collisions, no raycasts).
function Arena.glow(parent: Instance, name: string, size: Vector3, cframe: CFrame, color: Color3): Part
	local p = Arena.part(parent, name, size, cframe, color, Enum.Material.Neon)
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	return p
end

-- A vertical cylinder (Roblox cylinders lie along X, so it's turned upright).
function Arena.disc(
	parent: Instance,
	name: string,
	height: number,
	diameter: number,
	position: Vector3,
	color: Color3,
	material: Enum.Material?
): Part
	local p = Arena.part(
		parent,
		name,
		Vector3.new(height, diameter, diameter),
		CFrame.new(position) * CFrame.Angles(0, 0, math.rad(90)),
		color,
		material
	)
	p.Shape = Enum.PartType.Cylinder
	return p
end

-- Black marble pillar with a warm LED strip and a champagne cap. solid = false: flung players
-- fly through it (decor around Spin Sweep).
function Arena.pillar(parent: Instance, base: Vector3, height: number, solid: boolean?)
	local post = Arena.part(
		parent,
		"Pillar",
		Vector3.new(2, height, 2),
		CFrame.new(base + Vector3.new(0, height / 2, 0)),
		C.Black,
		Enum.Material.Marble
	)
	post.CanCollide = solid ~= false
	Arena.glow(
		parent,
		"PillarLed",
		Vector3.new(0.3, height - 1, 2.1),
		CFrame.new(base + Vector3.new(0, height / 2, 0)),
		C.Warm
	)
	Arena.part(
		parent,
		"PillarCap",
		Vector3.new(2.6, 0.6, 2.6),
		CFrame.new(base + Vector3.new(0, height + 0.3, 0)),
		C.Champagne,
		Enum.Material.Metal
	)
end

local function surface(target: BasePart, face: Enum.NormalId, ppsOverride: number?): SurfaceGui
	local gui = Instance.new("SurfaceGui")
	gui.Face = face
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = ppsOverride or 30
	gui.LightInfluence = 0
	gui.Parent = target
	return gui
end
Arena.surface = surface

function Arena.label(parent: Instance, text: string, position: UDim2, size: UDim2, color: Color3): TextLabel
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Position = position
	label.Size = size
	label.Font = Enum.Font.FredokaOne
	label.TextScaled = true
	label.TextColor3 = color
	label.Text = text
	local stroke = Instance.new("UIStroke")
	stroke.Thickness = 3
	stroke.Color = C.Plum
	stroke.Parent = label
	label.Parent = parent
	return label
end

-- A game sign: black marble board in a champagne frame with a title, a live status line and a
-- detail line, readable from both sides. Returns the status and detail labels (front face; the
-- back face mirrors them).
function Arena.sign(
	parent: Instance,
	name: string,
	cframe: CFrame,
	title: string,
	width: number?
): (TextLabel, TextLabel)
	local w = width or 26
	local frame = Arena.part(
		parent,
		`{name}Frame`,
		Vector3.new(w + 1, 10, 0.4),
		cframe,
		C.Champagne,
		Enum.Material.Metal
	)
	local board =
		Arena.part(parent, `{name}Sign`, Vector3.new(w, 9, 0.7), cframe, C.Black, Enum.Material.Marble)
	-- Not solid: flung players fly through instead of thudding into the board.
	frame.CanCollide = false
	board.CanCollide = false
	local labels: { { TextLabel } } = {}
	for _, face in { Enum.NormalId.Front, Enum.NormalId.Back } do
		local gui = surface(board, face)
		table.insert(labels, {
			Arena.label(gui, title, UDim2.fromScale(0.04, 0.06), UDim2.fromScale(0.92, 0.34), C.Pink),
			Arena.label(
				gui,
				"",
				UDim2.fromScale(0.04, 0.42),
				UDim2.fromScale(0.92, 0.32),
				Color3.new(1, 1, 1)
			),
			Arena.label(
				gui,
				"",
				UDim2.fromScale(0.04, 0.76),
				UDim2.fromScale(0.92, 0.18),
				Color3.fromRGB(220, 210, 240)
			),
		})
	end
	local front, back = labels[1], labels[2]
	front[2]:GetPropertyChangedSignal("Text"):Connect(function()
		back[2].Text = front[2].Text
	end)
	front[2]:GetPropertyChangedSignal("TextColor3"):Connect(function()
		back[2].TextColor3 = front[2].TextColor3
	end)
	front[3]:GetPropertyChangedSignal("Text"):Connect(function()
		back[3].Text = front[3].Text
	end)
	return front[2], front[3]
end

---------------------------------------------------------------------------------------------------
-- Players
---------------------------------------------------------------------------------------------------

function Arena.rootOf(player: Player): BasePart?
	local character = player.Character
	local humanoid = if character then character:FindFirstChildOfClass("Humanoid") else nil
	if not humanoid or humanoid.Health <= 0 then
		return nil
	end
	local root = character and character:FindFirstChild("HumanoidRootPart")
	return if root and root:IsA("BasePart") then root else nil
end

-- May this player take part right now? (Not in a round, alive, data loaded.)
function Arena.eligible(player: Player): boolean
	return player.Parent == Players
		and Arena.rootOf(player) ~= nil
		and PlayerData.isLoaded(player)
		and not RoundManager.isInRound(player)
end

function Arena.playerFromHit(hit: BasePart): (Player?, Model?)
	local character = hit:FindFirstAncestorOfClass("Model")
	local player = if character then Players:GetPlayerFromCharacter(character) else nil
	return player, if player then character else nil
end

function Arena.userIds(players: { Player }): { number }
	local ids = {}
	for _, player in players do
		table.insert(ids, player.UserId)
	end
	return ids
end

function Arena.now(): number
	return Workspace:GetServerTimeNow()
end

function Arena.toast(player: Player, text: string)
	Remotes.Events.Toast:FireClient(player, text)
end

-- Everyone within `radius` of a point.
function Arena.near(position: Vector3, radius: number): { Player }
	local list = {}
	for _, player in Players:GetPlayers() do
		local root = Arena.rootOf(player)
		if root and (root.Position - position).Magnitude <= radius then
			table.insert(list, player)
		end
	end
	return list
end

---------------------------------------------------------------------------------------------------
-- State + effects
---------------------------------------------------------------------------------------------------

-- Merge `changes` into the game's state (keys left out of `changes` that are optional get
-- cleared), update its sign and send it to everyone.
function Arena.setState(g: Game, changes: { [string]: any })
	for _, key in { "endsAt", "color", "detail" } do
		if changes[key] == nil then
			(g.state :: any)[key] = nil
		end
	end
	for key, value in changes do
		(g.state :: any)[key] = value
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

-- Send an effect to some players (or everyone near `fx.position` when `to` is nil).
function Arena.fx(to: { Player }?, fx: { [string]: any })
	if to then
		for _, player in to do
			if player.Parent == Players then
				Remotes.Events.MinigameFx:FireClient(player, fx)
			end
		end
	else
		Remotes.Events.MinigameFx:FireAllClients(fx)
	end
end

-- A sound at a point (everyone hears it, quieter with distance) or only for `to`.
function Arena.sound(id: string, position: Vector3?, to: { Player }?, volume: number?, pitch: number?)
	Arena.fx(to, { kind = "sound", id = id, position = position, volume = volume, pitch = pitch })
end

---------------------------------------------------------------------------------------------------
-- Rewards
---------------------------------------------------------------------------------------------------

local rewardTimes: { [Player]: { number } } = {}
local streaks: { [Player]: { game: string, count: number } } = {}
local winsThisServer: { [number]: { name: string, wins: number } } = {}
Arena.ChampionsChanged = Instance.new("BindableEvent")

function Arena.champions(): { { name: string, wins: number } }
	local list = {}
	for _, row in winsThisServer do
		table.insert(list, row)
	end
	table.sort(list, function(a, b)
		return a.wins > b.wins
	end)
	return list
end

-- Coins for a win (capped per hour), quest progress, streaks and the champions board.
function Arena.reward(player: Player, gameName: string)
	Quests.bump(player, "minigameWins", 1)
	Badges.award(player, "MinigameWin")
	local row = winsThisServer[player.UserId] or { name = player.DisplayName, wins = 0 }
	row.wins += 1
	winsThisServer[player.UserId] = row
	Arena.ChampionsChanged:Fire()

	local streak = streaks[player]
	if streak and streak.game == gameName then
		streak.count += 1
	else
		streak = { game = gameName, count = 1 }
		streaks[player] = streak
	end
	local streakText = if streak.count >= 2 then ` {streak.count} in a row!` else ""

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
		Arena.toast(player, `You won {gameName}!{streakText} (Coin limit reached for this hour.)`)
		return
	end
	table.insert(recent, os.clock())
	PlayerData.update(player, function(data)
		data.coins += SETTINGS.WinCoins
	end)
	Analytics.coins(player, SETTINGS.WinCoins, true, `Minigame_{gameName}`)
	Arena.toast(player, `You won {gameName}! +{SETTINGS.WinCoins} coins{streakText}`)
end

-- Players who took part but didn't win lose their streak.
function Arena.breakStreak(player: Player, gameName: string)
	local streak = streaks[player]
	if streak and streak.game == gameName then
		streaks[player] = nil
	end
end

Players.PlayerRemoving:Connect(function(player)
	rewardTimes[player] = nil
	streaks[player] = nil
end)

return Arena
