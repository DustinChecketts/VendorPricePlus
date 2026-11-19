-- Completed-tooltip reconciliation for pricing addons.
-- Work only on a tooltip queued by the Forever SellPrice callback; no global scanning.
VendorPricePlus = VendorPricePlus or {}
local VP = VendorPricePlus

local function GetLines(tt)
    local name = tt and tt.GetName and tt:GetName()
    if not name or not tt.NumLines then return end
    local rows = {}
    for i = 1, tt:NumLines() do
        local left = _G[name .. "TextLeft" .. i]
        local right = _G[name .. "TextRight" .. i]
        local label = left and left:GetText()
        if type(label) == "string" then
            -- Color codes and leading whitespace are presentation, not identity.
            local plain = label:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""):match("^%s*(.-)%s*$")
            rows[#rows + 1] = { label = plain, left = left, right = right }
        end
    end
    return rows
end

function VP:QueuePriceReconciliation(tt, context, count, stackPrice)
    if not tt then return end
    tt.__VendorPricePlusReconcile = {
        context = context,
        count = count,
        stackPrice = stackPrice,
        -- Wait until other addons have had an opportunity to append their rows.
        passes = 0,
    }
end

function VP:ReconcilePriceRows(tt)
    local pending = tt.__VendorPricePlusReconcile
    if not pending then return end
    if pending.context and not self:IsContextEnabled(pending.context) then
        tt.__VendorPricePlusReconcile = nil
        return
    end

    local rows = GetLines(tt)
    if not rows then
        tt.__VendorPricePlusReconcile = nil
        return
    end

    local native, vendor, stackVendor
    for _, row in ipairs(rows) do
        if row.label:find("^Sell Price:") then
            native = row
        elseif row.label:find("^Vendor%s*[xX]%d+") then
            stackVendor = true
        elseif row.label:match("^Vendor%s*:?$") then
            vendor = true
        end
    end

    pending.passes = pending.passes + 1
    if not vendor and pending.passes < 2 then return end

    if native then
        if vendor then
            -- An addon already provides Vendor; suppress only the redundant native row.
            native.left:SetText("")
            if native.right then native.right:SetText("") end
        else
            -- No competing Vendor row: keep the native price visible under VPP's label.
            native.left:SetText(NORMAL_FONT_COLOR:WrapTextInColorCode("Vendor"))
        end
    end

    -- A verified stack count is supplemental; never infer it by dividing prices.
    if pending.count and pending.count >= 2 and pending.stackPrice and not stackVendor then
        local amount = pending.stackPrice
        local gold = math.floor(amount / 10000)
        local silver = math.floor(amount % 10000 / 100)
        local copper = amount % 100
        local money = ""
        if gold > 0 then money = money .. gold .. " |TInterface\\MoneyFrame\\UI-GoldIcon:12:12:0:0|t " end
        if silver > 0 or gold > 0 then money = money .. silver .. " |TInterface\\MoneyFrame\\UI-SilverIcon:12:12:0:0|t " end
        money = money .. copper .. " |TInterface\\MoneyFrame\\UI-CopperIcon:12:12:0:0|t"
        tt:AddDoubleLine(NORMAL_FONT_COLOR:WrapTextInColorCode("Vendor |cff88ccffx" .. pending.count .. "|r"), money, 1, 1, 1, 1, 1, 1)
        tt:Show()
    end
    tt.__VendorPricePlusReconcile = nil
end
