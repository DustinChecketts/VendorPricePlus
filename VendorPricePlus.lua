-- Initialize VendorPricePlus table
VendorPricePlus = {}
local VP = VendorPricePlus

-- Cache frequently used WoW API functions
local GetItemInfo, GetCoinTextureString, IsShiftKeyDown =
      GetItemInfo, GetCoinTextureString, IsShiftKeyDown
local hooksecurefunc, format, pairs, select = 
      hooksecurefunc, string.format, pairs, select

-- Map container IDs to inventory IDs
local ContainerIDToInventoryID = ContainerIDToInventoryID or C_Container.ContainerIDToInventoryID

-- Constants
local SELL_PRICE_TEXT = format("%s:", SELL_PRICE)
local overridePrice

-- Identify character bags
local CharacterBags = {}
for i = CONTAINER_BAG_OFFSET + 1, 23 do
    CharacterBags[i] = true
end

-- Identify bank bags
local firstBankBag = ContainerIDToInventoryID(NUM_BAG_SLOTS + 1)
local lastBankBag = ContainerIDToInventoryID(NUM_BAG_SLOTS + NUM_BANKBAGSLOTS)
for i = firstBankBag, lastBankBag do
    CharacterBags[i] = true
end

-- First keyring inventory slot
local FIRST_KEYRING_INVSLOT = 107

-- Check if the tooltip owner is a merchant
local function IsMerchant(tt)
    if MerchantFrame:IsShown() then
        local owner = tt:GetOwner()
        return owner and not (owner:GetName():find("Character") or owner:GetName():find("TradeSkill"))
    end
end

-- Determine if the price should be shown in the tooltip
local function ShouldShowPrice(tt)
    return not IsMerchant(tt)
end

-- Check if the item is a recipe and should be priced
local function CheckRecipe(tt, classID, isOnTooltipSetItem)
    if classID == Enum.ItemClass.Recipe and isOnTooltipSetItem then
        tt.isFirstMoneyLine = not tt.isFirstMoneyLine
        return tt.isFirstMoneyLine
    end
end

-- Override SetTooltipMoney function to modify tooltip display on shift key press
local _SetTooltipMoney = SetTooltipMoney
function SetTooltipMoney(frame, money, ...)
    if IsShiftKeyDown() and overridePrice then
        _SetTooltipMoney(frame, overridePrice, ...)
    else
        _SetTooltipMoney(frame, money, ...)
        overridePrice = nil
    end
end

-- Clear overridePrice on tooltip hide
GameTooltip:HookScript("OnHide", function()
    overridePrice = nil
end)

-- Set price information in the tooltip
function VP:SetPrice(tt, _, _, count, item, isOnTooltipSetItem)
    if ShouldShowPrice(tt) then
        count = count or 1
        item = item or select(2, tt:GetItem())
        if item then
            local sellPrice, classID = select(11, GetItemInfo(item))
            if sellPrice and sellPrice > 0 and not CheckRecipe(tt, classID, isOnTooltipSetItem) then
                local isShift = IsShiftKeyDown() and count > 1
                local displayPrice = isShift and sellPrice or sellPrice * count
                local unitPrice = sellPrice

                -- Display unit price if count >= 2
                if count >= 2 then
                    unitPrice = isShift and sellPrice / count or sellPrice
                end

                tt:AddLine(format("%s %s", GetCoinTextureString(displayPrice), count >= 2 and format("@%s each", GetCoinTextureString(unitPrice)) or ""), 1, 1, 1, false)
                tt:Show()
            end
        end
    end
end

-- Define methods for setting price in various tooltips
local SetItem = {
    SetAction = function(tt, slot)
        if GetActionInfo(slot) == "item" then
            VP:SetPrice(tt, true, "SetAction", GetActionCount(slot))
        end
    end,
    SetAuctionItem = function(tt, auctionType, index)
        local _, _, count = GetAuctionItemInfo(auctionType, index)
        VP:SetPrice(tt, false, "SetAuctionItem", count)
    end,
    SetBagItem = function(tt, bag, slot)
        local count
        local info = C_Container.GetContainerItemInfo and C_Container.GetContainerItemInfo(bag, slot)
        if info then
            count = info.stackCount
        end
        if count then
            VP:SetPrice(tt, true, "SetBagItem", count)
        end
    end,
    SetInventoryItem = function(tt, unit, slot)
        if not CharacterBags[slot] then
            local count = GetInventoryItemCount(unit, slot)
            if slot < FIRST_KEYRING_INVSLOT then
                VP:SetPrice(tt, VP:IsShown(BankFrame), "SetInventoryItem", count)
            end
        end
    end,
}

-- Hook the SetItem methods to their respective tooltip events
for method, func in pairs(SetItem) do
    hooksecurefunc(GameTooltip, method, func)
end

-- Hook the OnTooltipSetItem event for the ItemRefTooltip
ItemRefTooltip:HookScript("OnTooltipSetItem", function(tt)
    local item = select(2, tt:GetItem())
    if item then
        local sellPrice, classID = select(11, GetItemInfo(item))
        if sellPrice and sellPrice > 0 and not CheckRecipe(tt, classID, true) then
            SetTooltipMoney(tt, sellPrice, nil, SELL_PRICE_TEXT)
        end
    end
end)
