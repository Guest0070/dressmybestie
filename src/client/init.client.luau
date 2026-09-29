--!strict
-- Client entry point. Starts each UI/system and wires them together.

local Catalog = require(script.UI.Catalog)
local HUD = require(script.UI.HUD)
local Moments = require(script.Moments)
local ResultsUI = require(script.UI.ResultsUI)
local ShopUI = require(script.UI.ShopUI)
local Stage = require(script.Stage)
local State = require(script.State)
local VotingUI = require(script.UI.VotingUI)

State.start()
HUD.start()
Catalog.start()
VotingUI.start()
ResultsUI.start()
ShopUI.start()
Moments.start()
Stage.start()

HUD.onOpenShop = ShopUI.open
HUD.onOpenLooks = ResultsUI.openLooks
Catalog.onRotate = Stage.rotate
VotingUI.onToast = HUD.toast
Moments.onAnnounce = function(text)
	HUD.toast(text, 6)
end

print("[StyleMyBestie] Client started")
