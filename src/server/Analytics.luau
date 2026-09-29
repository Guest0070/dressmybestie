--!strict
-- Funnel + economy analytics. View in Creator Dashboard -> your game -> Analytics.
-- Onboarding funnel: 1 Joined -> 2 First round started -> 3 First round finished -> 4 Second round finished.
-- Purchases are logged as a custom event so they can be compared against the funnel.

local AnalyticsService = game:GetService("AnalyticsService")

local PlayerData = require(script.Parent.Data.PlayerData)

local Analytics = {}

local STEP_NAMES = {
	"Joined",
	"First Round Started",
	"First Round Finished",
	"Second Round Finished",
}

-- Each onboarding step is logged once per player ever, in order.
function Analytics.funnelStep(player: Player, step: number)
	local data = PlayerData.get(player)
	if not data or data.funnelStep >= step then
		return
	end
	PlayerData.update(player, function(d)
		d.funnelStep = step
	end)
	pcall(function()
		AnalyticsService:LogOnboardingFunnelStepEvent(player, step, STEP_NAMES[step])
	end)
end

function Analytics.roundFinished(player: Player)
	local data = PlayerData.get(player)
	if not data then
		return
	end
	-- roundsPlayed was already incremented by the caller.
	if data.roundsPlayed >= 2 then
		Analytics.funnelStep(player, 4)
	elseif data.roundsPlayed >= 1 then
		Analytics.funnelStep(player, 3)
	end
end

function Analytics.purchase(player: Player, itemName: string, robux: number)
	pcall(function()
		AnalyticsService:LogCustomEvent(player, "Purchase", robux, {
			[Enum.AnalyticsCustomFieldKeys.CustomField01.Name] = itemName,
		})
	end)
end

function Analytics.coins(player: Player, amount: number, isSource: boolean, reason: string)
	local data = PlayerData.get(player)
	if not data or amount <= 0 then
		return
	end
	pcall(function()
		AnalyticsService:LogEconomyEvent(
			player,
			if isSource then Enum.AnalyticsEconomyFlowType.Source else Enum.AnalyticsEconomyFlowType.Sink,
			"Coins",
			amount,
			data.coins,
			if isSource
				then Enum.AnalyticsEconomyTransactionType.Gameplay.Name
				else Enum.AnalyticsEconomyTransactionType.Shop.Name,
			reason
		)
	end)
end

function Analytics.start()
	PlayerData.Loaded:Connect(function(player)
		Analytics.funnelStep(player, 1)
	end)
end

return Analytics
