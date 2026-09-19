# Architecture

VendorPricePlus is maintained by StormtrooperTK421 as part of a multi-client World of Warcraft addon family.

## Design goals

- Keep feature behavior independent from Blizzard client-specific APIs where practical.
- Prefer capability detection over client/version checks.
- Keep client/API compatibility in `Compat.lua`.
- Keep third-party addon compatibility in `Integrations.lua`.
- Preserve one addon version across supported WoW clients; client support is not the addon version.
- Avoid intentional behavior changes during architecture-only refactors.

## File responsibilities

- `VendorPricePlus.lua` — core vendor-price feature and Blizzard tooltip behavior.
- `Compat.lua` — Blizzard API adapters and capability fallbacks.
- `Integrations.lua` — optional third-party addon integrations.
- `VendorPricePlus.toc` — metadata and load order.

## Compatibility strategy

Feature code should call the compatibility layer when Blizzard exposes equivalent functionality through different APIs. Explicit client detection should be added only when capability detection cannot safely distinguish behavior.

WoW Forever must not be assumed to be Retail solely because it reports `WOW_PROJECT_MAINLINE`; capability checks remain authoritative.

## Development

`main` is the known-good/release branch. Compatibility and modernization work is developed on branches and merged after testing.

VendorPricePlus is authored and maintained by StormtrooperTK421. Development and modernization work is performed with assistance from OpenAI's ChatGPT, including code implementation, compatibility work, testing support, and documentation.
