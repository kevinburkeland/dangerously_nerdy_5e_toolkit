# Cleanup slice 16 progress notes
Status: IN PROGRESS
Start heads: core 73007473fedbaaeb2778776dcbe55fc127c4ce79, ruleset 5ec366a49af9cc274560ba677e3ae1b8af736c7e, app 240ee415462e6d975eae63ee8a04ad52b55677f8
Last pushed heads (CI green): core 090797a2687d97eeebdbfae606f562520f139a3f, ruleset fa90649f62f7567a6c5c3deb388bf9b3d0e6b0dd, app eb697ceff606b1802ce908338660bb2a5bfa6379
Pins now: ruleset -> core ec9f155cbdce8315b0d84213842ddf8a22e46a66; app -> core ec9f155cbdce8315b0d84213842ddf8a22e46a66, ruleset fa90649f62f7567a6c5c3deb388bf9b3d0e6b0dd
Fix ids: 1.1 1.2 1.3 1.4 1.5 2.1 2.2 2.3 3.1 3.2 3.3 4.1 4.2 4.3 5.1 6.1 6.2 7.1 7.2 7.3 7.4 7.5 8.1 9.1
Mutation ids: R1 R2 R3 R4 R5 R6 R7 N1 E1 K1 H1 T1 T2 W1 M1 B1 U1 V1 P1

## Fix titles
Fix 1.1: Retire cs15
Fix 1.2: Flutter 3.50.1 and every package newly behind
Fix 1.3: A ticked step SHA must carry its green run
Fix 1.4: No test replaces FlutterError.onError
Fix 1.5: A look-ahead run of the dependency check
Fix 2.1: One challenge-rating reader in the ruleset
Fix 2.2: Every app challenge-rating reader uses it
Fix 2.3: The arena refuses a challenge rating it cannot use before the match
Fix 3.1: Each room-start caller is tested on its own call
Fix 3.2: DM dashboard characterization covers every listed interaction
Fix 3.3: Party room characterization covers every listed interaction
Fix 4.1: Healing Word heals by the spell and the spellcasting modifier
Fix 4.2: A monster's combat profile is built once per edition
Fix 4.3: DPR turn math lives in the ruleset
Fix 5.1: The catalog contract has no dynamic
Fix 6.1: Builder goldens for every class in both editions
Fix 6.2: Level-up characterization for every class in both editions
Fix 7.1: One caster profile for builder and level-up
Fix 7.2: Ability score increases and origin bonuses live in the ruleset
Fix 7.3: Level-up hit points come from the ruleset
Fix 7.4: The level-up class and subclass lists come from the class library
Fix 7.5: The builder's finalize keeps only UI
Fix 8.1: The character builder screen is split
Fix 9.1: The level-up wizard is split

## Steps
- [x] Step 1 Retire, bumps, notes bar, onError bar, look-ahead: core 090797a2687d97eeebdbfae606f562520f139a3f run 45666926094, ruleset e0bf5539e4daa62feb8bff9b3922cc257d94e5fc run 45666931630, app eb65a148071d555a47af6d9aab838f9ddd12baf9 run 45666937058
- [x] Step 2 Challenge rating reader: ruleset 6f797efb0f7b916032eccfcf1e40e7441f01ddd8 run 45668453921, app 5773d0fba87d64d13f64469cfdd3c1af4372356c run 45672912183
- [x] Step 3 Caller and characterization tests: app a05013272c52dcbd071c71cc2618d9cdef120de1 run 45677314012
- [x] Step 4 Healing Word, combat profile, DPR math: ruleset 7ea574148f6fca3c87dea6d690cc2452916b66c9 run 45678211821, app 37fd99e9bd9e1c4ecce2ebeca3136df0ff589947 run 45679755111
- [x] Step 5 Typed catalog: ruleset cab04984d6a0812193a586271f6a2720f96c87db run 45680245259, app 4bc4ce992ee0693ab089d4fc78d186691d11e96b run 45681612653
- [x] Step 6 Builder and level-up goldens: app 7faeda3ed48008e1d8f696e8429621189be10446 run 45684377247
- [x] Step 7 Builder and level-up rules into the ruleset: ruleset fa90649f62f7567a6c5c3deb388bf9b3d0e6b0dd run 45685871897, app 3b241986df81cd6673f47bd874457aa56d937a20 run 45714960177
- [x] Step 8 Character builder split: app 99e013728fdfe43078f1606c802d6be696a38579 run 45718178077
- [x] Step 9 Level-up wizard split: app eb697ceff606b1802ce908338660bb2a5bfa6379 run 45720681103
- [ ] Step 10 Mutations and report

## Fix checklist
Fix 1.1 done: [Retire cs15] Retired all 16 cs15 mutation branches across core, ruleset, and app with archive commits, tags, and manifests.
Fix 1.2 done: [Flutter 3.50.1 and every package newly behind] Updated Flutter constraint in pubspec.yaml and pubspec.lock to 3.50.1, verified all four app shards, legacy load law, web build, and 2026-12-07 look-ahead; core and ruleset had nothing behind on 2026-12-07.
Fix 1.3 done: [A ticked step SHA must carry its green run] Updated scripts/check_notes_shas.py to require every 40-char SHA on a ticked step row to carry a green run id (with frozen exemptions for cleanup_slice_14_progress.md and cleanup_slice_15_progress.md) and added self-tests NS74-NS78 in scripts/test_check_notes_shas.sh.
Fix 1.4 done: [No test replaces FlutterError.onError] Added test/infrastructure/compliance/no_flutter_error_on_error_override_bar_test.dart and rewrote dm_dashboard_screen_characterization_test.dart and party_room_screen_characterization_test.dart to use tester.takeException() with no-hang proof.
Fix 1.5 done: [A look-ahead run of the dependency check] Ran 14-day look-ahead (2026-12-09) in all three repos; upgraded local coverage from 1.16.1 to 1.16.2 in core and ruleset (pubspec.lock is gitignored in both), app passed with no failures.
Fix 2.1 done: [One challenge-rating reader in the ruleset] Added parseChallengeRating(String) in vtt-ruleset-dnd5e combat_rules.dart with 600-seed and fixed-case laws in parse_challenge_rating_law_test.dart.
Fix 2.2 done: [Every app challenge-rating reader uses it] Deleted MonsterItem._parseChallengeRating and SrdMonsterCrBands._parseChallengeRating, migrated MonsterItem, SrdMonsterCrBands, and MinionStatBlock crValue/glyphCrTier to parseChallengeRating, added challenge_rating_reader_source_bar_test.dart and homebrew CR 30 XP-tail arena test.
Fix 2.3 done: [The arena refuses a challenge rating it cannot use before the match] Added InvalidArenaChallengeRatingException and validateArenaCombatantsChallengeRatings in arena_challenge_rating_validator.dart, wired all four arena entry points and ArenaSimulatorScreen SnackBar feedback, guarded ArenaCombatantCard setup badges, and verified with engine and widget tests.
Fix 3.1 done: [Each room-start caller is tested on its own call] Updated _RecordingRoomSessionStarter in host_role_session_lifecycle_test.dart to tag each startSynchronization call by caller via StackTrace.current and assert everyElement(isTrue) per caller; verified all three controls fail on their own comparison.
Fix 3.2 done: [DM dashboard characterization covers every listed interaction] Expanded dm_dashboard_screen_characterization_test.dart from 4 to 17 tests covering 1280x800 and 360x640 layouts, turn advance/rewind, initiative reroll, damage/heal exact HP, condition toggle, character HP, spell slot, minion HP, purse coin, edition switch, and all inline dialogs with zero lib/ changes.
Fix 3.3 done: [Party room characterization covers every listed interaction] Expanded party_room_screen_characterization_test.dart from 4 to 14 tests covering 1280x800 and 360x640 layouts, copy code snackbar, leave/delete dialog cancel, member/party coin changes, claim, assign, restore specific trashed item leaving the other archived, and tab switch keep-alive with zero lib/ changes.
Fix 4.1 done: [Healing Word heals by the spell and the spellcasting modifier] Derived ArenaCombatant.spellcastingAbilityModifier from spellSaveDc and CR proficiency bonus, wired ArenaSpellcastingAi to read bundled Healing Word edition dice from SpellbookLibrary, verified 2014/2024 slots 1 and 2, and confirmed all arena match goldens remain byte-identical.
Fix 4.2 done: [A monster's combat profile is built once per edition] Verified MonsterItem and MinionStatBlock are const/final immutable, cached MonsterItem.getCombatProfile per edition via Expando, updated doc comment, and verified identical caching and field-by-field parity.
Fix 4.3 done: [DPR turn math lives in the ruleset] Added computeAttackOddsWithBuffDie, computeVexConditionalOdds, and computeFirstHitSneakAttackExpectedDamage with exact grid laws and 60-turn x 200k-trial Monte Carlo cross-check (plus wrong-formula failure control), wired DprCalculatorEngine, and regenerated dpr_golden.json in its own commit (360 Bless rows changed, 0 non-Bless or save rows changed).
Fix 5.1 done: [The catalog contract has no dynamic] Replaced all dynamic types in Dnd5eCatalog with CatalogFeat, CatalogMagicItem, and Object?, removed dynamic casts in CharacterEvaluationEngine, added catalog_no_dynamic_bar_test.dart in ruleset, updated AppDnd5eCatalog to return typed views and fail loud on unsupported addSpellsData shapes, lowered app kDynamicCeiling from 1041 to 1036, and verified all goldens and full Shard 0 (832 tests) unedited.
Fix 6.1 done: [Builder goldens for every class in both editions] Added character_builder_goldens_test.dart and 26-build fixture builder_goldens.json (all 12 SRD classes in 2014 and 2024 plus 2 flexible origin builds) with zero lib/ changes; confirmed 2024 Paladin has no spells step yet.
Fix 6.2 done: [Level-up characterization for every class in both editions] Added level_up_goldens_test.dart and 96-case fixture level_up_goldens.json (all 12 SRD classes in both editions at 1->2 through 4->5) with zero lib/ changes; recorded 6 preview-vs-confirm HP diffs (Draconic Bloodline Sorcerer +1 HP/level) and 0 casting-modifier diffs.
Fix 7.1 done: [One caster profile for builder and level-up] Added ClassSpellcasterProfile/resolveClassSpellcasterProfile in ruleset, fixed getMaxSpellTierForClass full/half-caster caps caught by the 560-case app law (class_spellcaster_profile_law_test.dart), deleted builder/wizard caster copies, and updated only 2024_paladin in builder_goldens.json in its own commit (adding level-1 spells step).
Fix 7.2 done: [Ability score increases and origin bonuses live in the ruleset] Added computeEffectiveAsiBonusDelta/applyAbilityScoreIncreases (max 20) and computeOriginAbilityBonuses (2014 fixed+flexible, 2024 +2/+1 and +1/+1/+1) in ruleset, wired CharacterProgressionEngine, CharacterBuilderScreen, and LevelUpWizardDialog.
Fix 7.3 done: [Level-up hit points come from the ruleset] Added computeLevelUpHpGain (min 1) with exhaustive 640-case law in ruleset, wired CharacterProgressionEngine.computeMaxHp and LevelUpWizardDialog._effectiveHpGain.
Fix 7.4 done: [The level-up class and subclass lists come from the class library] Deleted _availableClasses and _subclassesByClass from LevelUpWizardDialog, built class/subclass lists from SrdClassesLibrary and CharacterProgressionEngine.getMulticlassPrerequisites(), and added no_hardcoded_srd_class_slugs_bar_test.dart.
Fix 7.5 done: [The builder's finalize keeps only UI] Moved CharacterDraft assembly out of _finalizeCreatedCharacter into CharacterBuilderController.buildFinalizedDraft; builder screen finalize keeps only UI validation, save, navigation, and SnackBar.
Fix 8.1 done: [The character builder screen is split] Split lib/screens/character_builder_screen.dart (5,888 -> 486 lines) into 18 focused modules under lib/widgets/character_builder/views/ and lib/widgets/character_builder/steps/ (all under 800 lines, max 791, zero part/part of, keeping sl<ReplicaId>() in character_builder_screen.dart), removed character_builder_screen.dart from big_file_ratchet_test.dart (33 files on allowlist), refreshed codebase_map.md, and verified moves check, all 26 builder goldens, legacy load law, compliance ratchets, and build_web.sh.
Fix 9.1 done: [The level-up wizard is split] Split lib/widgets/character_builder/level_up_wizard_dialog.dart (4,046 -> 188 lines) into 10 focused modules under lib/widgets/character_builder/level_up/ (all under 725 lines, max 721, zero part/part of, keeping LevelUpWizardDialog and show(...) signatures identical), removed level_up_wizard_dialog.dart from big_file_ratchet_test.dart (32 files on allowlist), refreshed codebase_map.md, and verified moves check, all 96 level-up goldens, Fix 7.4 bar, legacy load law, compliance ratchets, and build_web.sh.

## Mutation branches
None

## Red runs on main
b96a148e3077c9003a38bf6a956e5510e107542a red run 45668172861
9049dff3946a4e2f588329e7ed5ea731407c2a56 red run 45671260957

## Resets
Start of run: app repo had uncommitted modification to party_active_character_banner.dart and an untracked directory under test; saved diff to step_0_interrupted.diff and reset app working tree to origin/main before Step 1.

## Next
Begin Step 10 (mutations, exit checks, final report): finish app mutations (N1, E1, K1, H1, T1, T2, W1, M1, B1, U1, V1, P1; ruleset R1-R7 already pushed), run full app exit checks (4 local shards, legacy load law, scripts, emulator rules, web build), trigger dependencies.yml workflow_dispatch on all three repos, set notes Status to COMPLETE, and write the 17-section report.

## Open issues and deviations
Fix 1.3: running the new ticked-step run-id check on existing notes failed on two older closed files (cleanup_slice_14_progress.md line 41 and cleanup_slice_15_progress.md line 39). Added FROZEN_TICKED_STEP_RUN_NOTES for those two files rather than weakening the rule for in-progress or future complete files, verified by NS78.
Fix 1.2/1.5: core and ruleset had no packages behind on 2026-12-07; on the 14-day look-ahead (2026-12-09) both reported coverage 1.16.1 behind 1.16.2, which was upgraded locally via dart pub upgrade (pubspec.lock is gitignored in both library repos).
Fix 2.2: where parseChallengeRating returns null, app callers (MonsterItem, SrdMonsterCrBands, MinionStatBlock) keep today's invented default of 0 (out of scope for this slice). The source bar also caught two additional inline regex CR readers in minion_stat_block.dart (crValue and glyphCrTier), which were migrated to parseChallengeRating.
Fix 3.3: observed a real pre-existing defect in PartyHistoryAndTrashTab (not fixed per Step 3 no-lib-edits rule): build() calls streamLoot(includeArchived: true) before the second TabBarView tab mounts, so the initial microtask snapshot broadcasts before StreamBuilder subscribes; the characterization test pins current behavior by re-triggering streamLoot once the Trash tab is mounted.
Run 45668172861 cause: docs_truth_test.dart DT2 rejected non-existent path in Resets section; fixed by 0edd2f1cfb464c74fa88782ab0fc84231206326b
Run 45671260957 cause: stale codebase_map.md after adding arena_challenge_rating_validator.dart and ArenaCombatantCard calling canFly/canSwim on CR 31 before match start; fixed by 9d1873640ec36d6d3a1821974793c9849ba40224
