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

-- Do not replace Blizzard's global SetTooltipMoney. Native tooltip money
-- rendering must remain untouched when a context is disabled.

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
            elseif getterName == "GetRecipeReagentItem"
                or getterName == "GetTradeSkillItem"
                or getterName == "GetCraftItem"
                or getterName == "GetRecipeResultItem" then
                return "professions"
            elseif getterName == "GetAuctionItem" or getterName == "GetAuctionHouseItem"
                or getterName == "GetAuctionHouseBrowseItem" then
                return "auctionHouse"
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

        -- Forever quest rewards are built with GetQuestLogItem. The native
        -- SellPrice row already has the correct value; changing its label must
        -- not depend on a cached item price or a stack-price calculation.
        -- Adjust the processor's line data as well as any rendered FontString
        -- so either rendering order can pick up the new label.
        if contextKey == "questRewards" then
            if type(lineData.leftText) == "string"
                and lineData.leftText:find(SELL_PRICE_TEXT, 1, true) == 1 then
                lineData.leftText = "Vendor"
            end
            local tooltipName = tt.GetName and tt:GetName()
            if tooltipName and tt.NumLines then
                for i = 1, tt:NumLines() do
                    local left = _G[tooltipName .. "TextLeft" .. i]
                    local label = left and left:GetText()
                    if type(label) == "string"
                        and label:find(SELL_PRICE_TEXT, 1, true) == 1 then
                        left:SetText(NORMAL_FONT_COLOR:WrapTextInColorCode("Vendor"))
                        break
                    end
                end
            end
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

        -- Standardize Forever on the same terminology used by VPP on Classic:
        -- Vendor is the per-unit value and Vendor xN is the full stack value.
        -- Blizzard's native Sell Price line is therefore only an input value; VPP
        -- rewrites the visible presentation so installing Auctionator does not
        -- change the vocabulary players see.
        local owner = tt.GetOwner and tt:GetOwner()
        local count = owner and tonumber(owner.count) or 1

        if contextKey == "inventoryBank" then
            if count < 1 then
                count = 1
            end

            -- The rendered Sell Price is authoritative for this exact stack.
            -- Derive the per-unit value from it rather than trusting tooltipData's
            -- hyperlink, which can identify a related item for recipes.
            unitPrice = floor(stackPrice / count)

            -- Auctionator already supplies the per-unit Vendor row. When it is
            -- active, remove Blizzard's native Sell Price row instead of rewriting
            -- it into a second Vendor row. VPP then contributes only Vendor xN;
            -- Auctionator contributes Vendor and Auction.
            if IsAuctionatorLoaded() then
                local tooltipName = tt.GetName and tt:GetName()
                if tooltipName and tt.NumLines then
                    for i = 1, tt:NumLines() do
                        local left = _G[tooltipName .. "TextLeft" .. i]
                        local right = _G[tooltipName .. "TextRight" .. i]
                        local text = left and left:GetText()
                        if text and text:find(SELL_PRICE_TEXT, 1, true) == 1 then
                            left:SetText("")
                            if right then
                                right:SetText("")
                            end
                            break
                        end
                    end
                end

                -- Preserve Auctionator's normal Vendor/Auction ordering, then
                -- append VPP's stack total. Queue the row until the tooltip's
                -- OnUpdate so Auctionator's post-call has completed, but keep the
                -- pending data on the tooltip instead of relying on a timer whose
                -- item identity can differ between tooltip API representations.
                if count >= 2 then
                    tt.__VendorPricePlusPendingAuctionatorStack = {
                        text = format("Vendor |cff88ccffx%d|r", count),
                        value = FormatMoneyWithIcons(stackPrice),
                    }
                end
                return
            end

            -- Without Auctionator, VPP rewrites Blizzard's Sell Price row as
            -- Vendor and adds Vendor xN for genuine stacks.
            local tooltipName = tt.GetName and tt:GetName()
            if tooltipName and tt.NumLines then
                for i = 1, tt:NumLines() do
                    local left = _G[tooltipName .. "TextLeft" .. i]
                    local right = _G[tooltipName .. "TextRight" .. i]
                    local text = left and left:GetText()
                    if text and text:find(SELL_PRICE_TEXT, 1, true) == 1 and right then
                        left:SetText(NORMAL_FONT_COLOR:WrapTextInColorCode("Vendor"))
                        right:SetText(FormatMoneyWithIcons(unitPrice))
                        right:Show()
                        right:ClearAllPoints()
                        right:SetPoint("RIGHT", tt, "RIGHT", -10, 0)
                        break
                    end
                end
            end

            if count >= 2 then
                local stackText = format("Vendor |cff88ccffx%d|r", count)
                tt:AddDoubleLine(
                    NORMAL_FONT_COLOR:WrapTextInColorCode(stackText),
                    FormatMoneyWithIcons(stackPrice),
                    1, 1, 1, 1, 1, 1
                )
                tt:Show()
            end
            return
        else
            -- Forever's native Sell Price row is the authoritative stack
            -- value. Keep its normal presentation when the context is disabled
            -- (handled above), and use one vocabulary for enabled contexts.
            -- Do not infer a count from protected tooltip data.
            local tooltipName = tt.GetName and tt:GetName()
            if not tooltipName then return end
            local count = 1
            if Compat.CanAccessNumber(unitPrice) and unitPrice > 0
                and Compat.CanAccessNumber(stackPrice)
                and stackPrice >= unitPrice and stackPrice % unitPrice == 0 then
                count = stackPrice / unitPrice
            end

            for i = 1, tt:NumLines() do
                local left = _G[tooltipName .. "TextLeft" .. i]
                local right = _G[tooltipName .. "TextRight" .. i]
                local label = left and left:GetText()
                if type(label) == "string" and label:find(SELL_PRICE_TEXT, 1, true) == 1 then
                    left:SetText(NORMAL_FONT_COLOR:WrapTextInColorCode("Vendor"))
                    if right then
                        right:SetText(FormatMoneyWithIcons(unitPrice))
                        right:Show()
                    end
                    break
                end
            end
            if count >= 2 then
                tt:AddDoubleLine(
                    NORMAL_FONT_COLOR:WrapTextInColorCode(format("Vendor |cff88ccffx%d|r", count)),
                    FormatMoneyWithIcons(stackPrice),
                    1, 1, 1, 1, 1, 1
                )
                tt:Show()
            end
            return
        end
    end)
end

-- Some Forever quest rewards use the item tooltip pipeline without a
-- SellPrice line post-call. Normalize only the already-rendered native label;
-- never synthesize prices or interfere with Classic's tooltip hooks.
-- Auctionator appends its Vendor/Auction rows in the completed item-tooltip
-- callback. Flush our pending stack row on the tooltip's next update so VPP is
-- supplemental and appears after Auctionator rather than interrupting it.
if GameTooltip and GameTooltip.HookScript then
    GameTooltip:HookScript("OnUpdate", function(tt)
        local pending = tt.__VendorPricePlusPendingAuctionatorStack
        if not pending then return end

        tt.__VendorPricePlusPendingAuctionatorStack = nil
        tt:AddDoubleLine(
            NORMAL_FONT_COLOR:WrapTextInColorCode(pending.text),
            pending.value,
            1, 1, 1, 1, 1, 1
        )
        tt:Show()
    end)

    if GameTooltip.HasScript and GameTooltip:HasScript("OnHide") then
        GameTooltip:HookScript("OnHide", function(tt)
            tt.__VendorPricePlusPendingAuctionatorStack = nil
        end)
    end
end

-- Hide Blizzard's redundant native Sell Price text only when VPP actually
-- supplies its own Vendor row. This is presentation-only and does not modify
-- the underlying sell value or merchant transaction.
local function HideLegacySellPrice(tt)
    local tooltipName = tt and tt.GetName and tt:GetName()
    if not tooltipName or not tt.NumLines then return end
    for line = 1, tt:NumLines() do
        local left = _G[tooltipName .. "TextLeft" .. line]
        local label = left and left:GetText()
        if type(label) == "string" and label:find(SELL_PRICE_TEXT, 1, true) == 1 then
            left:SetText("")
            local right = _G[tooltipName .. "TextRight" .. line]
            if right then right:SetText("") end
        end
    end
end

-- A disabled context must be a complete no-op: leave Blizzard's Sell
-- Price line and all other tooltip content intact. Centralizing this check
-- also covers fallback hooks that call SetPrice directly.
local LEGACY_CONTEXTS = {
    SetAuctionItem = "auctionHouse",
    Integration = "auctionHouse",
    SetBagItem = "inventoryBank",
    SetInventoryItem = "inventoryBank",
    SetTradePlayerItem = "inventoryBank",
    SetTradeTargetItem = "inventoryBank",
    SetLootItem = "inventoryBank",
    SetMerchantItem = "merchant",
    SetBuybackItem = "merchant",
    SetSendMailItem = "mail",
    SetInboxItem = "mail",
    SetTradeSkillItem = "professions",
    SetCraftItem = "professions",
    SetRecipeReagentItem = "professions",
    QuestReward = "questRewards",
    QuestRewardFallback = "questRewards",
    SetQuestItem = "questRewards",
    SetQuestLogItem = "questRewards",
}

function VP:SetPrice(tt, _, source, count, item)
    local context = LEGACY_CONTEXTS[source]
    if context and not VP:IsContextEnabled(context) then return end
    -- Resolve the item before the count. Action-bar callers can provide an item
    -- ID even when GetActionCount() itself is protected.
    if not item and tt and type(tt.GetItem) == "function" then
        item = select(2, tt:GetItem())
    end

    -- Never allow an unreadable/secret count to reach arithmetic. Item actions
    -- may safely recover the equivalent inventory count; other contexts fall
    -- back to one rather than substituting an unrelated bag total.
    count = Compat.ResolveStackCount(count, item, source == "SetAction")

    if item and Compat.CanAccessValue(item) then
        local sellPrice = select(11, Compat.GetItemInfo(item))
        if Compat.CanAccessNumber(sellPrice) and sellPrice > 0 then
            local stackPrice = sellPrice * count
            local unitPrice = sellPrice

            -- Forever tooltips with a native SellPrice line are handled while
            -- Blizzard is rendering that line (see the line post-call above).
            -- Returning here prevents the legacy hooks from appending a duplicate
            -- Unit Price after Forever's beta feedback/footer text.
            if Compat.IsForever() then
                return
            end

            -- A quest button can invoke both its setter and an OnEnter hook.
            -- Avoid adding our price twice to the same tooltip rendering.
            if tt.__VendorPricePlusLegacyPriceAdded then return end
            tt.__VendorPricePlusLegacyPriceAdded = true

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

            -- Auctionator already provides the unit Vendor row for singles.
            -- Keep Blizzard's native line if VPP contributed no replacement.
            if not IsAuctionatorLoaded() or count >= 2 then
                HideLegacySellPrice(tt)
            end
            tt:Show()
        end
    end
end

-- Reset the per-render guard whenever Blizzard clears the tooltip.
if GameTooltip and GameTooltip.HasScript and GameTooltip:HasScript("OnTooltipCleared") then
    GameTooltip:HookScript("OnTooltipCleared", function(tt)
        tt.__VendorPricePlusLegacyPriceAdded = nil
    end)
end

-- Legacy/public tooltip setters shared by the supported WoW clients.
local SetItem = {
    SetAction = function(tt, slot)
        local actionType, itemID = GetActionInfo(slot)
        if actionType == "item" then
            -- Forever uses the modern SellPrice pipeline for action-bar items and
            -- must not inspect GetActionCount(), which can be secret in combat.
            if Compat.IsForever() then
                return
            end

            -- Other supported clients can expose the same protected action count.
            -- Pass the item identity so SetPrice can recover a readable inventory
            -- count without performing arithmetic on GetActionCount().
            if not Compat.CanAccessNumber(itemID) then
                itemID = nil
            end
            VP:SetPrice(tt, true, "SetAction", GetActionCount(slot), itemID)
        end
    end,
    SetAuctionItem = function(tt, auctionType, index)
        if not VP:IsContextEnabled("auctionHouse") then return end
        local _, _, count = GetAuctionItemInfo(auctionType, index)
        VP:SetPrice(tt, false, "SetAuctionItem", count)
    end,
    SetBagItem = function(tt, bag, slot)
        if not VP:IsContextEnabled("inventoryBank") then return end
        local info = Compat.GetContainerItemInfo(bag, slot)
        if info and info.stackCount then
            VP:SetPrice(tt, true, "SetBagItem", info.stackCount)
        end
    end,
    SetInventoryItem = function(tt, unit, slot)
        if not VP:IsContextEnabled("inventoryBank") then return end
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

-- Classic tooltip surfaces that use their own item setters. Use the
-- tooltip's resolved item link rather than guessing from frame button IDs.
-- Capability checks keep this compatible with Era, seasonal and Anniversary.
if not Compat.IsForever() then
    local contexts = {
        SetBuybackItem = { key = "merchant", count = function(index)
            if type(GetBuybackItemInfo) == "function" then
                local _, _, _, count = GetBuybackItemInfo(index)
                return count
            end
        end },
        SetMerchantItem = { key = "merchant", count = function(index)
            if type(GetMerchantItemInfo) == "function" then
                local _, _, _, count = GetMerchantItemInfo(index)
                return count
            end
        end },
        SetSendMailItem = { key = "mail", count = function(index)
            -- GetSendMailItem returns name, itemID, texture, count, quality.
            -- The third value is a texture identifier, NOT the stack count.
            if type(GetSendMailItem) == "function" then
                local _, _, _, count = GetSendMailItem(index)
                return count
            end
        end },
        SetInboxItem = { key = "mail", count = function(index, attachment)
            -- Era's tooltip setter can be called with only the message index.
            -- Blizzard's GetInboxItem requires a separate attachment slot;
            -- never pass nil (the tooltip refreshes frequently on hover).
            if type(index) ~= "number" then return 1 end
            if type(attachment) ~= "number" then attachment = 1 end
            if type(GetInboxItem) == "function" then
                local _, _, _, count = GetInboxItem(index, attachment)
                return count
            end
            return 1
        end },
        SetQuestItem = { key = "questRewards" },
        SetQuestLogItem = { key = "questRewards" },
        SetTradePlayerItem = { key = "inventoryBank" },
        SetTradeTargetItem = { key = "inventoryBank" },
        SetLootItem = { key = "inventoryBank" },
        SetRecipeReagentItem = { key = "professions" },
        -- Era's original TradeSkillFrame and CraftFrame use these legacy
        -- setters for both the crafted output and individual reagents.
        SetTradeSkillItem = { key = "professions", count = function(skillIndex, reagentIndex)
            if reagentIndex and type(GetTradeSkillReagentInfo) == "function" then
                local _, _, required = GetTradeSkillReagentInfo(skillIndex, reagentIndex)
                return required
            end
            if type(GetTradeSkillNumMade) == "function" then
                local minimum = GetTradeSkillNumMade(skillIndex)
                return minimum
            end
            return 1
        end },
        SetCraftItem = { key = "professions", count = function(skillIndex, reagentIndex)
            if reagentIndex and type(GetCraftReagentInfo) == "function" then
                local _, _, required = GetCraftReagentInfo(skillIndex, reagentIndex)
                return required
            end
            if type(GetCraftNumMade) == "function" then
                local minimum = GetCraftNumMade(skillIndex)
                return minimum
            end
            return 1
        end },
    }
    for method, config in pairs(contexts) do
        if type(GameTooltip[method]) == "function" then
            hooksecurefunc(GameTooltip, method, function(tt, ...)
                if not VP:IsContextEnabled(config.key) then return end
                local count = config.count and config.count(...) or 1
                VP:SetPrice(tt, false, method, count)


            end)
        end
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

        -- Forever's Map & Quest Log uses GetQuestLogItem for both reward
        -- choices and guaranteed items. Its Sell Price row may be supplied by
        -- Blizzard or by this post-call, depending on the quest surface.
        local info = tt.GetProcessingTooltipInfo and tt:GetProcessingTooltipInfo()
        local getterName = info and info.getterName
        local isQuestReward = owner.objectType == "item"
            and (owner.type == "reward" or owner.type == "choice")
            and (getterName == "GetQuestLogItem" or getterName == "GetQuestItem")

        if isQuestReward then
            if not VP:IsContextEnabled("questRewards") then return end

            -- Normalize an existing native row instead of returning with the
            -- old Sell Price label. Keep its displayed amount untouched.
            local tooltipName = tt.GetName and tt:GetName()
            if tooltipName and tt.NumLines then
                for i = 1, tt:NumLines() do
                    local left = _G[tooltipName .. "TextLeft" .. i]
                    local text = left and left:GetText()
                    if type(text) == "string"
                        and text:find(SELL_PRICE_TEXT, 1, true) == 1 then
                        left:SetText(NORMAL_FONT_COLOR:WrapTextInColorCode("Vendor"))
                        return
                    end
                end
            end

            -- The Map & Quest Log sometimes omits Blizzard's price entirely.
            -- Add a single vendor row there, using the reward's known count.
            local count = tonumber(owner.count) or 1
            local sellPrice = select(11, Compat.GetItemInfo(item))
            if Compat.CanAccessNumber(sellPrice) and sellPrice > 0 then
                tt:AddDoubleLine(
                    NORMAL_FONT_COLOR:WrapTextInColorCode("Vendor"),
                    FormatMoneyWithIcons(sellPrice),
                    1, 1, 1, 1, 1, 1
                )
                if count >= 2 then
                    tt:AddDoubleLine(
                        NORMAL_FONT_COLOR:WrapTextInColorCode(format("Vendor |cff88ccffx%d|r", count)),
                        FormatMoneyWithIcons(sellPrice * count),
                        1, 1, 1, 1, 1, 1
                    )
                end
                tt:Show()
            end
            return
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

-- Direct quest reward button hook for the legacy quest UI used by supported
-- Classic clients. Forever's Map & Quest Log is handled by the modern tooltip
-- post-call above.
local function OnEnterQuestReward(self)
    if Compat.IsForever() or not VP:IsContextEnabled("questRewards") then return end

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

if type(QuestInfo_Display) == "function" then
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
end

-- Tooltip fallback using GetOwner() (DF-safe)
if GameTooltip.HasScript and GameTooltip:HasScript("OnTooltipSetItem") then
    GameTooltip:HookScript("OnTooltipSetItem", function(tt)
        local _, itemLink = tt:GetItem()
        if not itemLink then return end

        local owner = tt:GetOwner()
        if not owner then return end

        local parent = owner:GetParent()
        local parentName = parent and parent:GetName()

        if not Compat.IsForever() and VP:IsContextEnabled("questRewards") and parentName and parentName:match("^QuestInfoRewardsFrame") then
            VP:SetPrice(tt, false, "QuestRewardFallback", owner.count or 1, itemLink)
        end
    end)
end
