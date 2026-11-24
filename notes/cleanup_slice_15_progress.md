# Cleanup slice 15 progress notes
Status: IN PROGRESS
Start heads: core ec9f155cbdce8315b0d84213842ddf8a22e46a66, ruleset e49258140498c919eb91808c1d48da20870cfd7d, app 058f7bda940ed634413328f798c779f3c7644e86
Last pushed heads (CI green): core 73007473fedbaaeb2778776dcbe55fc127c4ce79, ruleset 72c62b2295d6311e636bca28e8c740de8fde61d0, app 1ee86efd3127052e489114eb7f70b53caf81b5d5
Pins now: ruleset -> core ec9f155cbdce8315b0d84213842ddf8a22e46a66; app -> core ec9f155cbdce8315b0d84213842ddf8a22e46a66, ruleset e49258140498c919eb91808c1d48da20870cfd7d
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
- [ ] Step 4 Arena goldens
- [ ] Step 5 Arena rules into the ruleset
- [ ] Step 6 Arena engine split
- [ ] Step 7 DM dashboard
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

## Mutation branches
None

## Red runs on main
c20c44cf7f48878c5a8295661d9d30d186c51ca8 red run 45265072151

## Resets
Run 2 start: saved uncommitted Step 3 WIP diff to step_3_interrupted.diff (and earlier pause diff to step_3_saved_before_pause.diff plus host_role_session_lifecycle_test.dart.bak) and reset app working tree to 9190c8f86ef4bd37eefb97a4a5959016d3492413 before completing Step 3.

## Next
Verify arena determinism, generate and commit Step 4 arena match goldens (presets, all monster picker creatures, and Monte Carlo) plus the bundled creature damage-defense table.

## Open issues and deviations
- Fix 1.2: Prompt stated "case 19 (around line 262) proves the passing case only. Nothing proves a file with real code still fails at 0.0." Existing test_check_coverage_floor.sh in core and ruleset already had case 20 ("non-barrel file lowering floor to 0.0 still fails"); new cases 21-24 continued numbering and all four passed as guards on the existing check_coverage_floor.py.
- Fix 1.4: Look-ahead (--today 2026-12-07) in app also flagged T1 (Flutter SDK pin 3.50.0 behind newest stable 3.50.1, released 2026-11-20, 3 days old today). Not bumped because pubspec.yaml pins exact Flutter version 3.50.0 and local SDK is 3.50.0; today's dependency check passes within the 14-day grace period.
- Step 3 executeHostMilestoneFlush: calls campaignRepo.updateProfile with an identity transform returning current unchanged; LocalCampaignRepository.updateProfile cancels any pending debounced save and re-persists current to disk, so unless a debounced write is pending it writes nothing that was not already saved and retains all tombstones unchanged.
Run 45265072151 cause: docs_truth_test.dart DT2 flagged a scripts/ path to test_check_coverage_floor.sh in notes/cleanup_slice_15_progress.md because that script lives in core and ruleset, not app; fixed by 996eae6830246db0f242cf43f42ee6d729b5a6f0
