--!strict
-- Everything that makes the lobby minigames feel alive, on this client only:
--   * effects the server sends (MinigameFx): sounds, bursts, winner fireworks, being flung by
--     the Spin Sweep arm, paparazzi flashes, Runway Dash timer events
--   * animations driven by tags/attributes the server sets: Color Rush tiles blinking and
--     dropping, Runway Dash tiles vanishing, the disco floor, disco ball and stage lights,
--     the Spin Sweep hub
--   * a dance beat near Freeze Frame while it's DANCE time, a whoosh when an arm passes close,
--     and the Runway Dash jump pad
-- The server decides who's out; nothing here affects the game's outcome.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Audio = require(script.Parent.Audio)
local State = require(script.Parent.State)

local MinigameFx = {}

-- Set by init.client: Runway Dash timer events go to the minigame banner.
MinigameFx.onDash = function(_fx: { [string]: any }) end

local SOUNDS = {
	Beat = "rbxasset://sounds/bass.wav",
	HiHat = "rbxasset://sounds/clickfast.wav",
	Whoosh = "rbxasset://sounds/swordslash.wav",
	Launch = "rbxasset://sounds/Launching rocket.wav",
	Flash = "rbxasset://sounds/flashbulb.wav",
	Boom = "rbxasset://sounds/impact_explosion_03.mp3",
	Pop = "rbxasset://sounds/snap.mp3",
}
local PARTY = {
	Color3.fromRGB(255, 79, 163),
	Color3.fromRGB(70, 220, 255),
	Color3.fromRGB(255, 201, 74),
	Color3.fromRGB(165, 90, 255),
	Color3.fromRGB(70, 220, 120),
}
local ICE = Color3.fromRGB(190, 240, 255)
local IDLE_FLASH = Color3.fromRGB(90, 90, 110)

local player = Players.LocalPlayer
local flashOverlay: Frame

local function root(): BasePart?
	local character = player.Character
	local r = if character then character:FindFirstChild("HumanoidRootPart") else nil
	return if r and r:IsA("BasePart") then r else nil
end

---------------------------------------------------------------------------------------------------
-- Building blocks
---------------------------------------------------------------------------------------------------

local function sfxGroup(): SoundGroup?
	local group = SoundService:FindFirstChild("SFX")
	return if group and group:IsA("SoundGroup") then group else nil
end

-- A one-shot sound, at a point in the world (3D) or flat (2D).
local function play(id: string, position: Vector3?, volume: number?, pitch: number?)
	local sound = Instance.new("Sound")
	sound.SoundId = id
	sound.Volume = volume or 0.6
	sound.PlaybackSpeed = pitch or 1
	sound.SoundGroup = sfxGroup()
	if position then
		local attachment = Instance.new("Attachment")
		attachment.WorldPosition = position
		attachment.Parent = Workspace.Terrain
		sound.RollOffMinDistance = 20
		sound.RollOffMaxDistance = 160
		sound.Parent = attachment
		sound.Ended:Once(function()
			attachment:Destroy()
		end)
		task.delay(12, function()
			attachment:Destroy()
		end)
	else
		sound.Parent = SoundService
		sound.Ended:Once(function()
			sound:Destroy()
		end)
	end
	sound:Play()
end

local function emitter(color: Color3, props: { [string]: any }?): ParticleEmitter
	local e = Instance.new("ParticleEmitter")
	e.Enabled = false
	e.Color = ColorSequence.new(color, Color3.new(1, 1, 1))
	e.LightEmission = 0.8
	e.Lifetime = NumberRange.new(0.6, 1.1)
	e.Speed = NumberRange.new(18, 30)
	e.SpreadAngle = Vector2.new(180, 180)
	e.Acceleration = Vector3.new(0, -30, 0)
	e.Drag = 2
	e.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.6), NumberSequenceKeypoint.new(1, 0) })
	e.Transparency = NumberSequence.new(0, 1)
	if props then
		for key, value in props do
			(e :: any)[key] = value
		end
	end
	return e
end

local function burst(position: Vector3, color: Color3, count: number?, props: { [string]: any }?)
	local attachment = Instance.new("Attachment")
	attachment.WorldPosition = position
	attachment.Parent = Workspace.Terrain
	local e = emitter(color, props)
	e.Parent = attachment
	e:Emit(count or 40)
	task.delay(3, function()
		attachment:Destroy()
	end)
end

-- Winner fireworks: rockets up, bursts in party colours, confetti.
local function celebrate(position: Vector3, color: Color3)
	burst(position + Vector3.new(0, 2, 0), color, 60, {
		Speed = NumberRange.new(10, 22),
		Lifetime = NumberRange.new(1.2, 2),
		Rotation = NumberRange.new(0, 360),
		RotSpeed = NumberRange.new(-200, 200),
		Size = NumberSequence.new(0.4),
	})
	for i = 1, 5 do
		task.delay(i * 0.25, function()
			local offset = Vector3.new(math.random(-8, 8), 18 + math.random() * 10, math.random(-8, 8))
			burst(position + offset, PARTY[(i - 1) % #PARTY + 1], 70, {
				Speed = NumberRange.new(16, 26),
				Acceleration = Vector3.new(0, -12, 0),
				Lifetime = NumberRange.new(0.9, 1.4),
			})
			play(SOUNDS.Boom, position + offset, 0.25, 1.2 + math.random() * 0.3)
		end)
	end
end

local function screenFlash(color: Color3, strength: number)
	if not Audio.flashesOn then
		return -- Settings > Flashing effects
	end
	flashOverlay.BackgroundColor3 = color
	flashOverlay.BackgroundTransparency = 1 - strength
	TweenService
		:Create(flashOverlay, TweenInfo.new(0.35, Enum.EasingStyle.Quad), { BackgroundTransparency = 1 })
		:Play()
end

-- Paparazzi: every camera flash near the point fires, with the bulb sound.
local function paparazzi(position: Vector3, quiet: boolean?)
	for _, flash in CollectionService:GetTagged("PapFlash") do
		if not Audio.flashesOn then
			break -- Settings > Flashing effects: the shutter sound only
		end
		if
			flash:IsA("BasePart")
			and (flash.Position - position).Magnitude < 60
			and (not quiet or math.random() < 0.4)
		then
			task.delay(math.random() * (if quiet then 0.3 else 0.12), function()
				flash.Color = Color3.new(1, 1, 1)
				local light = Instance.new("PointLight")
				light.Range = 18
				light.Brightness = 6
				light.Parent = flash
				task.delay(0.12, function()
					flash.Color = IDLE_FLASH
					light:Destroy()
				end)
			end)
		end
	end
	play(SOUNDS.Flash, position, if quiet then 0.35 else 0.9, 0.95 + math.random() * 0.15)
	local r = root()
	if not quiet and r and (r.Position - position).Magnitude < 45 then
		screenFlash(Color3.new(1, 1, 1), 0.55)
	end
end

-- Launch the local character. tumble: hand it to physics for a moment (a real "you got hit"
-- throw: walking control would otherwise brake it within a few studs).
local function knock(velocity: Vector3, tumble: boolean?)
	local character = player.Character
	local humanoid = if character then character:FindFirstChildOfClass("Humanoid") else nil
	local r = root()
	if not humanoid or not r then
		return
	end
	if tumble then
		humanoid.PlatformStand = true
		r.AssemblyAngularVelocity = Vector3.new(math.random(-6, 6), math.random(-6, 6), math.random(-6, 6))
		task.delay(0.9, function()
			humanoid.PlatformStand = false
			humanoid:ChangeState(Enum.HumanoidStateType.GettingUp)
		end)
	else
		humanoid:ChangeState(Enum.HumanoidStateType.Freefall)
	end
	r.AssemblyLinearVelocity = velocity
	screenFlash(Color3.fromRGB(255, 120, 80), 0.35)
	-- A quick shake.
	task.spawn(function()
		for i = 1, 8 do
			humanoid.CameraOffset = Vector3.new(math.random() - 0.5, math.random() - 0.5, 0)
				* (1.2 - i * 0.14)
			task.wait(0.03)
		end
		humanoid.CameraOffset = Vector3.zero
	end)
end

---------------------------------------------------------------------------------------------------
-- Tagged animations
---------------------------------------------------------------------------------------------------

-- A tile that blinks while Warn is set and drops away while Gone is set (Color Rush, Runway Dash).
local function animateTile(tile: BasePart)
	local fullSize = tile.Size
	local glow = tile:FindFirstChild("TileGlow")
	local glowSize = if glow and glow:IsA("BasePart") then glow.Size else nil
	local glowTransparency = if glow and glow:IsA("BasePart") then glow.Transparency else 0
	local baseTransparency = tile.Transparency
	local blinkToken = 0
	local function setLook(transparency: number, scale: number, animate: boolean)
		local info =
			TweenInfo.new(if animate then 0.25 else 0, Enum.EasingStyle.Back, Enum.EasingDirection.In)
		TweenService:Create(tile, info, {
			Transparency = transparency,
			Size = Vector3.new(fullSize.X * scale, fullSize.Y, fullSize.Z * scale),
		}):Play()
		if glow and glow:IsA("BasePart") and glowSize then
			TweenService:Create(glow, info, {
				Transparency = if transparency >= 1 then 1 else glowTransparency,
				Size = Vector3.new(glowSize.X * scale, glowSize.Y, glowSize.Z * scale),
			}):Play()
		end
	end
	local function refresh()
		blinkToken += 1
		local token = blinkToken
		if tile:GetAttribute("Gone") == true then
			setLook(1, 0.2, true)
		elseif tile:GetAttribute("Warn") == true then
			setLook(baseTransparency, 1, false)
			task.spawn(function()
				local on = false
				while token == blinkToken do
					on = not on
					tile.Transparency = if on then 0.65 else baseTransparency
					if glow and glow:IsA("BasePart") then
						glow.Transparency = if on then 0.9 else glowTransparency
					end
					task.wait(0.09)
				end
			end)
		else
			-- Pop back in.
			tile.Size = Vector3.new(fullSize.X * 0.6, fullSize.Y, fullSize.Z * 0.6)
			local info = TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
			TweenService:Create(tile, info, { Size = fullSize, Transparency = baseTransparency }):Play()
			if glow and glow:IsA("BasePart") and glowSize then
				TweenService:Create(glow, info, { Size = glowSize, Transparency = glowTransparency }):Play()
			end
		end
	end
	tile:GetAttributeChangedSignal("Gone"):Connect(refresh)
	tile:GetAttributeChangedSignal("Warn"):Connect(refresh)
	if tile:GetAttribute("Gone") == true then
		setLook(1, 0.2, false)
	end
end

local function freezeState(): (boolean, boolean, Vector3?)
	local game_ = State.minigames.FreezeFrame
	if not game_ then
		return false, false, nil
	end
	local dancing = game_.phase == "Playing"
		and (game_.headline == "DANCE!" or game_.headline:find("STYLE") ~= nil)
	local frozen = game_.phase == "Playing" and not dancing
	return dancing, frozen, game_.center
end

-- Disco floor, ball, stage lights, sweep hubs and the Freeze Frame beat.
local function startLoops()
	local beatClock = 0
	local beatStep = 0
	local lastWhoosh = 0
	local lastLaunch = 0
	RunService.RenderStepped:Connect(function(dt)
		local dancing, frozen, stageCenter = freezeState()
		local r = root()
		-- The beat: on the beat a new colour for every disco tile; kick + hi-hat when you're near.
		beatClock += dt
		local beatLength = if dancing then 0.45 else 0.9
		if beatClock >= beatLength then
			beatClock = 0
			beatStep += 1
			local near = r and stageCenter and (r.Position - stageCenter).Magnitude < 70
			if dancing and near then
				play(SOUNDS.Beat, nil, 0.35, if beatStep % 4 == 0 then 0.75 else 0.85)
			end
			for _, tile in CollectionService:GetTagged("DiscoTile") do
				if tile:IsA("BasePart") then
					tile.Color = if frozen
						then ICE
						elseif dancing then PARTY[math.random(#PARTY)]
						else Color3.fromRGB(30, 24, 42)
							:Lerp(PARTY[1], (math.sin(os.clock() + tile.Position.X) + 1) * 0.15)
					tile.Material = if dancing or frozen
						then Enum.Material.Neon
						else Enum.Material.SmoothPlastic
				end
			end
			for _, lamp in CollectionService:GetTagged("StageLight") do
				if lamp:IsA("BasePart") then
					local color = if frozen then ICE else PARTY[(beatStep + #lamp.Name) % #PARTY + 1]
					lamp.Color = color
					local spot = lamp:FindFirstChildOfClass("SpotLight")
					if spot then
						spot.Color = color
					end
				end
			end
		elseif dancing and beatClock >= beatLength / 2 and beatClock - dt < beatLength / 2 then
			local near = r and stageCenter and (r.Position - stageCenter).Magnitude < 70
			if near then
				play(SOUNDS.HiHat, nil, 0.25, 1.1)
			end
		end
		for _, ball in CollectionService:GetTagged("DiscoBall") do
			if ball:IsA("BasePart") then
				ball.CFrame *= CFrame.Angles(0, dt * (if dancing then 2.5 else 0.6), 0)
			end
		end
		for _, cap in CollectionService:GetTagged("SweepCap") do
			if cap:IsA("BasePart") then
				cap.CFrame *= CFrame.Angles(dt * 3, 0, 0) -- it lies along X (cylinder)
				cap.Color = Color3.fromHSV((os.clock() * 0.2) % 1, 0.6, 1)
			end
		end

		if not r then
			return
		end
		-- Whoosh when a sweeping arm passes close by.
		if os.clock() - lastWhoosh > 0.35 then
			for _, arm in CollectionService:GetTagged("SweepArm") do
				if arm:IsA("BasePart") and arm.Transparency < 1 then
					local rel = r.Position - arm.Position
					local flat = Vector3.new(rel.X, 0, rel.Z)
					if flat.Magnitude < arm.Size.Z / 2 and math.abs(rel.Y) < 6 then
						local dir = arm.CFrame.LookVector
						dir = Vector3.new(dir.X, 0, dir.Z).Unit
						local across = (flat - dir * flat:Dot(dir)).Magnitude
						if across < 3 then
							lastWhoosh = os.clock()
							play(SOUNDS.Whoosh, r.Position, 0.5, 0.9 + math.random() * 0.3)
							break
						end
					end
				end
			end
		end
		-- Jump pads: stand on one and you're launched.
		if os.clock() - lastLaunch > 1 then
			for _, pad in CollectionService:GetTagged("LaunchPad") do
				if pad:IsA("BasePart") then
					local rel = pad.CFrame:PointToObjectSpace(r.Position)
					if
						math.abs(rel.X) <= pad.Size.X / 2
						and math.abs(rel.Z) <= pad.Size.Z / 2
						and rel.Y > 0
						and rel.Y < 4
					then
						lastLaunch = os.clock()
						local velocity = pad:GetAttribute("Velocity")
						if typeof(velocity) == "Vector3" then
							knock(velocity)
							play(SOUNDS.Launch, r.Position, 0.6, 1.3)
							burst(pad.Position + Vector3.new(0, 1, 0), Color3.fromRGB(255, 201, 74), 30)
						end
					end
				end
			end
		end
	end)
end

---------------------------------------------------------------------------------------------------
-- Start
---------------------------------------------------------------------------------------------------

function MinigameFx.start()
	local gui = Instance.new("ScreenGui")
	gui.Name = "MinigameFlash"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.DisplayOrder = 50
	gui.Parent = player:WaitForChild("PlayerGui")
	flashOverlay = Instance.new("Frame")
	flashOverlay.Size = UDim2.fromScale(1, 1)
	flashOverlay.BackgroundColor3 = Color3.new(1, 1, 1)
	flashOverlay.BackgroundTransparency = 1
	flashOverlay.BorderSizePixel = 0
	flashOverlay.Active = false
	flashOverlay.Parent = gui

	for _, tag in { "ColorRushTile", "DashVanish" } do
		for _, tile in CollectionService:GetTagged(tag) do
			if tile:IsA("BasePart") then
				animateTile(tile)
			end
		end
		CollectionService:GetInstanceAddedSignal(tag):Connect(function(tile)
			if tile:IsA("BasePart") then
				animateTile(tile)
			end
		end)
	end

	Remotes.Events.MinigameFx.OnClientEvent:Connect(function(fx: { [string]: any })
		local kind = fx.kind
		if kind == "sound" then
			play(fx.id, fx.position, fx.volume, fx.pitch)
		elseif kind == "burst" then
			burst(fx.position, fx.color or PARTY[1], fx.count)
		elseif kind == "celebrate" then
			celebrate(fx.position, fx.color or PARTY[3])
		elseif kind == "knock" then
			knock(fx.velocity, fx.tumble ~= false)
		elseif kind == "paparazzi" then
			paparazzi(fx.position, fx.quiet)
		elseif kind == "dash" then
			MinigameFx.onDash(fx)
			if fx.action == "finish" then
				screenFlash(Color3.fromRGB(255, 201, 74), 0.4)
			elseif fx.action == "split" then
				play(SOUNDS.Pop, nil, 0.6, 1.3)
			end
		end
	end)
	startLoops()
end

return MinigameFx
