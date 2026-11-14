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

## Mandatory research-first workflow
1. Before unfamiliar features or bug fixes, search maintained WoW addons that solve the same or similar problem. Inspect their source code and Blizzard UI implementations when relevant; document the applicable APIs, compatibility constraints, and tradeoffs. Respect licenses and credit adaptations.
2. If no proven implementation exists, consult Blizzard UI source, API documentation, and reliable technical references. Separate facts from hypotheses; use minimal read-only diagnostics and targeted in-game tests to gather evidence. Do not cycle through speculative fixes.
3. Before substantial changes, define module responsibilities and preserve clear boundaries between compatibility, data, logic, UI, events, and options where useful. Prefer existing Blizzard APIs and simple reusable helpers over duplication or needless abstractions.
4. Review code for consistency, dead code, oversized modules, performance costs, and unintended client regressions. Run applicable StormCore lint, format, syntax, TOC, and packaging checks. Clearly distinguish offline checks from in-game verification.
5. Work on dedicated branches, preserve known-good behavior, and do not open PRs during iteration, merge, tag, or publish without maintainer approval. Report evidence, changes, checks, remaining uncertainty, and exact test instructions.

Priority: correctness and compatibility > architecture and maintainability > portfolio consistency > lightweight simplicity > optional visual polish.
