--!strict
-- Spin Sweep: a sparking neon arm sweeps a round platform. Jump it! Get hit and you're FLUNG off.
-- It speeds up, a second arm joins at 22s (a cross), and from 12s random events hit:
--   REVERSE!  the arm stops and spins the other way (after a one-second warning)
--   SURGE!    it nearly doubles its speed for three seconds
-- Survive 60 seconds (solo) or be the last one on.
--
-- The arms are physics parts turned by a motor (smooth for every client) with no collisions:
-- who got hit is worked out on the server from the arm's angle and the player's feet height.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Arena = require(script.Parent.Arena)

local C = Arena.Colors
local S = Arena.Sounds

local SpinSweep = {}

function SpinSweep.build(parent: Instance): Arena.Game
	local ss = Config.Minigames.SpinSweep
	local model = Instance.new("Model")
	model.Name = "SpinSweep"
	local center = ss.Center
	local radius = ss.Radius
	local top = 1

	-- Platform: black marble, champagne rim, neon edge and radial LED spokes.
	Arena.disc(
		model,
		"Platform",
		1,
		radius * 2,
		center + Vector3.new(0, top - 0.5, 0),
		C.Black,
		Enum.Material.Marble
	)
	local rim = Arena.disc(
		model,
		"Rim",
		0.9,
		radius * 2 + 1.2,
		center + Vector3.new(0, top - 0.55, 0),
		C.Champagne,
		Enum.Material.Metal
	)
	rim.CanCollide = false
	local edge = Arena.disc(
		model,
		"Edge",
		0.3,
		radius * 2 + 2.2,
		center + Vector3.new(0, 0.15, 0),
		C.Cyan,
		Enum.Material.Neon
	)
	edge.CanCollide = false
	for k = 0, 7 do
		local angle = k * math.pi / 4
		local dir = Vector3.new(math.cos(angle), 0, math.sin(angle))
		Arena.glow(
			model,
			"Spoke",
			Vector3.new(0.25, 0.05, radius - 3),
			CFrame.lookAt(
				center + dir * (radius / 2 + 1.5) + Vector3.new(0, top + 0.03, 0),
				center + Vector3.new(0, top + 0.03, 0)
			),
			C.Purple
		)
	end
	-- Hub in the middle (you can't stand on it) with a glowing, spinning cap.
	local hubDiameter = 3.2
	Arena.disc(
		model,
		"Hub",
		4.5,
		hubDiameter,
		center + Vector3.new(0, top + 2.25, 0),
		C.Black,
		Enum.Material.Marble
	)
	local cap = Arena.disc(
		model,
		"HubCap",
		0.6,
		hubDiameter + 0.4,
		center + Vector3.new(0, top + 4.8, 0),
		C.Cyan,
		Enum.Material.Neon
	)
	cap.CanCollide = false
	cap:AddTag("SweepCap") -- spins + changes colour on the client

	-- The arms: a pivot (anchored) + a motor-driven arm with sparks at both tips.
	local armHeight = top + 1.4 -- jump it!
	local pivot = Arena.part(
		model,
		"Pivot",
		Vector3.new(1, 1, 1),
		CFrame.new(center + Vector3.new(0, armHeight, 0)),
		C.Cyan
	)
	pivot.Transparency = 1
	pivot.CanCollide = false
	pivot.CanQuery = false
	pivot.CanTouch = false
	local function arm(name: string, yaw: number): Part
		local a = Arena.part(
			model,
			name,
			Vector3.new(0.9, 0.9, radius * 2 - 0.4),
			CFrame.new(center + Vector3.new(0, armHeight, 0)) * CFrame.Angles(0, yaw, 0),
			C.Pink,
			Enum.Material.Neon
		)
		a.Anchored = false
		a.CanCollide = false
		a.CanTouch = false
		a.CanQuery = false
		a.Massless = true
		a:AddTag("SweepArm") -- the client plays a whoosh when one passes close
		for _, z in { -1, 1 } do
			local tip = Instance.new("Attachment")
			tip.Position = Vector3.new(0, 0, z * (radius - 0.4))
			tip.Parent = a
			local sparks = Instance.new("ParticleEmitter")
			sparks.Rate = 40
			sparks.Lifetime = NumberRange.new(0.25, 0.5)
			sparks.Speed = NumberRange.new(6, 12)
			sparks.SpreadAngle = Vector2.new(60, 60)
			sparks.Size = NumberSequence.new(0.35, 0)
			sparks.LightEmission = 1
			sparks.Color = ColorSequence.new(C.Gold, C.Pink)
			sparks.Parent = tip
		end
		return a
	end
	local armA = arm("ArmA", 0)
	local armB = arm("ArmB", math.pi / 2)
	armB.Transparency = 1
	for _, emitter in armB:GetDescendants() do
		if emitter:IsA("ParticleEmitter") then
			emitter.Enabled = false
		end
	end
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = armA
	weld.Part1 = armB
	weld.Parent = armA
	-- A hinge turns around its attachments' X axis; turned 90 degrees around Z that's vertical.
	local pivotAttach = Instance.new("Attachment")
	pivotAttach.CFrame = CFrame.Angles(0, 0, math.rad(90))
	pivotAttach.Parent = pivot
	local armAttach = Instance.new("Attachment")
	armAttach.CFrame = CFrame.Angles(0, 0, math.rad(90))
	armAttach.Parent = armA
	local motor = Instance.new("HingeConstraint")
	motor.ActuatorType = Enum.ActuatorType.Motor
	motor.MotorMaxTorque = math.huge
	motor.MotorMaxAcceleration = 40
	motor.AngularVelocity = 0.4
	motor.Attachment0 = pivotAttach
	motor.Attachment1 = armAttach
	motor.Parent = pivot

	-- Corner light posts.
	for k = 0, 3 do
		local angle = k * math.pi / 2 + math.pi / 4
		Arena.pillar(
			model,
			center + Vector3.new(math.cos(angle), 0, math.sin(angle)) * (radius + 3),
			10,
			false
		)
	end
	local status, detail = Arena.sign(
		model,
		"SpinSweep",
		CFrame.new(center + Vector3.new(radius + 7, 5, 0)) * CFrame.Angles(0, math.rad(-90), 0),
		"SPIN SWEEP"
	)
	model.Parent = parent
	-- The server owns the arm so everyone sees the same one. (Deferred: only works once the
	-- folder is in the Workspace, which happens after everything is built.)
	task.defer(function()
		pcall(function()
			armA:SetNetworkOwner(nil)
		end)
	end)

	---------------------------------------------------------------------------------------------
	-- Game
	---------------------------------------------------------------------------------------------

	local outSpot = center + Vector3.new(radius + 5, 3, 5)
	local function isOn(player: Player): boolean
		local root = Arena.rootOf(player)
		if not root then
			return false
		end
		local p = root.Position - center
		return Vector2.new(p.X, p.Z).Magnitude <= radius - 0.3 and p.Y > top and p.Y < top + 16
	end
	-- Is this arm sweeping through the player right now? (Near its line, and not jumping over it.)
	local function hitBy(armPart: Part, root: BasePart): boolean
		local rel = root.Position - center
		local flat = Vector3.new(rel.X, 0, rel.Z)
		local dir = armPart.CFrame.LookVector
		dir = Vector3.new(dir.X, 0, dir.Z).Unit
		local along = flat:Dot(dir)
		local across = (flat - dir * along).Magnitude
		local feet = root.Position.Y - 3
		return math.abs(along) <= radius and across < 1.3 and feet < armHeight + 0.45
	end

	local g: Arena.Game
	g = {
		rounds = true,
		state = {
			id = "SpinSweep",
			name = "Spin Sweep",
			phase = "Idle",
			headline = "",
			players = {},
			center = center + Vector3.new(0, top, 0),
		},
		sign = status,
		subSign = detail,
		isOn = isOn,
		joinSpot = function(playing: boolean): CFrame
			-- Not on the hub: half way out, between the arms.
			return if playing
				then CFrame.lookAt(outSpot, center)
				else CFrame.new(center + Vector3.new(radius * 0.55, top + 3, radius * 0.55))
		end,
		play = function(self: Arena.Game, participants: { Player }): { Player }
			local alive = table.clone(participants)
			local solo = #participants == 1
			local started = os.clock()
			local finish = Arena.now() + ss.Seconds
			local crossed = false
			local direction = 1
			local surgeUntil = 0
			local nextEvent = ss.EventsFrom + math.random() * 4
			local headline, headColor = "JUMP!", C.Pink
			local flung: { [Player]: number } = {}

			local function stateNow()
				Arena.setState(self, {
					phase = "Playing",
					headline = headline,
					color = headColor,
					detail = if solo then "Survive to win" else `{#alive} left`,
					endsAt = finish,
					players = Arena.userIds(alive),
				})
			end
			stateNow()
			Arena.sound(S.Go, center, nil, 0.7)
			local pendingReverse: number? = nil
			while true do
				task.wait(0.08)
				local t = os.clock() - started
				local progress = math.clamp(t / ss.Seconds, 0, 1)
				local speed = ss.StartSpeed + (ss.EndSpeed - ss.StartSpeed) * progress
				if os.clock() < surgeUntil then
					speed *= 1.8
				end

				-- Events.
				if pendingReverse and os.clock() >= pendingReverse then
					pendingReverse = nil
					direction = -direction
					Arena.sound(S.Launch, center, nil, 0.6, 1.2)
				end
				if t >= nextEvent and not pendingReverse then
					nextEvent = t + 6 + math.random() * 4
					if math.random() < 0.5 then
						headline, headColor = "REVERSE!", C.Gold
						pendingReverse = os.clock() + 1
						speed = 0.3 -- it slows right down before turning
					else
						headline, headColor = "SURGE!", C.Lime
						surgeUntil = os.clock() + 3
						Arena.sound(S.Launch, center, nil, 0.7)
					end
					stateNow()
				elseif headline ~= "JUMP!" and headline ~= "DOUBLE TROUBLE!" and t >= nextEvent - 4 then
					headline, headColor =
						if crossed then "DOUBLE TROUBLE!" else "JUMP!", if crossed then C.Cyan else C.Pink
					stateNow()
				end
				if pendingReverse then
					speed = 0.3
				end
				motor.AngularVelocity = speed * direction

				if not crossed and t >= ss.SecondArmAt then
					crossed = true
					armB.Transparency = 0
					for _, emitter in armB:GetDescendants() do
						if emitter:IsA("ParticleEmitter") then
							emitter.Enabled = true
						end
					end
					headline, headColor = "DOUBLE TROUBLE!", C.Cyan
					Arena.sound(S.Boom, center, nil, 0.4)
					stateNow()
				end

				local kept = {}
				for _, player in alive do
					local root = Arena.rootOf(player)
					if not root or not Arena.eligible(player) then
						Arena.toast(player, "Out!")
					elseif not isOn(player) then
						Arena.sound(S.Out, nil, { player }, 0.8)
						Arena.toast(
							player,
							if flung[player]
								then `SWEPT! You lasted {math.floor(t)}s.`
								else "Out! You left the platform."
						)
					elseif
						t > 1.5
						and (hitBy(armA, root) or (crossed and hitBy(armB, root)))
						and not flung[player]
					then
						-- FLING: away from the middle and up. They count as out once they're off.
						flung[player] = os.clock()
						local away = Vector3.new(root.Position.X - center.X, 0, root.Position.Z - center.Z)
						away = if away.Magnitude > 0.1 then away.Unit else Vector3.new(1, 0, 0)
						Arena.fx(
							{ player },
							{ kind = "knock", velocity = away * ss.KnockSpeed + Vector3.new(0, 45, 0) }
						)
						Arena.fx(nil, { kind = "burst", position = root.Position, color = C.Gold })
						Arena.sound(S.Hit, root.Position, nil, 1)
						table.insert(kept, player)
					elseif flung[player] and os.clock() - flung[player] > 1.5 then
						-- Got hit but somehow still here: out anyway.
						(root.Parent :: Model):PivotTo(CFrame.lookAt(outSpot, center))
						Arena.toast(player, `SWEPT! You lasted {math.floor(t)}s.`)
					else
						table.insert(kept, player)
					end
				end
				if #kept ~= #alive then
					alive = kept
					stateNow()
				end
				if #alive == 0 then
					break
				elseif not solo and #alive == 1 then
					break
				elseif t >= ss.Seconds then
					break
				end
			end
			motor.AngularVelocity = 0.4
			armB.Transparency = 1
			for _, emitter in armB:GetDescendants() do
				if emitter:IsA("ParticleEmitter") then
					emitter.Enabled = false
				end
			end
			-- Flung players still in the air don't win.
			local winners = {}
			for _, player in alive do
				if not flung[player] then
					table.insert(winners, player)
				end
			end
			return winners
		end,
	}
	return g
end

return SpinSweep
