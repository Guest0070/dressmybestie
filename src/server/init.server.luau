--!strict
-- Server entry point. Boots each system in order; systems never start themselves.

local Analytics = require(script.Analytics)
local LookApplier = require(script.Styling.LookApplier)
local Map = require(script.Round.Map)
local Passes = require(script.Monetization.Passes)
local PlayerData = require(script.Data.PlayerData)
local Receipts = require(script.Monetization.Receipts)
local RoundManager = require(script.Round.RoundManager)
local Shop = require(script.Monetization.Shop)
local Voting = require(script.Voting.Voting)

Map.ensure()
Passes.start()
Analytics.start() -- before PlayerData so it sees every Loaded event
PlayerData.start()
LookApplier.start()
Voting.start()
Shop.start()
Receipts.start()
RoundManager.start()

print("[StyleMyBestie] Server started")
