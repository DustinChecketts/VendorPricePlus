-- VendorPricePlus client/API compatibility layer
--
-- Keep differences between WoW client API surfaces here so feature code can
-- remain client-agnostic. Prefer capability detection over project IDs.

VendorPricePlus = VendorPricePlus or {}
local VP = VendorPricePlus

VP.Compat = VP.Compat or {}
local Compat = VP.Compat

function Compat.GetItemInfo(item)
    if C_Item and C_Item.GetItemInfo then
        return C_Item.GetItemInfo(item)
    end

    if GetItemInfo then
        return GetItemInfo(item)
    end
end

function Compat.GetContainerItemInfo(bag, slot)
    if C_Container and C_Container.GetContainerItemInfo then
        return C_Container.GetContainerItemInfo(bag, slot)
    end

    if GetContainerItemInfo then
        local texture, stackCount, locked, quality, readable, lootable, itemLink,
              isFiltered, noValue, itemID, isBound = GetContainerItemInfo(bag, slot)

        if texture then
            return {
                iconFileID = texture,
                stackCount = stackCount,
                isLocked = locked,
                quality = quality,
                isReadable = readable,
                hasLoot = lootable,
                hyperlink = itemLink,
                isFiltered = isFiltered,
                hasNoValue = noValue,
                itemID = itemID,
                isBound = isBound,
            }
        end
    end
end

-- Secret/protected values can be passed through addon code but must not be
-- inspected, compared, converted, or used in arithmetic unless readable.
-- Prefer canaccessvalue when available; older clients simply treat ordinary
-- values as readable.
function Compat.CanAccessValue(value)
    if canaccessvalue then
        local ok, allowed = pcall(canaccessvalue, value)
        return ok and allowed and true or false
    end

    if issecretvalue then
        local ok, secret = pcall(issecretvalue, value)
        return ok and not secret
    end

    return value ~= nil
end

function Compat.CanAccessNumber(value)
    return type(value) == "number" and Compat.CanAccessValue(value)
end

-- Action-bar counts can become secret in combat. For item actions only, recover
-- the usable inventory count from GetItemCount/C_Item.GetItemCount. Do not use
-- this fallback for bag slots, mail attachments, or other individual stacks,
-- where the total inventory count could describe a different quantity.
function Compat.GetItemCount(item)
    if not Compat.CanAccessValue(item) or item == nil then
        return nil
    end

    local itemInfo = item
    if type(item) == "string" then
        local id = item:match("item:(%d+)")
        if id then
            itemInfo = tonumber(id)
        end
    end

    local getter = (C_Item and C_Item.GetItemCount) or GetItemCount
    if type(getter) ~= "function" then
        return nil
    end

    local ok, count = pcall(getter, itemInfo, false, true)
    if ok then
        return count
    end
end

function Compat.ResolveStackCount(count, item, recoverFromInventory)
    if Compat.CanAccessNumber(count) then
        return count
    end

    if recoverFromInventory then
        local bagCount = Compat.GetItemCount(item)
        if Compat.CanAccessNumber(bagCount) then
            return bagCount
        end
    end

    return 1
end

function Compat.IsAddOnLoaded(addonName)
    if C_AddOns and C_AddOns.IsAddOnLoaded then
        return C_AddOns.IsAddOnLoaded(addonName)
    end

    if IsAddOnLoaded then
        return IsAddOnLoaded(addonName)
    end

    return false
end

-- WoW Forever reported the Mainline project ID through build 1.60.1.70124 and
-- its own, WOW_PROJECT_CAMELOT, from 1.60.1.70170. Accept either, and tell it
-- from Retail by its interface generation: 16000-series (currently 16001),
-- while Retail is not. WOW_PROJECT_CAMELOT is nil on clients without it.
function Compat.IsForever()
    local interfaceVersion = select(4, GetBuildInfo())
    return (WOW_PROJECT_ID == WOW_PROJECT_MAINLINE or WOW_PROJECT_ID == WOW_PROJECT_CAMELOT)
        and type(interfaceVersion) == "number"
        and interfaceVersion >= 16000
        and interfaceVersion < 17000
end
