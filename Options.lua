-- VendorPricePlus options
--
-- This file owns saved preferences and the Blizzard AddOns settings panel.
-- Keeping configuration UI separate from tooltip behavior makes the core addon
-- easier to review and lets future contributors extend settings independently.

VendorPricePlus = VendorPricePlus or {}
local VP = VendorPricePlus
local Compat = VP.Compat

-- Every supported Forever tooltip surface is enabled on first install. These
-- switches are primarily here so players can opt out of a specific enhancement.
local CONTEXT_DEFAULTS = {
    inventoryBank = true,
    mail = true,
    merchant = true,
    professions = true,
    questRewards = true,
}

function VP:EnsureSettingsDefaults()
    VendorPricePlusDB = VendorPricePlusDB or {}
    VendorPricePlusDB.contexts = VendorPricePlusDB.contexts or {}

    for key, defaultValue in pairs(CONTEXT_DEFAULTS) do
        if VendorPricePlusDB.contexts[key] == nil then
            VendorPricePlusDB.contexts[key] = defaultValue
        end
    end
end

function VP:IsContextEnabled(key)
    self:EnsureSettingsDefaults()
    return VendorPricePlusDB.contexts[key] ~= false
end

function VP:SetContextEnabled(key, enabled)
    self:EnsureSettingsDefaults()
    VendorPricePlusDB.contexts[key] = enabled and true or false
end

-- The current context controls are Forever-specific because the older clients
-- use VendorPricePlus's established tooltip behavior. Shared display settings
-- can be added here later without mixing them into client compatibility code.
if not Compat.IsForever() then
    return
end

VP:EnsureSettingsDefaults()

local panel = CreateFrame("Frame", "VendorPricePlusOptionsPanel")
panel.name = "VendorPricePlus"

local function CreateOptionsPanel(self)
    if self.initialized then
        return
    end
    self.initialized = true

    local title = self:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 16, -16)
    title:SetText("VendorPricePlus")

    local subtitle = self:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    subtitle:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -8)
    subtitle:SetText("Choose where VendorPricePlus adds clearer vendor pricing.")

    local heading = self:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    heading:SetPoint("TOPLEFT", subtitle, "BOTTOMLEFT", 0, -22)
    heading:SetText("Show Unit Price In")

    local choices = {
        { key = "inventoryBank", label = "Inventory & Bank" },
        { key = "mail", label = "Mail" },
        { key = "merchant", label = "Merchant & Buyback" },
        { key = "professions", label = "Professions" },
        { key = "questRewards", label = "Quest Rewards" },
    }

    -- Anchor every checkbox to the panel, rather than to the previous checkbox.
    -- This keeps the controls in a perfectly straight column and makes spacing
    -- predictable if labels or rows are changed later.
    local firstY = -118
    local rowSpacing = 52
    local lastCheck

    for index, choice in ipairs(choices) do
        local check = CreateFrame("CheckButton", nil, self, "UICheckButtonTemplate")
        check:SetPoint("TOPLEFT", 12, firstY - ((index - 1) * rowSpacing))
        check:SetChecked(VP:IsContextEnabled(choice.key))

        local label = check:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
        label:SetPoint("LEFT", check, "RIGHT", 2, 0)
        label:SetText(choice.label)

        check:SetScript("OnClick", function(button)
            VP:SetContextEnabled(choice.key, button:GetChecked())
        end)

        lastCheck = check
    end

    local note = self:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
    note:SetPoint("TOPLEFT", lastCheck, "BOTTOMLEFT", 4, -18)
    note:SetWidth(500)
    note:SetJustifyH("LEFT")
    note:SetText("All supported tooltip contexts are enabled by default. The Auction House already shows Blizzard's correct per-unit Sell Price, so VendorPricePlus leaves it unchanged.")
end

panel:SetScript("OnShow", CreateOptionsPanel)

-- Prefer the modern Settings API, while retaining the legacy registration path
-- for clients that still expose InterfaceOptions_AddCategory.
if Settings and Settings.RegisterCanvasLayoutCategory and Settings.RegisterAddOnCategory then
    local category = Settings.RegisterCanvasLayoutCategory(panel, "VendorPricePlus")
    Settings.RegisterAddOnCategory(category)
    VP.OptionsCategory = category
elseif InterfaceOptions_AddCategory then
    InterfaceOptions_AddCategory(panel)
end

-- /vpp is a convenience shortcut to the same panel available under AddOns.
SLASH_VENDORPRICEPLUS1 = "/vpp"
SlashCmdList.VENDORPRICEPLUS = function()
    if Settings and Settings.OpenToCategory and VP.OptionsCategory then
        Settings.OpenToCategory(VP.OptionsCategory:GetID())
    elseif InterfaceOptionsFrame_OpenToCategory then
        -- Older Blizzard clients sometimes require two calls to fully select an
        -- addon category after opening the Interface Options window.
        InterfaceOptionsFrame_OpenToCategory(panel)
        InterfaceOptionsFrame_OpenToCategory(panel)
    else
        print("VendorPricePlus options are available from the AddOns settings.")
    end
end
