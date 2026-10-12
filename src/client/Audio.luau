--!strict
-- Client-side sound mixing: two SoundGroups (Music, SFX) that the Settings toggles mute.
-- Kit.playSound routes every UI/game sound through SFX. Lobby music plays through Music once
-- Config.Sounds.LobbyMusic has an audio ID (0 = no music yet).
-- Settings last for this play session only (they aren't saved to the profile yet).

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")

local Config = require(ReplicatedStorage.Shared.Config)
local State = require(script.Parent.State)

local Audio = {}

local MUSIC_VOLUME = 0.5
local SFX_VOLUME = 1

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

function Audio.setMusic(on: boolean)
	Audio.musicOn = on
	Audio.music.Volume = if on then MUSIC_VOLUME else 0
end

function Audio.setSfx(on: boolean)
	Audio.sfxOn = on
	Audio.sfx.Volume = if on then SFX_VOLUME else 0
end

function Audio.start()
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

return Audio
