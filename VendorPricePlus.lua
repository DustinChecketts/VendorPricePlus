-- Initialize VendorPricePlus table
VendorPricePlus = VendorPricePlus or {}
local VP = VendorPricePlus

-- Cache frequently used WoW API functions
local IsShiftKeyDown = IsShiftKeyDown
local hooksecurefunc, format, pairs, select, max =
      hooksecurefunc, string.format, pairs, select, math.max

local Compat = VP.Compat

-- Safely check if Auctionator is loaded (cross-version compatible)
local function IsAuctionatorLoaded()
    return Compat.IsAddOnLoaded("Auctionator")
end

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
if GameTooltip and GameTooltip.HasScript and GameTooltip:HasScript("OnHide") then
    GameTooltip:HookScript("OnHide", function()
        overridePrice = nil
    end)
end

-- Function to format money values with precise alignment & 12x12 icons
local function FormatMoneyWithIcons(amount)
    local gold = floor(amount / (COPPER_PER_SILVER * SILVER_PER_GOLD))
    local silver = floor((amount % (COPPER_PER_SILVER * SILVER_PER_GOLD)) / COPPER_PER_SILVER)
    local copper = amount % COPPER_PER_SILVER

    local goldString = gold > 0 and format("%d |TInterface\\MoneyFrame\\UI-GoldIcon:12:12:0:0|t ", gold) or ""
    local silverString = silver > 0 and format("%d |TInterface\\MoneyFrame\\UI-SilverIcon:12:12:0:0|t ", silver)
        or (gold > 0 and " 0 |TInterface\\MoneyFrame\\UI-SilverIcon:12:12:0:0|t " or "")
    local copperString = copper > 0 and format("%d |TInterface\\MoneyFrame\\UI-CopperIcon:12:12:0:0|t", copper)
        or ((silver > 0 or gold > 0) and "00 |TInterface\\MoneyFrame\\UI-CopperIcon:12:12:0:0|t" or "")

    return goldString .. silverString .. copperString
end

function VP:SetPrice(tt, _, _, count, item)
    count = count or 1
    item = item or select(2, tt:GetItem())

    if item then
        local sellPrice = select(11, Compat.GetItemInfo(item))
        if sellPrice and sellPrice > 0 then
            local stackPrice = sellPrice * count
            local unitPrice = sellPrice

            -- Forever already displays Blizzard's Sell Price for the whole stack.
            -- Leave that native line alone and add only the missing per-unit value.
            -- A single item is already unambiguous, so it gets no extra line.
            if Compat.IsForever() then
                if count >= 2 then
                    tt:AddDoubleLine(
                        NORMAL_FONT_COLOR:WrapTextInColorCode("Each"),
                        FormatMoneyWithIcons(unitPrice),
                        1, 1, 1, 1, 1, 1
                    )
                    tt:Show()
                end
                return
            end

            local stackText = count >= 2 and format("Vendor |cff88ccffx%d|r", count) or "Vendor"

            if IsAuctionatorLoaded() then
                if count >= 2 then
                    tt:AddDoubleLine(
                        NORMAL_FONT_COLOR:WrapTextInColorCode(stackText),
                        FormatMoneyWithIcons(stackPrice),
                        1, 1, 1, 1, 1, 1
                    )
                end
            else
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

-- Standard tooltip hooks
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
        local info = Compat.GetContainerItemInfo(bag, slot)
        if info and info.stackCount then
            VP:SetPrice(tt, true, "SetBagItem", info.stackCount)
        end
    end,
    SetInventoryItem = function(tt, unit, slot)
        if slot < FIRST_KEYRING_INVSLOT then
            VP:SetPrice(tt, true, "SetInventoryItem", GetInventoryItemCount(unit, slot))
        end
    end,
}

for method, func in pairs(SetItem) do
    if type(GameTooltip[method]) == "function" then
        hooksecurefunc(GameTooltip, method, func)
    end
end

-- ItemRef tooltip support
if ItemRefTooltip and ItemRefTooltip.HasScript and ItemRefTooltip:HasScript("OnTooltipSetItem") then
    ItemRefTooltip:HookScript("OnTooltipSetItem", function(tt)
        local item = select(2, tt:GetItem())
        if item then
            local sellPrice = select(11, Compat.GetItemInfo(item))
            if sellPrice and sellPrice > 0 then
                SetTooltipMoney(tt, sellPrice, nil, SELL_PRICE_TEXT)
            end
        end
    end)
end

--------------------------------------------------------------------------------
-- Quest reward tooltip support (FIXED for DF-style UI)
--------------------------------------------------------------------------------

-- Direct quest reward button hook
local function OnEnterQuestReward(self)
    local link = self.itemLink or (self.GetID and GetQuestItemLink(self.type, self:GetID()))
    if link then
        VP:SetPrice(GameTooltip, false, "QuestReward", self.count or 1, link)
    end
end

local function SafeHookScript(frame, scriptName, callback)
    if not frame or type(frame.HookScript) ~= "function" then
        return false
    end
    if frame.HasScript and not frame:HasScript(scriptName) then
        return false
    end
    frame:HookScript(scriptName, callback)
    return true
end

hooksecurefunc("QuestInfo_Display", function()
    for i = 1, MAX_NUM_ITEMS do
        local button = QuestInfoRewardsFrame and QuestInfoRewardsFrame["QuestInfoItem" .. i]
        if button and not button.__VendorPricePlusHooked then
            if SafeHookScript(button, "OnEnter", OnEnterQuestReward) then
                button.__VendorPricePlusHooked = true
            end
        end
    end
end)

-- Tooltip fallback using GetOwner() (DF-safe)
if GameTooltip.HasScript and GameTooltip:HasScript("OnTooltipSetItem") then
    GameTooltip:HookScript("OnTooltipSetItem", function(tt)
        local _, itemLink = tt:GetItem()
        if not itemLink then return end

        local owner = tt:GetOwner()
        if not owner then return end

        local parent = owner:GetParent()
        local parentName = parent and parent:GetName()

        if parentName and parentName:match("^QuestInfoRewardsFrame") then
            VP:SetPrice(tt, false, "QuestRewardFallback", owner.count or 1, itemLink)
        end
    end)
end
