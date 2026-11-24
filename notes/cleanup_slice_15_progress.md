# Cleanup slice 15 progress notes
Status: IN PROGRESS
Start heads: core ec9f155cbdce8315b0d84213842ddf8a22e46a66, ruleset e49258140498c919eb91808c1d48da20870cfd7d, app 058f7bda940ed634413328f798c779f3c7644e86
Last pushed heads (CI green): core 73007473fedbaaeb2778776dcbe55fc127c4ce79, ruleset 5ec366a49af9cc274560ba677e3ae1b8af736c7e, app d937228a2c7f31944b6a4fa70dcd53d7b8baf9c3
Pins now: ruleset -> core ec9f155cbdce8315b0d84213842ddf8a22e46a66; app -> core ec9f155cbdce8315b0d84213842ddf8a22e46a66, ruleset 5ec366a49af9cc274560ba677e3ae1b8af736c7e
Fix ids: 1.1 1.2 1.3 1.4 2.1 2.2 3.1 3.2 4.1 4.2 5.1 5.2 5.3 5.4 6.1 6.2 7.1 7.2 7.3 8.1 8.2
Mutation ids: C1 R1 R2 R3 A1 D1 L1 H1 H2 G1 W1 P1 F1 I1 S1 S2

## Fix titles
Fix 1.1: Retire cs14
Fix 1.2: The barrel floor rule has a failing case
Fix 1.3: The cast resolver reads addsAbilityMod from the scaling rule
Fix 1.4: A look-ahead run of the dependency check
Fix 2.1: Every campaign dialog opens with a list of any size
Fix 2.2: Disperse Loot works with a roster
Fix 3.1: The host role is given to each sync session
Fix 3.2: Stopping sync forgets the host role
Fix 4.1: Arena match goldens for fixed seeds
Fix 4.2: A damage-defense table for every bundled creature
Fix 5.1: Damage defenses from stat-block text live in the ruleset
Fix 5.2: Attack rolls and the Shield reaction live in the ruleset
Fix 5.3: Save DCs live in the ruleset
Fix 5.4: Monster proficiency follows the SRD table above CR 20
Fix 6.1: The arena engine is split by concern
Fix 6.2: The arena rules folder is plain Dart
Fix 7.1: Characterization tests for the DM dashboard
Fix 7.2: The DM dashboard has no service-locator fallbacks
Fix 7.3: The DM dashboard is split
Fix 8.1: Characterization tests for the party room screen
Fix 8.2: The party room screen is split

## Steps
- [x] Step 1 Retire, barrel case, scaling flag, look-ahead: core 73007473fedbaaeb2778776dcbe55fc127c4ce79 run 45262883355, ruleset 72c62b2295d6311e636bca28e8c740de8fde61d0 run 45262983455, app 5f751d470fa962d860e3682ffa89fcd5954dd436 run 45264114586
- [x] Step 2 Campaign dialogs with lists: app 7729245ee750d67528e473949d754e2dbb244ca9 run 45268393281
- [x] Step 3 Host role per session: app 1ee86efd3127052e489114eb7f70b53caf81b5d5 run 45482109288
- [x] Step 4 Arena goldens: app 8f5a68ebd1d602229f1b5d161f981fb2b5e37719 run 45485123855
- [x] Step 5 Arena rules into the ruleset: ruleset 5ec366a49af9cc274560ba677e3ae1b8af736c7e run 45487553077, app 524fba8936af3ae6e5185540bef691fe012fda11 run 45488746529
- [x] Step 6 Arena engine split: app 91130e9007a364f40adee32c15d6d100ec4a6116 run 45492495145
- [x] Step 7 DM dashboard: app d937228a2c7f31944b6a4fa70dcd53d7b8baf9c3 run 45495349388 (Fix 7.1); Fixes 7.2-7.3 landed in 499d68113bbb47a1c816e88c4ffa97c1706f51e4
- [ ] Step 8 Party room screen
- [ ] Step 9 Mutations and report

## Fix checklist
Fix 1.1 done: [Retire cs14] Retired all cs14 mutation branches across core, ruleset, and app with archive tags and manifests.
Fix 1.2 done: [The barrel floor rule has a failing case] Added self-test cases 21-24 to test_check_coverage_floor.sh in core and ruleset (byte-identical).
Fix 1.3 done: [The cast resolver reads addsAbilityMod from the scaling rule] Updated lib/providers/spell_cast_formula_resolver.dart to read addsAbilityMod from SpellScalingFormula instead of customProperties and added test/providers/spell_cast_formula_resolver_test.dart.
Fix 1.4 done: [A look-ahead run of the dependency check] Ran 14-day look-ahead (2026-12-07) in all three repos; upgraded cli_util locally in core/ruleset and upgraded 7 pub packages plus file_picker floor in app pubspec.yaml/pubspec.lock.
Fix 2.1 done: [Every campaign dialog opens with a list of any size] Added test/widgets/party/campaign_dialogs_list_size_law_test.dart covering all 13 public dialogs at sizes 0, 1, 3, and 12 on 360x640 and 1280x800 with a completeness bar and control.
Fix 2.2 done: [Disperse Loot works with a roster] Wrapped DisperseLootDialog content in SizedBox(width: double.maxFinite), replaced its shrinkWrap ListView with a scrollable Column, fixed 360x640 overflows in 9 campaign dialogs, and added the 3-member Disperse Loot characterization case.
Fix 3.1 done: [The host role is given to each sync session] Removed RoomSyncOrchestrator constructor isHost, added required isHost to startSynchronization and RoomSessionStarter.start, wired PartyRoomScreen, RoomBannerWidget, and DiceRoomService from CampaignRegistryService, and added host_role_session_lifecycle_test.dart.
Fix 3.2 done: [Stopping sync forgets the host role] Reset _isHost to false in RoomSyncOrchestrator.stopSynchronization before emitting telemetry, verified by host-to-player session switch test.
Fix 4.1 done: [Arena match goldens for fixed seeds] Verified determinism control with Random(7) and recorded 336 preset matches (7 presets), 343 creature duels, and 7 Monte Carlo runs in test/fixtures/arena_goldens/ with test/services/arena_match_goldens_test.dart.
Fix 4.2 done: [A damage-defense table for every bundled creature] Recorded 10,290 damage-defense rows across 686 bundled stat blocks via public executeTurn 101-damage probe in test/services/arena_damage_defense_table_test.dart (322 empty-string non-none rows, 0 zzz rows; only shrieker uses damageType "none", no bundled attack uses empty string).
Fix 5.1 done: [Damage defenses from stat-block text live in the ruleset] Added DamageDefenses with laws in vtt-ruleset-dnd5e, re-pinned app to 5ec366a49af9cc274560ba677e3ae1b8af736c7e, migrated ArenaCombatEngine._applyDefensiveModifiers, and updated only the 322 empty-string rows in damage_defense_table.json to none.
Fix 5.2 done: [Attack rolls and the Shield reaction live in the ruleset] Added classifyAttackRoll and doesShieldBlockAttack with laws in vtt-ruleset-dnd5e, migrated all 9 attack-roll sites and 8 Shield sites in ArenaCombatEngine, and added test/infrastructure/compliance/arena_rules_source_bar_test.dart.
Fix 5.3 done: [Save DCs live in the ruleset] Added computeSaveDc with laws in vtt-ruleset-dnd5e and migrated ArenaCombatEngine._computeSaveDc and StatBlockAclParser.parseStatBlockBoundary.
Fix 5.4 done: [Monster proficiency follows the SRD table above CR 20] Added proficiencyBonusForChallengeRating (CR 0-30, +2 to +9) in vtt-ruleset-dnd5e, replaced both +6-capped ladders in ArenaCombatEngine and StatBlockAclParser, added test/services/arena_default_save_dc_law_test.dart, and updated only the two CR 21+ creature duels (Solar CR 21 and Tarrasque CR 30) in creature_duels.json.
Fix 6.1 done: [The arena engine is split by concern] Split lib/services/rules/arena_combat_engine.dart into 10 pure-Dart modules under lib/services/rules/arena/ (all under 580 lines) behind a 163-line facade preserving all public signatures and removed arena_combat_engine.dart from big_file_ratchet_test.dart.
Fix 6.2 done: [The arena rules folder is plain Dart] Moved compute isolate wrappers to lib/services/rules/arena_combat_engine_async.dart, switched lib/services/rules/aoe_resolver.dart to package:meta/meta.dart, and added lib/services/rules/arena to test/domain/transitive_purity_test.dart with zero violations.
Fix 7.1 done: [Characterization tests for the DM dashboard] Added test/widgets/dm_dashboard/dm_dashboard_screen_characterization_test.dart covering empty and populated campaigns at 1280x800 and 360x640, combat tracker, campaign picker, and inline dialogs, landed on its own in d937228a2c7f31944b6a4fa70dcd53d7b8baf9c3.
Fix 7.2 done: [The DM dashboard has no service-locator fallbacks] Made all DmDashboardController collaborators required with zero isRegistered calls, removed LocalReplicaIdentityStore.createRuntimeReplicaId and isRegistered from DmDashboardScreen, emptied kExpectedIsRegisteredCounts, removed dm_dashboard_controller.dart from kAllowedLocatorImporters, lowered sl uses ceiling to 37 and defaults ceiling to 44, and added missing-DI StateError test.
Fix 7.3 done: [The DM dashboard is split] Split lib/screens/dm_dashboard_screen.dart (2,575 -> 782 lines) into 7 files under lib/widgets/dm_dashboard/ (135-489 lines each) keeping deleteProfile in dm_dashboard_screen.dart, and removed dm_dashboard_screen.dart from big_file_ratchet_test.dart.

## Mutation branches
None

## Red runs on main
c20c44cf7f48878c5a8295661d9d30d186c51ca8 red run 45265072151
8949993c0edd6e84d60d74d528f1ed2a19cd1abd red run 45489705049
72bf0e59357b6663fc68d6e20b7ba40a3d5b0f61 red run 45497804963
499d68113bbb47a1c816e88c4ffa97c1706f51e4 red run 45498842483

## Resets
Run 2 start: saved uncommitted Step 3 WIP diff to step_3_interrupted.diff (and earlier pause diff to step_3_saved_before_pause.diff plus host_role_session_lifecycle_test.dart.bak) and reset app working tree to 9190c8f86ef4bd37eefb97a4a5959016d3492413 before completing Step 3.

## Next
Write characterization tests for PartyRoomScreen, split lib/screens/party_room_screen.dart into widgets under lib/widgets, and remove party_room_screen.dart from big_file_ratchet_test.dart.

## Open issues and deviations
- Step 5 other 8 + DC formula: lib/services/rules/dpr_calculator_engine.dart line 125 has an 8 + formula; left untouched as out of scope for Step 5.
- Step 5 StatBlockAclParser persistence (Inferred): StatBlockAclParser.parseStatBlockBoundary is called only from MonsterCombatProfile.fromStatBlock in memory; its computed spellSaveDc, spellAttackBonus, and fallback rider DCs are not persisted to disk.
- Step 5 Fix 5.4 golden diff (Executed): Only 2 of 343 creature duels changed (Solar CR 21 v2024 spell attack +16 -> +17; Tarrasque CR 30 v2024 spell attack +6 -> +9, totalRounds 3 -> 2). All 336 preset matches, 341 other creature duels, and 7 Monte Carlo presets were byte-identical.
- Fix 1.2: Prompt stated "case 19 (around line 262) proves the passing case only. Nothing proves a file with real code still fails at 0.0." Existing test_check_coverage_floor.sh in core and ruleset already had case 20 ("non-barrel file lowering floor to 0.0 still fails"); new cases 21-24 continued numbering and all four passed as guards on the existing check_coverage_floor.py.
- Fix 1.4: Look-ahead (--today 2026-12-07) in app also flagged T1 (Flutter SDK pin 3.50.0 behind newest stable 3.50.1, released 2026-11-20, 3 days old today). Not bumped because pubspec.yaml pins exact Flutter version 3.50.0 and local SDK is 3.50.0; today's dependency check passes within the 14-day grace period.
- Step 3 executeHostMilestoneFlush: calls campaignRepo.updateProfile with an identity transform returning current unchanged; LocalCampaignRepository.updateProfile cancels any pending debounced save and re-persists current to disk, so unless a debounced write is pending it writes nothing that was not already saved and retains all tombstones unchanged.
- Step 4 preset count: Prompt estimated "8 preset matchups" (384 matches); ArenaPresetMatchup.defaultPresets has 7 presets, so preset_matches.json records 336 matches (7 x 2 x 4 x 3 x 2) and monte_carlo.json records 7 presets.
- Step 4 Fix 4.2 bundled attack damage types: Only srd_mon_shrieker (v2014 and v2024) has a non-SRD damageType ("none", 0 damage); no bundled attack, spell, or rider in the arena produces an empty-string damage type.
Run 45265072151 cause: docs_truth_test.dart DT2 flagged a scripts/ path to test_check_coverage_floor.sh in notes/cleanup_slice_15_progress.md because that script lives in core and ruleset, not app; fixed by 996eae6830246db0f242cf43f42ee6d729b5a6f0

Run 45489705049 cause: docs_truth_test.dart DT2 flagged the planned future arena subfolder path in Next before Step 6 created it; fixed by d06dcc12c228dfb6a11e907c203e3625d045646a
Run 45497804963 cause: two widget tests pumping DmDashboardScreen (dm_linked_character_sheet_test.dart and cold_iron_pass_7_2_regression_test.dart) did not register ICharacterRepository, CombatEncounterService, and RoomSyncOrchestrator in sl after Fix 7.2 removed isRegistered fallbacks; fixed by 499d68113bbb47a1c816e88c4ffa97c1706f51e4

Run 45498842483 cause: check_notes_shas.py flagged an undisclosed prior red run because the test fix commit landed before progress notes were updated; fixed by 51ccf7c110ecaedb2e5bd337858a5697f39de4cb
