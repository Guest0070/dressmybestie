--!strict
-- Freeze Frame: a paparazzi photo shoot. DANCE! on a disco stage (the beat plays, the floor and
-- lights go wild), then the photographers call:
--   FREEZE!                -> the cameras flash; anyone who moves is "CAUGHT MOVING!"
--   JUMP FOR THE CAMERA!   -> from round 3: anyone who doesn't jump in time is out
--   FREE... STYLE!         -> a fake-out mid-dance: don't fall for it, keep dancing
-- Calls come faster and stricter each round. The winner's name goes on the COVER STAR board.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Arena = require(script.Parent.Arena)

local C = Arena.Colors
local S = Arena.Sounds

local FreezeFrame = {}

function FreezeFrame.build(parent: Instance): Arena.Game
	local ff = Config.Minigames.FreezeFrame
	local model = Instance.new("Model")
	model.Name = "FreezeFrame"
	local center = ff.Center
	local radius = ff.Radius
	local top = 1

	-- Stage: black marble disc, champagne rim, neon edge and a disco floor of square tiles.
	Arena.disc(model, "Stage", 1, radius * 2, center + Vector3.new(0, 0.5, 0), C.Black, Enum.Material.Marble)
	local rim = Arena.disc(
		model,
		"Rim",
		0.9,
		radius * 2 + 1.2,
		center + Vector3.new(0, 0.45, 0),
		C.Champagne,
		Enum.Material.Metal
	)
	rim.CanCollide = false
	local edge = Arena.disc(
		model,
		"Edge",
		0.3,
		radius * 2 + 2,
		center + Vector3.new(0, 0.15, 0),
		C.Pink,
		Enum.Material.Neon
	)
	edge.CanCollide = false
	local tileSize = 3.6
	local count = math.floor((radius - 1) * 2 / tileSize)
	for i = 0, count - 1 do
		for j = 0, count - 1 do
			local x = (i - (count - 1) / 2) * tileSize
			local z = (j - (count - 1) / 2) * tileSize
			if Vector2.new(x, z).Magnitude <= radius - 2.2 then
				local tile = Arena.glow(
					model,
					"DiscoTile",
					Vector3.new(tileSize - 0.3, 0.06, tileSize - 0.3),
					CFrame.new(center + Vector3.new(x, top + 0.03, z)),
					C.Plum
				)
				tile.Material = Enum.Material.SmoothPlastic
				tile:AddTag("DiscoTile") -- the client lights these to the beat
			end
		end
	end

	-- Rig: four pillars, a square truss, a disco ball and coloured spotlights.
	local rigHeight = 18
	local reach = radius + 3
	for k = 0, 3 do
		local angle = k * math.pi / 2 + math.pi / 4
		Arena.pillar(model, center + Vector3.new(math.cos(angle), 0, math.sin(angle)) * reach, rigHeight)
	end
	local side = reach * math.sqrt(2)
	for _, spec in
		{
			{ Vector3.new(side, 1, 1), Vector3.new(0, rigHeight, reach / math.sqrt(2)) },
			{ Vector3.new(side, 1, 1), Vector3.new(0, rigHeight, -reach / math.sqrt(2)) },
			{ Vector3.new(1, 1, side), Vector3.new(reach / math.sqrt(2), rigHeight, 0) },
			{ Vector3.new(1, 1, side), Vector3.new(-reach / math.sqrt(2), rigHeight, 0) },
			{ Vector3.new(side, 0.6, 0.6), Vector3.new(0, rigHeight, 0) },
		}
	do
		Arena.part(model, "Truss", spec[1], CFrame.new(center + spec[2]), C.Black, Enum.Material.Marble)
	end
	local ball = Arena.part(
		model,
		"DiscoBall",
		Vector3.new(4, 4, 4),
		CFrame.new(center + Vector3.new(0, rigHeight - 4, 0)),
		Color3.fromRGB(225, 225, 240),
		Enum.Material.Glass
	)
	ball.Shape = Enum.PartType.Ball
	ball.Reflectance = 0.5
	ball.CanCollide = false
	ball:AddTag("DiscoBall") -- spins on the client
	Arena.part(
		model,
		"BallRod",
		Vector3.new(0.3, 2, 0.3),
		CFrame.new(center + Vector3.new(0, rigHeight - 1.5, 0)),
		C.Champagne,
		Enum.Material.Metal
	)
	for k = 0, 3 do
		local angle = k * math.pi / 2
		local at = center
			+ Vector3.new(math.cos(angle), 0, math.sin(angle)) * (reach * 0.6)
			+ Vector3.new(0, rigHeight - 0.8, 0)
		local lamp =
			Arena.glow(model, "StageLight", Vector3.new(1.2, 1.2, 1.6), CFrame.lookAt(at, center), C.Pink)
		local spot = Instance.new("SpotLight")
		spot.Face = Enum.NormalId.Front
		spot.Range = 40
		spot.Angle = 45
		spot.Brightness = 3
		spot.Color = C.Pink
		spot.Parent = lamp
		lamp:AddTag("StageLight") -- colour cycles on the client
	end

	-- Paparazzi: six cameras on tripods around the stage, flashes ready.
	for k = 0, 5 do
		local angle = k * math.pi / 3 + math.pi / 6
		local base = center + Vector3.new(math.cos(angle), 0, math.sin(angle)) * (radius + 5.5)
		local facing = CFrame.lookAt(base + Vector3.new(0, 4.6, 0), center + Vector3.new(0, 3, 0))
		for leg = 0, 2 do
			local legAngle = leg * math.pi * 2 / 3
			local foot = base + Vector3.new(math.cos(legAngle), 0, math.sin(legAngle)) * 1.2
			local headPos = base + Vector3.new(0, 4, 0)
			local legPart = Arena.part(
				model,
				"TripodLeg",
				Vector3.new(0.2, (headPos - foot).Magnitude, 0.2),
				CFrame.lookAt((foot + headPos) / 2, headPos) * CFrame.Angles(math.rad(90), 0, 0),
				C.Black,
				Enum.Material.Metal
			)
			legPart.CanCollide = false
		end
		Arena.part(model, "Camera", Vector3.new(1.6, 1.2, 1.2), facing, C.Black, Enum.Material.SmoothPlastic)
		local lens = Arena.part(
			model,
			"Lens",
			Vector3.new(0.8, 0.8, 0.8),
			facing * CFrame.new(0, 0, -0.9) * CFrame.Angles(0, math.rad(90), 0),
			Color3.fromRGB(40, 40, 60),
			Enum.Material.Glass
		)
		lens.Shape = Enum.PartType.Cylinder
		local flash = Arena.glow(
			model,
			"Flash",
			Vector3.new(1, 0.5, 0.3),
			facing * CFrame.new(0, 0.9, -0.3),
			Color3.fromRGB(90, 90, 110)
		)
		flash:AddTag("PapFlash") -- the client fires these on FREEZE!
	end

	-- COVER STAR board (north side): the last winner, magazine-cover style.
	local coverCFrame = CFrame.new(center + Vector3.new(0, 9, -radius - 7))
	Arena.part(model, "CoverFrame", Vector3.new(13, 17, 0.4), coverCFrame, C.Champagne, Enum.Material.Metal)
	local cover =
		Arena.part(model, "Cover", Vector3.new(12, 16, 0.7), coverCFrame, C.Plum, Enum.Material.SmoothPlastic)
	local coverName: { TextLabel } = {}
	for _, face in { Enum.NormalId.Back, Enum.NormalId.Front } do
		local gui = Arena.surface(cover, face, 30)
		Arena.label(gui, "COVER STAR", UDim2.fromScale(0.05, 0.03), UDim2.fromScale(0.9, 0.16), C.Pink)
		Arena.label(
			gui,
			"FREEZE FRAME CHAMPION",
			UDim2.fromScale(0.1, 0.2),
			UDim2.fromScale(0.8, 0.06),
			C.Champagne
		)
		table.insert(
			coverName,
			Arena.label(
				gui,
				"Could be you!",
				UDim2.fromScale(0.05, 0.42),
				UDim2.fromScale(0.9, 0.2),
				Color3.new(1, 1, 1)
			)
		)
		Arena.label(gui, "★ ★ ★", UDim2.fromScale(0.2, 0.72), UDim2.fromScale(0.6, 0.1), C.Gold)
	end

	local status, detail = Arena.sign(
		model,
		"FreezeFrame",
		CFrame.new(center + Vector3.new(radius + 7, 5, 0)) * CFrame.Angles(0, math.rad(-90), 0),
		"FREEZE FRAME"
	)
	model.Parent = parent

	---------------------------------------------------------------------------------------------
	-- Game
	---------------------------------------------------------------------------------------------

	local outSpot = center + Vector3.new(radius + 4, 3, 6)
	local function isOn(player: Player): boolean
		local root = Arena.rootOf(player)
		if not root then
			return false
		end
		local p = root.Position - center
		return Vector2.new(p.X, p.Z).Magnitude <= radius - 0.5 and p.Y > top and p.Y < top + 14
	end
	local function kickOff(player: Player, why: string)
		local character = player.Character
		local root = Arena.rootOf(player)
		if root then
			Arena.fx(nil, { kind = "burst", position = root.Position, color = C.Cyan })
		end
		if character and player.Parent then
			character:PivotTo(CFrame.lookAt(outSpot, center))
		end
		Arena.sound(S.Out, nil, { player }, 0.8)
		Arena.toast(player, why)
	end

	local g: Arena.Game
	g = {
		rounds = true,
		state = {
			id = "FreezeFrame",
			name = "Freeze Frame",
			phase = "Idle",
			headline = "",
			players = {},
			center = center + Vector3.new(0, top, 0),
		},
		sign = status,
		subSign = detail,
		isOn = isOn,
		joinSpot = function(playing: boolean): CFrame
			return if playing
				then CFrame.lookAt(outSpot, center)
				else CFrame.new(center + Vector3.new(4, top + 3, 4))
		end,
		onWin = function(_self, winners: { Player })
			if #winners == 0 then
				return
			end
			local names = {}
			for i = 1, math.min(2, #winners) do
				table.insert(names, winners[i].DisplayName)
			end
			local text = table.concat(names, " & ") .. (if #winners > 2 then " +" .. (#winners - 2) else "")
			for _, label in coverName do
				label.Text = text
			end
		end,
		play = function(self: Arena.Game, participants: { Player }): { Player }
			local alive = table.clone(participants)
			local solo = #participants == 1
			local winners: { Player } = {}

			local function dropLeavers(): { Player }
				local kept = {}
				for _, player in alive do
					if Arena.eligible(player) and isOn(player) then
						table.insert(kept, player)
					else
						kickOff(player, "Out! You left the stage.")
					end
				end
				return kept
			end

			for round = 1, ff.Rounds do
				local roundText = if solo
					then `Round {round}/{ff.Rounds}`
					else `Round {round}/{ff.Rounds}  ·  {#alive} left`
				local hurry = 1 - math.min(0.4, (round - 1) * 0.04) -- dances get shorter
				local danceFor = (
					ff.DanceSeconds[1] + math.random() * (ff.DanceSeconds[2] - ff.DanceSeconds[1])
				) * hurry
				Arena.setState(self, {
					phase = "Playing",
					headline = "DANCE!",
					color = C.Pink,
					detail = roundText,
					players = Arena.userIds(alive),
				})
				-- A fake-out somewhere in the dance.
				local fakeAt = if round >= 2 and math.random() < ff.FakeChance
					then danceFor * (0.3 + math.random() * 0.4)
					else nil
				local danceEnd = os.clock() + danceFor
				local faked = false
				while os.clock() < danceEnd do
					task.wait(0.15)
					if fakeAt and not faked and os.clock() >= danceEnd - danceFor + fakeAt then
						faked = true
						Arena.setState(self, {
							phase = "Playing",
							headline = "FREE...",
							color = C.Cyan,
							detail = roundText,
							players = Arena.userIds(alive),
						})
						task.wait(0.7)
						Arena.setState(self, {
							phase = "Playing",
							headline = "...STYLE! Keep dancing!",
							color = C.Pink,
							detail = roundText,
							players = Arena.userIds(alive),
						})
						danceEnd += 1.2
					end
					local kept = dropLeavers()
					if #kept ~= #alive then
						alive = kept
					end
				end
				if #alive == 0 then
					break
				end

				local jumpCall = round >= ff.JumpFromRound and math.random() < ff.JumpChance
				local out: { [Player]: string } = {}
				if jumpCall then
					-- JUMP FOR THE CAMERA: everyone must leave the ground in time.
					local window = ff.JumpWindow * hurry + 0.3
					Arena.setState(self, {
						phase = "Playing",
						headline = "JUMP FOR THE CAMERA!",
						color = C.Gold,
						detail = roundText,
						endsAt = Arena.now() + window,
						players = Arena.userIds(alive),
					})
					local ground: { [Player]: number } = {}
					local best: { [Player]: number } = {}
					for _, player in alive do
						local root = Arena.rootOf(player)
						if root then
							ground[player] = root.Position.Y
							best[player] = 0
						end
					end
					local windowEnd = os.clock() + window
					while os.clock() < windowEnd do
						task.wait(0.08)
						for _, player in alive do
							local root = Arena.rootOf(player)
							if root and ground[player] then
								best[player] = math.max(best[player], root.Position.Y - ground[player])
							end
						end
					end
					Arena.fx(Arena.near(center, 90), { kind = "paparazzi", position = center })
					for _, player in alive do
						if (best[player] or 0) < 1.6 then
							out[player] = "No jump, no photo! You're out."
						end
					end
				else
					-- FREEZE: snapshot after a short grace, then anyone who moves is out.
					local freezeFor = (
						ff.FreezeSeconds[1] + math.random() * (ff.FreezeSeconds[2] - ff.FreezeSeconds[1])
					) * (2 - hurry)
					Arena.setState(self, {
						phase = "Playing",
						headline = "FREEZE!",
						color = C.Cyan,
						detail = roundText,
						endsAt = Arena.now() + freezeFor,
						players = Arena.userIds(alive),
					})
					Arena.fx(Arena.near(center, 90), { kind = "paparazzi", position = center })
					task.wait(ff.Grace)
					local snapshot: { [Player]: Vector3 } = {}
					for _, player in alive do
						local root = Arena.rootOf(player)
						if root then
							snapshot[player] = root.Position
						end
					end
					local tolerance = math.max(0.8, ff.MoveTolerance * hurry + 0.2)
					local freezeEnd = os.clock() + freezeFor - ff.Grace
					local nextFlash = os.clock() + 0.9
					while os.clock() < freezeEnd do
						task.wait(0.12)
						if os.clock() >= nextFlash then
							nextFlash = os.clock() + 0.6 + math.random() * 0.6
							Arena.fx(
								Arena.near(center, 90),
								{ kind = "paparazzi", position = center, quiet = true }
							)
						end
						for _, player in alive do
							if out[player] then
								continue
							end
							local root = Arena.rootOf(player)
							local start = snapshot[player]
							if not root or not start or not Arena.eligible(player) then
								out[player] = "Out! You left the shoot."
								continue
							end
							local moved = root.Position - start
							if
								Vector2.new(moved.X, moved.Z).Magnitude > tolerance
								or math.abs(moved.Y) > 1.5
							then
								out[player] = `CAUGHT MOVING! Out in round {round}.`
								Arena.fx(nil, { kind = "burst", position = root.Position, color = C.Cyan })
								Arena.sound(S.Flash, root.Position, nil, 1)
							end
						end
					end
				end
				local kept = {}
				for _, player in alive do
					if out[player] then
						kickOff(player, out[player])
					elseif isOn(player) then
						table.insert(kept, player)
					else
						kickOff(player, "Out! You left the stage.")
					end
				end
				if #kept == 0 then
					winners = {}
					break
				end
				alive = kept
				if not solo and #alive == 1 then
					winners = alive
					break
				end
				if round == ff.Rounds then
					winners = alive
				end
			end
			return winners
		end,
	}
	return g
end

return FreezeFrame
