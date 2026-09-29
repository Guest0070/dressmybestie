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

-- Runway cinematic. t = seconds since this walker started; pos = walker; dir = walk direction.
-- Returns the camera CFrame, field of view and how fast to blend towards them.
local shotWearer: number? = nil
local shotStart = 0
local function cinematicShot(t: number, pos: Vector3, dir: Vector3): (CFrame, number, number)
	local chest = pos + Vector3.new(0, 1, 0)
	if t < 3 then
		-- 1. Wide tracking shot from the front as they start walking.
		return CFrame.lookAt(pos + dir * 16 + Vector3.new(0, 5, 0), chest), 70, CAMERA_LERP
	elseif t < 5.5 then
		-- 2. Orbit around the look.
		local angle = (t - 3) * 1.3
		local around = CFrame.Angles(0, angle, 0):VectorToWorldSpace(dir) * 9
		return CFrame.lookAt(pos + around + Vector3.new(0, 3, 0), chest), 60, CAMERA_LERP * 1.5
	elseif t < 7 then
		-- 3. Low hero angle, looking up.
		return CFrame.lookAt(pos + dir * 7 + Vector3.new(0, -1.5, 0), pos + Vector3.new(0, 2, 0)),
			65,
			CAMERA_LERP * 1.5
	end
	-- 4. Close-up for the pose at the end.
	return CFrame.lookAt(pos + dir * 6 + Vector3.new(0, 2.2, 0), pos + Vector3.new(0, 1.8, 0)),
		40,
		CAMERA_LERP
end

local function updateCamera()
	local camera = Workspace.CurrentCamera
	if not camera then
		return
	end
	local round = State.round
	local target = State.myTarget()

	-- Dressing Room: frame my own character like a mannequin in a booth.
	local dressingRoot = if State.dressingRoom and State.player.Character
		then State.player.Character:FindFirstChild("HumanoidRootPart")
		else nil
	if dressingRoot and dressingRoot:IsA("BasePart") then
		camera.CameraType = Enum.CameraType.Scriptable
		local pivot = dressingRoot.CFrame
		local look = (CFrame.Angles(0, orbitAngle, 0) * pivot).LookVector
		local dir = Vector3.new(look.X, 0, look.Z).Unit
		local cameraPos = pivot.Position + dir * ORBIT_DISTANCE + Vector3.new(0, CAMERA_RAISE, 0)
		local level = CFrame.lookAt(cameraPos, cameraPos - dir)
		local viewport = camera.ViewportSize
		local aspect = viewport.X / math.max(viewport.Y, 1)
		local halfFov = math.rad(camera.FieldOfView) / 2
		local yaw = math.atan(0.5 * math.tan(halfFov) * aspect)
		camera.CFrame = camera.CFrame:Lerp(level * CFrame.Angles(0, -yaw, 0), CAMERA_LERP * 2)
		return
	end

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
		-- Cinematic: a sequence of shots per walker (see cinematicShot).
		local root = rootOf(round.runwayWearer)
		local startPart = mapPart({ "Runway", "Start" })
		local endPart = mapPart({ "Runway", "End" })
		if root and startPart and endPart then
			camera.CameraType = Enum.CameraType.Scriptable
			if round.runwayWearer ~= shotWearer then
				shotWearer = round.runwayWearer
				shotStart = os.clock()
			end
			local along = endPart.Position - startPart.Position
			local dir = Vector3.new(along.X, 0, along.Z).Unit
			local desired, fov, speed = cinematicShot(os.clock() - shotStart, root.Position, dir)
			camera.CFrame = camera.CFrame:Lerp(desired, speed)
			camera.FieldOfView += (fov - camera.FieldOfView) * speed
			return
		end
	end
	if camera.FieldOfView ~= 70 then
		camera.FieldOfView = 70 -- the runway close-up zooms in; reset for every other shot
	end
	if round.phase == "Results" then
		-- Close shot of the podium (winners face +Z, towards this camera). Aim a little to the
		-- right so the podium sits left of the results panel in the bottom-right corner.
		local first = mapPart({ "Podium", "First" })
		if first then
			camera.CameraType = Enum.CameraType.Scriptable
			local facing = first.CFrame.LookVector
			local focus = first.Position + Vector3.new(0, -2, 0) + first.CFrame.RightVector * -4
			local desired = CFrame.lookAt(first.Position + facing * 22 + Vector3.new(0, 2, 0), focus)
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

-- Screen effects in Lighting (Bloom, ColorGrading, ...) are switched off while styling and put
-- back afterwards. They can wash a bright scene out to white; the booth needs true colours.
local POST_EFFECT_CLASSES = {
	"BloomEffect",
	"ColorGradingEffect",
	"ColorCorrectionEffect",
	"SunRaysEffect",
	"DepthOfFieldEffect",
	"BlurEffect",
}
local disabledEffects: { Instance } = {}

local function setPostEffectsSuspended(suspended: boolean)
	if suspended then
		for _, effect in Lighting:GetChildren() do
			if table.find(POST_EFFECT_CLASSES, effect.ClassName) and (effect :: any).Enabled then
				(effect :: any).Enabled = false
				table.insert(disabledEffects, effect)
			end
		end
	else
		for _, effect in disabledEffects do
			if effect.Parent then
				(effect :: any).Enabled = true
			end
		end
		disabledEffects = {}
	end
end

local function onRoundChanged()
	local locked = (inRound() and State.round.phase ~= "Lobby") or State.dressingRoom
	if controls then
		if locked then
			controls:Disable()
		else
			controls:Enable()
		end
	end
	setResetEnabled(not locked)
	setCharacterHidden(shouldHideCharacter())
	setPostEffectsSuspended(State.round.phase == "Styling")
	if State.round.phase ~= "Styling" and not State.dressingRoom then
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

-- Paparazzi: quick camera flashes along both sides of the runway while someone walks.
local function flashLoop()
	while true do
		task.wait(0.12 + math.random() * 0.25)
		if State.round.phase ~= "Runway" or not State.round.runwayWearer then
			continue
		end
		local startPart = mapPart({ "Runway", "Start" })
		local endPart = mapPart({ "Runway", "End" })
		if not startPart or not endPart then
			continue
		end
		local along = startPart.Position:Lerp(endPart.Position, math.random())
		local side = if math.random() < 0.5 then -1 else 1
		local flash = Instance.new("Part")
		flash.Anchored = true
		flash.CanCollide = false
		flash.CanQuery = false
		flash.CanTouch = false
		flash.Transparency = 1
		flash.Size = Vector3.new(0.5, 0.5, 0.5)
		flash.Position = Vector3.new(along.X + side * 14, along.Y + 2 + math.random() * 3, along.Z)
		local light = Instance.new("PointLight")
		light.Brightness = 6
		light.Range = 16
		light.Parent = flash
		local sparkle = Instance.new("ParticleEmitter")
		sparkle.Rate = 0
		sparkle.Lifetime = NumberRange.new(0.08)
		sparkle.Size = NumberSequence.new(2.5)
		sparkle.LightEmission = 1
		sparkle.Parent = flash
		flash.Parent = Workspace
		sparkle:Emit(1)
		task.delay(0.08, function()
			flash:Destroy()
		end)
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
local function poseAtEnd(poseAnimationId: number)
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
	-- Equipped runway pose (bought in the shop): play it on my own character (it replicates).
	local animator = humanoid:FindFirstChildOfClass("Animator")
	if poseAnimationId > 0 and animator then
		local animation = Instance.new("Animation")
		animation.AnimationId = `rbxassetid://{poseAnimationId}`
		local ok, track = pcall(animator.LoadAnimation, animator, animation)
		if ok and track then
			track.Priority = Enum.AnimationPriority.Action
			track:Play()
			task.delay(3, function()
				track:Stop(0.3)
			end)
			return
		end
	end
	-- Otherwise the emote the stylist picked for this look, if any.
	pcall(humanoid.PlayEmoteAsync, humanoid, "Pose")
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

	task.spawn(flashLoop)
	RunService:BindToRenderStep("StyleMyBestieCamera", Enum.RenderPriority.Camera.Value + 1, updateCamera)
	State.RoundChanged:Connect(onRoundChanged)
	State.DressingRoomChanged:Connect(onRoundChanged)
	Remotes.Events.RunwayEffect.OnClientEvent:Connect(
		function(userId: number, isVip: boolean, poseId: number?)
			if isVip then
				vipGlow()
			end
			if userId == State.player.UserId then
				task.spawn(poseAtEnd, poseId or 0)
			end
		end
	)
	onRoundChanged()
end

return Stage
