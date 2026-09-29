--!strict
-- The client's copy of what the server told it. UI modules read from here and listen for changes.
-- Nothing here is trusted by the server; it only drives what the player sees.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Signal = require(ReplicatedStorage.Shared.Signal)
local Types = require(ReplicatedStorage.Shared.Types)

local State = {}

State.player = Players.LocalPlayer
State.round = { phase = "Lobby", roundNumber = 0 } :: Types.RoundState
State.data = nil :: Types.PublicData?
-- Looks from the last results screen, kept so "Buy this look" works in the lobby too.
State.lastShopLooks = {} :: { Types.ShopLook }

State.RoundChanged = Signal.new() :: Signal.Signal<Types.RoundState, Types.RoundPhase?>
State.DataChanged = Signal.new() :: Signal.Signal<Types.PublicData>

-- True while the player is in the lobby Dressing Room (dressing their own avatar).
State.dressingRoom = false
State.DressingRoomChanged = Signal.new() :: Signal.Signal<boolean>

function State.setDressingRoom(open: boolean)
	if State.dressingRoom ~= open then
		State.dressingRoom = open
		State.DressingRoomChanged:Fire(open)
	end
end

-- True if I'm playing in the current round (not a spectator / late joiner).
function State.isParticipant(): boolean
	local names = State.round.names
	return names ~= nil and names[tostring(State.player.UserId)] ~= nil
end

-- Lobby things (shop, quests, booths, dressing room) are open in the lobby, and for spectators
-- while the round is still in the styling part (they're moved to the audience for the show).
function State.canUseLobby(): boolean
	local phase = State.round.phase
	if phase == "Lobby" then
		return true
	end
	if State.isParticipant() then
		return false
	end
	return phase == "Pairing" or phase == "ThemeReveal" or phase == "Styling"
end

-- User ID of the player I'm styling right now, if any.
function State.myTarget(): number?
	local assignments = State.round.assignments
	return if assignments then assignments[tostring(State.player.UserId)] else nil
end

function State.nameOf(userId: number): string
	local names = State.round.names
	local name = if names then names[tostring(userId)] else nil
	if name then
		return name
	end
	local player = Players:GetPlayerByUserId(userId)
	return if player then player.DisplayName else "Someone"
end

local function setRound(round: Types.RoundState)
	local previous: Types.RoundPhase = State.round.phase :: Types.RoundPhase
	State.round = round
	if round.shopLooks and #round.shopLooks > 0 then
		State.lastShopLooks = round.shopLooks
	end
	State.RoundChanged:Fire(round, if previous ~= round.phase then previous else nil)
end

local function setData(data: Types.PublicData)
	State.data = data
	State.DataChanged:Fire(data)
end

function State.start()
	Remotes.Events.RoundState.OnClientEvent:Connect(setRound)
	Remotes.Events.DataChanged.OnClientEvent:Connect(setData)
	task.spawn(function()
		local ok, round = pcall(Remotes.Functions.GetRoundState.InvokeServer, Remotes.Functions.GetRoundState)
		if ok and round then
			setRound(round)
		end
		local okData, data = pcall(Remotes.Functions.GetMyData.InvokeServer, Remotes.Functions.GetMyData)
		if okData and data then
			setData(data)
		end
	end)
end

return State
