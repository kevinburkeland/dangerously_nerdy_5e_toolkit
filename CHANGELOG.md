# Changelog

One line per slice, newest first. Each line: date, slice name, what changed for a user or a developer.
Work before Map slice 1.1 (hardening passes 0 to 12) is in the git history.

## 2026-11-26
- Cleanup slice 17: Re-pin vtt_ruleset_dnd5e to 343f48dcacf42a7c339a76cab4cc225cecaa19b0, migrate all 323 bundled spells to unified Spell via idempotent tool/migrate_bundled_spells.py, delete SpellItem, SpellEditionDetails (app copy), and HomebrewPersistenceService.spellToSpellItem, add no_second_spell_or_item_model_bar_test.dart, lower kDynamicCeiling to 1034, and lower big-file ceilings (removing level_6_spells.dart) (Fixes 6.1-6.3).
- Cleanup slice 17: Re-pin vtt_ruleset_dnd5e to 8509bb5edece484f2649b0a2b511f30966a26dd6, migrate bundled MagicItem catalogs to unified EquipmentItem + ItemPresentation registry via idempotent tool/migrate_bundled_items.py, delete MagicItem, SrdEquipmentLibrary._mapItemToEquipmentItem, and HomebrewPersistenceService.equipmentItemToMagicItem, add no_regex_item_rules_bar_test.dart, and lower big-file ceilings (removing armor_and_shields.dart) (Fixes 5.1-5.3).
- Cleanup slice 17: Pin bundled spell (323) and item (675) catalog goldens, library lookups, and rules view under test/fixtures/catalog_goldens/, pin stored homebrew/bundle/backup formats with a load law under test/fixtures/stored_formats/, and add HomebrewPersistenceService public-API characterization suite with zero lib/ changes (Fixes 4.1-4.3).
- Cleanup slice 17: Re-pin vtt_ruleset_dnd5e to 8e809ccf779f5749145109e4b6fbca8c0d577f41, show 2024 class-table prepared subtitle in BuilderSpellsStep, add typed CasterProgression and parsedSpellcastingAbility to CharacterClass and CompendiumClassParser, wire homebrew casters into builder and level-up without fallback abilities, and regenerate named spell-count builder and level-up goldens (Fixes 3.1-3.3).
- Cleanup slice 17: Add 14 high-casting-ability spell-picking builds (with casting ability 16 via manual entry, spells-held guard, and build/step names in step-finder errors) to character_builder_goldens_test.dart and builder_goldens.json with zero lib/ changes (Fix 2.1).
- Cleanup slice 17: Retire 12 cs16 mutation branches, add per-case runner and no-token stub to test_check_notes_shas.sh (NS79-NS82), document why tester.takeException() cannot unpack Multiple exceptions batches under the FlutterError.onError bar, and upgrade dart_webrtc (1.9.0) and webrtc_interface (1.6.0) for 14-day look-ahead (Fixes 1.1, 1.2, 1.4).

## 2026-11-25
- Cleanup slice 16: Split lib/widgets/character_builder/level_up_wizard_dialog.dart (4,046 -> 188 lines) into 10 focused modules under lib/widgets/character_builder/level_up/ (all under 725 lines, zero part/part of, keeping LevelUpWizardDialog and show(...) signatures identical) and remove level_up_wizard_dialog.dart from big_file_ratchet_test.dart (Fix 9.1).
- Cleanup slice 16: Split lib/screens/character_builder_screen.dart (5,888 -> 486 lines) into 18 focused modules under lib/widgets/character_builder/views/ and lib/widgets/character_builder/steps/ (all under 800 lines, zero part/part of, keeping sl<ReplicaId>() in character_builder_screen.dart) and remove character_builder_screen.dart from big_file_ratchet_test.dart (Fix 8.1).
- Cleanup slice 16: Re-pin vtt_ruleset_dnd5e to fa90649f62f7567a6c5c3deb388bf9b3d0e6b0dd, migrate builder and level-up spellcaster profiles, ASI/origin bonuses, and level-up HP gain to ruleset (giving 2024 Paladin its level-1 spells step), replace hardcoded class/subclass lists in LevelUpWizardDialog with SrdClassesLibrary plus a 3+ SRD class-slug source bar, and move draft assembly out of _finalizeCreatedCharacter to CharacterBuilderController (Fixes 7.1-7.5).
- Cleanup slice 16: Add CharacterBuilderScreen goldens (26 builds across all SRD classes in both editions plus flexible origin builds) and LevelUpWizardDialog characterization goldens (96 cases across all SRD classes in both editions at levels 1->2 through 4->5) with zero lib/ changes (Fixes 6.1, 6.2).
- Cleanup slice 16: Re-pin vtt_ruleset_dnd5e to cab04984d6a0812193a586271f6a2720f96c87db, map AppDnd5eCatalog to typed CatalogFeat/CatalogMagicItem views, and fail loudly on unsupported addSpellsData shapes (Fix 5.1).
- Cleanup slice 16: Re-pin vtt_ruleset_dnd5e to 7ea574148f6fca3c87dea6d690cc2452916b66c9, fix Arena Healing Word to use bundled edition dice and spellcasting ability modifier, cache MonsterItem.getCombatProfile per edition, and delegate DPR buff-die, Vex, and first-hit Sneak Attack math to ruleset with updated Bless golden rows (Fixes 4.1-4.3).
- Cleanup slice 16: Tighten host-role caller spy to assert each caller's own isHost value and expand DmDashboardScreen (4 -> 17 tests) and PartyRoomScreen (4 -> 14 tests) characterization suites (Fixes 3.1-3.3).
- Cleanup slice 16: Re-pin vtt_ruleset_dnd5e to 6f797efb0f7b916032eccfcf1e40e7441f01ddd8, migrate all app numeric challenge-rating readers (MonsterItem, SrdMonsterCrBands, MinionStatBlock) to parseChallengeRating with a source bar, and refuse out-of-range challenge ratings before arena matches with InvalidArenaChallengeRatingException and ArenaSimulatorScreen SnackBar feedback (Fixes 2.2, 2.3).
- Cleanup slice 16: Retire cs15 mutation branches, bump Flutter constraint to 3.50.1, require green run ids on every ticked step SHA in check_notes_shas.py (NS74-NS78), add FlutterError.onError compliance bar and rewrite characterization tests to use tester.takeException(), and verify 14-day dependency look-ahead (Fixes 1.1-1.5).

## 2026-11-24
- Cleanup slice 15: Add PartyRoomScreen characterization tests, split lib/screens/party_room_screen.dart (2,401 -> 759 lines) into 7 files under lib/widgets/party_room/ (all under 500 lines) keeping all service-locator calls in party_room_screen.dart, and remove party_room_screen.dart from big_file_ratchet_test.dart (Fixes 8.1, 8.2).
- Cleanup slice 15: Add DmDashboardScreen characterization tests, remove all 12 .isRegistered fallbacks and runtime replica creation from DmDashboardController and DmDashboardScreen (emptying kExpectedIsRegisteredCounts and lowering sl/defaults ceilings to 37/44), split dm_dashboard_screen.dart into 7 files under lib/widgets/dm_dashboard/ (all under 800 lines), and remove dm_dashboard_screen.dart from big_file_ratchet_test.dart (Fixes 7.1-7.3).
- Cleanup slice 15: Split lib/services/rules/arena_combat_engine.dart into 10 pure-Dart modules under lib/services/rules/arena/ (all under 580 lines) behind a thin facade, move compute isolate runners to arena_combat_engine_async.dart, switch aoe_resolver.dart to package:meta/meta.dart, enforce transitive purity on lib/services/rules/arena, and remove arena_combat_engine.dart from big_file_ratchet_test.dart (Fixes 6.1, 6.2).
- Cleanup slice 15: Re-pin vtt_ruleset_dnd5e to 5ec366a49af9cc274560ba677e3ae1b8af736c7e, delegate arena damage defenses, attack roll classification, Shield reaction, save DC, and full SRD CR 0-30 proficiency bonus (+2 to +9) to ruleset, add arena rules source bar and default save DC law, and update CR 21+ arena goldens (Fixes 5.1-5.4).
- Cleanup slice 15: Add deterministic arena match goldens (336 preset matches, 343 creature duels, 7 Monte Carlo presets) and 10,290-row bundled creature damage-defense table fixtures with explicit opt-in generator (Fixes 4.1, 4.2).
- Cleanup slice 15: Move host role from RoomSyncOrchestrator constructor to required isHost argument on startSynchronization and RoomSessionStarter.start, wire PartyRoomScreen, RoomBannerWidget, and DiceRoomService from CampaignRegistryService, and reset host role in stopSynchronization (Fixes 3.1, 3.2).

## 2026-11-23
- Cleanup slice 15: Add campaign dialog list-size and completeness law test across all 13 dialogs at sizes 0/1/3/12 and 360x640/1280x800, fix DisperseLootDialog RenderShrinkWrappingViewport crash with non-empty rosters, and fix narrow-screen layout overflows in 9 campaign dialogs (Fixes 2.1, 2.2).
- Cleanup slice 15: Retire cs14 mutation branches, read addsAbilityMod from SpellScalingFormula in SpellCastFormulaResolver instead of customProperties, and upgrade 7 pending pub packages (file_picker family and jni/jni_flutter) (Fixes 1.1, 1.3, 1.4).

## 2026-11-21
- Cleanup slice 14: Add characterization widget tests for all campaign dialogs and ImportDmPasskeyDialog, split campaign_dialogs.dart into 13 files under lib/widgets/party/campaign_dialogs/ leaving campaign_dialogs.dart as exports only, and remove campaign_dialogs.dart from big_file_ratchet_test.dart (Fixes 8.1-8.2).
- Cleanup slice 14: Re-pin vtt_engine_core to ec9f155cbdce8315b0d84213842ddf8a22e46a66 (canonical Set encoding, session_graph split, empty-allowlist big-file bar) and vtt_ruleset_dnd5e to e49258140498c919eb91808c1d48da20870cfd7d (big-file bar and duplicate test removal) (Fixes 7.1-7.4).

## 2026-11-19
- Cleanup slice 14: Add transitive purity bar (test/domain/transitive_purity_test.dart) with empty allowlist verifying 0 Flutter/Crashlytics leaks across lib/models, lib/domain, lib/application, and lib/infrastructure/dtos; route LoggingService through pure LogSink port (CrashlyticsLogSink installed in main.dart, RecordingLogSink in test/flutter_test_config.dart, fail-closed StateError when uninstalled); decouple RoomSyncOrchestrator from DiceRoomService via IRemoteRollIngestor; move DPR compute wrappers to lib/services/rules/dpr_calculator_async.dart (Fixes 6.1-6.3).
- Cleanup slice 14: Stamp legacy CampaignProfileDto.toDomain roomState title with HybridLogicalClock.genesis, reset per-session fields in RoomSyncOrchestrator.stopSynchronization, delegate CryptoUtils.sha256Hex to package:crypto, enforce app-internal unique type names, and delete unused duplicate lib/application/services/party_room_service.dart (Fixes 5.1-5.4).
- Cleanup slice 14: Re-pin vtt_ruleset_dnd5e to dca5db4a5f5928634ae828598e5d0b9bef532599 (read-only Character inventory and closure super-conversion bar) and make parse_semver fail closed in check_dependencies.py with DC75-DC76 self-tests (Fixes 4.1-4.3).
- Cleanup slice 14: Re-pin vtt_ruleset_dnd5e to 862a6f64e1d61d01fa3017f3ba27f6549c107514, resolve DiceModTerm in CharacterSheetController.castSpell using the caster's spellcasting modifier (with class selection and no-spellcasting-modifier SnackBar rejection in SpellCard and InteractiveSpellTile), reject signed non-match tokens in _parseSpellFormulaField, and add bundled-spell and 520-seed formula laws (Fixes 3.1-3.3).
- Cleanup slice 14: Prove all 13 Bonus slice 1.1 and 4 Cleanup slice 7 S1-S4 archived mutations from their patches, verify all 15 Cleanup slice 5 archives end to end with archive/cs5-* tags, and record the backfill table in notes/mutation_evidence_backfill.md (Fixes 2.1-2.3).
- Cleanup slice 14: Retire cs13 mutation branches, restore three slice 11 renamed-test reasons in test/removed_test_names.txt, allow renamed-test reasons in check_srd_terms.py, enforce append-only history on test/removed_test_names.txt in check_test_names.py, and upgrade dbus to 0.8.1 and firebase-tools to 15.37.0 (Fixes 1.1-1.4).

## 2026-11-18
- Cleanup slice 13: Re-pin vtt_engine_core (87011633eb26d170a67b7992132cae9866cd297b) and vtt_ruleset_dnd5e (0562855170a8e74d351e01d6c0c5333cd75451d9), route CharacterTelemetryDto.armorClass through queryStat('ac', module: Dnd5eRulesetModule.forEdition(rulesEdition)), add 300-seed party AC telemetry law, and update app legacy character goldens with Step 8 diff-guard (Fixes 8.1-8.5).
- Cleanup slice 13: Re-pin vtt_engine_core (db2e90c5e657a6c6ccba631764e999816d2e14fd) and vtt_ruleset_dnd5e (455cc7f8a7a885f62a02bfcf192a26f7d47dd91d), update TabletopEntityType and RulesetEdition call sites, remove all 16 hide combinators on core/ruleset imports, and add unique-type-names and no-package-hide compliance bars (Fixes 6.1, 7.1, 7.2).
- Cleanup slice 13: Enforce full schema paths on need_child/opt_child, OSV range events, and npm audit entries in check_dependencies.py, and move 12 pure-ruleset SpellAllocationValidator tests to vtt_ruleset_dnd5e (Fixes 5.1, 5.3).
- Cleanup slice 13: Tighten dice reading compliance bar to catch case-insensitive/spaced/character-class dice regexes, upgrade Rule P2 callback bar to statement-level cross-file typedef resolution, and remove critThreshold clamping in DprCalculatorEngine while rejecting out-of-range critThreshold on deserialization (Fixes 4.1-4.3).
- Cleanup slice 13: Re-pin vtt_ruleset_dnd5e to de529f197a77ccc642c1876babeed0db3cbeefd3, fix castSpell to roll all base/scaling die groups and flat bonuses, reject unreadable formulas before slot spend with SnackBar feedback, delete dead rollSpellDamage, migrate single-group sites to singleDieGroup, and add .diceTerms source bar (Fixes 3.1-3.3).
- Cleanup slice 13: Retire cs12 mutation branches and replace thinking-out-loud comment in DPR golden characterization test (Fixes 2.1, 2.3).
- Cleanup slice 13: Remove non-SRD table, presets, subclass/spell special cases, and non-SRD loot labels; enforce bundled MagicItem reference law on all loot tables; expand shared SRD denylist and scanner; review npm N4 overrides (remove unneeded minimatch override, extend remaining four to 2026-12-18) and upgrade fast_immutable_collections to 12.0.1 (Fixes 1.1-1.5).
- Cleanup slice 12: Simplify CharacterDto to a thin codec wrapping Character.fromMap/toMap and migrate HomebrewIngestor.parseCustomCharacters to Character.fromMap (Fix 8.1).
- Cleanup slice 12: Re-pin vtt_ruleset_dnd5e to 18a2768cf6bd153410946c84ed8713a3d59b4775, route DprCalculatorEngine hit/crit/save odds through ruleset computeAttackOdds/computeSaveFailureProbability, and route all three ArenaCombatEngine save sites through computeSaveDamage (Fix 7.4).

## 2026-11-17
- Cleanup slice 12: Move pure ruleset tests to vtt-ruleset-dnd5e, re-pin ruleset to b7936cfe772e14ce6c672843652ce917b10f812e, and add ruleset_tests_home_test compliance bar (Fix 6.1, Fix 6.3).
- Cleanup slice 12: Models declare no callback types, remove kRuleP2Allowlist, and replace SummonPreset BudgetCalculator with pure table data (Fix 5.1).
- Cleanup slice 12: Bump minimatch npm override to 11.0.9, review five N4 overrides and extend review dates to 2026-12-17, update firebase npm dependency to 13.4.0, update actions/setup-java pin to v6.3.0, and upgrade pub dependencies (Fix 1.1, Fix 1.2).

## 2026-11-16
- Cleanup slice 11: Re-pin ruleset with DiceExpression.tryParse, DiceExpression.findAll, and dice helpers (Fix 7.1), add characterization suite for 16 dice reading sites (Fix 7.2), enforce Law D16 compliance bar with zero allowlist (Fix 7.3), and migrate all 16 app dice reading sites to DiceExpression (Fix 7.4).

## 2026-11-15
- Cleanup slice 11: Focused sync deltas for party purse and pinned rules fall through to full room sync when other profile fields mutate concurrently (Fix 6.1), transport adapters refresh existing room records but never create unowned room stubs (Fix 6.2), update privacy policy and add compliance test matching declared Firestore collections (Fix 6.3), and campaign registry deduplicates stored memberships by room code with newest lastPlayed winning (Fix 6.4).

## 2026-11-13
- Cleanup slice 11: Remove non-SRD terms from code, tests and docs, add canonical SRD denylist and compliance scanner (Fix 5.1, Fix 5.2), update Terms of Service with dual SRD 5.1 and 5.2.1 CC-BY-4.0 attribution (Fix 5.3), and re-pin ruleset with massive damage at 0 HP fix (Fix 5.4).
- Cleanup slice 11: One import reader (Fix 4.1), pure folder package allowlist in layer import table (Fix 4.2), and no function fields or typedefs in models (Fix 4.3).
- Cleanup slice 11: Enforce fail-closed input validation by schema table in check_dependencies.py (Fix 3.1) and generate dynamic table-driven damage and valid tests in test_check_dependencies.sh (Fix 3.2).
- Cleanup slice 11: Retire bs2 and cs101 mutation branches, clean up mutation subject exception rows in retirement, enforce Mutation ids line and branch checks (Fix 2.3), enforce same-repo descendant fix commits in notes cause lines (Fix 2.4), and refuse live and invented test names in test-name ratchet (Fix 2.5).
- Cleanup slice 11: Update glob npm override to 14.0.6 in firestore_rules_test and dependency_exceptions.tsv, and update transitive android_file_picker lockfile entry to 2.1.6.

## 2026-11-12
- Bonus slice 3: Plain dice rooms no longer show a red "no campaign" error or create fake campaigns and switch the active campaign, the dice roller Join dialog offers a "Your campaigns" dropdown sorted by newest lastPlayed to fill a joined campaign's room code, and a legacy campaign room (no campaignId on the server) opened from the banner on a device where no local profile claims its code is now treated as a dice room while still opening as a campaign through the Party Room screen and the join/rehydrate campaign paths.
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
