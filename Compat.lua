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

function Compat.IsAddOnLoaded(addonName)
    if C_AddOns and C_AddOns.IsAddOnLoaded then
        return C_AddOns.IsAddOnLoaded(addonName)
    end

    if IsAddOnLoaded then
        return IsAddOnLoaded(addonName)
    end

    return false
end

-- WoW Forever currently reports the Mainline project ID, so do not use
-- WOW_PROJECT_ID alone to distinguish it from Retail. Its interface generation
-- is 16000-series (currently 16001), while Retail is not.
function Compat.IsForever()
    local interfaceVersion = select(4, GetBuildInfo())
    return WOW_PROJECT_ID == WOW_PROJECT_MAINLINE
        and type(interfaceVersion) == "number"
        and interfaceVersion >= 16000
        and interfaceVersion < 17000
end
