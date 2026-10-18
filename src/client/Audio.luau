--!strict
-- Client-side sound mixing and the player's saved settings.
--   * Two SoundGroups (Music, SFX) that the Settings switches mute. Kit.playSound routes every
--     UI/game sound through SFX.
--   * Music: the runway gets a beat while looks walk (kick, hi-hat, clap, built from sounds that
--     ship with Roblox) unless Config.Sounds.RunwayMusic has a track ID. Lobby music plays once
--     Config.Sounds.LobbyMusic has an ID.
--   * Settings (music, sound effects, flashing effects) are saved to the player's profile, so
--     they follow them to every server.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")

local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Signal = require(ReplicatedStorage.Shared.Signal)
local Types = require(ReplicatedStorage.Shared.Types)
local State = require(script.Parent.State)

local Audio = {}

local MUSIC_VOLUME = 0.5
local SFX_VOLUME = 1
local BEAT = {
	Kick = "rbxasset://sounds/bass.wav",
	HiHat = "rbxasset://sounds/clickfast.wav",
	Clap = "rbxasset://sounds/snap.mp3",
}
local BPM = 118

local function group(name: string, volume: number): SoundGroup
	local existing = SoundService:FindFirstChild(name)
	if existing and existing:IsA("SoundGroup") then
		return existing
	end
	local g = Instance.new("SoundGroup")
	g.Name = name
	g.Volume = volume
	g.Parent = SoundService
	return g
end

Audio.music = group("Music", MUSIC_VOLUME)
Audio.sfx = group("SFX", SFX_VOLUME)
Audio.musicOn = true
Audio.sfxOn = true
Audio.flashesOn = true
-- Fires when settings change (including when the saved ones first arrive).
Audio.Changed = Signal.new() :: Signal.Signal<>

local saveQueued = false
local function save()
	if saveQueued then
		return
	end
	saveQueued = true
	task.delay(1, function()
		saveQueued = false
		Remotes.Events.SaveSettings:FireServer({
			music = Audio.musicOn,
			sfx = Audio.sfxOn,
			flashes = Audio.flashesOn,
		})
	end)
end

local function apply()
	Audio.music.Volume = if Audio.musicOn then MUSIC_VOLUME else 0
	Audio.sfx.Volume = if Audio.sfxOn then SFX_VOLUME else 0
end

function Audio.setMusic(on: boolean)
	Audio.musicOn = on
	apply()
	save()
	Audio.Changed:Fire()
end

function Audio.setSfx(on: boolean)
	Audio.sfxOn = on
	apply()
	save()
	Audio.Changed:Fire()
end

-- Camera flashes and screen flashes (MinigameFx). Off for players sensitive to flashing light.
function Audio.setFlashes(on: boolean)
	Audio.flashesOn = on
	save()
	Audio.Changed:Fire()
end

local function hit(id: string, volume: number, pitch: number)
	local sound = Instance.new("Sound")
	sound.SoundId = id
	sound.Volume = volume
	sound.PlaybackSpeed = pitch
	sound.SoundGroup = Audio.music
	sound.Parent = SoundService
	sound.Ended:Once(function()
		sound:Destroy()
	end)
	sound:Play()
end

-- The runway beat: a simple four-on-the-floor groove while looks walk and get rated.
local function startRunwayBeat()
	local track: Sound? = nil
	local id = Config.Sounds.RunwayMusic
	if id and id ~= 0 then
		local sound = Instance.new("Sound")
		sound.Name = "RunwayMusic"
		sound.SoundId = if type(id) == "string" then id else `rbxassetid://{id}`
		sound.Looped = true
		sound.SoundGroup = Audio.music
		sound.Parent = SoundService
		track = sound
	end
	local step = 0
	local clock = 0
	local stepLength = 60 / BPM / 2 -- eighth notes
	RunService.Heartbeat:Connect(function(dt)
		local phase = State.round.phase
		local showing = phase == "Runway" or phase == "Voting"
		if track then
			if showing and not track.IsPlaying then
				track:Play()
			elseif not showing and track.IsPlaying then
				track:Stop()
			end
			return
		end
		if not showing or not Audio.musicOn then
			clock, step = 0, 0
			return
		end
		clock += dt
		while clock >= stepLength do
			clock -= stepLength
			local beat = step % 8 -- eight eighth-notes = one bar
			if beat % 2 == 0 then
				hit(BEAT.Kick, 0.55, if beat == 0 then 0.75 else 0.8)
			else
				hit(BEAT.HiHat, 0.25, 1.15)
			end
			if beat == 2 or beat == 6 then
				hit(BEAT.Clap, 0.4, 0.9)
			end
			step += 1
		end
	end)
end

local function startLobbyMusic()
	local id = Config.Sounds.LobbyMusic
	if not id or id == 0 then
		return
	end
	local music = Instance.new("Sound")
	music.Name = "LobbyMusic"
	music.SoundId = if type(id) == "string" then id else `rbxassetid://{id}`
	music.Looped = true
	music.SoundGroup = Audio.music
	music.Parent = SoundService
	-- Lobby music only in the lobby, so it doesn't fight the runway.
	local function refresh()
		local wanted = State.round.phase == "Lobby"
		if wanted and not music.IsPlaying then
			music:Play()
		elseif not wanted and music.IsPlaying then
			music:Stop()
		end
	end
	State.RoundChanged:Connect(refresh)
	refresh()
end

function Audio.start()
	-- Saved settings arrive with the player's data (once).
	local loaded = false
	local function load(data: Types.PublicData)
		if loaded or not data.settings then
			return
		end
		loaded = true
		Audio.musicOn = data.settings.music
		Audio.sfxOn = data.settings.sfx
		Audio.flashesOn = data.settings.flashes
		apply()
		Audio.Changed:Fire()
	end
	State.DataChanged:Connect(load)
	if State.data then
		load(State.data)
	end
	startRunwayBeat()
	startLobbyMusic()
end

return Audio
