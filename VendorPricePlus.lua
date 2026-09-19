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

-- Forever uses additional modern tooltip setters for several item contexts.
-- Hook the setters that expose an item location and derive the real stack count
-- from that location. This keeps the feature data-driven instead of tied to a
-- particular window such as Mail or Merchant Buyback.
if Compat.IsForever() and ItemLocation and ItemLocation.CreateFromEquipmentSlot then
    local function SetPriceFromItemLocation(tt, itemLocation)
        if not itemLocation or not C_Item or not C_Item.DoesItemExist or not C_Item.DoesItemExist(itemLocation) then
            return
        end

        local count = 1
        if C_Item.GetStackCount then
            count = C_Item.GetStackCount(itemLocation) or 1
        end

        local item = C_Item.GetItemLink and C_Item.GetItemLink(itemLocation)
        VP:SetPrice(tt, true, "ItemLocation", count, item)
    end

    local itemLocationMethods = {
        SetBagItem = function(bag, slot)
            if ItemLocation.CreateFromBagAndSlot then
                return ItemLocation:CreateFromBagAndSlot(bag, slot)
            end
        end,
        SetInventoryItem = function(unit, slot)
            if unit == "player" then
                return ItemLocation:CreateFromEquipmentSlot(slot)
            end
        end,
    }

    for method, makeLocation in pairs(itemLocationMethods) do
        if type(GameTooltip[method]) == "function" then
            -- SetBagItem/SetInventoryItem are already covered above. The modern
            -- location path is intentionally not installed twice.
        end
    end

    -- Modern item-location tooltip setter used by Forever UI surfaces when present.
    if type(GameTooltip.SetItemByItemLocation) == "function" then
        hooksecurefunc(GameTooltip, "SetItemByItemLocation", function(tt, itemLocation)
            SetPriceFromItemLocation(tt, itemLocation)
        end)
    end
end

-- Forever tooltip diagnostics.
-- Temporary test instrumentation: /vppdiag toggles logging. While enabled,
-- hover an item in each problem context (Mail, Buyback, Quest rewards, etc.).
-- We hook only tooltip methods that actually exist and print the method name,
-- arguments, owner, and resolved item without changing tooltip behavior.
if Compat.IsForever() then
    local diagEnabled = false
    local diagLast = {}

    local function DiagValue(value)
        local valueType = type(value)
        if valueType == "string" or valueType == "number" or valueType == "boolean" or value == nil then
            return tostring(value)
        end
        return "<" .. valueType .. ">"
    end

    local function DiagOwner(tt)
        local owner = tt.GetOwner and tt:GetOwner()
        if not owner then
            return "nil"
        end
        if owner.GetName then
            local name = owner:GetName()
            if name then return name end
        end
        return tostring(owner)
    end

    local function Diag(method, tt, ...)
        if not diagEnabled then return end

        local itemName, itemLink
        if tt.GetItem then
            itemName, itemLink = tt:GetItem()
        end

        local args = {}
        for i = 1, select("#", ...) do
            args[#args + 1] = DiagValue(select(i, ...))
        end

        local owner = tt.GetOwner and tt:GetOwner()
        local ownerName = DiagOwner(tt)
        local ownerType = owner and owner.GetObjectType and owner:GetObjectType() or "nil"
        local ownerID = owner and owner.GetID and owner:GetID() or "nil"
        local parent = owner and owner.GetParent and owner:GetParent()
        local parentName = parent and parent.GetName and parent:GetName() or "nil"

        local line = format(
            "|cff88ccffVPP DIAG|r %s owner=%s type=%s id=%s parent=%s item=%s args=[%s]",
            method,
            ownerName,
            tostring(ownerType),
            tostring(ownerID),
            tostring(parentName),
            itemLink or itemName or "nil",
            table.concat(args, ", ")
        )

        -- Avoid identical spam while the same tooltip is refreshed repeatedly.
        if diagLast[method] ~= line then
            diagLast[method] = line
            print(line)
        end
    end

    local diagnosticMethods = {
        "SetAction",
        "SetBagItem",
        "SetBuybackItem",
        "SetHyperlink",
        "SetInboxItem",
        "SetInventoryItem",
        "SetItemByID",
        "SetItemByItemLocation",
        "SetLootItem",
        "SetLootRollItem",
        "SetMerchantItem",
        "SetQuestItem",
        "SetQuestLogItem",
        "SetSendMailItem",
        "SetTradePlayerItem",
        "SetTradeSkillItem",
        "SetTradeTargetItem",
    }

    for _, method in ipairs(diagnosticMethods) do
        if type(GameTooltip[method]) == "function" then
            hooksecurefunc(GameTooltip, method, function(tt, ...)
                Diag(method, tt, ...)
            end)
        end
    end

    -- Some Forever UI surfaces build tooltips through the modern tooltip-data
    -- pipeline without calling a public GameTooltip setter. Log those item
    -- post-calls too, including the tooltip owner/button that requested them.
    if TooltipDataProcessor and TooltipDataProcessor.AddTooltipPostCall
        and Enum and Enum.TooltipDataType and Enum.TooltipDataType.Item then
        TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Item, function(tt, data)
            if not diagEnabled then return end
            local dataID = data and (data.id or data.itemID or data.guid)

            local owner = tt.GetOwner and tt:GetOwner()
            local ownerText = {}
            if owner then
                for key, value in pairs(owner) do
                    local valueType = type(value)
                    if valueType == "string" or valueType == "number" or valueType == "boolean" then
                        ownerText[#ownerText + 1] = tostring(key) .. "=" .. tostring(value)
                    end
                end
                table.sort(ownerText)
            end

            Diag("TooltipDataProcessor.Item", tt, dataID)
            if #ownerText > 0 then
                print("|cff88ccffVPP OWNER|r " .. table.concat(ownerText, " "))
            end
        end)
    end

    SLASH_VENDORPRICEPLUSDIAG1 = "/vppdiag"
    SlashCmdList.VENDORPRICEPLUSDIAG = function()
        diagEnabled = not diagEnabled
        wipe(diagLast)
        print("VendorPricePlus diagnostics: " .. (diagEnabled and "|cff00ff00ON|r" or "|cffff0000OFF|r"))
    end
end

-- Forever context hooks discovered through /vppdiag.
-- Mail and Buyback use dedicated setters rather than the bag-item path.
if Compat.IsForever() then
    if type(GameTooltip.SetSendMailItem) == "function" then
        hooksecurefunc(GameTooltip, "SetSendMailItem", function(tt, attachmentIndex)
            local name, _, count = GetSendMailItem(attachmentIndex)
            if name then
                VP:SetPrice(tt, true, "SetSendMailItem", count or 1)
            end
        end)
    end

    if type(GameTooltip.SetBuybackItem) == "function" then
        hooksecurefunc(GameTooltip, "SetBuybackItem", function(tt, buybackIndex)
            local name, _, price, count = GetBuybackItemInfo(buybackIndex)
            if name then
                VP:SetPrice(tt, true, "SetBuybackItem", count or 1)
            end
        end)
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
