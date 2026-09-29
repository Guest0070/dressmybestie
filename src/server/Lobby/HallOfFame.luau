--!strict
-- Hall of Fame: statues of the last round's top 3 looks, on a stage past the lobby arch.
-- Walk up to a statue and press the prompt to open "Buy this look" for it.

local Players = game:GetService("Players")

local HallOfFame = {}

export type Entry = {
	place: number,
	userId: number,
	name: string,
	stylistNames: { string },
	description: HumanoidDescription,
}

local PLACE_TEXT = { "1st", "2nd", "3rd" }
local PLACE_COLOR =
	{ Color3.fromRGB(255, 210, 80), Color3.fromRGB(220, 220, 235), Color3.fromRGB(225, 150, 90) }
local PEDESTAL_X = { 0, -12, 12 }
local CENTER = Vector3.new(0, 0, 74)

local pedestals: { BasePart } = {}
local statues: { Model? } = {}

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

function HallOfFame.build(parent: Instance)
	local model = Instance.new("Model")
	model.Name = "HallOfFame"
	part(
		model,
		"Stage",
		Vector3.new(44, 1, 18),
		CFrame.new(CENTER + Vector3.new(0, 0.5, 0)),
		Color3.fromRGB(45, 38, 62)
	)
	part(
		model,
		"Edge",
		Vector3.new(44, 0.4, 0.5),
		CFrame.new(CENTER + Vector3.new(0, 1.1, -9)),
		Color3.fromRGB(255, 110, 180),
		true
	)
	local sign = part(
		model,
		"Sign",
		Vector3.new(40, 6, 1),
		CFrame.new(CENTER + Vector3.new(0, 13, 8)),
		Color3.fromRGB(35, 30, 50)
	)
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Front -- faces -Z, towards the lobby
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 40
	gui.LightInfluence = 0
	gui.Parent = sign
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1, 1)
	label.Font = Enum.Font.FredokaOne
	label.TextScaled = true
	label.TextColor3 = Color3.fromRGB(255, 210, 80)
	label.Text = "HALL OF FAME · last round's best looks"
	label.Parent = gui

	for place = 1, 3 do
		local height = if place == 1 then 4 elseif place == 2 then 3 else 2
		local pedestal = part(
			model,
			`Pedestal{place}`,
			Vector3.new(7, height, 7),
			CFrame.new(CENTER + Vector3.new(PEDESTAL_X[place], 1 + height / 2, 2)),
			PLACE_COLOR[place]
		)
		local prompt = Instance.new("ProximityPrompt")
		prompt.ActionText = "Buy this look"
		prompt.ObjectText = `{PLACE_TEXT[place]} place`
		prompt.HoldDuration = 0
		prompt.MaxActivationDistance = 12
		prompt.RequiresLineOfSight = false
		prompt.Enabled = false -- until a look is on it
		prompt.Parent = pedestal
		pedestals[place] = pedestal
	end
	model.Parent = parent
end

-- Replace the statues with the newest podium. Called after each round's results.
function HallOfFame.show(entries: { Entry })
	if #pedestals == 0 then
		return -- no Hall of Fame on a hand-built map
	end
	for place = 1, 3 do
		local old = statues[place]
		if old then
			old:Destroy()
			statues[place] = nil
		end
		local prompt = pedestals[place]:FindFirstChildOfClass("ProximityPrompt")
		if prompt then
			prompt.Enabled = false
		end
	end
	for _, entry in entries do
		local pedestal = pedestals[entry.place]
		if not pedestal then
			continue
		end
		task.spawn(function()
			local ok, statue = pcall(
				Players.CreateHumanoidModelFromDescriptionAsync,
				Players,
				entry.description,
				Enum.HumanoidRigType.R15
			)
			if not ok or not statue then
				return
			end
			statue.Name = `Statue{entry.place}`
			local humanoid = statue:FindFirstChildOfClass("Humanoid")
			if humanoid then
				humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
			end
			local root = statue:FindFirstChild("HumanoidRootPart")
			if root and root:IsA("BasePart") then
				root.Anchored = true
			end
			local top = pedestal.Position + Vector3.new(0, pedestal.Size.Y / 2 + 3, 0)
			statue:PivotTo(CFrame.lookAt(top, top - Vector3.new(0, 0, 10))) -- face the lobby

			local head = statue:FindFirstChild("Head")
			if head and head:IsA("BasePart") then
				local tag = Instance.new("BillboardGui")
				tag.Size = UDim2.fromOffset(240, 60)
				tag.StudsOffset = Vector3.new(0, 3, 0)
				tag.MaxDistance = 90
				local text = Instance.new("TextLabel")
				text.BackgroundTransparency = 1
				text.Size = UDim2.fromScale(1, 1)
				text.Font = Enum.Font.FredokaOne
				text.TextScaled = true
				text.TextColor3 = PLACE_COLOR[entry.place]
				text.TextStrokeTransparency = 0.2
				local stylists = if #entry.stylistNames > 0
					then table.concat(entry.stylistNames, " & ")
					else "?"
				text.Text = `{PLACE_TEXT[entry.place]}: {entry.name}\nstyled by {stylists}`
				text.Parent = tag
				tag.Parent = head
			end
			statue.Parent = pedestal.Parent
			statues[entry.place] = statue
			local prompt = pedestal:FindFirstChildOfClass("ProximityPrompt")
			if prompt then
				prompt:SetAttribute("HallOfFameUserId", entry.userId)
				prompt.Enabled = true
			end
		end)
	end
end

return HallOfFame
