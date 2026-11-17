# Cleanup slice 11 progress notes
Status: IN PROGRESS
Start heads: core 8d9b3ea509bca5e78c21298924d06963c938321f, ruleset 016a09556cd3e522593248a83aa22f982fcb6adc, app 5889a4d16927984a006a166791614836270b437b
Last pushed heads (CI green): core f71ae361d3be4eea36e50cbd67e28baa19903b6c, ruleset d9334641b75b17993ec8bd53a90e7c612abec04c, app 355dc0a89c23417d18587681a6b4b1b0960984cd
Pins now: ruleset -> core 0617617e954e0add7898a00cf5f9b4ec3334525e; app -> core 0617617e954e0add7898a00cf5f9b4ec3334525e, ruleset d9334641b75b17993ec8bd53a90e7c612abec04c
Fix ids: 1.1 1.2 2.1 2.2 2.3 2.4 2.5 3.1 3.2 4.1 4.2 4.3 5.1 5.2 5.3 5.4 6.1 6.2 6.3 6.4 7.1 7.2 7.3
Mutation ids: D1 F1 F2 S2 M1 X1 N1 C1 T1 I1 I2 K1 K2 S1 Y1 R1 P1 L1 X2

## Fix titles
Fix 1.1: setup-dart v1.8.2 in core and ruleset
Fix 1.2: glob 14.0.6 in the app's npm overrides
Fix 2.1: Retire bs2
Fix 2.2: Retire cs101 and its exception rows
Fix 2.3: Mutation ids are fixed and checked
Fix 2.4: A fix commit is in the same repo and after the red run
Fix 2.5: The test-name ratchet refuses live and invented names
Fix 3.1: Damage rows come from the fields the script reads
Fix 3.2: Every needed field that is missing fails
Fix 4.1: One import reader for every import check
Fix 4.2: Pure folders import only listed packages
Fix 4.3: No function-typed fields in models, however written
Fix 5.1: One SRD denylist, scanned in all three repos
Fix 5.2: Non-SRD names out of code, tests and docs
Fix 5.3: Terms of Service names the licences truthfully
Fix 5.4: Massive damage at 0 HP kills
Fix 6.1: A focused sync delta only when nothing else changed
Fix 6.2: Transport adapters never create a room
Fix 6.3: The privacy policy tells the truth
Fix 6.4: Loaded campaign memberships have unique room codes
Fix 7.1: DiceExpression finds dice in text
Fix 7.2: App dice reading goes through DiceExpression
Fix 7.3: No hand-written dice reading in app lib

## Steps
- [x] Step 1 setup-dart and glob before the deadline: core bbd4956fdd2d5dfe6d74c544d63dd3966f33d4bb run 43506779610, ruleset a894bc85d584525fa4111660e73ed075460d22e1 run 43507045209, app 5889a4d16927984a006a166791614836270b437b run 43343566938
- [x] Step 2 Retire, and the notes and ratchet rules: core 4c32fe77c8812b9098f2a84391d85ba18eea8844 run 43510633135, ruleset b03b93608a5f63f64df2edb66cdccfcc19f5ed9d run 43510658360, app ad074573be125e834ce6db821b1eeb728d923e36 run 43515303929
- [x] Step 3 The dependency check fails closed by schema: core 5d8ff3ee38c8bad7c08a41f52f882c74856ddc4d run 43650302385, ruleset ac46b6b38dcfc53ed4b5cdd98ad087d994810caf run 43650304011, app b8e85809033a13128077f81bfe22a9c3104ba77f run 43650309256
- [x] Step 4 One import reader, the package rule, and P2: app 816a30b0de9a34af7496b4919cc346633b9dee02 run 43652468422
- [x] Step 5 SRD names out, and massive damage: core f71ae361d3be4eea36e50cbd67e28baa19903b6c run 43654804368, ruleset bc2cd73f762ef0414037873ed337519bcc45e641 run 43654969518, app 8acd69d75abc7cb326b70301fd09d08d80f50c3e run 43656952040
- [x] Step 6 Sync deltas, room creation, and the privacy policy: app bd15b2dd5630be90b2665bede8d32efa6f0e282d run 43786744971
- [x] Step 7 One dice reader: ruleset d9334641b75b17993ec8bd53a90e7c612abec04c run 43950359433, app 355dc0a89c23417d18587681a6b4b1b0960984cd run 44006865703
- [ ] Step 8 Mutations and report

## Fix checklist
Fix 1.1 done: [setup-dart v1.8.2 in core and ruleset] Updated dart-lang/setup-dart pins to v1.8.2 in core and ruleset ci.yml and dependencies.yml
Fix 1.2 done: [glob 14.0.6 in the app's npm overrides] Updated glob override to 14.0.6 in package.json, package-lock.json, and dependency_exceptions.tsv
Fix 2.1 done: [Retire bs2] Retired bs2 branches across core (4), ruleset (2), and app (7) with archive tags
Fix 2.2 done: [Retire cs101 and its exception rows] Taught retire script to drop matching prefix rows in mutation_subject_exceptions.tsv, retired 12 cs101 branches, and deleted all 12 rows
Fix 2.3 done: [Mutation ids are fixed and checked] check_notes_shas validates Mutation ids line byte-identity, token uniqueness, and matching branches at COMPLETE and IN PROGRESS
Fix 2.4 done: [A fix commit is in the same repo and after the red run] check_notes_shas validates cause lines point to descendant commits in the same repo
Fix 2.5 done: [The test-name ratchet refuses live and invented names] check_test_names refuses rows for live tests and names that never existed, removed live DTO purity row
Fix 3.1 done: [Damage rows come from the fields the script reads] check_dependencies.py defines SCHEMA table for all 16 JSON/YAML inputs and accesses all fields strictly via need()
Fix 3.2 done: [Every needed field that is missing fails] Dynamic table-driven test_check_dependencies.sh generates damage tests for all schema fields and verifies 316 fail closed and 6 valid pass
Fix 4.1 done: [One import reader for every import check] Created test/support/dart_directive_reader.dart and migrated 11 test files to shared directive reader
Fix 4.2 done: [Pure folders import only listed packages] Enforced pure-folder package allowlist in layer_import_table_test.dart and documented in docs/ARCHITECTURE.md
Fix 4.3 done: [No function-typed fields in models, however written] Rule P2 in presentation_boundary_bars_test flags direct function types, initializers, and function-typed typedefs in lib/models
Fix 5.1 done: [One SRD denylist, scanned in all three repos] Byte-identical compliance/srd_denylist.txt, check_srd_terms.py, and test_check_srd_terms.sh across core, ruleset, and app; integrated into app release.yml
Fix 5.2 done: [Non-SRD names out of code, tests and docs] Removed non-SRD species slug checks from ruleset; removed non-SRD spell branch from app arena_combat_engine; renamed non-SRD feat advantage type to rollThreeKeepHighest with legacy key reader and denylist exceptions; renamed non-SRD test references and preserved test names in test/removed_test_names.txt
Fix 5.3 done: [Terms of Service names the licences truthfully] Dual CC-BY-4.0 SRD 5.1 and 5.2.1 attribution in TERMS_OF_SERVICE.md and web/legal/TERMS_OF_SERVICE.md, verified byte-identical
Fix 5.4 done: [Massive damage at 0 HP kills] Fixed applyDamage in ruleset to evaluate currentVitals.maxHp at 0 HP instead of relying on excessDamage exceeding negative maxHp
Fix 6.1 done: [A focused sync delta only when nothing else changed] Fall through to full sync on concurrent profile mutations in lib/application/services/room_sync_orchestrator.dart
Fix 6.2 done: [Transport adapters never create a room] Adapters refresh existing rooms and skip missing in lib/infrastructure/adapters/p2p/firebase_fallback_adapter.dart and firebase_signaling_adapter.dart
Fix 6.3 done: [The privacy policy tells the truth] Updated device storage, shared room records, Android Crashlytics, and 9 Firestore collections in PRIVACY_POLICY.md and web/legal/PRIVACY_POLICY.md
Fix 6.4 done: [Loaded campaign memberships have unique room codes] Deduplicate loaded memberships by upper-cased room code with newest lastPlayed winning in lib/services/party/campaign_registry_service.dart
Fix 7.1 done: [DiceExpression finds dice in text] Added tryParse, findAll, DiceMatch, diceTerms, constantSum, largestDie, totalDiceCount, hasDice, and laws DX8-DX13 in vtt-ruleset-dnd5e
Fix 7.2 done: [App dice reading goes through DiceExpression] Characterized 16 dice reading sites across 9 files with 5 inputs each in test/services/dice_reading_characterization_test.dart and migrated all 16 sites to DiceExpression
Fix 7.3 done: [No hand-written dice reading in app lib] Enforced Law D16 compliance bar in test/infrastructure/compliance/dice_reading_bar_test.dart with empty allowlist

## Mutation branches
None

## Red runs on main
0447ece03df8722a19a0937f86dbc374457790de cancelled run 43510726706
06e8ad23c8199366971b8658a89488158fa85d09 red run 43510818731
518c0718f5c7c227d2d9b5872cf0054a4a3000cc red run 43654461595
fd002b8026ee180329a10c7b62d07f36b8164dd7 red run 43654463029
3ab87e25c91c4542ab8049679604b07f140129f9 red run 43656014152

## Next
Step 8: Mutations and report

## Open issues and deviations
Run 43510726706 cause: cancelled since a higher priority waiting request for main existed when push 06e8ad23 was made; fixed by 06e8ad23c8199366971b8658a89488158fa85d09
Run 43510818731 cause: DCO job failed in check_notes_shas.py with undisclosed cancelled run on 0447ece03df8722a19a0937f86dbc374457790de; fixed by f71ae361d3be4eea36e50cbd67e28baa19903b6c
Run 43654461595 cause: test_check_srd_terms fixture tokens contained denylist terms; fixed by f71ae361d3be4eea36e50cbd67e28baa19903b6c
Run 43654463029 cause: compliance test name was renamed and caught by check_test_names.py; fixed by bc2cd73f762ef0414037873ed337519bcc45e641
Run 43656014152 cause: big-file ratchet ceiling for arena_combat_engine.dart needed reduction from 4056 to 3985 after removing hardcoded non-SRD spell branch; fixed by 8c75a5409a1cc2a1f4b912aefac0534a0aefd2c4
Bonus slice 2 notes run 42936489472 cause correction: cancelled by the push of 4fd8711db7177fb7dbea7c77c8d51ba69070834b
When running the app dependency check with --today 2026-12-11, all five N4 rows in dependency_exceptions.tsv fail rule E1 because their review_by date 2026-12-10 is in the past on 2026-12-11; recorded as a known review date for Kevin without changing those rows.
When running the app dependency check with --today 2026-11-26, transitive dependency android_file_picker 2.1.5 (resolvable 2.1.6 published 2026-11-12) also exceeded the 14-day grace window, so pubspec.lock was updated to 2.1.6 alongside glob 14.0.6.
