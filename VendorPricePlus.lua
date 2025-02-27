-- Initialize VendorPricePlus table
VendorPricePlus = {}
local VP = VendorPricePlus

-- Cache frequently used WoW API functions
local GetItemInfo, IsShiftKeyDown, IsAddOnLoaded =
      GetItemInfo, IsShiftKeyDown, IsAddOnLoaded
local hooksecurefunc, format, pairs, select, max =
      hooksecurefunc, string.format, pairs, select, math.max

-- Constants
local SELL_PRICE_TEXT = format("%s:", SELL_PRICE)
local overridePrice

-- First keyring inventory slot
local FIRST_KEYRING_INVSLOT = 107

-- Override SetTooltipMoney function to modify tooltip display
local _SetTooltipMoney = SetTooltipMoney
function SetTooltipMoney(frame, money, ...)
    if overridePrice then
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

-- Function to format money values with precise alignment & 12x12 icons
local function FormatMoneyWithIcons(amount)
    local gold = floor(amount / (COPPER_PER_SILVER * SILVER_PER_GOLD))
    local silver = floor((amount % (COPPER_PER_SILVER * SILVER_PER_GOLD)) / COPPER_PER_SILVER)
    local copper = amount % COPPER_PER_SILVER

    -- Ensure icons and numbers are perfectly aligned with Auctionator
    local goldString = gold > 0 and format("%d |TInterface\\MoneyFrame\\UI-GoldIcon:12:12:0:0|t ", gold) or ""
    local silverString = silver > 0 and format("%d |TInterface\\MoneyFrame\\UI-SilverIcon:12:12:0:0|t ", silver) or (gold > 0 and " 0 |TInterface\\MoneyFrame\\UI-SilverIcon:12:12:0:0|t " or "")
    local copperString = copper > 0 and format("%d |TInterface\\MoneyFrame\\UI-CopperIcon:12:12:0:0|t", copper) or ((silver > 0 or gold > 0) and "00 |TInterface\\MoneyFrame\\UI-CopperIcon:12:12:0:0|t" or "")

    return goldString .. silverString .. copperString
end

function VP:SetPrice(tt, _, _, count, item, isOnTooltipSetItem)
    count = count or 1
    item = item or select(2, tt:GetItem())

    if item then
        local sellPrice = select(11, GetItemInfo(item))
        if sellPrice and sellPrice > 0 then
            local stackPrice = sellPrice * count
            local unitPrice = sellPrice

            -- Format the stack text: "Vendor xY" (light blue xY for consistency)
            local stackText = count >= 2 and format("Vendor |cff88ccffx%d|r", count) or "Vendor"

            if IsAddOnLoaded("Auctionator") then
                -- Auctionator installed: Show only "Vendor xY"
                if count >= 2 then
                    tt:AddDoubleLine(
                        NORMAL_FONT_COLOR:WrapTextInColorCode(stackText),
                        FormatMoneyWithIcons(stackPrice),
                        1, 1, 1, 1, 1, 1
                    )
                end
            else
                -- Normal behavior: Show "Vendor" for unit price and "Vendor xY" for stack price
                tt:AddDoubleLine(
                    NORMAL_FONT_COLOR:WrapTextInColorCode("Vendor"),
                    FormatMoneyWithIcons(unitPrice),
                    1, 1, 1, 1, 1, 1
                )
                if count >= 2 then
                    tt:AddDoubleLine(
                        NORMAL_FONT_COLOR:WrapTextInColorCode(stackText),
                        FormatMoneyWithIcons(stackPrice),
                        1, 1, 1, 1, 1, 1
                    )
                end
            end

            tt:Show()
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
        local count = GetInventoryItemCount(unit, slot)
        if slot < FIRST_KEYRING_INVSLOT then
            VP:SetPrice(tt, true, "SetInventoryItem", count)
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
        local sellPrice = select(11, GetItemInfo(item))
        if sellPrice and sellPrice > 0 then
            SetTooltipMoney(tt, sellPrice, nil, SELL_PRICE_TEXT)
        end
    end
end)
