# Changelog

One line per slice, newest first. Each line: date, slice name, what changed for a user or a developer.
Work before Map slice 1.1 (hardening passes 0 to 12) is in the git history.

## 2026-11-12
- Bonus slice 2: Flutter 3.50 deprecates package:flutter/material.dart, every Material import moved to material_ui (1.11.0), and the Flutter-free checks now decide from the package graph because the old name list missed material_ui.
- Bonus slice 2: Update DC36 in test_check_dependencies.sh to dynamically read repo target SDK.
- Bonus slice 2: Retire bs11 mutation branches, enforce Fix titles section, checklist brackets, and byte-identity in check_notes_shas, validate cancelled runs and deviation cause lines, document Bonus slice 1.1 runs, and add self-tests NS38-NS53.

## 2026-11-11
- Bonus slice 1.1: Enforce mutation branch commit rules (single commit, Signed-off-by trailer, and MUTATION subject format with matching id), validate remote branch subjects and active branch limit in check_mutation_branches.sh, support dated exact-SHA exceptions in mutation_subject_exceptions.tsv, verify notes Mutation branches section and commit subjects in check_notes_shas.py, and add MB1-MB17, RM1-RM20, and NS32-NS37 self-tests.
- Bonus slice 1.1: Declare npm overrides in dependency_exceptions.tsv as dated exceptions with 30-day review dates, which existed since Bonus slice 1 without being declared (removing GHSA-m9gg-hp2v-232j, GHSA-f596-whhp-79r4, GHSA-8988-4f7v-96qf, GHSA-3g3m-2fjr-6pw4, GHSA-g3hv-75wg-m249, and GHSA-w5hq-g745-h8pq across firebase and firebase-tools), move @opentelemetry/core, glob, and minimatch to newest in major, enforce override declaration rule N4 and per-advisory rule N2, and add DC60-DC69 self-tests.
- Bonus slice 1.1: Calculate wait counts from first newer release date, enforce declared floor currency (rule D6), tighten direct dependency floors, refine D4 exception reasons, update actions/setup-java pin, pin core to a570912f39a03889a1c76b03482ed9c680e2df3a and ruleset to d34b11dcad7678563d2990ece6f969f4455bd50e, and add DC50-DC59 self-tests.
- Bonus slice 1.1: Enforce fail-closed validation for missing or unreadable inputs, validate pub and npm JSON shapes, fail on npm audit/outdated error objects, and add DC42-DC49 self-tests.
- Bonus slice 1.1: Fix workflow parsing in check_dependencies to follow jobs layout, check exact min-sdk job id, require single min-sdk job with single setup-dart step in pure Dart packages, print setup-dart summary, and add DC36-DC41 self-tests.

## 2026-11-10
- Bonus slice 1: Update npm dependencies with zero audit vulnerabilities, Node to 26 LTS, Actions pins to newest releases, wire check_dependencies in CI, and add weekly workflow.
- Bonus slice 1: Bring Dart packages, Flutter SDK (3.47.9), and upstream engine/ruleset pins up to date, resolve linter findings, and ratchet strict analysis ignore count to 47.
- Bonus slice 1: Baseline test measurements across core, ruleset, app, and firestore rules emulators, and defer cs101 mutation branch retirement.

## 2026-11-06
- Cleanup slice 10.1: Retire cs10 mutation branches; check_notes_shas verifies Fix checklist against Fix ids with NS23-NS31 self-tests; PartyRoomService.newInstance restores isolated DiceRoomService.newInstance default, with party room dice isolation test and test setups updated; combat actions carry data instead of callbacks via ActionRoll and ActionUse, presentation runner combat_action_runner.dart, presentation boundary bars test rules P1-P3, and resolver line ceiling reduced to 1909; Argb and AppIcon pure-Dart visual types with presentation bridge, glyph_tokens split into models-facing glyph_kinds and presentation glyph_kinds_ui, pinned with 1801-entry UI value snapshot characterization test; 15 creatures and summons models hold plain Argb and AppIcon values with zero Flutter imports and presentation visual extensions, reducing layer allowlist to 27 files; convert remaining models (app settings, arena simulation, srd equipment, rollable tables, spellbook data, glyph gallery, magic item data) to plain Argb and AppIcon values with Flutter imports eliminated, enforcing zero Flutter imports in lib/models/ with zero allowlist, and clearing all remaining flutter entries from layer allowlist down to 19 entries.

## 2026-11-05
- Cleanup slice 10: Retire cs9 mutation branches; move InjectionContainer to service_container.dart with zero service imports, remove static bind methods, rename cache and test reset methods, add shared test helper, and add rules 4 and 5 to service_locator_bars_test.dart; make configure/newInstance/bind collaborator bindings required and non-null with _require getters on CampaignProfileService, DmBackupService, and DiceRoomService, and add unbound_collaborator_law_test.dart and bar rule 6; make CampaignStorageMigration stateless with required non-null parameters, add runStartupMigrationFromServices in main.dart, restore stubbed-DI startup control test, and add bar rule 7; add layer import table to docs/ARCHITECTURE.md and enforce it with exact allowlist and controls in layer_import_table_test.dart; eliminate upward dependencies from models by replacing flutter/foundation with meta in 7 files, replacing ruleset re-export shims with package imports, moving landing_tool_item.dart to presentation, extracting UI members to presentation widgets, and moving EntityFluff to models domain, reducing layer allowlist from 50 to 40 files.
- Cleanup slice 9: Retire script pushes archive tags atomically with leased branch deletions; notes check verifies run-id form and red runs, and adds self-tests NS14-NS22; DI graph law and characterization tests pin normal-startup behavior across migration, persistence, dice room, party room, and screens; campaign and dice room services off the locator with no isRegistered in lib/services; screens without isRegistered and service locator bars for imports, isRegistered calls, and sl and defaults ceilings; big-file ratchet pins files over 1,500 lines to a 38-file allowlist with exact line-count ceilings.

## 2026-11-04
- Cleanup slice 8: Retire cs7 mutation branches; split unit test suite across 4 parallel shards via test_shard.py with workflow matrix integration; enforce single root analysis_options.yaml in check_strict_analysis.sh; lower dynamic ceiling to 1054 via Object? cast in webrtc_mesh_adapter and direct ruleset pass in homebrew_persistence_service; verify CI run IDs in check_notes_shas.py with API caching and fail-closed semantics, fix run ID in cleanup_slice_7_progress.md, and add NS8-NS13 self-tests.
- Cleanup slice 7: Retire cs6 mutation branches; restore test removal list header and align deleted file reasons; add dynamic ratchet test, implicit-dynamic ceilings script, and CI verification; type 10 error callbacks and promote 14 guarded for loops under strict-casts; make explicit remaining 24 strict cast sites and update test suites with dynamic ceiling ratchet at 1056; turn on strict-casts permanently with canary and options/ignore guards in check_strict_analysis.sh and documentation updates.

## 2026-11-03
- Cleanup slice 6: Ratchet sees renamed and moved test files with --no-renames and self-tests TN9-TN11; real SHAs in progress notes verified by check_notes_shas and CI integration; reachability law with controls RC1, RL1; remove 36 unreachable files across re-export shims and dead features with zero allowlist.

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
