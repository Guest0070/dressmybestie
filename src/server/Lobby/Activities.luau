--!strict
-- Things to do in the lobby between rounds: an obby into the sky, collectible gems, a light-up
-- dance floor, bounce pads and a live "top stylists" board. Built next to the auto-built lobby
-- decorations (only when Workspace.Map.Lobby.Decor exists, i.e. the placeholder lobby is used).
-- Coin rewards are small and capped (Config.Lobby) so the lobby is fun, not a coin farm.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Analytics = require(script.Parent.Parent.Analytics)
local PlayerData = require(script.Parent.Parent.Data.PlayerData)
local Map = require(script.Parent.Parent.Round.Map)
local Quests = require(script.Parent.Parent.Quests)
local HallOfFame = require(script.Parent.HallOfFame)

local Activities = {}

local PINK = Color3.fromRGB(255, 110, 180)
local DARK = Color3.fromRGB(35, 30, 50)
local WHITE = Color3.fromRGB(250, 245, 250)
local OBBY_COLORS = {
	Color3.fromRGB(255, 110, 180),
	Color3.fromRGB(110, 200, 255),
	Color3.fromRGB(255, 220, 80),
	Color3.fromRGB(180, 120, 255),
}

local gemCoinsThisVisit: { [Player]: number } = {}
local lastObbyReward: { [Player]: number } = {}
local touchDebounce: { [Player]: number } = {}
local boardLines: { TextLabel } = {}

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

local function signText(target: BasePart, face: Enum.NormalId, text: string, color: Color3): TextLabel
	local gui = Instance.new("SurfaceGui")
	gui.Face = face
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 40
	gui.LightInfluence = 0
	gui.Parent = target
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1, 1)
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

local function playerFromHit(hit: BasePart): Player?
	local model = hit:FindFirstAncestorOfClass("Model")
	return if model then Players:GetPlayerFromCharacter(model) else nil
end

-- Ignore repeat touches from the same player for a moment (Touched fires many times).
local function debounced(player: Player, seconds: number): boolean
	local now = os.clock()
	if now - (touchDebounce[player] or 0) < seconds then
		return true
	end
	touchDebounce[player] = now
	return false
end

local function toast(player: Player, text: string)
	Remotes.Events.Toast:FireClient(player, text)
end

---------------------------------------------------------------------------------------------------
-- Gems
---------------------------------------------------------------------------------------------------

local function makeGem(parent: Instance, position: Vector3)
	local gem = part(
		parent,
		"Gem",
		Vector3.new(1.6, 1.6, 1.6),
		CFrame.new(position) * CFrame.Angles(math.rad(45), 0, math.rad(45)),
		PINK,
		true
	)
	gem.CanCollide = false
	gem:SetAttribute("Active", true)
	local light = Instance.new("PointLight")
	light.Color = PINK
	light.Range = 8
	light.Parent = gem
	CollectionService:AddTag(gem, "Gem") -- the client spins these

	gem.Touched:Connect(function(hit)
		if gem:GetAttribute("Active") ~= true then
			return
		end
		local player = playerFromHit(hit)
		if not player then
			return
		end
		local earned = gemCoinsThisVisit[player] or 0
		if earned >= Config.Lobby.GemCoinCapPerVisit then
			return -- capped: gems stay for others to grab
		end
		gem:SetAttribute("Active", false)
		gem.Transparency = 1
		light.Enabled = false
		gemCoinsThisVisit[player] = earned + Config.Lobby.GemCoins
		PlayerData.update(player, function(data)
			data.coins += Config.Lobby.GemCoins
		end)
		Analytics.coins(player, Config.Lobby.GemCoins, true, "Gem")
		Quests.bump(player, "gems", 1)
		if gemCoinsThisVisit[player] >= Config.Lobby.GemCoinCapPerVisit then
			toast(player, "Gem bag full for this visit! Play rounds for more coins.")
		end
		task.delay(Config.Lobby.GemRespawnSeconds, function()
			gem:SetAttribute("Active", true)
			gem.Transparency = 0
			light.Enabled = true
		end)
	end)
end

---------------------------------------------------------------------------------------------------
-- Obby
---------------------------------------------------------------------------------------------------

local function buildObby(parent: Instance)
	local obby = Instance.new("Model")
	obby.Name = "Obby"
	part(obby, "Start", Vector3.new(8, 1, 8), CFrame.new(-62, 0.5, 30), Color3.fromRGB(80, 220, 120), true)
	local sign = part(obby, "StartSign", Vector3.new(12, 4, 0.6), CFrame.new(-62, 7, 34.5), DARK)
	signText(
		sign,
		Enum.NormalId.Front,
		"OBBY  +" .. Config.Lobby.ObbyReward .. " coins",
		Color3.fromRGB(80, 220, 120)
	)
	signText(
		sign,
		Enum.NormalId.Back,
		"OBBY  +" .. Config.Lobby.ObbyReward .. " coins",
		Color3.fromRGB(80, 220, 120)
	)
	part(obby, "PoleL", Vector3.new(0.6, 5, 0.6), CFrame.new(-67.5, 2.5, 34.5), WHITE)
	part(obby, "PoleR", Vector3.new(0.6, 5, 0.6), CFrame.new(-56.5, 2.5, 34.5), WHITE)

	local steps = 16
	local last = Vector3.zero
	for i = 1, steps do
		local position = Vector3.new(-62 - i * 7, 1 + i * 1.8, 30 + math.sin(i * 0.9) * 7)
		local small = i % 4 == 0
		local size = if small then Vector3.new(3.5, 1, 3.5) else Vector3.new(5, 1, 5)
		part(obby, `Step{i}`, size, CFrame.new(position), OBBY_COLORS[(i - 1) % #OBBY_COLORS + 1], i % 2 == 0)
		if i % 5 == 0 then
			makeGem(obby, position + Vector3.new(0, 3, 0))
		end
		last = position
	end

	local finishPos = last + Vector3.new(-9, 1.8, 0)
	part(obby, "FinishDeck", Vector3.new(12, 1, 12), CFrame.new(finishPos), Color3.fromRGB(255, 215, 90))
	local finish = part(
		obby,
		"FinishPad",
		Vector3.new(6, 0.4, 6),
		CFrame.new(finishPos + Vector3.new(0, 0.7, 0)),
		Color3.fromRGB(255, 240, 150),
		true
	)
	local flag = part(
		obby,
		"FinishSign",
		Vector3.new(10, 3, 0.6),
		CFrame.new(finishPos + Vector3.new(0, 6, -5.5)),
		DARK
	)
	signText(flag, Enum.NormalId.Back, "YOU MADE IT!", Color3.fromRGB(255, 215, 90))

	finish.Touched:Connect(function(hit)
		local player = playerFromHit(hit)
		if not player or debounced(player, 2) then
			return
		end
		Quests.bump(player, "obby", 1)
		local now = os.time()
		local waitLeft = (lastObbyReward[player] or 0) + Config.Lobby.ObbyCooldownSeconds - now
		if waitLeft <= 0 then
			lastObbyReward[player] = now
			PlayerData.update(player, function(data)
				data.coins += Config.Lobby.ObbyReward
			end)
			Analytics.coins(player, Config.Lobby.ObbyReward, true, "Obby")
			toast(player, `Obby complete! +{Config.Lobby.ObbyReward} coins`)
		else
			toast(player, `Obby complete! Next coin reward in {math.ceil(waitLeft / 60)} min.`)
		end
		local character = player.Character
		if character then
			character:PivotTo(Map.lobbyCFrame())
		end
	end)
	obby.Parent = parent
end

---------------------------------------------------------------------------------------------------
-- Dance floor, bounce pads, leaderboard
---------------------------------------------------------------------------------------------------

local function buildDanceFloor(parent: Instance)
	local floor = Instance.new("Model")
	floor.Name = "DanceFloor"
	for x = 0, 4 do
		for z = 0, 4 do
			local tile = part(
				floor,
				"Tile",
				Vector3.new(3.8, 0.3, 3.8),
				CFrame.new(40 + x * 4, 0.35, -8 + z * 4),
				PINK,
				true
			)
			CollectionService:AddTag(tile, "DanceTile") -- the client cycles the colours
		end
	end
	local sign = part(floor, "Sign", Vector3.new(20, 3, 0.6), CFrame.new(48, 9, -11), DARK)
	signText(sign, Enum.NormalId.Back, "DANCE FLOOR", PINK)
	part(floor, "PoleL", Vector3.new(0.6, 8, 0.6), CFrame.new(38.5, 4, -11), WHITE)
	part(floor, "PoleR", Vector3.new(0.6, 8, 0.6), CFrame.new(57.5, 4, -11), WHITE)
	local ball =
		part(floor, "DiscoBall", Vector3.new(3, 3, 3), CFrame.new(48, 12, 0), Color3.fromRGB(220, 220, 235))
	ball.Shape = Enum.PartType.Ball
	ball.Material = Enum.Material.Glass
	ball.Reflectance = 0.6
	local light = Instance.new("PointLight")
	light.Color = PINK
	light.Range = 20
	light.Brightness = 2
	light.Parent = ball
	floor.Parent = parent
end

local function buildBouncePads(parent: Instance)
	for _, position in { Vector3.new(-22, 0.3, 42), Vector3.new(22, 0.3, 42) } do
		local pad = part(
			parent,
			"BouncePad",
			Vector3.new(0.6, 8, 8),
			CFrame.new(position) * CFrame.Angles(0, 0, math.pi / 2),
			Color3.fromRGB(110, 200, 255),
			true
		)
		pad.Shape = Enum.PartType.Cylinder
		CollectionService:AddTag(pad, "BouncePad") -- the client launches you
	end
end

local function buildLeaderboard(parent: Instance)
	local board = part(parent, "Leaderboard", Vector3.new(1, 14, 20), CFrame.new(58, 8, -30), DARK)
	part(parent, "LeaderboardGlow", Vector3.new(0.5, 15, 21), CFrame.new(58.6, 8, -30), PINK, true)
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Left -- faces -X, towards the plaza
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 40
	gui.LightInfluence = 0
	gui.Parent = board
	local layout = Instance.new("UIListLayout")
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	layout.Parent = gui
	for i = 0, 8 do
		local label = Instance.new("TextLabel")
		label.LayoutOrder = i
		label.BackgroundTransparency = 1
		label.Size = UDim2.fromScale(0.95, if i == 0 then 0.16 else 0.1)
		label.Font = Enum.Font.FredokaOne
		label.TextScaled = true
		label.TextColor3 = if i == 0 then PINK else WHITE
		label.Text = if i == 0 then "TOP STYLISTS" else ""
		label.Parent = gui
		if i > 0 then
			table.insert(boardLines, label)
		end
	end
end

local function refreshLeaderboard()
	local rows = {}
	for _, player in Players:GetPlayers() do
		local data = PlayerData.get(player)
		if data then
			table.insert(rows, { name = player.DisplayName, xp = data.styleXp })
		end
	end
	table.sort(rows, function(a, b)
		return a.xp > b.xp
	end)
	for i, label in boardLines do
		local row = rows[i]
		if row then
			local rank = PlayerData.getRank(row.xp)
			label.Text = `{i}. {row.name}  ·  {Config.RankNames[rank] or "Stylist"}`
		else
			label.Text = ""
		end
	end
end

function Activities.start()
	local map = Workspace:FindFirstChild("Map")
	local lobby = if map then map:FindFirstChild("Lobby") else nil
	if not lobby or not lobby:FindFirstChild("Decor") or lobby:FindFirstChild("Activities") then
		return -- hand-built lobby: add your own activities there
	end
	local folder = Instance.new("Model")
	folder.Name = "Activities"
	buildObby(folder)
	buildDanceFloor(folder)
	buildBouncePads(folder)
	buildLeaderboard(folder)
	HallOfFame.build(folder)
	for _, position in
		{
			Vector3.new(-15, 3, 40),
			Vector3.new(15, 3, 40),
			Vector3.new(-40, 3, 30),
			Vector3.new(40, 3, 30),
			Vector3.new(-40, 3, -35),
			Vector3.new(40, 3, -35),
			Vector3.new(-18, 3, -12),
			Vector3.new(18, 3, -12),
			Vector3.new(0, 3, 36),
			Vector3.new(48, 3, 0),
		}
	do
		makeGem(folder, position)
	end
	folder.Parent = lobby

	Players.PlayerRemoving:Connect(function(player)
		gemCoinsThisVisit[player] = nil
		lastObbyReward[player] = nil
		touchDebounce[player] = nil
	end)
	task.spawn(function()
		while true do
			refreshLeaderboard()
			task.wait(Config.Lobby.LeaderboardRefreshSeconds)
		end
	end)
end

return Activities
