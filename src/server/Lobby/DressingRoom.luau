--!strict
-- Dressing Room: in the lobby, players dress their OWN avatar from the catalog (same checks as
-- styling a mannequin), then can buy the pieces they like. Their real avatar comes back with
-- "Reset" or when they respawn. Blocked during a round, when the avatar belongs to the round.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Passes = require(script.Parent.Parent.Monetization.Passes)
local LookApplier = require(script.Parent.Parent.Styling.LookApplier)
local LookValidator = require(script.Parent.Parent.Styling.LookValidator)
local RoundManager = require(script.Parent.Parent.Round.RoundManager)
local PlayerData = require(script.Parent.Parent.Data.PlayerData)
local Appearance = require(script.Parent.Appearance)

local DressingRoom = {}

local baseDescriptions: { [Player]: HumanoidDescription } = {}
local pending: { [Player]: any } = {}
local busy: { [Player]: boolean } = {}

local function getHumanoid(player: Player): Humanoid?
	local character = player.Character
	local humanoid = if character then character:FindFirstChildOfClass("Humanoid") else nil
	return if humanoid and humanoid.Health > 0 then humanoid else nil
end

-- The player's real avatar (from their Roblox profile), fetched once per visit.
local function getRealAvatar(player: Player): HumanoidDescription?
	local cached = baseDescriptions[player]
	if cached then
		return cached
	end
	local ok, desc = pcall(Players.GetHumanoidDescriptionFromUserIdAsync, Players, player.UserId)
	if ok and desc then
		baseDescriptions[player] = desc
		return desc
	end
	local humanoid = getHumanoid(player)
	if humanoid then
		local okApplied, applied = pcall(humanoid.GetAppliedDescription, humanoid)
		if okApplied and applied then
			baseDescriptions[player] = applied
			return applied
		end
	end
	return nil
end

-- Real avatar + the skin tone / body type chosen in the lobby booths.
local function getBase(player: Player): HumanoidDescription?
	local real = getRealAvatar(player)
	local data = PlayerData.get(player)
	if not real or not data then
		return real
	end
	return Appearance.applyTo(player, real:Clone(), data)
end

local function process(player: Player)
	busy[player] = true
	while pending[player] ~= nil and player.Parent == Players do
		local raw = pending[player]
		pending[player] = nil
		if RoundManager.isInRound(player) then
			break
		end
		local validated = LookValidator.validate(raw, Passes.owns(player, "VIP"))
		local base = getBase(player)
		local humanoid = getHumanoid(player)
		if base and humanoid and not RoundManager.isInRound(player) then
			LookApplier.apply(humanoid, LookApplier.build(base, validated))
			local seq = if type(raw) == "table" and type(raw.seq) == "number" then raw.seq else nil
			Remotes.Events.LookSync:FireClient(player, player.UserId, validated.look, seq)
		end
		task.wait(Config.Limits.LookUpdateInterval)
	end
	busy[player] = nil
	pending[player] = nil
end

function DressingRoom.start()
	Remotes.Events.SetOwnLook.OnServerEvent:Connect(function(player, raw)
		if RoundManager.isInRound(player) then
			return
		end
		pending[player] = raw
		if not busy[player] then
			task.spawn(process, player)
		end
	end)
	Remotes.Events.ResetOwnLook.OnServerEvent:Connect(function(player)
		if RoundManager.isInRound(player) then
			return
		end
		local base = getBase(player)
		local humanoid = getHumanoid(player)
		if base and humanoid then
			LookApplier.apply(humanoid, base)
		end
	end)
	Players.PlayerRemoving:Connect(function(player)
		baseDescriptions[player] = nil
		pending[player] = nil
		busy[player] = nil
	end)
end

return DressingRoom
