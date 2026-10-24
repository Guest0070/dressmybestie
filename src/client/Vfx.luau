--!strict
-- Shared visual-effect building blocks for every client system (Stage, HUD, Results, Voting,
-- Moments, MinigameFx). Everything here cleans itself up and stays inside fixed budgets
-- (Config.Vfx): when a budget is full the effect is skipped, never queued.
--   * Quality: phones and low graphics settings get fewer particles and no extra lights.
--   * Reduced motion (Roblox's own "Reduced Motion" setting): no travel, sweeps or pulses; effects
--     fade in place instead.
--   * Flashing (Settings > Flashing effects, Audio.flashesOn): no bright flashes or strobing.

local GuiService = game:GetService("GuiService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage.Shared.Config)
local Audio = require(script.Parent.Audio)

local Vfx = {}

local SETTINGS = Config.Vfx
local COLORS = SETTINGS.Colors
Vfx.Colors = COLORS

---------------------------------------------------------------------------------------------------
-- Comfort and quality
---------------------------------------------------------------------------------------------------

local lowQuality = false
do
	local touchOnly = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
	local ok, level = pcall(function()
		return (UserSettings():GetService("UserGameSettings") :: any).SavedQualityLevel.Value
	end)
	-- SavedQualityLevel 0 = automatic; 1-4 of 10 = a low manual setting.
	lowQuality = touchOnly or (ok and type(level) == "number" and level > 0 and level <= 4)
end

function Vfx.isLowQuality(): boolean
	return lowQuality
end

function Vfx.reducedMotion(): boolean
	local ok, on = pcall(function()
		return (GuiService :: any).ReducedMotionEnabled
	end)
	return ok and on == true
end

function Vfx.flashesAllowed(): boolean
	return Audio.flashesOn
end

-- Scale a particle count for this device.
function Vfx.count(n: number): number
	return math.max(1, math.round(n * (if lowQuality then SETTINGS.LowQualityScale else 1)))
end

---------------------------------------------------------------------------------------------------
-- 3D particles
---------------------------------------------------------------------------------------------------

export type Kind = "Sparkle" | "Heart" | "Star" | "Confetti" | "Glow"

local activeBursts = 0

-- Base look per kind; callers override any ParticleEmitter property with props.
local function baseProps(kind: Kind, color: Color3): { [string]: any }
	local props: { [string]: any } = {
		Texture = Config.textureId(kind),
		Color = ColorSequence.new(color, COLORS.Chrome),
		LightEmission = 0.7,
		Lifetime = NumberRange.new(0.7, 1.2),
		Speed = NumberRange.new(8, 16),
		SpreadAngle = Vector2.new(180, 180),
		Drag = 3,
		Acceleration = Vector3.new(0, -4, 0),
		Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.7), NumberSequenceKeypoint.new(1, 0) }),
		Transparency = NumberSequence.new(0, 1),
		Rotation = NumberRange.new(0, 360),
		RotSpeed = NumberRange.new(-90, 90),
	}
	if kind == "Confetti" then
		props.Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, COLORS.Pink),
			ColorSequenceKeypoint.new(0.33, COLORS.Cyan),
			ColorSequenceKeypoint.new(0.66, COLORS.Gold),
			ColorSequenceKeypoint.new(1, COLORS.Chrome),
		})
		props.LightEmission = 0.2
		props.Lifetime = NumberRange.new(1.6, 2.6)
		props.Speed = NumberRange.new(18, 30)
		props.SpreadAngle = Vector2.new(55, 55)
		props.Acceleration = Vector3.new(0, -22, 0)
		props.Drag = 1.5
		props.Size = NumberSequence.new(0.45)
		props.Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0),
			NumberSequenceKeypoint.new(0.8, 0),
			NumberSequenceKeypoint.new(1, 1),
		})
		props.RotSpeed = NumberRange.new(-300, 300)
		props.EmissionDirection = Enum.NormalId.Top
	elseif kind == "Heart" then
		props.Color = ColorSequence.new(color)
		props.Acceleration = Vector3.new(0, 6, 0) -- hearts float up
		props.RotSpeed = NumberRange.new(-30, 30)
		props.Rotation = NumberRange.new(-15, 15)
	elseif kind == "Glow" then
		props.Color = ColorSequence.new(color)
		props.Speed = NumberRange.new(0)
		props.Size =
			NumberSequence.new({ NumberSequenceKeypoint.new(0, 3), NumberSequenceKeypoint.new(1, 6) })
		props.LightEmission = 1
	end
	return props
end

local function apply(emitter: ParticleEmitter, props: { [string]: any })
	for key, value in props do
		(emitter :: any)[key] = value
	end
end

-- Emit `count` particles once at a world point. Returns false when the budget is full.
-- props: the ParticleEmitter properties to use.
function Vfx.emit(position: Vector3, props: { [string]: any }, count: number): boolean
	if activeBursts >= SETTINGS.MaxBursts then
		return false
	end
	activeBursts += 1
	local attachment = Instance.new("Attachment")
	attachment.WorldPosition = position
	attachment.Parent = Workspace.Terrain
	local emitter = Instance.new("ParticleEmitter")
	emitter.Enabled = false
	apply(emitter, props)
	emitter.Parent = attachment
	emitter:Emit(Vfx.count(count))
	task.delay(emitter.Lifetime.Max + 0.3, function()
		attachment:Destroy()
		activeBursts -= 1
	end)
	return true
end

-- A burst of one kind of particle; props overrides any part of the look.
function Vfx.burst(position: Vector3, kind: Kind, count: number?, color: Color3?, props: { [string]: any }?)
	local merged = baseProps(kind, color or COLORS.Cyan)
	if Vfx.reducedMotion() then
		merged.Speed = NumberRange.new(0, 2) -- appear and fade where they are
		merged.Acceleration = Vector3.zero
	end
	if props then
		for key, value in props do
			merged[key] = value
		end
	end
	return Vfx.emit(position, merged, count or 24)
end

-- A continuous emitter on a part (sparkle trail, aura) until the returned function is called or
-- `seconds` pass. Rate is scaled down on low quality.
function Vfx.attach(
	part: BasePart,
	kind: Kind,
	color: Color3?,
	rate: number?,
	seconds: number?,
	props: { [string]: any }?
): () -> ()
	local merged = baseProps(kind, color or COLORS.Cyan)
	merged.Speed = NumberRange.new(0.5, 2)
	merged.Acceleration = Vector3.new(0, 1, 0)
	merged.Lifetime = NumberRange.new(0.6, 1.1)
	merged.Size =
		NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.45), NumberSequenceKeypoint.new(1, 0) })
	merged.Rate = Vfx.count(rate or 12)
	if props then
		for key, value in props do
			merged[key] = value
		end
	end
	local emitter = Instance.new("ParticleEmitter")
	emitter.Name = "VfxAttached"
	apply(emitter, merged)
	emitter.Parent = part
	local done = false
	local function stop()
		if done then
			return
		end
		done = true
		emitter.Enabled = false
		task.delay(emitter.Lifetime.Max, function()
			emitter:Destroy()
		end)
	end
	if seconds then
		task.delay(seconds, stop)
	end
	return stop
end

-- A ribbon trail behind a moving part (e.g. the runway walker). Not drawn on low quality.
function Vfx.trail(part: BasePart, color: Color3, seconds: number?): () -> ()
	if lowQuality then
		return function() end
	end
	local a0 = Instance.new("Attachment")
	a0.Position = Vector3.new(0, 1.2, 0)
	a0.Parent = part
	local a1 = Instance.new("Attachment")
	a1.Position = Vector3.new(0, -1.6, 0)
	a1.Parent = part
	local trail = Instance.new("Trail")
	trail.Attachment0 = a0
	trail.Attachment1 = a1
	trail.Lifetime = 0.45
	trail.LightEmission = 0.8
	trail.FaceCamera = true
	trail.Color = ColorSequence.new(color, COLORS.Chrome)
	trail.Transparency = NumberSequence.new(0.55, 1)
	trail.Parent = part
	local done = false
	local function stop()
		if done then
			return
		end
		done = true
		trail.Enabled = false
		task.delay(trail.Lifetime, function()
			trail:Destroy()
			a0:Destroy()
			a1:Destroy()
		end)
	end
	if seconds then
		task.delay(seconds, stop)
	end
	return stop
end

---------------------------------------------------------------------------------------------------
-- Highlights and light beams
---------------------------------------------------------------------------------------------------

local activeHighlights = 0

-- Outline + soft fill on a model. Returns a cleanup function (no-op when over budget).
function Vfx.highlight(adornee: Instance, color: Color3, seconds: number?, shimmer: boolean?): () -> ()
	if activeHighlights >= SETTINGS.MaxHighlights then
		return function() end
	end
	activeHighlights += 1
	local h = Instance.new("Highlight")
	h.Name = "VfxHighlight"
	h.Adornee = adornee
	h.FillColor = color
	h.OutlineColor = color:Lerp(Color3.new(1, 1, 1), 0.4)
	h.FillTransparency = 0.85
	h.OutlineTransparency = 0.1
	h.DepthMode = Enum.HighlightDepthMode.Occluded
	h.Parent = adornee
	local tween: Tween? = nil
	if shimmer and not Vfx.reducedMotion() then
		-- Slow breathing fill (2 s period): a shimmer, never a flash.
		tween = TweenService:Create(
			h,
			TweenInfo.new(1, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
			{ FillTransparency = 0.6 }
		)
		tween:Play()
	end
	local done = false
	local function stop()
		if done then
			return
		end
		done = true
		if tween then
			tween:Cancel()
		end
		h:Destroy()
		activeHighlights -= 1
	end
	if seconds then
		task.delay(seconds, stop)
	end
	return stop
end

-- A fake volumetric light cone from `from` (world point) to an attachment target. FaceCamera
-- beams with a soft glow texture read as light shafts. Returns the beam and a cleanup function.
function Vfx.lightBeam(from: Vector3, target: Attachment, color: Color3, width: number?): (Beam, () -> ())
	local source = Instance.new("Attachment")
	source.WorldPosition = from
	source.Parent = Workspace.Terrain
	local beam = Instance.new("Beam")
	beam.Attachment0 = source
	beam.Attachment1 = target
	beam.FaceCamera = true
	beam.Texture = Config.textureId("Glow")
	beam.TextureMode = Enum.TextureMode.Stretch
	beam.LightEmission = 1
	beam.LightInfluence = 0
	beam.Width0 = 0.6
	beam.Width1 = width or 7
	beam.Segments = 1
	beam.Color = ColorSequence.new(color)
	beam.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.55),
		NumberSequenceKeypoint.new(1, 0.88),
	})
	beam.Parent = source
	local function stop()
		source:Destroy()
	end
	return beam, stop
end

---------------------------------------------------------------------------------------------------
-- 2D (screen) effects
---------------------------------------------------------------------------------------------------

local GLYPHS: { [string]: string } = { Sparkle = "✨", Heart = "💖", Star = "⭐", Coin = "💰" }

local layer: ScreenGui? = nil
local function uiLayer(): ScreenGui
	if layer and layer.Parent then
		return layer
	end
	local gui = Instance.new("ScreenGui")
	gui.Name = "Vfx"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.DisplayOrder = 50 -- over the HUD, under Roblox menus
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
	layer = gui
	return gui
end

local uiParticles = 0

local function centreOf(target: GuiObject | Vector2): Vector2
	if typeof(target) == "Vector2" then
		return target
	end
	local object = target :: GuiObject
	return object.AbsolutePosition + object.AbsoluteSize / 2 + GuiService:GetGuiInset()
end

-- Little particles flying out of a UI element (or a screen point). kind: Sparkle, Heart, Star,
-- Coin, or Confetti (paper bits). toward: they drift there instead of outward (reward pickup).
function Vfx.uiBurst(target: GuiObject | Vector2, kind: string, count: number?, toward: Vector2?)
	local origin = centreOf(target)
	local gui = uiLayer()
	local reduced = Vfx.reducedMotion()
	local n = math.min(Vfx.count(count or 10), SETTINGS.MaxUiParticles - uiParticles)
	for i = 1, n do
		uiParticles += 1
		local piece: GuiObject
		if kind == "Confetti" then
			local palette = { COLORS.Pink, COLORS.Cyan, COLORS.Gold, COLORS.Chrome, COLORS.Violet }
			piece = Instance.new("Frame")
			piece.BackgroundColor3 = palette[(i - 1) % #palette + 1]
			piece.BorderSizePixel = 0
			piece.Size = UDim2.fromOffset(8, 14)
			piece.Rotation = math.random(0, 360)
		else
			local label = Instance.new("TextLabel")
			label.BackgroundTransparency = 1
			label.Text = GLYPHS[kind] or GLYPHS.Sparkle
			label.TextScaled = true
			label.Size = UDim2.fromOffset(22, 22)
			piece = label
		end
		piece.AnchorPoint = Vector2.new(0.5, 0.5)
		piece.Position = UDim2.fromOffset(origin.X, origin.Y)
		piece.ZIndex = 5
		piece.Parent = gui
		local angle = math.random() * math.pi * 2
		local distance = 40 + math.random() * 70
		local goal = if toward
			then toward + Vector2.new(math.random(-10, 10), math.random(-10, 10))
			else origin + Vector2.new(math.cos(angle), math.sin(angle)) * distance
		if reduced then
			goal = origin + (goal - origin) * 0.15
		end
		local time = if toward then 0.55 + i * 0.03 else 0.5 + math.random() * 0.3
		local props: { [string]: any } = { Position = UDim2.fromOffset(goal.X, goal.Y) }
		if kind == "Confetti" then
			props.BackgroundTransparency = 1
			props.Rotation = piece.Rotation + math.random(-180, 180)
		else
			props.TextTransparency = 1
		end
		local tween = TweenService:Create(
			piece,
			TweenInfo.new(
				time,
				if toward then Enum.EasingStyle.Quad else Enum.EasingStyle.Quint,
				Enum.EasingDirection.Out
			),
			props
		)
		tween.Completed:Once(function()
			piece:Destroy()
			uiParticles -= 1
		end)
		tween:Play()
	end
end

-- Screen-space confetti falling from the top for a few seconds (bounded by MaxUiParticles).
function Vfx.uiConfetti(seconds: number)
	if Vfx.reducedMotion() then
		return
	end
	local gui = uiLayer()
	local palette = { COLORS.Pink, COLORS.Cyan, COLORS.Gold, COLORS.Chrome, COLORS.Violet }
	local width = gui.AbsoluteSize.X
	local height = gui.AbsoluteSize.Y
	local total = Vfx.count(math.floor(seconds * 18))
	task.spawn(function()
		for i = 1, total do
			if uiParticles < SETTINGS.MaxUiParticles then
				uiParticles += 1
				local piece = Instance.new("Frame")
				piece.BackgroundColor3 = palette[(i - 1) % #palette + 1]
				piece.BorderSizePixel = 0
				piece.AnchorPoint = Vector2.new(0.5, 0.5)
				piece.Size = UDim2.fromOffset(math.random(6, 10), math.random(10, 16))
				piece.Rotation = math.random(0, 360)
				local x = math.random() * width
				piece.Position = UDim2.fromOffset(x, -20)
				piece.Parent = gui
				local tween =
					TweenService:Create(piece, TweenInfo.new(2 + math.random(), Enum.EasingStyle.Linear), {
						Position = UDim2.fromOffset(x + math.random(-80, 80), height + 20),
						Rotation = piece.Rotation + math.random(-360, 360),
					})
				tween.Completed:Once(function()
					piece:Destroy()
					uiParticles -= 1
				end)
				tween:Play()
			end
			task.wait(seconds / total)
		end
	end)
end

-- Soft coloured glow around the screen edges that fades out (timer warnings, time up).
-- Strength is kept low and it never strobes; without flashing effects it is gentler still.
local edge: Frame? = nil
function Vfx.edgePulse(color: Color3, strength: number?)
	local gui = uiLayer()
	if not edge or not edge.Parent then
		local frame = Instance.new("Frame")
		frame.Name = "EdgePulse"
		frame.BackgroundTransparency = 1
		frame.Size = UDim2.fromScale(1, 1)
		frame.ZIndex = 1
		for _, side in { "Top", "Bottom", "Left", "Right" } do
			local strip = Instance.new("Frame")
			strip.Name = side
			strip.BorderSizePixel = 0
			strip.BackgroundColor3 = Color3.new(1, 1, 1)
			strip.BackgroundTransparency = 1
			local vertical = side == "Left" or side == "Right"
			strip.Size = if vertical then UDim2.fromScale(0.12, 1) else UDim2.fromScale(1, 0.12)
			strip.Position = if side == "Bottom"
				then UDim2.fromScale(0, 0.88)
				elseif side == "Right" then UDim2.fromScale(0.88, 0)
				else UDim2.fromScale(0, 0)
			local gradient = Instance.new("UIGradient")
			gradient.Rotation = if side == "Top"
				then 90
				elseif side == "Bottom" then -90
				elseif side == "Left" then 0
				else 180
			gradient.Transparency = NumberSequence.new(0, 1)
			gradient.Parent = strip
			strip.Parent = frame
		end
		frame.Parent = gui
		edge = frame
	end
	local peak = 1 - math.clamp((strength or 0.35) * (if Vfx.flashesAllowed() then 1 else 0.5), 0, 0.6)
	for _, strip in (edge :: Frame):GetChildren() do
		if strip:IsA("Frame") then
			strip.BackgroundColor3 = color
			strip.BackgroundTransparency = peak
			TweenService
				:Create(strip, TweenInfo.new(0.8, Enum.EasingStyle.Quad), { BackgroundTransparency = 1 })
				:Play()
		end
	end
end

-- Full-screen fade used to cover teleports (lobby -> booth, results -> lobby).
local cover: Frame? = nil
function Vfx.transition(hold: number?)
	local gui = uiLayer()
	if not cover or not cover.Parent then
		local frame = Instance.new("Frame")
		frame.Name = "Transition"
		frame.BackgroundColor3 = Color3.fromRGB(20, 13, 31)
		frame.BorderSizePixel = 0
		frame.BackgroundTransparency = 1
		frame.Size = UDim2.fromScale(1, 1)
		frame.ZIndex = 10
		local gradient = Instance.new("UIGradient")
		gradient.Color = ColorSequence.new(Color3.fromRGB(20, 13, 31), Color3.fromRGB(40, 24, 60))
		gradient.Rotation = 90
		gradient.Parent = frame
		frame.Parent = gui
		cover = frame
	end
	local frame = cover :: Frame
	local fade = if Vfx.reducedMotion() then 0.12 else 0.25
	TweenService:Create(frame, TweenInfo.new(fade), { BackgroundTransparency = 0 }):Play()
	task.delay(fade + (hold or 0.35), function()
		TweenService:Create(frame, TweenInfo.new(fade * 1.6), { BackgroundTransparency = 1 }):Play()
	end)
end

-- A chrome sheen sweeping once across a UI element (reveal cards, rare items): a translucent
-- band on an overlay, so the element's own colours are untouched.
function Vfx.shimmer(object: GuiObject)
	if Vfx.reducedMotion() then
		return
	end
	local overlay = Instance.new("Frame")
	overlay.Name = "VfxShimmer"
	overlay.BackgroundColor3 = COLORS.Chrome
	overlay.BorderSizePixel = 0
	overlay.Size = UDim2.fromScale(1, 1)
	overlay.ZIndex = object.ZIndex + 1
	local corner = object:FindFirstChildOfClass("UICorner")
	if corner then
		corner:Clone().Parent = overlay
	end
	local gradient = Instance.new("UIGradient")
	gradient.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1),
		NumberSequenceKeypoint.new(0.42, 1),
		NumberSequenceKeypoint.new(0.5, 0.55),
		NumberSequenceKeypoint.new(0.58, 1),
		NumberSequenceKeypoint.new(1, 1),
	})
	gradient.Rotation = 20
	gradient.Offset = Vector2.new(-1, 0)
	gradient.Parent = overlay
	overlay.Parent = object
	local tween = TweenService:Create(
		gradient,
		TweenInfo.new(0.9, Enum.EasingStyle.Quad),
		{ Offset = Vector2.new(1, 0) }
	)
	tween.Completed:Once(function()
		overlay:Destroy()
	end)
	tween:Play()
end

-- Pop-in scale for a UI element (reveal cards).
function Vfx.pop(object: GuiObject)
	local scale = object:FindFirstChildOfClass("UIScale") or Instance.new("UIScale")
	scale.Parent = object
	if Vfx.reducedMotion() then
		scale.Scale = 1
		return
	end
	scale.Scale = 0.6
	TweenService:Create(scale, TweenInfo.new(0.35, Enum.EasingStyle.Back), { Scale = 1 }):Play()
end

-- For tests and the admin panel: what is alive right now.
function Vfx.stats(): { bursts: number, highlights: number, uiParticles: number }
	return { bursts = activeBursts, highlights = activeHighlights, uiParticles = uiParticles }
end

return Vfx
