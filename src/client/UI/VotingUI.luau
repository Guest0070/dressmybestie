--!strict
-- Hearts-only voting: a card per look (live 3D preview of the player on stage) with a heart toggle.
-- Up to Config.Limits.MaxHeartsPerVoter picks; no scores, no thumbs-down, no "last place".

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local State = require(script.Parent.Parent.State)
local Kit = require(script.Parent.Kit)

local VotingUI = {}

VotingUI.onToast = function(_text: string) end

local panel: Frame
local cardList: ScrollingFrame
local picks: { number } = {}
local builtForRound = -1

local function heartText(selected: boolean): string
	return if selected then "♥ Loved!" else "♡"
end

-- A frozen 3D snapshot of the player's character, as they stand on stage right now.
local function makePreview(parent: GuiObject, userId: number)
	local viewport = Kit.new("ViewportFrame", {
		BackgroundColor3 = Kit.Colors.PanelLight,
		Size = UDim2.new(1, -8, 0, 110),
		Position = UDim2.fromOffset(4, 4),
		Ambient = Color3.fromRGB(200, 200, 200),
		LightColor = Color3.fromRGB(255, 255, 255),
		Parent = parent,
	}, { Kit.corner(10) })
	local player = Players:GetPlayerByUserId(userId)
	local character = if player then player.Character else nil
	local root = if character then character:FindFirstChild("HumanoidRootPart") else nil
	if not character or not root or not root:IsA("BasePart") then
		return
	end
	character.Archivable = true -- characters can't be cloned without this (local change only)
	local clone = character:Clone()
	for _, descendant in clone:GetDescendants() do
		if descendant:IsA("BaseScript") or descendant:IsA("Sound") then
			descendant:Destroy()
		end
	end
	clone.Parent = viewport
	local camera = Instance.new("Camera")
	local focus = root.Position + Vector3.new(0, 0.3, 0)
	camera.CFrame = CFrame.lookAt(focus + root.CFrame.LookVector * 7 + Vector3.new(0, 1, 0), focus)
	camera.FieldOfView = 45
	camera.Parent = viewport
	viewport.CurrentCamera = camera
end

local function buildCards()
	for _, child in cardList:GetChildren() do
		if child:IsA("GuiObject") then
			child:Destroy()
		end
	end
	picks = {}
	local myTarget = State.myTarget()
	local candidates: { number } = State.round.candidates or {}
	for index, userId in candidates do
		-- Only the look I styled is off-limits (the server also blocks earlier looks after a swap).
		local isMine = userId == myTarget
		local card = Kit.panel({ Size = UDim2.fromOffset(140, 176), LayoutOrder = index, Parent = cardList })
		makePreview(card, userId)
		Kit.label({
			Text = State.nameOf(userId),
			Size = UDim2.new(1, -8, 0, 20),
			Position = UDim2.fromOffset(4, 116),
			Font = Kit.BodyFont,
			Parent = card,
		})
		local heart: TextButton
		heart = Kit.button({
			Text = if isMine then "You styled" else heartText(false),
			Size = UDim2.new(1, -8, 0, 40),
			Position = UDim2.fromOffset(4, 136),
			BackgroundColor3 = if isMine then Kit.Colors.Grey else Kit.Colors.PanelLight,
			AutoButtonColor = not isMine,
			Parent = card,
		}, function()
			if isMine then
				VotingUI.onToast("You can't heart a look you styled!")
				return
			end
			local index = table.find(picks, userId)
			if index then
				table.remove(picks, index)
			elseif #picks >= Config.Limits.MaxHeartsPerVoter then
				VotingUI.onToast(
					`You can give up to {Config.Limits.MaxHeartsPerVoter} hearts. Tap one again to take it back.`
				)
				return
			else
				table.insert(picks, userId)
				Kit.playSound("Heart")
			end
			local selected = table.find(picks, userId) ~= nil
			heart.Text = heartText(selected)
			heart.BackgroundColor3 = if selected then Kit.Colors.Pink else Kit.Colors.PanelLight
			Remotes.Events.CastHearts:FireServer(picks)
		end)
	end
end

local function refresh()
	local voting = State.round.phase == "Voting"
	panel.Visible = voting
	if voting and builtForRound ~= State.round.roundNumber then
		builtForRound = State.round.roundNumber
		-- Give the lineup teleport a moment to replicate before snapshotting characters.
		task.delay(0.6, function()
			if State.round.phase == "Voting" then
				buildCards()
			end
		end)
	end
end

function VotingUI.start()
	local _, root = Kit.screen("Voting", 3)
	panel = Kit.panel({
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -8),
		Size = UDim2.new(1, -16, 0, 196),
		Visible = false,
		Parent = root,
	})
	cardList = Kit.new("ScrollingFrame", {
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(8, 8),
		Size = UDim2.new(1, -16, 1, -16),
		CanvasSize = UDim2.new(0, 0, 0, 0),
		AutomaticCanvasSize = Enum.AutomaticSize.X,
		ScrollingDirection = Enum.ScrollingDirection.X,
		ScrollBarThickness = 6,
		Parent = panel,
	}, { Kit.list(Enum.FillDirection.Horizontal, 8) })
	State.RoundChanged:Connect(refresh)
	refresh()
end

return VotingUI
