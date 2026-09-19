-- VendorPricePlus core tooltip behavior.
-- Client/API differences belong in Compat.lua; settings UI belongs in Options.lua.
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

-- Normalize Blizzard's native Forever Sell Price row into the same visual
-- language VPP uses for stacked items: gold label on the left and money in a
-- compact, right-aligned value column. This also applies to single-item prices
-- so vendor values do not change presentation based on stack size.
local function FormatForeverSellPriceRow(tt, sellPrice)
    local tooltipName = tt.GetName and tt:GetName()
    if not tooltipName or not tt.NumLines then return nil end

    for i = 1, tt:NumLines() do
        local left = _G[tooltipName .. "TextLeft" .. i]
        local right = _G[tooltipName .. "TextRight" .. i]
        local text = left and left:GetText()

        if text and text:find(SELL_PRICE_TEXT, 1, true) == 1 and right then
            left:SetText(SELL_PRICE_TEXT)
            left:SetTextColor(NORMAL_FONT_COLOR.r, NORMAL_FONT_COLOR.g, NORMAL_FONT_COLOR.b)
            right:SetText(FormatMoneyWithIcons(sellPrice))
            right:Show()

            -- Forever can mark tooltip geometry as secret/protected, especially
            -- for action-bar item tooltips. Never perform arithmetic on measured
            -- FontString widths here; use Blizzard's normal right column instead.
            right:ClearAllPoints()
            right:SetPoint("RIGHT", tt, "RIGHT", -10, 0)

            return left, right
        end
    end
end

-- Compact Forever price rows into a small two-column table.
-- Blizzard writes Sell Price as one left-aligned string. For stack contexts we
-- split that native line into the existing left/right FontStrings, then align
-- our Unit Price row to the same nearby right edge. If the expected tooltip
-- FontStrings are unavailable, this safely falls back to Blizzard's layout.
local function CompactForeverPriceRows(tt, stackPrice, unitPrice)
    local tooltipName = tt.GetName and tt:GetName()
    if not tooltipName or not tt.NumLines then return false end

    local sellLeft, sellRight = FormatForeverSellPriceRow(tt, stackPrice)
    if not (sellLeft and sellRight) then
        return false
    end

    local unitLeft, unitRight
    for i = 1, tt:NumLines() do
        local left = _G[tooltipName .. "TextLeft" .. i]
        local right = _G[tooltipName .. "TextRight" .. i]
        if left and left:GetText() == "Unit Price:" then
            unitLeft, unitRight = left, right
            break
        end
    end

    if not (unitLeft and unitRight) then
        return false
    end

    unitLeft:SetTextColor(NORMAL_FONT_COLOR.r, NORMAL_FONT_COLOR.g, NORMAL_FONT_COLOR.b)

    -- Keep both values in Blizzard's normal right column. Do not inspect or
    -- calculate from FontString geometry: Forever may protect those measurements
    -- as secret values on secure tooltip paths such as action-bar items.
    sellRight:ClearAllPoints()
    sellRight:SetPoint("RIGHT", tt, "RIGHT", -10, 0)
    unitRight:ClearAllPoints()
    unitRight:SetPoint("RIGHT", tt, "RIGHT", -10, 0)

    return true
end
-- Forever's modern tooltip pipeline exposes Sell Price as its own typed line.
-- A line post-call runs immediately after Blizzard renders that line but before
-- the following footer/help lines are rendered. Adding Unit Price here keeps the
-- two price rows together without moving or rewriting Blizzard's later rows.
--
-- This is intentionally Forever-only. Older supported clients continue through
-- the established SetPrice hooks below.
if Compat.IsForever()
    and TooltipDataProcessor
    and TooltipDataProcessor.AddLinePostCall
    and Enum
    and Enum.TooltipDataLineType
    and Enum.TooltipDataLineType.SellPrice then

    local function GetForeverContextKey(tt)
        -- The modern tooltip handler retains the C_TooltipInfo getter that built
        -- the current tooltip. Prefer that stable API context over frame names.
        local info = tt.GetProcessingTooltipInfo and tt:GetProcessingTooltipInfo()
        local getterName = info and info.getterName

        if getterName then
            if getterName == "GetSendMailItem" or getterName == "GetInboxItem" then
                return "mail"
            elseif getterName == "GetBuybackItem" or getterName == "GetMerchantItem" then
                return "merchant"
            elseif getterName == "GetRecipeReagentItem" then
                return "professions"
            elseif getterName == "GetQuestItem" or getterName == "GetQuestLogItem" then
                return "questRewards"
            elseif getterName == "GetBagItem"
                or getterName == "GetBagItemChild"
                or getterName == "GetInventoryItem" then
                return "inventoryBank"
            end
        end

        -- Profession reagent buttons have useful owner metadata in Forever even
        -- when the tooltip getter is not exposed by name.
        local owner = tt.GetOwner and tt:GetOwner()
        if owner and owner.buttonContext == "ButtonContext_ProfessionsReagentButton" then
            return "professions"
        end

        -- Unknown item surfaces keep the historical default behavior. The
        -- stack-price comparison below still prevents an unnecessary Unit Price
        -- line when Blizzard is already displaying a single-item value.
        return nil
    end

    TooltipDataProcessor.AddLinePostCall(Enum.TooltipDataLineType.SellPrice, function(tt, lineData)
        if not tt or not lineData then return end

        local contextKey = GetForeverContextKey(tt)
        if contextKey and not VP:IsContextEnabled(contextKey) then
            return
        end

        local info = tt.GetProcessingTooltipInfo and tt:GetProcessingTooltipInfo()
        local tooltipData = info and info.tooltipData
        local item = tooltipData and (tooltipData.hyperlink or tooltipData.id)

        if not item and type(tt.GetItem) == "function" then
            item = select(2, tt:GetItem())
        end
        if not item then return end

        local unitPrice = select(11, Compat.GetItemInfo(item))
        local stackPrice = tonumber(lineData.price)

        if not unitPrice or unitPrice <= 0 or not stackPrice or stackPrice <= 0 then
            return
        end

        -- Always normalize the native Sell Price row, including single items.
        -- This gives Forever tooltips one consistent vendor-price presentation.
        FormatForeverSellPriceRow(tt, stackPrice)

        -- Only stacks need the additional per-unit value. When Blizzard is
        -- already showing one item's vendor value, Sell Price alone is enough.
        if stackPrice <= unitPrice then
            return
        end

        tt:AddDoubleLine(
            "Unit Price:",
            FormatMoneyWithIcons(unitPrice),
            NORMAL_FONT_COLOR.r, NORMAL_FONT_COLOR.g, NORMAL_FONT_COLOR.b,
            1, 1, 1
        )

        -- This callback runs before Blizzard renders later footer/help lines, so
        -- Unit Price remains directly beneath Sell Price without moving any rows.
        CompactForeverPriceRows(tt, stackPrice, unitPrice)
    end)
end

function VP:SetPrice(tt, _, _, count, item)
    count = count or 1
    item = item or select(2, tt:GetItem())

    if item then
        local sellPrice = select(11, Compat.GetItemInfo(item))
        if sellPrice and sellPrice > 0 then
            local stackPrice = sellPrice * count
            local unitPrice = sellPrice

            -- Forever tooltips with a native SellPrice line are handled while
            -- Blizzard is rendering that line (see the line post-call above).
            -- Returning here prevents the legacy hooks from appending a duplicate
            -- Unit Price after Forever's beta feedback/footer text.
            if Compat.IsForever() then
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

-- Legacy/public tooltip setters shared by the supported WoW clients.
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
        if Compat.IsForever() and not VP:IsContextEnabled("inventoryBank") then return end
        local info = Compat.GetContainerItemInfo(bag, slot)
        if info and info.stackCount then
            VP:SetPrice(tt, true, "SetBagItem", info.stackCount)
        end
    end,
    SetInventoryItem = function(tt, unit, slot)
        if Compat.IsForever() and not VP:IsContextEnabled("inventoryBank") then return end
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

-- Forever-specific tooltip contexts discovered during beta testing.
-- Mail and Buyback use dedicated setters rather than the bag-item path.
if Compat.IsForever() then
    if type(GameTooltip.SetSendMailItem) == "function" then
        hooksecurefunc(GameTooltip, "SetSendMailItem", function(tt, attachmentIndex)
            if not VP:IsContextEnabled("mail") then return end
            local name, _, count = GetSendMailItem(attachmentIndex)
            if name then
                VP:SetPrice(tt, true, "SetSendMailItem", count or 1)
            end
        end)
    end

    if type(GameTooltip.SetBuybackItem) == "function" then
        hooksecurefunc(GameTooltip, "SetBuybackItem", function(tt, buybackIndex)
            if not VP:IsContextEnabled("merchant") then return end
            local name, _, price, count = GetBuybackItemInfo(buybackIndex)
            if name then
                VP:SetPrice(tt, true, "SetBuybackItem", count or 1)
            end
        end)
    end
end

-- Forever modern tooltip contexts that do not use legacy tooltip setters.
if Compat.IsForever() and TooltipDataProcessor and TooltipDataProcessor.AddTooltipPostCall
    and Enum and Enum.TooltipDataType and Enum.TooltipDataType.Item then
    TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Item, function(tt, data)
        local owner = tt.GetOwner and tt:GetOwner()
        if not owner then return end

        -- Comparison tooltips in Forever can participate in the modern item
        -- pipeline without exposing GetItem(). Prefer the data ID, and only call
        -- GetItem when that method actually exists.
        local item = data and (data.id or data.itemID)
        if type(tt.GetItem) == "function" then
            item = select(2, tt:GetItem()) or item
        end
        if not item then return end

        -- Profession reagent buttons expose the recipe-required quantity through
        -- itemContextMatchResult (confirmed in Forever). Blizzard's Sell Price
        -- is the value of that required quantity, so add the per-unit value.
        if owner.buttonContext == "ButtonContext_ProfessionsReagentButton" then
            if not VP:IsContextEnabled("professions") then return end
            local count = tonumber(owner.itemContextMatchResult) or tonumber(owner.count) or 1
            if count >= 2 then
                VP:SetPrice(tt, true, "ProfessionReagent", count, item)
            end
            return
        end

        -- Guaranteed quest reward buttons expose stable reward metadata here.
        -- Selectable quest choices are also handled by the direct quest-button
        -- hook below because their Forever owner metadata differs.
        if owner.type == "reward" and owner.objectType == "item" then
            if not VP:IsContextEnabled("questRewards") then return end
            local count = tonumber(owner.count) or 1
            local sellPrice = select(11, Compat.GetItemInfo(item))
            if sellPrice and sellPrice > 0 then
                tt:AddDoubleLine(
                    NORMAL_FONT_COLOR:WrapTextInColorCode(SELL_PRICE_TEXT),
                    FormatMoneyWithIcons(sellPrice * count),
                    1, 1, 1, 1, 1, 1
                )
                if count >= 2 then
                    tt:AddDoubleLine(
                        "Unit Price:",
                        FormatMoneyWithIcons(sellPrice),
                        1, 1, 1, 1, 1, 1
                    )
                end
                tt:Show()
            end
        end
    end)
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

-- Direct quest reward button hook. This path is important on Forever because
-- selectable quest choices do not expose the same modern tooltip-owner metadata
-- as guaranteed rewards.
local function OnEnterQuestReward(self)
    local link = self.itemLink or (self.GetID and GetQuestItemLink(self.type, self:GetID()))
    if not link then return end

    if Compat.IsForever() then
        if not VP:IsContextEnabled("questRewards") then return end

        -- Guaranteed rewards may already have been handled by the modern
        -- tooltip post-call above. Do not add a duplicate Sell Price row.
        local tooltipName = GameTooltip.GetName and GameTooltip:GetName()
        if tooltipName and GameTooltip.NumLines then
            for i = 1, GameTooltip:NumLines() do
                local left = _G[tooltipName .. "TextLeft" .. i]
                local text = left and left:GetText()
                if text and text:find(SELL_PRICE_TEXT, 1, true) == 1 then
                    return
                end
            end
        end

        local count = tonumber(self.count) or 1
        local sellPrice = select(11, Compat.GetItemInfo(link))
        if sellPrice and sellPrice > 0 then
            GameTooltip:AddDoubleLine(
                NORMAL_FONT_COLOR:WrapTextInColorCode(SELL_PRICE_TEXT),
                FormatMoneyWithIcons(sellPrice * count),
                1, 1, 1, 1, 1, 1
            )
            if count >= 2 then
                GameTooltip:AddDoubleLine(
                    "Unit Price:",
                    FormatMoneyWithIcons(sellPrice),
                    1, 1, 1, 1, 1, 1
                )
            end
            GameTooltip:Show()
        end
        return
    end

    VP:SetPrice(GameTooltip, false, "QuestReward", self.count or 1, link)
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

local function HookQuestRewardButtons()
    -- Older quest UI exposes reward buttons as named children of
    -- QuestInfoRewardsFrame.
    for i = 1, MAX_NUM_ITEMS do
        local button = QuestInfoRewardsFrame and QuestInfoRewardsFrame["QuestInfoItem" .. i]
        if button and not button.__VendorPricePlusHooked then
            if SafeHookScript(button, "OnEnter", OnEnterQuestReward) then
                button.__VendorPricePlusHooked = true
            end
        end

        -- Forever's Map & Quest Log uses the global QuestInfoItemN buttons for
        -- both guaranteed rewards and selectable choices. They are not indexed
        -- as children on QuestInfoRewardsFrame, so hook the globals as well.
        local globalButton = _G["QuestInfoItem" .. i]
        if globalButton and not globalButton.__VendorPricePlusHooked then
            if SafeHookScript(globalButton, "OnEnter", OnEnterQuestReward) then
                globalButton.__VendorPricePlusHooked = true
            end
        end
    end
end

hooksecurefunc("QuestInfo_Display", HookQuestRewardButtons)

-- Quest reward frames may be created lazily. Run once at load for any buttons
-- that already exist; QuestInfo_Display will cover subsequent refreshes.
HookQuestRewardButtons()

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
