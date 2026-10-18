--!strict
-- Cover Star (arcade hall): a magazine cover shoot. The four edges of the platform glow in four
-- colours, and the photographer (on the CAMERA side) calls where to pose:
--   FACE THE CAMERA! / FACE PINK! / FACE CYAN! / FACE GOLD!   turn to face that edge in time
--   JUMP FOR THE COVER!                                       (from round 3) jump before the shot
-- The window shrinks every round. When it closes the camera flashes: anyone facing the wrong way
-- (or who didn't jump) is out. Last one standing wins (solo: survive every round).
-- The server reads each character's facing; clients only show the calls.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Arena = require(script.Parent.Arena)

local C = Arena.Colors
local S = Arena.Sounds

local CoverStar = {}

type Side = { name: string, call: string, color: Color3, dir: Vector3 }

-- Returns nil when the arcade hall isn't in this place (Cover Star only exists there).
function CoverStar.build(parent: Instance): Arena.Game?
	local cs = Config.Minigames.CoverStar
	local platform = Arena.arcadeSpot("ARC_Cover_Star_Platform__MAT_Silver_Metal")
	if not platform then
		return nil
	end
	local model = Instance.new("Model")
	model.Name = "CoverStar"
	local center = Vector3.new(platform.X, 0, platform.Z)
	local top = platform.Y + 0.03
	local half = 8.6 -- the platform's tile area is 18 studs across

	-- The camera faces the hall (west, -X); the other three edges are colours.
	local sides: { Side } = {
		{
			name = "CAMERA",
			call = "FACE THE CAMERA!",
			color = Color3.new(1, 1, 1),
			dir = Vector3.new(-1, 0, 0),
		},
		{ name = "PINK", call = "FACE PINK!", color = C.Pink, dir = Vector3.new(1, 0, 0) },
		{ name = "CYAN", call = "FACE CYAN!", color = C.Cyan, dir = Vector3.new(0, 0, -1) },
		{ name = "GOLD", call = "FACE GOLD!", color = C.Gold, dir = Vector3.new(0, 0, 1) },
	}
	for _, side in sides do
		-- A glowing strip along the edge and a floating label over it.
		local along = Vector3.new(side.dir.Z, 0, side.dir.X) -- perpendicular, in the floor plane
		local edgeCentre = center + side.dir * (half - 0.4) + Vector3.new(0, top + 0.05, 0)
		Arena.glow(
			model,
			`Edge{side.name}`,
			Vector3.new(0.6, 0.1, half * 2 - 1), -- long along the edge (the CFrame's look axis)
			CFrame.lookAt(edgeCentre, edgeCentre + along),
			side.color
		)
		local label = Arena.part(
			model,
			`Label{side.name}`,
			Vector3.new(1, 1, 1),
			CFrame.new(center + side.dir * (half + 0.5) + Vector3.new(0, 6.5, 0)),
			side.color
		)
		label.Transparency = 1
		label.CanCollide = false
		label.CanQuery = false
		label.CanTouch = false
		local gui = Instance.new("BillboardGui")
		gui.Size = UDim2.fromScale(5, 1.6)
		gui.LightInfluence = 0
		gui.MaxDistance = 90
		gui.Parent = label
		Arena.label(
			gui,
			if side.name == "CAMERA" then "📸 CAMERA" else side.name,
			UDim2.fromScale(0, 0),
			UDim2.fromScale(1, 1),
			side.color
		)
	end

	-- The photographer's camera on a tripod, on the CAMERA side, aimed at the platform.
	local camBase = center + sides[1].dir * (half + 3)
	local facing = CFrame.lookAt(camBase + Vector3.new(0, 4.6, 0), center + Vector3.new(0, 3, 0))
	for leg = 0, 2 do
		local legAngle = leg * math.pi * 2 / 3
		local foot = camBase + Vector3.new(math.cos(legAngle), 0, math.sin(legAngle)) * 1.2
		local headPos = camBase + Vector3.new(0, 4, 0)
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
	Arena.part(model, "Camera", Vector3.new(2, 1.5, 1.5), facing, C.Black, Enum.Material.SmoothPlastic)
	local flash = Arena.glow(
		model,
		"Flash",
		Vector3.new(1.2, 0.6, 0.3),
		facing * CFrame.new(0, 1.1, -0.3),
		Color3.fromRGB(90, 90, 110)
	)
	flash:AddTag("PapFlash")

	-- Last cover star, floating over the frame.
	local coverAnchor = Arena.part(
		model,
		"LastCover",
		Vector3.new(1, 1, 1),
		CFrame.new(center + Vector3.new(0, 12.5, 0)),
		C.Plum
	)
	coverAnchor.Transparency = 1
	coverAnchor.CanCollide = false
	coverAnchor.CanQuery = false
	coverAnchor.CanTouch = false
	local coverGui = Instance.new("BillboardGui")
	coverGui.Size = UDim2.fromScale(12, 1.4)
	coverGui.LightInfluence = 0
	coverGui.MaxDistance = 140
	coverGui.Parent = coverAnchor
	local lastCover = Arena.label(
		coverGui,
		"LAST COVER STAR: could be you!",
		UDim2.fromScale(0, 0),
		UDim2.fromScale(1, 1),
		C.Gold
	)
	local status, detail = Arena.statusBoard(model, "CoverStar", center + Vector3.new(0, 10, 0))
	model.Parent = parent

	---------------------------------------------------------------------------------------------
	-- Game
	---------------------------------------------------------------------------------------------

	local outSpot = CFrame.lookAt(center + sides[1].dir * (half + 5) + Vector3.new(0, 3.5, 4), center)
	local function isOn(player: Player): boolean
		local root = Arena.rootOf(player)
		if not root then
			return false
		end
		local p = root.Position - center
		return math.abs(p.X) <= half and math.abs(p.Z) <= half and p.Y > top and p.Y < top + 14
	end
	local function kickOff(player: Player, why: string)
		local character = player.Character
		local root = Arena.rootOf(player)
		if root then
			Arena.fx(nil, { kind = "burst", position = root.Position, color = C.Pink })
		end
		if character and player.Parent then
			character:PivotTo(outSpot)
		end
		Arena.sound(S.Out, nil, { player }, 0.8)
		Arena.toast(player, why)
	end
	-- Is the character facing this way (within ~45 degrees)?
	local function faces(root: BasePart, dir: Vector3): boolean
		local look = root.CFrame.LookVector
		local flat = Vector3.new(look.X, 0, look.Z)
		return flat.Magnitude > 0.1 and flat.Unit:Dot(dir) > 0.7
	end

	local g: Arena.Game
	g = {
		rounds = true,
		state = {
			id = "CoverStar",
			name = "Cover Star",
			phase = "Idle",
			headline = "",
			players = {},
			center = center + Vector3.new(0, top, 0),
		},
		sign = status,
		subSign = detail,
		isOn = isOn,
		joinSpot = function(playing: boolean): CFrame
			return if playing then outSpot else CFrame.new(center + Vector3.new(0, top + 3, 0))
		end,
		onWin = function(_self, winners: { Player })
			if #winners > 0 then
				local names = {}
				for i = 1, math.min(2, #winners) do
					table.insert(names, winners[i].DisplayName)
				end
				lastCover.Text = `LAST COVER STAR: {table.concat(names, " & ")}{if #winners > 2
					then " +" .. (#winners - 2)
					else ""}`
			end
		end,
		play = function(self: Arena.Game, participants: { Player }): { Player }
			local alive = table.clone(participants)
			local solo = #participants == 1
			local winners: { Player } = {}
			local previous: Side? = nil
			for round = 1, cs.Rounds do
				local progress = (round - 1) / math.max(1, cs.Rounds - 1)
				local window = cs.FirstWindow + (cs.LastWindow - cs.FirstWindow) * progress
				local roundText = if solo
					then `Shot {round}/{cs.Rounds}`
					else `Shot {round}/{cs.Rounds}  ·  {#alive} left`
				local jump = round >= cs.JumpFromRound and math.random() < cs.JumpChance
				local side: Side = sides[1]
				if not jump then
					-- Never the same direction twice in a row (that would be a free round).
					repeat
						side = sides[math.random(#sides)]
					until side ~= previous
					previous = side
				end
				Arena.setState(self, {
					phase = "Playing",
					headline = if jump then "JUMP FOR THE COVER!" else side.call,
					color = if jump then C.Gold else side.color,
					detail = roundText,
					endsAt = Arena.now() + window,
					players = Arena.userIds(alive),
				})
				Arena.sound(S.Switch, center, nil, 0.6, 1 + round * 0.03)

				-- During the window: leaving the platform is out; for JUMP, track how high they got.
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

				-- The shot.
				Arena.fx(Arena.near(center, 90), { kind = "paparazzi", position = center })
				local kept = {}
				for _, player in alive do
					local root = Arena.rootOf(player)
					if not root or not Arena.eligible(player) or not isOn(player) then
						kickOff(player, "Out! You left the shoot.")
					elseif jump and (best[player] or 0) < 1.6 then
						kickOff(player, "No jump, no cover! You're out.")
					elseif not jump and not faces(root, side.dir) then
						kickOff(player, `Wrong pose! You had to face {side.name}.`)
					else
						table.insert(kept, player)
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
				if round == cs.Rounds then
					winners = alive
				end
				-- A beat between shots.
				Arena.setState(self, {
					phase = "Playing",
					headline = "📸 SNAP!",
					color = Color3.new(1, 1, 1),
					detail = roundText,
					players = Arena.userIds(alive),
				})
				task.wait(0.9)
			end
			return winners
		end,
	}
	return g
end

return CoverStar
