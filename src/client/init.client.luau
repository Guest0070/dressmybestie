--!strict
-- Client entry point. Starts each UI/system and wires them together.

local AdminPanel = require(script.UI.AdminPanel)
local Audio = require(script.Audio)
local BoothsUI = require(script.UI.BoothsUI)
local Catalog = require(script.UI.Catalog)
local HUD = require(script.UI.HUD)
local HowToPlay = require(script.UI.HowToPlay)
local Lobby = require(script.Lobby)
local LobbyUI = require(script.UI.LobbyUI)
local MinigameUI = require(script.UI.MinigameUI)
local MinigameFx = require(script.MinigameFx)
local Moments = require(script.Moments)
local QuestsUI = require(script.UI.QuestsUI)
local ReactionsUI = require(script.UI.ReactionsUI)
local ResultsUI = require(script.UI.ResultsUI)
local SettingsUI = require(script.UI.SettingsUI)
local ShopUI = require(script.UI.ShopUI)
local Stage = require(script.Stage)
local StarsUI = require(script.UI.StarsUI)
local State = require(script.State)
local VotingUI = require(script.UI.VotingUI)
local WardrobeUI = require(script.UI.WardrobeUI)

State.start()
Audio.start()
HUD.start()
LobbyUI.start()
SettingsUI.start()
Catalog.start()
VotingUI.start()
ResultsUI.start()
ShopUI.start()
HowToPlay.start()
AdminPanel.start()
QuestsUI.start()
StarsUI.start()
BoothsUI.start()
MinigameUI.start()
MinigameFx.start()
ReactionsUI.start()
WardrobeUI.start()
Moments.start()
Stage.start()
Lobby.start()

LobbyUI.onOpenShop = ShopUI.open
LobbyUI.onOpenGames = MinigameUI.togglePanel
MinigameFx.onDash = MinigameUI.onDash
LobbyUI.onOpenLooks = ResultsUI.openLooks
LobbyUI.onOpenHelp = HowToPlay.open
LobbyUI.onOpenAdmin = AdminPanel.toggle
LobbyUI.onOpenQuests = QuestsUI.open
LobbyUI.onOpenSettings = SettingsUI.toggle
LobbyUI.onCustomize = Catalog.openDressingRoom
LobbyUI.onToast = HUD.toast
LobbyUI.hasClaimableQuest = QuestsUI.hasClaimable
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
Catalog.onWardrobe = WardrobeUI.toggle
VotingUI.onToast = HUD.toast
Moments.onAnnounce = function(text)
	HUD.toast(text, 6)
end

print("[StyleMyBestie] Client started")
