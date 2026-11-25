# Cleanup slice 16 progress notes
Status: IN PROGRESS
Start heads: core 73007473fedbaaeb2778776dcbe55fc127c4ce79, ruleset 5ec366a49af9cc274560ba677e3ae1b8af736c7e, app 240ee415462e6d975eae63ee8a04ad52b55677f8
Last pushed heads (CI green): core 090797a2687d97eeebdbfae606f562520f139a3f, ruleset e0bf5539e4daa62feb8bff9b3922cc257d94e5fc, app eb65a148071d555a47af6d9aab838f9ddd12baf9
Pins now: ruleset -> core ec9f155cbdce8315b0d84213842ddf8a22e46a66; app -> core ec9f155cbdce8315b0d84213842ddf8a22e46a66, ruleset 5ec366a49af9cc274560ba677e3ae1b8af736c7e
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
- [ ] Step 2 Challenge rating reader
- [ ] Step 3 Caller and characterization tests
- [ ] Step 4 Healing Word, combat profile, DPR math
- [ ] Step 5 Typed catalog
- [ ] Step 6 Builder and level-up goldens
- [ ] Step 7 Builder and level-up rules into the ruleset
- [ ] Step 8 Character builder split
- [ ] Step 9 Level-up wizard split
- [ ] Step 10 Mutations and report

## Fix checklist
Fix 1.1 done: [Retire cs15] Retired all 16 cs15 mutation branches across core, ruleset, and app with archive commits, tags, and manifests.
Fix 1.2 done: [Flutter 3.50.1 and every package newly behind] Updated Flutter constraint in pubspec.yaml and pubspec.lock to 3.50.1, verified all four app shards, legacy load law, web build, and 2026-12-07 look-ahead; core and ruleset had nothing behind on 2026-12-07.
Fix 1.3 done: [A ticked step SHA must carry its green run] Updated scripts/check_notes_shas.py to require every 40-char SHA on a ticked step row to carry a green run id (with frozen exemptions for cleanup_slice_14_progress.md and cleanup_slice_15_progress.md) and added self-tests NS74-NS78 in scripts/test_check_notes_shas.sh.
Fix 1.4 done: [No test replaces FlutterError.onError] Added test/infrastructure/compliance/no_flutter_error_on_error_override_bar_test.dart and rewrote dm_dashboard_screen_characterization_test.dart and party_room_screen_characterization_test.dart to use tester.takeException() with no-hang proof.
Fix 1.5 done: [A look-ahead run of the dependency check] Ran 14-day look-ahead (2026-12-09) in all three repos; upgraded local coverage from 1.16.1 to 1.16.2 in core and ruleset (pubspec.lock is gitignored in both), app passed with no failures.

## Mutation branches
None

## Red runs on main
None

## Resets
Start of run: app repo had uncommitted modification to party_active_character_banner.dart and an untracked directory under test; saved diff to step_0_interrupted.diff and reset app working tree to origin/main before Step 1.

## Next
Begin Step 2 by adding the challenge-rating reader and seeded laws in the ruleset, then migrating app callers and adding the arena pre-match CR check.

## Open issues and deviations
Fix 1.3: running the new ticked-step run-id check on existing notes failed on two older closed files (cleanup_slice_14_progress.md line 41 and cleanup_slice_15_progress.md line 39). Added FROZEN_TICKED_STEP_RUN_NOTES for those two files rather than weakening the rule for in-progress or future complete files, verified by NS78.
Fix 1.2/1.5: core and ruleset had no packages behind on 2026-12-07; on the 14-day look-ahead (2026-12-09) both reported coverage 1.16.1 behind 1.16.2, which was upgraded locally via dart pub upgrade (pubspec.lock is gitignored in both library repos).
