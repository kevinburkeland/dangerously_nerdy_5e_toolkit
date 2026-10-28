# Changelog

One line per slice, newest first. Each line: date, slice name, what changed for a user or a developer.
Work before Map slice 1.1 (hardening passes 0 to 12) is in the git history.

## 2026-10-28
- Cleanup slice 5: Restore lost settings screen widget tests, add test-name ratchet script, self-test suite, CI workflow integration, unified settings codec field table, arena damage adjustment ordering delegating to upstream ruleset, and unified dice expression handling with graceful invalid notation rejection across all roll call sites.

## 2026-10-27
- Cleanup slice 4.1: Checked legacy inventory (`B1`–`B30`) with real controls (`LC1`–`LC5`), derived fixtures, and upstream pin bumps. Full backup restore now restores settings; a missing key keeps the current value, a bad value is skipped and reported.

## 2026-10-26
- Cleanup slice 3: Automated mutation branch retirement script, self-test, legacy campaign safety net, golden fixtures, and legacy load law test.
- Mutation slice-id prefixes: ms111 = Map slice 1.1.1, ms12 = 1.2, ms121 = 1.2.1, ms13 = 1.3, ms14 = 1.4, ms141 = 1.4.1, ms15 = 1.5, ms16 = 1.6, cs1 = Cleanup slice 1, cs2 = Cleanup slice 2, cs3 = Cleanup slice 3, cs41 = Cleanup slice 4.1.
- Cleanup slice 2: Architecture documentation truth, generated codebase map tool, architecture decision records, markdown link verification, and accurate sync description.
- Cleanup slice 1: Streamline README, extract feature catalog to docs/FEATURES.md, add mutation branch CI checks, link validation test, and repository hygiene rules.
- Map slice 1.6: Battle map tokens layout, mover, candidates, view, layer, picker, panel, screens, and source bars.

## 2026-10-25
- Map slice 1.5: Token storage, sync, rules, service, controller, and source bars.
- Map slice 1.4.1: Grid editor, feet validation, map panning and recenter.
- Map slice 1.4: Shared map grid, ruler, controls, and sync.
- Map slice 1.3: Active map controller, intake service, blob store, and UI screens.
- Map slice 1.2.1: Map transfer resilience and reliability fixes.

## 2026-10-24
- Map slice 1.2: Blob store and map transfer adapter.
- Map slice 1.1.1: Map references browser loading fixes.
- Map slice 1.1: Active map reference in campaign profile.
