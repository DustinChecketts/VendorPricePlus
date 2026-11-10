-- Temporary, opt-in tooltip diagnostic for Auctionator/VPP compatibility.
-- Remove this file and its TOC/SavedVariables entries before release.
VendorPricePlus = VendorPricePlus or {}
local VP = VendorPricePlus
local D = {}
VP.Debug = D

local function safe(value)
    if value == nil then return "nil" end
    if VP.Compat and not VP.Compat.CanAccessValue(value) then return "<protected>" end
    local ok, result = pcall(tostring, value)
    return ok and result or "<unreadable>"
end

local function log(message)
    if not D.enabled then return end
    VendorPricePlusDebugLog = VendorPricePlusDebugLog or {}
    if #VendorPricePlusDebugLog >= 350 then return end
    VendorPricePlusDebugLog[#VendorPricePlusDebugLog + 1] =
        safe(date and date("%H:%M:%S") or "") .. " " .. message
end

function D.Log(event, detail)
    log(safe(event) .. (detail and (" | " .. safe(detail)) or ""))
end

function D.Bypass()
    return D.enabled and D.bypass
end

local function ownerPath(tt)
    local frame = tt and tt.GetOwner and tt:GetOwner()
    local parts = {}
    for i = 1, 12 do
        if not frame then break end
        local name = frame.GetName and frame:GetName()
        parts[#parts + 1] = safe(name or (frame.GetObjectType and frame:GetObjectType()))
        frame = frame.GetParent and frame:GetParent()
    end
    return table.concat(parts, " > ")
end

local function snapshot(tt, event)
    if not D.enabled or not tt or not tt.NumLines then return end
    local name = tt.GetName and tt:GetName()
    if not name then return end
    local rows = {}
    for i = 1, math.min(tt:NumLines(), 35) do
        local left = _G[name .. "TextLeft" .. i]
        local right = _G[name .. "TextRight" .. i]
        local label = left and left:GetText()
        if type(label) == "string" and
            (label:find("Vendor", 1, true) or label:find("Auction", 1, true)
             or label:find("Sell Price", 1, true)) then
            rows[#rows + 1] = i .. ":" .. safe(label) .. "=" .. safe(right and right:GetText())
        end
    end
    local signature = table.concat(rows, " / ")
    if signature ~= D.lastRows then
        D.lastRows = signature
        log(event .. " rows: " .. (signature ~= "" and signature or "(none)"))
    end
end

function D.Capture(tt, event, detail)
    if not D.enabled then return end
    local info = tt and tt.GetProcessingTooltipInfo and tt:GetProcessingTooltipInfo()
    local itemName, link
    if tt and type(tt.GetItem) == "function" then
        local ok, a, b = pcall(tt.GetItem, tt)
        if ok then itemName, link = a, b end
    end
    local owner = tt and tt.GetOwner and tt:GetOwner()
    log(event .. " | " .. safe(detail) .. " | item=" .. safe(itemName)
        .. " link=" .. safe(link) .. " getter=" .. safe(info and info.getterName)
        .. " owner.count=" .. safe(owner and owner.count)
        .. " ownerPath=" .. ownerPath(tt)
        .. " AH=" .. safe(AuctionFrame and AuctionFrame.IsShown and AuctionFrame:IsShown())
        .. " Auctionator=" .. safe(VP.Compat.IsAddOnLoaded("Auctionator"))
        .. " bypass=" .. safe(D.bypass))
    snapshot(tt, event)
end

local function setMode(enabled, bypass)
    D.enabled = enabled
    D.bypass = bypass or false
    D.lastRows = nil
    VendorPricePlusDebugLog = {}
    if enabled then
        log("TRACE START | diagnostic build | mode=" .. (D.bypass and "bypass" or "normal"))
        log("build=" .. safe(select(4, GetBuildInfo()))
            .. " VPP=1.2.4-diagnostic Auctionator=" .. safe(VP.Compat.IsAddOnLoaded("Auctionator")))
    end
    print("VPP diagnostic: " .. (enabled and (D.bypass and "BYPASS" or "NORMAL") or "OFF"))
end

SLASH_VPPDEBUG1 = "/vppdebug"
SlashCmdList.VPPDEBUG = function(input)
    input = (input or ""):lower():match("^%s*(.-)%s*$")
    if input == "on" then
        setMode(true, false)
    elseif input == "bypass" then
        setMode(true, true)
    elseif input == "off" then
        D.enabled = false
        D.bypass = false
        print("VPP diagnostic OFF; existing log preserved until next /vppdebug on or bypass")
    elseif input == "status" then
        print("VPP diagnostic " .. (D.enabled and (D.bypass and "BYPASS" or "NORMAL") or "OFF")
            .. "; entries=" .. safe(VendorPricePlusDebugLog and #VendorPricePlusDebugLog or 0))
    else
        print("/vppdebug on | bypass | off | status")
    end
end

if GameTooltip and GameTooltip.HookScript then
    if GameTooltip:HasScript("OnTooltipSetItem") then
        GameTooltip:HookScript("OnTooltipSetItem", function(tt)
            D.Capture(tt, "OnTooltipSetItem")
        end)
    end
    if GameTooltip:HasScript("OnTooltipCleared") then
        GameTooltip:HookScript("OnTooltipCleared", function()
            D.lastRows = nil
        end)
    end
    GameTooltip:HookScript("OnUpdate", function(tt)
        snapshot(tt, "OnUpdate")
    end)
end

-- Observe appended rows without replacing the tooltip API. This captures
-- Auctionator's and VPP's additions; source attribution comes from VPP markers.
if GameTooltip and type(GameTooltip.AddDoubleLine) == "function" then
    hooksecurefunc(GameTooltip, "AddDoubleLine", function(tt, left, right)
        if D.enabled then
            log("AddDoubleLine | " .. safe(left) .. " = " .. safe(right))
        end
    end)
end
