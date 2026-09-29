--!strict
-- Admin commands, sent from the Admin panel. Every command re-checks permission on the server,
-- so a hacked client can't use them. No typed text: fixed buttons only.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Permissions = require(script.Parent.Data.Permissions)
local PlayerData = require(script.Parent.Data.PlayerData)
local RoundManager = require(script.Parent.Round.RoundManager)

local Admin = {}

local commands: { [string]: (Player, any) -> string } = {
	StartNow = function()
		return RoundManager.adminStartNow()
	end,
	SkipPhase = function()
		return RoundManager.adminSkip()
	end,
	ForceChaos = function(_, id)
		return if type(id) == "string" then RoundManager.adminForceChaos(id) else "Pick a chaos mode."
	end,
	GiveCoins = function(player)
		PlayerData.update(player, function(data)
			data.coins += Config.Admin.CoinsGrant
		end)
		return `+{Config.Admin.CoinsGrant} coins`
	end,
	GiveXp = function(player)
		PlayerData.update(player, function(data)
			data.styleXp += Config.Admin.XpGrant
		end)
		return `+{Config.Admin.XpGrant} XP`
	end,
	DailyAgain = function(player)
		PlayerData.update(player, function(data)
			data.lastDailyRewardDay = 0
		end)
		return "Daily reward can be claimed again."
	end,
	ResetMyData = function(player)
		PlayerData.resetToTemplate(player)
		return "Your data was reset to a brand-new player."
	end,
}

local function onCommand(player: Player, command: any, arg: any)
	if not Permissions.isAdmin(player) then
		return -- silently ignore: not an admin
	end
	local handler = if type(command) == "string" then commands[command] else nil
	if not handler then
		return
	end
	local ok, message = pcall(handler, player, arg)
	Remotes.Events.Toast:FireClient(player, if ok then `[Admin] {message}` else `[Admin] Failed: {message}`)
	print(`[Admin] {player.Name} ran {command}: {message}`)
end

function Admin.start()
	Remotes.Events.AdminCommand.OnServerEvent:Connect(onCommand)
end

return Admin
