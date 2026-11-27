# Cleanup slice 18 progress notes
Status: IN PROGRESS
Start heads: core 0af9c2b66e9216b04cbc1f688482e5675ffab6cd, ruleset 343f48dcacf42a7c339a76cab4cc225cecaa19b0, app d0ec577035660eda7054495ab5673be005bcbecc
Last pushed heads (CI green): core 9cf861c5de25b86228e452fc079bbadcad171d15, ruleset 188c03912b1d7d2a5313502885275f52275be3a2, app 73cbecded5cd8084137b32bfaf89b8eb67ddfc14
Pins now: ruleset -> core ec9f155cbdce8315b0d84213842ddf8a22e46a66; app -> core ec9f155cbdce8315b0d84213842ddf8a22e46a66, ruleset 343f48dcacf42a7c339a76cab4cc225cecaa19b0
Fix ids: 1.1 1.2 1.3 1.4 1.5 2.1 2.2 2.3 3.1 3.2 4.1 4.2 5.1 5.2 6.1 6.2 6.3 7.1 7.2 7.3
Mutation ids: R1 R2 R3 R4 N1 X1 P1 P2 P3 S1 S2 D1 M1 M2 U1 U2

## Fix titles
Fix 1.1: Retire cs17
Fix 1.2: Characterization tests fail on every real error
Fix 1.3: The notes self-test names missing archive tags
Fix 1.4: Round-trip laws name the field that differs
Fix 1.5: A look-ahead run of the dependency check
Fix 2.1: What new homebrew records showed before the merge is recorded
Fix 2.2: No silent defaults for category, rarity or edition details
Fix 2.3: Every form and importer path writes the full record
Fix 3.1: One id per SRD item
Fix 3.2: The second-model bar matches by shape and names every exemption
Fix 4.1: The bundled monster and summon catalog is pinned
Fix 4.2: Stored and newly built monsters are pinned
Fix 5.1: One stat block model
Fix 5.2: Monster presentation is attached by id
Fix 6.1: One monster model
Fix 6.2: Old stored monsters load into the one model
Fix 6.3: No second model for a monster
Fix 7.1: A monster's missing facts stay unknown
Fix 7.2: An unreadable challenge rating is not CR 0
Fix 7.3: The named fixture changes for unknown facts

## Steps
- [x] Step 1 Retire, exception checks, tag hint, law messages, look-ahead: core 9cf861c5de25b86228e452fc079bbadcad171d15 run 45931531663, ruleset 188c03912b1d7d2a5313502885275f52275be3a2 run 45931534002, app 73cbecded5cd8084137b32bfaf89b8eb67ddfc14 run 45932116881
- [ ] Step 2 New homebrew spells and items keep their data
- [ ] Step 3 One item id and a shape-based model bar
- [ ] Step 4 Monster catalog, stored-format and construction pins
- [ ] Step 5 One stat block model
- [ ] Step 6 One monster model
- [ ] Step 7 Unknown monster facts stay unknown
- [ ] Step 8 Mutations and report

## Fix checklist
Fix 1.1 done: [Retire cs17] Retired 5 ruleset and 11 app cs17 mutation branches to archive tags with zero remaining across all three repos.
Fix 1.2 done: [Characterization tests fail on every real error] Added test/support/characterization_error_guard.dart and characterization_error_guard_test.dart, removed Multiple exceptions skips from dm_dashboard_screen_characterization_test.dart and party_room_screen_characterization_test.dart, widened 12 rich DM dashboard interaction viewports to 1600px, and used Zone print capture on the remaining overflowing tests.
Fix 1.3 done: [The notes self-test names missing archive tags] Added require_notes_commits_present and NS83 to scripts/test_check_notes_shas.sh so missing archive commits emit one hint line with the git fetch command before NS31, NS37, NS45, or NS73 runs.
Fix 1.4 done: [Round-trip laws name the field that differs] Added map_diff_helper.dart in vtt-ruleset-dnd5e and wired it into ruleset spell_law_test.dart and equipment_item_law_test.dart (test-only change; app did not re-pin).
Fix 1.5 done: [A look-ahead run of the dependency check] Ran 14-day dependency look-ahead across core, ruleset, and app with zero outdated or expiring dependencies.

## Mutation branches
None

## Red runs on main
cd1a0589d922aa2f06e814dbb267de14c9aa789b red run 45931535844

## Resets
None

## Next
Begin Step 2 by inventorying all spell and item construction sites, writing fixed test inputs, and recording pre-merge catalog views at the last pre-merge app commit.

## Open issues and deviations
- Step 1 ruleset commit 188c03912b1d7d2a5313502885275f52275be3a2 changed only test files and the changelog, so the app did not re-pin ruleset in Step 1.
- Fix 1.2: TestWidgetsFlutterBinding resets debugPrint to debugPrintOverride right before dumping a Multiple exceptions batch, so Choice 2 captures dumped error records via ZoneSpecification(print: ...) inside CharacterizationErrorCapture.run rather than assigning debugPrint directly; this does not assign FlutterError.onError.
Run 45931535844 cause: flutter analyze flagged deprecated package:flutter/material.dart import in test/support/characterization_error_guard_test.dart; fixed by 73cbecded5cd8084137b32bfaf89b8eb67ddfc14
