# Vendor Price Plus

Vendor Price Plus is a lightweight World of Warcraft addon that makes vendor values easier to read without adding unnecessary bulk to item tooltips.

Version 1.2.0 adds support for **WoW Forever** while preserving the addon's established behavior for **TBC Anniversary** and **Classic Era**. Retail and Mists of Pandaria Classic are not currently tested or advertised as supported.

## Features

### WoW Forever

- Keeps Blizzard's native **Sell Price** and presents it in a consistent, compact format.
- Adds **Unit Price** directly below Sell Price when a tooltip represents more than one item.
- Right-aligns money values so gold, silver, and copper denominations are easy to scan.
- Keeps single-item tooltips simple: Sell Price is formatted consistently without adding a redundant Unit Price.
- Enhances supported Inventory & Bank, Mail, Merchant & Buyback, Profession, and Quest Reward tooltip contexts.
- Leaves the Auction House unchanged because Forever already displays the correct per-unit vendor value there.
- Includes an AddOns settings panel with per-context controls, enabled by default.

### TBC Anniversary and Classic Era

Vendor Price Plus retains its established Classic behavior:

- Displays the vendor value per item.
- Displays the total vendor value of a stack.
- Integrates with Blizzard's default tooltip UI.
- Supports Auctionator-aware tooltip behavior.

## Commands

- `/vpp` — Opens Vendor Price Plus settings on WoW Forever.

## Compatibility

| Client | Status |
| --- | --- |
| WoW Forever | Supported |
| TBC Anniversary | Supported |
| Classic Era / Hardcore / Season of Discovery | Supported architecture; Classic Era regression test pending for 1.2.0 |
| Mists of Pandaria Classic | Not currently tested/supported |
| Retail | Not currently tested/supported |

## Acknowledgements

Vendor Price Plus includes functionality derived from the original **Vendor Price** addon by Ketho17 and Icesythe7. Their historical author credits remain in the addon metadata.

## Development

Vendor Price Plus is authored, maintained, and published by **StormtrooperTK421**. Development and modernization work is performed with assistance from OpenAI's ChatGPT, including code implementation, compatibility work, testing support, and documentation.

The code is intentionally separated by responsibility:

- `Compat.lua` — client/API compatibility
- `Options.lua` — settings and saved preferences
- `VendorPricePlus.lua` — core tooltip behavior
- `Integrations.lua` — third-party addon integrations

Issues and pull requests are welcome. Code is commented where behavior or compatibility decisions may not be obvious to future contributors.

## License

Vendor Price Plus is released under the MIT License.
