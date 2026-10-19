# VendorPricePlus development guidance

Follow the shared StormCore standards: https://github.com/DustinChecketts/stormcore

Read StormCore's AGENTS.md and standards/development.md, compatibility.md, and packaging.md before significant changes.

## Local project rules
- VendorPricePlus is independently installable. Do not add a StormCore runtime dependency.
- Preserve the existing /vpp command, VendorPricePlusDB SavedVariables, and options across upgrades.
- Preserve tested WoW Forever and Classic Anniversary behavior while expanding Classic Era, Hardcore, and seasonal tooltip coverage.
- Keep pricing calculations shared; isolate API-specific tooltip handling in readable, small functions.
- Prefer Blizzard-native UI and nonintrusive Auctionator coexistence. Do not duplicate vendor rows.
- Never perform arithmetic on secret/protected values; verify readable values first.
- Keep the addon author and CurseForge project metadata intact.
- Use a development branch; no PR, merge, tag, or release without maintainer approval.
- Before proposing a release, validate Lua 5.1 syntax, TOC file references, version consistency, package contents, and in-game client coverage.
- Developer documentation, tests, and CI files must not ship in the addon ZIP.
