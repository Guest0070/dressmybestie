--!strict
-- Client-side "direction": cameras for booth/runway/voting/results, locking movement during a
-- round, hiding your own mannequin from you, and striking a pose at the end of your walk.

local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local StarterGui = game:GetService("StarterGui")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Remotes = require(ReplicatedStorage.Shared.Remotes)
local State = require(script.Parent.State)

local Stage = {}

local ORBIT_DISTANCE = 10
-- Raise the camera (studs) so the mannequin sits low on screen, below the timer/banner panels.
local CAMERA_RAISE = 3
local CAMERA_LERP = 0.15

local orbitAngle = 0
local controls: any = nil

function Stage.rotate(direction: number)
	orbitAngle += direction * math.rad(45)
end

local function inRound(): boolean
	local names = State.round.names
	return names ~= nil and names[tostring(State.player.UserId)] ~= nil
end

local function mapPart(path: { string }): BasePart?
	local current: Instance? = Workspace:FindFirstChild("Map")
	for _, name in path do
		current = if current then current:FindFirstChild(name) else nil
	end
	return if current and current:IsA("BasePart") then current else nil
end

local function findMannequin(userId: number): Model?
	local folder = Workspace:FindFirstChild("Mannequins")
	if not folder then
		return nil
	end
	for _, model in folder:GetChildren() do
		if model:IsA("Model") and model:GetAttribute("TargetUserId") == userId then
			return model
		end
	end
	return nil
end

local function rootOf(userId: number): BasePart?
	local player = game:GetService("Players"):GetPlayerByUserId(userId)
	local character = if player then player.Character else nil
	local root = if character then character:FindFirstChild("HumanoidRootPart") else nil
	return if root and root:IsA("BasePart") then root else nil
end

-- Which point the runway camera should look at right now.
local function stageFocus(): Vector3?
	local round = State.round
	if round.phase == "Runway" and round.runwayWearer then
		local root = rootOf(round.runwayWearer)
		return if root then root.Position else nil
	elseif round.phase == "Voting" then
		local lineup = mapPart({ "Runway", "Lineup" }) or mapPart({ "Runway", "End" })
		return if lineup then lineup.Position else nil
	elseif round.phase == "Results" then
		local first = mapPart({ "Podium", "First" }) or mapPart({ "Runway", "End" })
		return if first then first.Position else nil
	end
	return nil
end

-- Hide my own character locally while styling so it never blocks the mannequin.
local function setCharacterHidden(hidden: boolean)
	local character = State.player.Character
	if not character then
		return
	end
	for _, descendant in character:GetDescendants() do
		if descendant:IsA("BasePart") or descendant:IsA("Decal") then
			(descendant :: any).LocalTransparencyModifier = if hidden then 1 else 0
		end
	end
end

local function updateCamera()
	local camera = Workspace.CurrentCamera
	if not camera then
		return
	end
	local round = State.round
	local target = State.myTarget()

	if round.phase == "Styling" and target then
		local mannequin = findMannequin(target)
		if mannequin then
			camera.CameraType = Enum.CameraType.Scriptable
			local pivot = mannequin:GetPivot()
			local look = (CFrame.Angles(0, orbitAngle, 0) * pivot).LookVector
			local dir = Vector3.new(look.X, 0, look.Z).Unit -- from mannequin toward camera, level
			local cameraPos = pivot.Position + dir * ORBIT_DISTANCE + Vector3.new(0, CAMERA_RAISE, 0)
			-- Look level (not down) so the raise pushes the mannequin lower on screen.
			local level = CFrame.lookAt(cameraPos, cameraPos - dir)
			-- Turn the camera right so the mannequin appears centred in the LEFT half of the screen
			-- (the catalog covers the right half). Turning instead of sliding keeps it inside the booth.
			local viewport = camera.ViewportSize
			local aspect = viewport.X / math.max(viewport.Y, 1)
			local halfFov = math.rad(camera.FieldOfView) / 2
			local yaw = math.atan(0.5 * math.tan(halfFov) * aspect)
			local desired = level * CFrame.Angles(0, -yaw, 0)
			camera.CFrame = camera.CFrame:Lerp(desired, CAMERA_LERP * 2)
			-- Roblox's camera scripts reset character transparency every frame, so re-apply it.
			setCharacterHidden(true)
			return
		end
	elseif round.phase == "Runway" and round.runwayWearer then
		-- Follow the walker from the front, like a fashion-show camera.
		local root = rootOf(round.runwayWearer)
		local startPart = mapPart({ "Runway", "Start" })
		local endPart = mapPart({ "Runway", "End" })
		if root and startPart and endPart then
			camera.CameraType = Enum.CameraType.Scriptable
			local along = endPart.Position - startPart.Position
			local dir = Vector3.new(along.X, 0, along.Z).Unit
			local focus = root.Position + Vector3.new(0, 1, 0)
			local desired = CFrame.lookAt(root.Position + dir * 14 + Vector3.new(0, 4, 0), focus)
			camera.CFrame = camera.CFrame:Lerp(desired, CAMERA_LERP)
			return
		end
	end
	if round.phase == "Runway" or round.phase == "Voting" or round.phase == "Results" then
		local cameraPart = mapPart({ "Runway", "Camera" })
		local focus = stageFocus()
		if cameraPart and focus then
			camera.CameraType = Enum.CameraType.Scriptable
			local desired = CFrame.lookAt(cameraPart.Position, focus + Vector3.new(0, 1, 0))
			camera.CFrame = camera.CFrame:Lerp(desired, CAMERA_LERP)
			return
		end
	end

	if camera.CameraType ~= Enum.CameraType.Custom then
		camera.CameraType = Enum.CameraType.Custom
		local character = State.player.Character
		local humanoid = if character then character:FindFirstChildOfClass("Humanoid") else nil
		if humanoid then
			camera.CameraSubject = humanoid
		end
	end
end

local function shouldHideCharacter(): boolean
	local target = State.myTarget()
	-- Solo Studio test: I'm styling myself, so my mannequin is visible and my body just blocks it.
	return State.round.phase == "Styling" and target ~= nil
end

local function setResetEnabled(enabled: boolean)
	-- SetCore can fail if CoreScripts haven't loaded yet; retry a few times.
	task.spawn(function()
		for _ = 1, 10 do
			if pcall(StarterGui.SetCore, StarterGui, "ResetButtonCallback", enabled) then
				return
			end
			task.wait(0.5)
		end
	end)
end

local function onRoundChanged()
	local locked = inRound() and State.round.phase ~= "Lobby"
	if controls then
		if locked then
			controls:Disable()
		else
			controls:Enable()
		end
	end
	setResetEnabled(not locked)
	setCharacterHidden(shouldHideCharacter())
	if State.round.phase ~= "Styling" then
		orbitAngle = 0
	end
	-- Hide my own mannequin (unless I'm styling myself in a solo Studio test).
	local folder = Workspace:FindFirstChild("Mannequins")
	if folder then
		for _, model in folder:GetChildren() do
			Stage.hideIfMine(model)
		end
	end
end

function Stage.hideIfMine(model: Instance)
	local me = State.player.UserId
	if model:GetAttribute("TargetUserId") == me and State.myTarget() ~= me then
		-- Local-only change: the server and everyone else still have it.
		model.Parent = nil
	end
end

-- VIP walkers get a warm golden glow over the whole scene while they walk.
local function vipGlow()
	local effect = Instance.new("ColorCorrectionEffect")
	effect.TintColor = Color3.fromRGB(255, 235, 190)
	effect.Brightness = 0.05
	effect.Parent = Lighting
	TweenService:Create(effect, TweenInfo.new(4), { TintColor = Color3.new(1, 1, 1), Brightness = 0 }):Play()
	task.delay(4.2, function()
		effect:Destroy()
	end)
end

-- When my own walk reaches the end of the runway, strike the stylist's emote (or my signature pose).
local function poseAtEnd()
	local finish = mapPart({ "Runway", "End" })
	local character = State.player.Character
	local humanoid = if character then character:FindFirstChildOfClass("Humanoid") else nil
	local root = if character then character:FindFirstChild("HumanoidRootPart") else nil
	if not finish or not humanoid or not root or not root:IsA("BasePart") then
		return
	end
	-- Backup walk from this side too (the server normally drives the walk; this is harmless if so).
	task.wait(0.3)
	pcall(humanoid.MoveTo, humanoid, finish.Position)
	local deadline = os.clock() + 9
	while os.clock() < deadline and (root.Position - finish.Position).Magnitude > 5 do
		task.wait(0.1)
	end
	for _, emote in { "Pose", "Signature" } do
		local ok, played = pcall(humanoid.PlayEmoteAsync, humanoid, emote)
		if ok and played then
			return
		end
	end
end

function Stage.start()
	task.spawn(function()
		local playerScripts = State.player:WaitForChild("PlayerScripts")
		local ok, module = pcall(function()
			return (require :: any)(playerScripts:WaitForChild("PlayerModule"))
		end)
		if ok and module then
			controls = module:GetControls()
			onRoundChanged()
		end
	end)

	task.spawn(function()
		local folder = Workspace:WaitForChild("Mannequins")
		folder.ChildAdded:Connect(function(model)
			task.defer(Stage.hideIfMine, model)
		end)
	end)

	RunService:BindToRenderStep("StyleMyBestieCamera", Enum.RenderPriority.Camera.Value + 1, updateCamera)
	State.RoundChanged:Connect(onRoundChanged)
	Remotes.Events.RunwayEffect.OnClientEvent:Connect(function(userId: number, isVip: boolean)
		if isVip then
			vipGlow()
		end
		if userId == State.player.UserId then
			task.spawn(poseAtEnd)
		end
	end)
	onRoundChanged()
end

return Stage
