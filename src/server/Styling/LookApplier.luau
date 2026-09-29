--!strict
-- Builds HumanoidDescriptions from validated looks and applies them (mannequin or real avatar).
-- Also remembers each player's own outfit so it can be put back after the round.

local Players = game:GetService("Players")

local LookValidator = require(script.Parent.LookValidator)

type ValidatedLook = LookValidator.ValidatedLook

local LookApplier = {}

local originals: { [Player]: HumanoidDescription } = {}

local function getHumanoid(player: Player): Humanoid?
	local character = player.Character
	return if character then character:FindFirstChildOfClass("Humanoid") else nil
end

-- A copy of the wearer's body (skin, head, body shape, face, animations) with all clothing removed.
-- Body parts are never changed by a look: that is what blocks body/skin swaps.
function LookApplier.blankFrom(original: HumanoidDescription): HumanoidDescription
	local desc = original:Clone()
	desc:SetAccessories({}, true)
	desc.Shirt = 0
	desc.Pants = 0
	desc.GraphicTShirt = 0
	desc:SetEmotes({})
	desc:SetEquippedEmotes({})
	return desc
end

function LookApplier.build(original: HumanoidDescription, look: ValidatedLook): HumanoidDescription
	local desc = LookApplier.blankFrom(original)
	desc:SetAccessories(look.accessories :: any, true)
	for property, id in look.classic do
		(desc :: any)[property] = id
	end
	if look.emoteId then
		desc:SetEmotes({ Pose = { look.emoteId } })
		desc:SetEquippedEmotes({ { Slot = 1, Name = "Pose" } } :: any)
	end
	return desc
end

-- ApplyDescriptionAsync yields and can fail (e.g. a layered item that doesn't fit this body).
-- On failure we retry without layered clothing so the look still mostly shows up.
function LookApplier.apply(humanoid: Humanoid, desc: HumanoidDescription): boolean
	local ok, err = pcall(humanoid.ApplyDescriptionAsync, humanoid, desc)
	if ok then
		return true
	end
	warn(`[LookApplier] ApplyDescriptionAsync failed, retrying without layered clothing: {err}`)
	local fallback = desc:Clone()
	local rigidOnly = {}
	for _, accessory in fallback:GetAccessories(true) do
		if not accessory.IsLayered then
			table.insert(rigidOnly, accessory)
		end
	end
	fallback:SetAccessories(rigidOnly, true)
	return (pcall(humanoid.ApplyDescriptionAsync, humanoid, fallback))
end

-- Call before touching a player's avatar in a round.
function LookApplier.saveOriginal(player: Player): HumanoidDescription?
	local humanoid = getHumanoid(player)
	if not humanoid then
		return nil
	end
	local ok, desc = pcall(humanoid.GetAppliedDescription, humanoid)
	if ok and desc then
		originals[player] = desc
		return desc
	end
	return nil
end

function LookApplier.getOriginal(player: Player): HumanoidDescription?
	return originals[player]
end

-- Put the player's own outfit back. Safe to call if they respawned or left.
function LookApplier.restore(player: Player)
	local original = originals[player]
	originals[player] = nil
	local humanoid = getHumanoid(player)
	if original and humanoid and player.Parent == Players then
		LookApplier.apply(humanoid, original)
	end
end

function LookApplier.start()
	Players.PlayerRemoving:Connect(function(player)
		originals[player] = nil
	end)
end

return LookApplier
