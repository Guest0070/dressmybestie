--!strict
-- Daily quests + achievements. Other systems call Quests.bump(player, stat, amount) when
-- something happens; players claim finished quests from the Quests panel for fixed coins.
-- Stats: rounds, heartsGiven, gems, obby, heartsReceived, podiums.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Types = require(ReplicatedStorage.Shared.Types)
local Analytics = require(script.Parent.Analytics)
local PlayerData = require(script.Parent.Data.PlayerData)

local Quests = {}

-- rounds and heartsReceived already have lifetime fields in PlayerData; the rest live in `lifetime`.
local LIFETIME_IN_TABLE = { gems = true, obby = true, heartsGiven = true, podiums = true }

local function today(): number
	return os.time() // 86400
end

local function ensureToday(data: Types.PlayerData)
	local day = today()
	if data.questDay ~= day then
		data.questDay = day
		data.questProgress = {}
		data.questClaimed = {}
	end
end

function Quests.bump(player: Player, stat: string, amount: number)
	if amount <= 0 then
		return
	end
	PlayerData.update(player, function(data)
		ensureToday(data)
		data.questProgress[stat] = (data.questProgress[stat] or 0) + amount
		if LIFETIME_IN_TABLE[stat] then
			data.lifetime[stat] = (data.lifetime[stat] or 0) + amount
		end
	end)
end

local function findQuest(list: { Config.Quest }, id: string): Config.Quest?
	for _, quest in list do
		if quest.id == id then
			return quest
		end
	end
	return nil
end

local function claim(player: Player, kind: any, id: any)
	if type(id) ~= "string" or (kind ~= "daily" and kind ~= "achievement") then
		return
	end
	local quest = findQuest(if kind == "daily" then Config.DailyQuests else Config.Achievements, id)
	if not quest then
		return
	end
	local q = quest :: Config.Quest
	local paid = false
	PlayerData.update(player, function(data)
		if kind == "daily" then
			ensureToday(data)
			if data.questClaimed[q.id] or (data.questProgress[q.stat] or 0) < q.target then
				return
			end
			data.questClaimed[q.id] = true
		else
			if data.achievementsClaimed[q.id] or PlayerData.lifetimeStat(data, q.stat) < q.target then
				return
			end
			data.achievementsClaimed[q.id] = true
		end
		data.coins += q.reward
		paid = true
	end)
	if paid then
		Analytics.coins(player, q.reward, true, `Quest_{q.id}`)
		Remotes.Events.Toast:FireClient(player, `Quest complete: {q.text}! +{q.reward} coins`)
	end
end

function Quests.start()
	Remotes.Events.ClaimQuest.OnServerEvent:Connect(claim)
end

return Quests
