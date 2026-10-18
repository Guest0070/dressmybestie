--!strict
-- Wardrobe (Dressing Room): saved outfits, ready to wear again. One card per slot (3, or 6 with
-- VIP): a preview of the outfit's first item, how many pieces it has, and WEAR / SAVE / delete.
-- SAVE stores what you're wearing right now; the server saves the look it applied itself.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Types = require(ReplicatedStorage.Shared.Types)
local State = require(script.Parent.Parent.State)
local Components = require(script.Parent.Components)
local Kit = require(script.Parent.Kit)
local Theme = require(script.Parent.Theme)

local WardrobeUI = {}

local panel: Frame
local list: Frame

local function thumbFor(look: Types.Look): string
	local first = look.assetIds[1]
	if first then
		return Kit.assetThumb(first)
	elseif look.shoeBundleId then
		return Kit.bundleThumb(look.shoeBundleId)
	end
	return ""
end

local function rebuild()
	for _, child in list:GetChildren() do
		if child:IsA("GuiObject") then
			child:Destroy()
		end
	end
	local data = State.data
	if not data then
		return
	end
	local slots = data.outfitSlots or Config.Wardrobe.Slots
	for slot = 1, slots do
		local saved = data.outfits and data.outfits[tostring(slot)]
		local card = Components.panel({
			Raised = true,
			Size = UDim2.fromOffset(118, 188),
			LayoutOrder = slot,
			Parent = list,
		})
		local preview = Kit.new("ImageLabel", {
			BackgroundColor3 = Theme.Colors.Background,
			Position = UDim2.fromOffset(9, 9),
			Size = UDim2.fromOffset(100, 74),
			Image = if saved then thumbFor(saved) else "",
			ScaleType = Enum.ScaleType.Fit,
			Parent = card,
		}, { Components.corner(8) })
		if not saved then
			Components.text({
				Text = "Empty",
				Size = UDim2.fromScale(1, 1),
				TextColor3 = Theme.Colors.Muted,
				MaxTextSize = 16,
				Parent = preview,
			})
		end
		local pieces = if saved then #saved.assetIds + (if saved.shoeBundleId then 1 else 0) else 0
		Components.text({
			Text = if saved
				then `Outfit {slot} · {pieces} piece{if pieces == 1 then "" else "s"}`
				else `Slot {slot}`,
			Position = UDim2.fromOffset(6, 86),
			Size = UDim2.new(1, -12, 0, 18),
			FontFace = Theme.Fonts.Heading,
			MaxTextSize = 14,
			Parent = card,
		})
		if saved then
			Components.button({
				Text = "WEAR",
				Variant = "Primary",
				Position = UDim2.fromOffset(8, 108),
				Size = UDim2.new(1, -16, 0, 28),
				MaxTextSize = 14,
				onClick = function()
					Remotes.Events.WearOutfit:FireServer(slot)
				end,
				Parent = card,
			})
		end
		Components.button({
			Text = if saved then "SAVE OVER" else "SAVE HERE",
			Variant = if saved then "Secondary" else "Special",
			Position = UDim2.fromOffset(8, if saved then 140 else 112),
			Size = UDim2.new(1, if saved then -44 else -16, 0, if saved then 36 else 40),
			MaxTextSize = 12,
			onClick = function()
				Remotes.Events.SaveOutfit:FireServer(slot)
			end,
			Parent = card,
		})
		if saved then
			Components.button({
				Text = "X",
				Position = UDim2.new(1, -34, 0, 140),
				Size = UDim2.fromOffset(26, 36),
				MaxTextSize = 12,
				onClick = function()
					Remotes.Events.DeleteOutfit:FireServer(slot)
				end,
				Parent = card,
			})
		end
	end
	if slots < Config.Wardrobe.VipSlots and not (data.ownedPasses and data.ownedPasses.VIP) then
		Components.text({
			Text = `VIP: {Config.Wardrobe.VipSlots} slots`,
			Size = UDim2.fromOffset(90, 188),
			TextColor3 = Theme.Colors.Gold,
			TextWrapped = true,
			MaxTextSize = 14,
			LayoutOrder = 99,
			Parent = list,
		})
	end
end

function WardrobeUI.toggle()
	panel.Visible = not panel.Visible and State.dressingRoom
	if panel.Visible then
		rebuild()
	end
end

function WardrobeUI.start()
	local _, root = Kit.screen("Wardrobe", 3)
	panel = Components.panel({
		Name = "WardrobePanel",
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, 8, 1, -24 - 2 * Kit.ButtonHeight),
		Size = UDim2.fromOffset(440, 248),
		Visible = false,
		Parent = root,
	})
	Components.text({
		Text = "WARDROBE",
		Position = UDim2.fromOffset(14, 8),
		Size = UDim2.new(1, -60, 0, 26),
		FontFace = Theme.Fonts.Heading,
		TextColor3 = Theme.Colors.Primary,
		TextXAlignment = Enum.TextXAlignment.Left,
		MaxTextSize = 22,
		Parent = panel,
	})
	Components.button({
		Text = "X",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -8, 0, 6),
		Size = UDim2.fromOffset(Theme.MinTouch, Theme.MinTouch - 4),
		onClick = WardrobeUI.toggle,
		Parent = panel,
	})
	local scroller = Kit.new("ScrollingFrame", {
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(8, 44),
		Size = UDim2.new(1, -16, 1, -52),
		CanvasSize = UDim2.new(0, 0, 0, 0),
		AutomaticCanvasSize = Enum.AutomaticSize.X,
		ScrollingDirection = Enum.ScrollingDirection.X,
		ScrollBarThickness = 4,
		Parent = panel,
	})
	list = Kit.new("Frame", {
		BackgroundTransparency = 1,
		AutomaticSize = Enum.AutomaticSize.X,
		Size = UDim2.fromScale(0, 1),
		Parent = scroller,
	}, {
		Kit.new("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			Padding = UDim.new(0, 8),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	})
	State.DataChanged:Connect(function()
		if panel.Visible then
			rebuild()
		end
	end)
	State.DressingRoomChanged:Connect(function(open)
		if not open then
			panel.Visible = false
		end
	end)
end

return WardrobeUI
