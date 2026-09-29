--!strict
-- Server entry point. Boots each system in order; systems never start themselves.

local PlayerData = require(script.Data.PlayerData)

PlayerData.start()

print("[StyleMyBestie] Server started")
