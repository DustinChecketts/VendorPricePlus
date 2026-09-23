# Changelog

## 1.2.2

### WoW Forever
- Fixed protected/secret stack-count errors when hovering stackable items on action bars.
- Restored Unit Price information for stackable action-bar item tooltips.
- Fixed incorrect Unit Price detection on recipe tooltips.
- Fixed duplicate Sell Price information on quest-offer reward tooltips.

## 1.2.1

### WoW Forever
- Fixed missing Sell Price on selectable quest rewards in the Map & Quest Log.
- Fixed protected/secret tooltip geometry errors when hovering item actions such as food and water on the action bar.
- Kept Forever price-row formatting on Blizzard's safe tooltip layout path instead of measuring protected FontString geometry.

## 1.2.0

### WoW Forever
- Added WoW Forever client detection and modern tooltip compatibility.
- Added compact Sell Price formatting with right-aligned money values.
- Added Unit Price directly beneath Sell Price for stacked item tooltips.
- Added support for Inventory & Bank, Mail, Merchant & Buyback, Professions, and Quest Reward contexts.
- Added missing vendor pricing to Forever quest reward tooltips.
- Added a Blizzard AddOns settings panel with per-context enable/disable controls.
- Added persistent settings through `VendorPricePlusDB`.
- Leaves the Forever Auction House unchanged because its tooltip already reports the correct per-unit vendor value.

### Architecture
- Added `Compat.lua` as the client/API compatibility layer.
- Moved third-party addon support into `Integrations.lua`.
- Added `Options.lua` for settings and configuration UI.
- Added human-readable comments around compatibility and tooltip behavior.
- Preserved the established non-Forever Vendor Price Plus behavior for supported Classic clients.

### Compatibility
- WoW Forever: tested successfully.
- TBC Anniversary: regression tested successfully.
- Classic Era: regression tested successfully.
- Mists of Pandaria Classic and Retail: not currently tested or advertised as supported.

## 1.1.3
- Previous production release.
