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
        local _, count = GetContainerItemInfo(bag, slot)
        if count then
            return { stackCount = count }
        end
    end
end

function Compat.IsAddOnLoaded(name)
    if C_AddOns and C_AddOns.IsAddOnLoaded then
        return C_AddOns.IsAddOnLoaded(name)
    end
    if IsAddOnLoaded then
        return IsAddOnLoaded(name)
    end
    return false
end
