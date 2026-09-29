--!strict
-- The round state machine: Lobby -> Pairing -> ThemeReveal -> Styling -> Runway -> Voting -> Results.
-- Everything is server-authoritative; clients only see RoundState broadcasts.
-- Chaos rounds are just flags on the round (see Config.ChaosModifiers), not separate code paths.
-- Players can leave at ANY point: every step re-checks who is still here.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Types = require(ReplicatedStorage.Shared.Types)
local Analytics = require(script.Parent.Parent.Analytics)
local PlayerData = require(script.Parent.Parent.Data.PlayerData)
local Passes = require(script.Parent.Parent.Monetization.Passes)
local LookApplier = require(script.Parent.Parent.Styling.LookApplier)
local LookValidator = require(script.Parent.Parent.Styling.LookValidator)
local Voting = require(script.Parent.Parent.Voting.Voting)
local Effects = require(script.Parent.Effects)
local Map = require(script.Parent.Map)
local Pairing = require(script.Parent.Pairing)
local Rewards = require(script.Parent.Rewards)

type ValidatedLook = LookValidator.ValidatedLook
type Phase = Types.RoundPhase

-- One entry per player in the round. Keyed by the player who WEARS the look.
type Participant = {
	player: Player,
	userId: number,
	name: string,
	original: HumanoidDescription, -- their own outfit, restored after the round
	boothIndex: number, -- booth where their mannequin stands
	mannequin: Model?,
	look: ValidatedLook, -- what their stylist has built so far
	stylists: { Player }, -- everyone who styled this look (more than one after a swap)
	walked: boolean,
}

type ChaosModifier = Config.ChaosModifier

local RoundManager = {}

local state: Types.RoundState = { phase = "Lobby", roundNumber = 0 }
local participants: { [Player]: Participant } = {}
local assignments: { [Player]: Player } = {} -- stylist -> target (wearer)
local chaos: ChaosModifier? = nil
local recentThemes: { string } = {}
local pendingLooks: { [Player]: { raw: any, stylist: Player } } = {} -- keyed by target
local lookWorkers: { [Player]: boolean } = {}
local friendCache: { [string]: boolean } = {}
local mannequinFolder: Folder

---------------------------------------------------------------------------------------------------
-- Helpers
---------------------------------------------------------------------------------------------------

local function isHere(player: Player): boolean
	return player.Parent == Players
end

local function getHumanoid(player: Player): Humanoid?
	local character = player.Character
	local humanoid = if character then character:FindFirstChildOfClass("Humanoid") else nil
	return if humanoid and humanoid.Health > 0 then humanoid else nil
end

local function teleport(player: Player, cframe: CFrame)
	local character = player.Character
	if character and isHere(player) then
		character:PivotTo(cframe)
	end
end

-- Freeze (speed 0) or release a player. Clients also disable their controls outside the lobby.
local function setMovement(player: Player, speed: number)
	local humanoid = getHumanoid(player)
	if not humanoid then
		return
	end
	humanoid.WalkSpeed = speed
	if humanoid.UseJumpPower then
		humanoid.JumpPower = if speed > 0 then 50 else 0
	else
		humanoid.JumpHeight = if speed > 0 then 7.2 else 0
	end
end

local function participantList(): { Participant }
	local list = {}
	for _, p in participants do
		table.insert(list, p)
	end
	return list
end

local function countParticipants(): number
	local n = 0
	for _ in participants do
		n += 1
	end
	return n
end

local function minPlayers(): number
	return if RunService:IsStudio() then Config.StudioMinPlayers else Config.MinPlayersToStart
end

-- Players who can join the next round: data loaded and a living character.
local function eligiblePlayers(): { Player }
	local list = {}
	for _, player in Players:GetPlayers() do
		if PlayerData.isLoaded(player) and getHumanoid(player) then
			table.insert(list, player)
		end
	end
	return list
end

local function friendKey(a: Player, b: Player): string
	return if a.UserId < b.UserId then `{a.UserId}_{b.UserId}` else `{b.UserId}_{a.UserId}`
end

-- Friend checks are web calls, so they run in the background when someone joins;
-- pairing only reads the cache and never waits.
local function prefetchFriends(newPlayer: Player)
	for _, other in Players:GetPlayers() do
		if other ~= newPlayer then
			task.spawn(function()
				local ok, result = pcall(newPlayer.IsFriendsWithAsync, newPlayer, other.UserId)
				friendCache[friendKey(newPlayer, other)] = ok and result == true
			end)
		end
	end
end

local function areFriends(a: Player, b: Player): boolean
	return friendCache[friendKey(a, b)] == true
end

-- Waits up to `seconds`. Returns false early if shouldStop() becomes true.
local function waitFor(seconds: number, shouldStop: (() -> boolean)?): boolean
	local deadline = os.clock() + seconds
	while os.clock() < deadline do
		if shouldStop and shouldStop() then
			return false
		end
		task.wait(0.2)
	end
	return true
end

local function noOneLeft(): boolean
	return countParticipants() == 0
end

---------------------------------------------------------------------------------------------------
-- State broadcast
---------------------------------------------------------------------------------------------------

local function assignmentPayload(): { [string]: number }
	local payload = {}
	for stylist, target in assignments do
		payload[tostring(stylist.UserId)] = target.UserId
	end
	return payload
end

local function broadcast()
	Remotes.Events.RoundState:FireAllClients(state)
end

-- Per-phase fields are cleared on every phase change; round-wide ones (theme, chaos, names) stay.
local function setPhase(phase: Phase, duration: number?, fields: { [string]: any }?)
	state.phase = phase
	state.endsAt = if duration then Workspace:GetServerTimeNow() + duration else nil
	state.assignments = if next(assignments) then assignmentPayload() else nil
	state.runwayWearer = nil
	state.runwayStylists = nil
	state.candidates = nil
	state.podium = nil
	state.shopLooks = nil
	state.message = nil
	if fields then
		for key, value in fields do
			(state :: any)[key] = value
		end
	end
	broadcast()
end

local function toast(player: Player, text: string)
	if isHere(player) then
		Remotes.Events.Toast:FireClient(player, text)
	end
end

---------------------------------------------------------------------------------------------------
-- Theme + chaos
---------------------------------------------------------------------------------------------------

local function pickTheme(anyVip: boolean): string
	local featured = Config.featuredTheme()
	if featured and not table.find(recentThemes, featured) and math.random() < Config.FeaturedThemeChance then
		table.insert(recentThemes, featured)
		return featured
	end
	local options = {}
	for _, theme in Config.Themes do
		if (not theme.vip or anyVip) and not table.find(recentThemes, theme.name) then
			table.insert(options, theme.name)
		end
	end
	if #options == 0 then
		for _, theme in Config.Themes do
			if not theme.vip or anyVip then
				table.insert(options, theme.name)
			end
		end
	end
	local name = options[math.random(1, #options)]
	table.insert(recentThemes, name)
	while #recentThemes > Config.ThemeNoRepeat do
		table.remove(recentThemes, 1)
	end
	return name
end

local function pickChaos(roundNumber: number, playerCount: number): (ChaosModifier?, Types.ChaosInfo?)
	if roundNumber % Config.ChaosEveryRounds ~= 0 or math.random() > Config.ChaosChance then
		return nil, nil
	end
	local options = {}
	for _, modifier in Config.ChaosModifiers do
		if playerCount >= modifier.minPlayers then
			table.insert(options, modifier)
		end
	end
	if #options == 0 then
		return nil, nil
	end
	local modifier = options[math.random(1, #options)]
	local info: Types.ChaosInfo = {
		id = modifier.id,
		displayName = modifier.displayName,
		description = modifier.description,
		reverseVoting = modifier.reverseVoting,
	}
	if modifier.oneColor then
		local color = Config.ChaosColors[math.random(1, #Config.ChaosColors)]
		info.colorName = color.name
		info.description = `Style using only {color.name}!`
	end
	return modifier, info
end

---------------------------------------------------------------------------------------------------
-- Styling: mannequins + look updates
---------------------------------------------------------------------------------------------------

local function applyToMannequin(p: Participant)
	local mannequin = p.mannequin
	local humanoid = if mannequin then mannequin:FindFirstChildOfClass("Humanoid") else nil
	if humanoid then
		LookApplier.apply(humanoid, LookApplier.build(p.original, p.look))
	end
end

local function createMannequin(p: Participant)
	local ok, model = pcall(
		Players.CreateHumanoidModelFromDescriptionAsync,
		Players,
		LookApplier.blankFrom(p.original),
		Enum.HumanoidRigType.R15
	)
	if not ok or not model then
		warn(`[Round] Couldn't create mannequin for {p.name}: {model}`)
		return
	end
	if participants[p.player] ~= p or state.phase ~= "Styling" then
		model:Destroy() -- they left, or styling ended while we were building
		return
	end
	model.Name = `Mannequin_{p.userId}`
	model:SetAttribute("TargetUserId", p.userId)
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	end
	local root = model:FindFirstChild("HumanoidRootPart")
	if root and root:IsA("BasePart") then
		root.Anchored = true
	end
	model:PivotTo(Map.booth(p.boothIndex).mannequin)
	model.Parent = mannequinFolder
	p.mannequin = model
	-- The stylist may have picked items while the mannequin was loading.
	if #p.look.look.assetIds > 0 or p.look.look.shoeBundleId then
		applyToMannequin(p)
	end
end

-- Only the newest look per target is processed, one at a time, at most every LookUpdateInterval.
local function processLooks(target: Player)
	lookWorkers[target] = true
	while true do
		local pending = pendingLooks[target]
		local p = participants[target]
		if not pending or not p or state.phase ~= "Styling" then
			break
		end
		pendingLooks[target] = nil

		local validated = LookValidator.validate(pending.raw, Passes.owns(pending.stylist, "VIP"))
		-- Re-check after yielding: the round may have moved on, or the stylist swapped away.
		if
			participants[target] ~= p
			or state.phase ~= "Styling"
			or assignments[pending.stylist] ~= target
		then
			continue
		end
		p.look = validated
		if not table.find(p.stylists, pending.stylist) then
			table.insert(p.stylists, pending.stylist)
		end
		-- Echo the client's sequence number so it only trusts the reply to its newest edit.
		local seq = if type(pending.raw) == "table" and type(pending.raw.seq) == "number"
			then pending.raw.seq
			else nil
		Remotes.Events.LookSync:FireClient(pending.stylist, p.userId, validated.look, seq)
		applyToMannequin(p)
		task.wait(Config.Limits.LookUpdateInterval)
	end
	pendingLooks[target] = nil
	lookWorkers[target] = nil
end

local function onSetLook(stylist: Player, raw: any)
	local target = assignments[stylist]
	if RunService:IsStudio() then
		local count = if type(raw) == "table" and type(raw.assetIds) == "table" then #raw.assetIds else -1
		print(`[Round] {stylist.Name} sent a look with {count} item(s); phase={state.phase}, target={target}`)
	end
	if state.phase ~= "Styling" then
		return
	end
	if not target or not participants[target] then
		return
	end
	pendingLooks[target] = { raw = raw, stylist = stylist }
	if not lookWorkers[target] then
		task.spawn(processLooks, target)
	end
end

local function doSwap()
	local swapped = Pairing.swap(assignments)
	if not swapped then
		return
	end
	assignments = swapped
	for stylist, target in assignments do
		local p = participants[target]
		if not p then
			continue
		end
		teleport(stylist, Map.booth(p.boothIndex).stand)
		Remotes.Events.LookSync:FireClient(stylist, p.userId, p.look.look)
		toast(stylist, `SWAP! You're now finishing {p.name}'s look!`)
	end
	state.assignments = assignmentPayload()
	broadcast()
end

---------------------------------------------------------------------------------------------------
-- Leaving mid-round
---------------------------------------------------------------------------------------------------

local function onPlayerRemoving(player: Player)
	local p = participants[player]
	if p then
		participants[player] = nil
		if p.mannequin then
			p.mannequin:Destroy()
		end
		Voting.removeCandidate(p.userId)
		-- Whoever was styling them now has no one to style.
		for stylist, target in assignments do
			if target == player and stylist ~= player then
				assignments[stylist] = nil
				toast(stylist, `{p.name} left the game. Sit tight, you'll still get round rewards!`)
			end
		end
	end
	-- If they were a stylist, the look they started stays as it is.
	assignments[player] = nil
	pendingLooks[player] = nil
	if state.phase ~= "Lobby" then
		state.assignments = if next(assignments) then assignmentPayload() else nil
		broadcast()
	end
end

-- Respawned mid-round (fell, reset): put them back where the round needs them.
local function onCharacterAdded(player: Player)
	if not participants[player] then
		return
	end
	task.wait(0.5) -- let the character finish loading
	local phase = state.phase
	if phase == "Styling" then
		local target = assignments[player]
		local p = if target then participants[target] else nil
		if p then
			teleport(player, Map.booth(p.boothIndex).stand)
		end
		setMovement(player, 0)
	elseif phase == "Runway" or phase == "Voting" or phase == "Results" then
		teleport(player, Map.audienceCFrame())
		setMovement(player, 0)
	end
end

---------------------------------------------------------------------------------------------------
-- Phases
---------------------------------------------------------------------------------------------------

local function lobby()
	-- Everyone who isn't in a round is free to walk around, shop and claim rewards.
	while true do
		local need = minPlayers()
		local lastCount = -1
		while #eligiblePlayers() < need do
			local count = #eligiblePlayers()
			if count ~= lastCount then
				lastCount = count
				setPhase("Lobby", nil, { message = `Waiting for players ({count}/{need})` })
			end
			task.wait(1)
		end
		setPhase("Lobby", Config.Timings.Lobby, { message = "Next round starting soon!" })
		local finished = waitFor(Config.Timings.Lobby, function()
			return #eligiblePlayers() < need
		end)
		if finished then
			return
		end
	end
end

-- Builds participants + assignments. Returns false if too many people left while loading.
local function setupRound(): boolean
	local players = eligiblePlayers()
	if #players < minPlayers() then
		return false
	end
	state.roundNumber += 1
	participants = {}
	assignments = {}

	-- Save everyone's own outfit first (yields), in parallel.
	local originals: { [Player]: HumanoidDescription } = {}
	local remaining = #players
	for _, player in players do
		task.spawn(function()
			originals[player] = LookApplier.saveOriginal(player) :: HumanoidDescription
			remaining -= 1
		end)
	end
	local deadline = os.clock() + 10
	while remaining > 0 and os.clock() < deadline do
		task.wait(0.1)
	end

	local present = {}
	for _, player in players do
		if isHere(player) and originals[player] then
			table.insert(present, player)
		end
	end
	if #present < minPlayers() then
		return false
	end

	local names: { [string]: string } = {}
	local anyVip = false
	for index, player in present do
		participants[player] = {
			player = player,
			userId = player.UserId,
			name = player.DisplayName,
			original = originals[player],
			boothIndex = index,
			look = LookValidator.empty(),
			stylists = {},
			walked = false,
		}
		names[tostring(player.UserId)] = player.DisplayName
		anyVip = anyVip or Passes.owns(player, "VIP")
		Analytics.funnelStep(player, 2)
	end

	assignments = Pairing.pair(present, areFriends)
	for stylist, target in assignments do
		table.insert(participants[target].stylists, stylist)
	end

	local chaosInfo
	chaos, chaosInfo = pickChaos(state.roundNumber, #present)
	state.theme = pickTheme(anyVip)
	state.chaos = chaosInfo
	state.names = names
	return true
end

local function styling()
	for stylist, target in assignments do
		local p = participants[target]
		if p then
			teleport(stylist, Map.booth(p.boothIndex).stand)
			setMovement(stylist, 0)
		end
	end

	-- Phase must be "Styling" before mannequins are built (createMannequin checks it).
	setPhase("Styling", Config.Timings.Styling)
	for _, p in participantList() do
		task.spawn(createMannequin, p)
	end
	local startedAt = os.clock()
	local swapped = false
	local modifier = chaos
	waitFor(Config.Timings.Styling, function()
		if
			modifier
			and modifier.swapMidRound
			and not swapped
			and os.clock() - startedAt >= Config.Timings.SwapAt
		then
			swapped = true
			doSwap()
		end
		return noOneLeft()
	end)
end

local function runway()
	setPhase("Runway", nil)
	pendingLooks = {}
	for _, p in participantList() do
		if p.mannequin then
			p.mannequin:Destroy()
			p.mannequin = nil
		end
		teleport(p.player, Map.audienceCFrame())
		setMovement(p.player, 0)
	end

	local order = participantList()
	for i = #order, 2, -1 do
		local j = math.random(1, i)
		order[i], order[j] = order[j], order[i]
	end

	for _, p in order do
		local player = p.player
		local humanoid = getHumanoid(player)
		if participants[player] ~= p or not humanoid then
			continue
		end

		local desc = LookApplier.build(p.original, p.look)
		local data = PlayerData.get(player)
		local equipped: { [string]: string } = if data then data.equipped else {}
		local walk = if equipped.Walk then Config.getCosmetic(equipped.Walk) else nil
		if
			walk
			and walk.animationId
			and walk.animationId > 0
			and PlayerData.ownsCosmetic(player, walk.id)
		then
			desc.WalkAnimation = walk.animationId
		end
		local pose = if equipped.Pose then Config.getCosmetic(equipped.Pose) else nil
		if
			pose
			and pose.animationId
			and pose.animationId > 0
			and PlayerData.ownsCosmetic(player, pose.id)
		then
			local emotes = desc:GetEmotes()
			emotes.Signature = { pose.animationId }
			desc:SetEmotes(emotes)
		end
		LookApplier.apply(humanoid, desc)
		if participants[player] ~= p then
			continue -- left while the look was loading
		end

		local stylistNames = {}
		for _, stylist in p.stylists do
			table.insert(stylistNames, stylist.DisplayName)
		end
		teleport(player, Map.runwayStart())
		setPhase("Runway", Config.Timings.RunwayPerPlayer, {
			runwayWearer = p.userId,
			runwayStylists = stylistNames,
		})

		local entrance = equipped.Entrance
		local character = player.Character
		if character and entrance and PlayerData.ownsCosmetic(player, entrance) then
			Effects.playEntrance(character, entrance)
		end
		Remotes.Events.RunwayEffect:FireAllClients(p.userId, Passes.owns(player, "VIP"))

		setMovement(player, Config.RunwayWalkSpeed)
		local walker = getHumanoid(player)
		if walker then
			walker:MoveTo(Map.runwayEnd().Position)
		end
		waitFor(Config.Timings.RunwayPerPlayer, function()
			return participants[player] ~= p
		end)
		setMovement(player, 0)
		p.walked = true
	end
end

local function voting(): { [number]: number }
	local candidates: { Participant } = {}
	for _, p in participantList() do
		if p.walked then
			table.insert(candidates, p)
		end
	end
	local ids = {}
	for index, p in candidates do
		table.insert(ids, p.userId)
		teleport(p.player, Map.lineupCFrame(index, #candidates))
	end

	Voting.begin(ids, function(voter: Player)
		-- No hearts for your own look, or for a look you styled.
		local excluded = { [voter.UserId] = true }
		for _, p in participants do
			if table.find(p.stylists, voter) then
				excluded[p.userId] = true
			end
		end
		return excluded
	end)

	-- With 1 look (Studio solo test) there is nothing to vote on; keep it short.
	local duration = if #candidates >= 2 then Config.Timings.Voting else 5
	setPhase("Voting", duration, { candidates = ids })
	waitFor(duration, noOneLeft)
	return Voting.finish()
end

local function results(hearts: { [number]: number })
	local ranked: { Participant } = {}
	local tiebreak: { [Participant]: number } = {}
	for _, p in participantList() do
		if p.walked then
			table.insert(ranked, p)
			tiebreak[p] = math.random()
		end
	end
	-- Most hearts first; ties broken randomly (never alphabetically, never by join order).
	table.sort(ranked, function(a, b)
		local ha, hb = hearts[a.userId] or 0, hearts[b.userId] or 0
		if ha ~= hb then
			return ha > hb
		end
		return tiebreak[a] < tiebreak[b]
	end)

	local podium: { Types.PodiumEntry } = {}
	local lookResults: { Rewards.LookResult } = {}
	local shopLooks: { Types.ShopLook } = {}
	for index, p in ranked do
		local count = hearts[p.userId] or 0
		-- Only looks that got hearts make the podium; nobody is ever shown as "last".
		local place = if index <= 3 and count > 0 then index else nil
		if place then
			local stylistNames = {}
			for _, stylist in p.stylists do
				table.insert(stylistNames, stylist.DisplayName)
			end
			table.insert(podium, {
				place = place,
				wearerUserId = p.userId,
				wearerName = p.name,
				stylistNames = stylistNames,
				hearts = count,
			})
			local spot = Map.podiumCFrame(place)
			if spot then
				teleport(p.player, spot)
			end
		end
		table.insert(lookResults, {
			wearer = p.player,
			wearerUserId = p.userId,
			stylists = p.stylists,
			hearts = count,
			place = place,
		})
		table.insert(shopLooks, { wearerUserId = p.userId, wearerName = p.name, look = p.look.look })
	end

	local present = {}
	for player in participants do
		table.insert(present, player)
	end
	Rewards.grant(present, lookResults)

	setPhase("Results", Config.Timings.Results, { podium = podium, shopLooks = shopLooks })
	waitFor(Config.Timings.Results)
end

-- Always runs at the end of a round, even after an error, so nobody is left stuck in a booth
-- or wearing someone else's outfit.
local function cleanup()
	for _, p in participantList() do
		local player = p.player
		task.spawn(function()
			LookApplier.restore(player)
		end)
		teleport(player, Map.lobbyCFrame())
		setMovement(player, Config.DefaultWalkSpeed)
		if p.mannequin then
			p.mannequin:Destroy()
		end
	end
	mannequinFolder:ClearAllChildren()
	participants = {}
	assignments = {}
	pendingLooks = {}
	chaos = nil
	state.theme = nil
	state.chaos = nil
	state.names = nil
	Voting.finish()
end

local function playRound()
	lobby()
	if not setupRound() then
		return
	end

	setPhase("Pairing", Config.Timings.Pairing)
	waitFor(Config.Timings.Pairing, noOneLeft)

	setPhase("ThemeReveal", Config.Timings.ThemeReveal)
	waitFor(Config.Timings.ThemeReveal, noOneLeft)

	styling()
	if noOneLeft() then
		return
	end
	runway()
	if noOneLeft() then
		return
	end
	local hearts = voting()
	results(hearts)
end

function RoundManager.start()
	mannequinFolder = Instance.new("Folder")
	mannequinFolder.Name = "Mannequins"
	mannequinFolder.Parent = Workspace

	Remotes.Events.SetMannequinLook.OnServerEvent:Connect(onSetLook)
	Remotes.Functions.GetRoundState.OnServerInvoke = function()
		return state
	end
	Players.PlayerRemoving:Connect(function(player)
		onPlayerRemoving(player)
		local id = tostring(player.UserId)
		for key in friendCache do
			local low, high = string.match(key, "^(%d+)_(%d+)$")
			if low == id or high == id then
				friendCache[key] = nil
			end
		end
	end)
	local function watchCharacter(player: Player)
		player.CharacterAdded:Connect(function()
			onCharacterAdded(player)
		end)
		prefetchFriends(player)
	end
	for _, player in Players:GetPlayers() do
		watchCharacter(player)
	end
	Players.PlayerAdded:Connect(watchCharacter)

	task.spawn(function()
		while true do
			xpcall(playRound, function(err)
				warn(`[Round] Round crashed, cleaning up: {err}\n{debug.traceback()}`)
			end)
			xpcall(cleanup, function(err)
				warn(`[Round] Cleanup failed: {err}`)
			end)
			task.wait(1)
		end
	end)
end

return RoundManager
