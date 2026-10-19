# Vendor Price Plus

**Version 1.2.4**

Vendor Price Plus is a lightweight World of Warcraft addon that makes vendor values easier to read while preserving Blizzard's familiar item tooltips.

## Features

- Displays vendor values in supported item tooltips, using **Vendor** for an individual item and **Vendor xN** for a stack when its count is available.
- Supports Inventory & Bank, Mail, Merchant & Buyback, Professions, Quest Rewards, and Auction House tooltips, subject to client capabilities.
- Provides a Blizzard AddOns options panel to choose where vendor pricing appears. All supported contexts are enabled by default; **Defaults** restores these settings.
- Leaves Blizzard's native tooltip behavior in place when a context is disabled.
- Coexists with Auctionator without intentionally duplicating its vendor-price rows or disrupting its usual ordering.
- Retains the same independently installable addon across supported Classic clients and WoW Forever.

Exact tooltip behavior may vary by client and context. In WoW Forever, vendor-price formatting uses the client's modern tooltip processing path. In Classic clients, the addon preserves the relevant legacy tooltip behavior.

## Commands

- `/vpp` — Open Vendor Price Plus settings.

## Compatibility

| Client | Version 1.2.4 status |
| --- | --- |
| WoW Forever | Tested, including quest rewards |
| TBC Anniversary | Regression tested during 1.2.4 development |
| Classic Era | Previously supported; final 1.2.4 regression test pending |
| Classic Era Hardcore and seasonal variants | Expected to follow Classic Era behavior; not separately verified for 1.2.4 |
| Mists of Pandaria Classic | Not tested or advertised as supported |
| Retail | Not tested or advertised as supported |

The TBC Anniversary quest-log reward tooltip may display the unit vendor value without a total stack value. See [CHANGELOG.md](CHANGELOG.md) for release history and known limitations.

## Acknowledgements

Vendor Price Plus builds on the original **Vendor Price** addon by Ketho17 and Icesythe7. Historical author credits remain in the addon metadata.

## Development

Vendor Price Plus is authored, maintained, and published by **StormtrooperTK421**, with development assistance from OpenAI's ChatGPT.

The code is organized by responsibility:

- `Compat.lua` — client and API compatibility
- `Options.lua` — settings and saved preferences
- `VendorPricePlus.lua` — core tooltip behavior
- `Integrations.lua` — third-party addon integration

Development follows the shared [StormCore standards](https://github.com/DustinChecketts/stormcore). Issues and pull requests are welcome.

## License

MIT License.
