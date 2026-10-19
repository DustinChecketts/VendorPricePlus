# Architecture

VendorPricePlus is maintained by StormtrooperTK421 as an independently installable, multi-client World of Warcraft addon. Development follows [StormCore](https://github.com/DustinChecketts/stormcore).

## Design goals

- Extend Blizzard's existing tooltip presentation rather than replace it.
- Share vendor-price calculations where practical, while isolating differing client APIs and presentation.
- Prefer capability checks over client identity assumptions; WoW Forever is not Retail.
- Preserve previously tested client behavior, existing settings, and the `/vpp` command.
- Keep Auctionator's normal tooltip presentation and row order intact.
- Do not refactor proven behavior merely for architectural conformity.

## File responsibilities

- `VendorPricePlus.lua` — core vendor-price feature, context handling, and Blizzard tooltip behavior.
- `Compat.lua` — Blizzard API adapters, capability checks, and compatibility fallbacks.
- `Options.lua` — settings panel, defaults, and persisted preferences in `VendorPricePlusDB`.
- `Integrations.lua` — optional third-party addon integrations, including Auctionator coexistence.
- `VendorPricePlus.toc` — addon metadata, interface declarations, and load order.
- `.pkgmeta` — release-package contents and manual changelog configuration.
- `.github/workflows/` — validation and release automation (not shipped to players).

## Compatibility and safety

WoW Forever may expose protected or secret values through tooltip APIs, owner metadata, and stack counts. Validate readability before comparisons, formatting, arithmetic, or other inspection. A total inventory count must not silently replace the quantity represented by a particular tooltip.

Forever's Map & Quest Log quest reward tooltip can use the `GetQuestLogItem` processing path. The native Sell Price presentation requires context-aware handling to display the addon label `Vendor`. Preserve this tested path rather than reintroducing obsolete reward-specific workarounds.

Legacy and modern tooltip behavior should remain distinct where Blizzard's APIs differ. When a pricing context is disabled, avoid modifying that tooltip.

Where callback timing, post-processing, or a Blizzard global override is needed, document the reason, scope, and regression tests near the implementation. In particular, test Auctionator with the integration both enabled and disabled.

## Development and release

`main` is the known-good release branch. Changes are developed and tested on separate branches. No PR, merge, tag, or publication without maintainer approval.

Before publishing, verify Lua 5.1 syntax, TOC references, version consistency (TOC/README/CHANGELOG/tag), saved settings, client regression tests, and the actual installable ZIP contents. Refer to StormCore's release-readiness checklist.

VendorPricePlus is authored and maintained by StormtrooperTK421, with development assistance from OpenAI's ChatGPT.
