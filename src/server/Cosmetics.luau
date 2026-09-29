--!strict
-- Things other players can see about you: an overhead name tag (name, title, rank), your
-- equipped trail, and coins/rank in the player list ("leaderstats").

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local PlayerData = require(script.Parent.Data.PlayerData)

local Cosmetics = {}

local function ensureLeaderstats(player: Player): (IntValue, StringValue)
	local folder = player:FindFirstChild("leaderstats")
	if not folder then
		local created = Instance.new("Folder")
		created.Name = "leaderstats"
		created.Parent = player
		folder = created
	end
	local parent = folder :: Instance
	local coins = parent:FindFirstChild("Coins")
	if not coins or not coins:IsA("IntValue") then
		local created = Instance.new("IntValue")
		created.Name = "Coins"
		created.Parent = parent
		coins = created
	end
	local rank = parent:FindFirstChild("Rank")
	if not rank or not rank:IsA("StringValue") then
		local created = Instance.new("StringValue")
		created.Name = "Rank"
		created.Parent = parent
		rank = created
	end
	return coins :: IntValue, rank :: StringValue
end

local function label(parent: Instance, name: string, text: string, color: Color3, y: number, height: number)
	local l = Instance.new("TextLabel")
	l.Name = name
	l.BackgroundTransparency = 1
	l.Position = UDim2.fromScale(0, y)
	l.Size = UDim2.fromScale(1, height)
	l.Font = Enum.Font.FredokaOne
	l.TextScaled = true
	l.TextColor3 = color
	l.TextStrokeTransparency = 0.3
	l.Text = text
	l.Parent = parent
	return l
end

local function applyNametag(player: Player, character: Model)
	local head = character:FindFirstChild("Head")
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local data = PlayerData.get(player)
	if not head or not head:IsA("BasePart") or not data then
		return
	end
	if humanoid then
		humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None -- ours replaces it
	end
	local existing = head:FindFirstChild("Nametag")
	if existing then
		existing:Destroy()
	end

	local titleId = data.equipped.Title
	local title = if titleId and PlayerData.ownsCosmetic(player, titleId)
		then Config.getCosmetic(titleId)
		else nil
	local rank = PlayerData.getRank(data.styleXp)

	local tag = Instance.new("BillboardGui")
	tag.Name = "Nametag"
	tag.Size = UDim2.fromOffset(220, 72)
	tag.StudsOffset = Vector3.new(0, 2.6, 0)
	tag.MaxDistance = 80
	tag.LightInfluence = 0
	if title then
		label(tag, "Title", title.displayName, title.color or Color3.new(1, 1, 1), 0, 0.32)
	end
	label(tag, "Name", player.DisplayName, Color3.new(1, 1, 1), 0.3, 0.42)
	label(
		tag,
		"Rank",
		`{Config.RankNames[rank] or "Stylist"} · Lv {rank}`,
		Color3.fromRGB(255, 190, 225),
		0.72,
		0.28
	)
	tag.Parent = head
end

local function applyTrail(player: Player, character: Model)
	local root = character:FindFirstChild("HumanoidRootPart")
	local data = PlayerData.get(player)
	if not root or not root:IsA("BasePart") or not data then
		return
	end
	local old = root:FindFirstChild("CosmeticTrail")
	if old then
		old:Destroy()
	end
	local trailId = data.equipped.Trail
	local cosmetic = if trailId and PlayerData.ownsCosmetic(player, trailId)
		then Config.getCosmetic(trailId)
		else nil
	if not cosmetic or not cosmetic.color then
		return
	end

	local top = root:FindFirstChild("TrailTop") :: Attachment? or Instance.new("Attachment")
	top.Name = "TrailTop"
	top.Position = Vector3.new(0, 0.9, 0)
	top.Parent = root
	local bottom = root:FindFirstChild("TrailBottom") :: Attachment? or Instance.new("Attachment")
	bottom.Name = "TrailBottom"
	bottom.Position = Vector3.new(0, -0.9, 0)
	bottom.Parent = root

	local trail = Instance.new("Trail")
	trail.Name = "CosmeticTrail"
	trail.Attachment0 = top
	trail.Attachment1 = bottom
	trail.Lifetime = 0.7
	trail.LightEmission = 0.6
	trail.FaceCamera = true
	trail.Color = ColorSequence.new(cosmetic.color, cosmetic.color2 or cosmetic.color)
	trail.Transparency = NumberSequence.new(0.1, 1)
	trail.Parent = root
end

function Cosmetics.refresh(player: Player)
	local data = PlayerData.get(player)
	if data then
		local coins, rank = ensureLeaderstats(player)
		coins.Value = data.coins
		rank.Value = Config.RankNames[PlayerData.getRank(data.styleXp)] or "Stylist"
	end
	local character = player.Character
	if character then
		applyNametag(player, character)
		applyTrail(player, character)
	end
end

function Cosmetics.start()
	local function watch(player: Player)
		player.CharacterAdded:Connect(function(character)
			character:WaitForChild("Head", 10)
			character:WaitForChild("HumanoidRootPart", 10)
			Cosmetics.refresh(player)
		end)
	end
	for _, player in Players:GetPlayers() do
		watch(player)
	end
	Players.PlayerAdded:Connect(watch)
	PlayerData.Changed:Connect(Cosmetics.refresh)
end

return Cosmetics
