--!strict
-- Client entry point. Starts each UI/system and wires them together.

local AdminPanel = require(script.UI.AdminPanel)
local BoothsUI = require(script.UI.BoothsUI)
local Catalog = require(script.UI.Catalog)
local HUD = require(script.UI.HUD)
local HowToPlay = require(script.UI.HowToPlay)
local Lobby = require(script.Lobby)
local Moments = require(script.Moments)
local QuestsUI = require(script.UI.QuestsUI)
local ResultsUI = require(script.UI.ResultsUI)
local ShopUI = require(script.UI.ShopUI)
local Stage = require(script.Stage)
local StarsUI = require(script.UI.StarsUI)
local State = require(script.State)
local VotingUI = require(script.UI.VotingUI)

State.start()
HUD.start()
Catalog.start()
VotingUI.start()
ResultsUI.start()
ShopUI.start()
HowToPlay.start()
AdminPanel.start()
QuestsUI.start()
StarsUI.start()
BoothsUI.start()
Moments.start()
Stage.start()
Lobby.start()

HUD.onOpenShop = ShopUI.open
HUD.onOpenLooks = ResultsUI.openLooks
HUD.onOpenHelp = HowToPlay.open
HUD.onOpenAdmin = AdminPanel.toggle
HUD.onOpenQuests = QuestsUI.open
HUD.hasClaimableQuest = QuestsUI.hasClaimable
Lobby.onHallOfFame = function(userId)
	for _, shopLook in State.lastShopLooks do
		if shopLook.wearerUserId == userId then
			ResultsUI.openLooks({ shopLook })
			return
		end
	end
	HUD.toast("That look is from before you joined. Play a round to see new ones!")
end
Catalog.onRotate = Stage.rotate
Catalog.onBuyOutfit = function(look)
	ResultsUI.openLooks({ { wearerUserId = State.player.UserId, wearerName = "Your outfit", look = look } })
end
ShopUI.onDressingRoom = Catalog.openDressingRoom
VotingUI.onToast = HUD.toast
Moments.onAnnounce = function(text)
	HUD.toast(text, 6)
end

print("[StyleMyBestie] Client started")
