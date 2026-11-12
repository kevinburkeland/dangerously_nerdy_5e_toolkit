# Bonus slice 2 progress notes
Status: COMPLETE
Start heads: core 3273f19428d5baf1e82cbb6d590546562a5edf41, ruleset e7912d0012f3d224321193d6add918ee386b34e5, app 940cee3278338d690958548695ee1f856b870300
Last pushed heads (CI green): core 8d9b3ea509bca5e78c21298924d06963c938321f, ruleset 016a09556cd3e522593248a83aa22f982fcb6adc, app 4b0eecbf5c6f1ac45d89b5c30edc8f4fe6d9d4d3
Pins now: ruleset -> core 0617617e954e0add7898a00cf5f9b4ec3334525e; app -> core 0617617e954e0add7898a00cf5f9b4ec3334525e, ruleset a19c4acd1a35b1f29420ca3824a214766c694f91
Fix ids: 1.1 1.2 1.3 1.4 2.1 2.2 2.3 3.1 3.2 3.3 4.1 4.2 4.3 4.4

## Fix titles
Fix 1.1: Retire bs11
Fix 1.2: Fix titles are fixed and checked
Fix 1.3: Every red or cancelled run is explained
Fix 1.4: Explain Bonus slice 1.1's red and cancelled runs
Fix 2.1: Core on Dart 3.14
Fix 2.2: DC36 reads the repo's own SDK
Fix 2.3: Ruleset on Dart 3.14, pinned to the new core
Fix 3.1: Material imports move to material_ui
Fix 3.2: Flutter-free means no Flutter anywhere underneath
Fix 3.3: App on Flutter 3.50, pinned to both
Fix 4.1: Fail-closed law for every input
Fix 4.2: CI keeps npm's exit code and stderr
Fix 4.3: Refused-registry proof
Fix 4.4: N2 exceptions name one exact version

## Steps
- [x] Step 1 Notes rules and bs11 retired: core 976abfb84447af79141ce86fb22281ade4e854f9 run 43157388887, ruleset 42d4012c2a456c26189ed86da7f378706ac0ed88 run 43157564436, app 026539d83ddf2f0bb196ca642f377dd5a40fb050 run 43157646748
- [x] Step 2 Core and ruleset on Dart 3.14: core 0617617e954e0add7898a00cf5f9b4ec3334525e run 43163267063, ruleset a19c4acd1a35b1f29420ca3824a214766c694f91 run 43163862271
- [x] Step 3 App on Flutter 3.50: app 4b8a3f3dd2ee0180de71dd7b4a1592d57aaeb148 run 43168741616
- [x] Step 4 Every input fails closed: core 1c0b56915510190dc7d90969a61783a8efa8c954 run 43204445690, ruleset 15601eb351278d66668e0b664d1e531099ba9e85 run 43204456819, app 38f1fd1ec538c0068930d3ad38cb1a2aad19eab0 run 43204469535
- [x] Step 5 Mutations and report: core 8d9b3ea509bca5e78c21298924d06963c938321f run 43206498137, ruleset 016a09556cd3e522593248a83aa22f982fcb6adc run 43206503234, app 4b0eecbf5c6f1ac45d89b5c30edc8f4fe6d9d4d3 run 43206520372

## Fix checklist
Fix 1.1 done: [Retire bs11] Retired 9 branches in core, 1 in ruleset, and 3 in app with 13 archive tags
Fix 1.2 done: [Fix titles are fixed and checked] check_notes_shas enforces Fix titles section, checklist brackets, and byte-identity
Fix 1.3 done: [Every red or cancelled run is explained] check_notes_shas validates cancelled runs and requires deviation cause lines
Fix 1.4 done: [Explain Bonus slice 1.1's red and cancelled runs] Documented causes and fixing commits for all five 1.1 red and cancelled runs
Fix 2.1 done: [Core on Dart 3.14] Upgraded environment SDK to ^3.14.0, setup-dart to 3.14.0, all 433 unit tests and 402 node tests pass
Fix 2.2 done: [DC36 reads the repo's own SDK] DC36 dynamically reads target Dart and floor Flutter, passes across all three repos with 0 hits in DC36
Fix 2.3 done: [Ruleset on Dart 3.14, pinned to the new core] Upgraded environment SDK to ^3.14.0, pinned core to 0617617e954e0add7898a00cf5f9b4ec3334525e, setup-dart to 3.14.0, all 94 unit tests pass
Fix 3.1 done: [Material imports move to material_ui] Migrated all 284 Material import lines in 283 lib/ and test/ .dart files to material_ui 1.11.0
Fix 3.2 done: [Flutter-free means no Flutter anywhere underneath] Implemented FlutterPackageDetector helper resolving Flutter-bound packages from package graph, updated all 6 purity checks, added material_ui negative cases
Fix 3.3 done: [App on Flutter 3.50, pinned to both] Upgraded environment SDK to >=3.14.0 and flutter to 3.50.0, pinned core to 0617617e954e0add7898a00cf5f9b4ec3334525e and ruleset to a19c4acd1a35b1f29420ca3824a214766c694f91, verified clean analyze and tests
Fix 4.1 done: [Fail-closed law for every input] DC71 tests 136 damaged inputs across all files/URLs and verifies fail-closed exit and identifier mention
Fix 4.2 done: [CI keeps npm's exit code and stderr] release.yml and dependencies.yml capture npm exit code in status files and stream stderr
Fix 4.3 done: [Refused-registry proof] Verified npm status 1 and check_dependencies.py fail-closed under refused registry, proof saved to outputs
Fix 4.4 done: [N2 exceptions name one exact version] Enforced ^\d+\.\d+\.\d+$ regex for N2 held_at and require explicit package-lock version resolution

## Mutation branches
mutation/bs2-u1 7b7ff40a1317c14a218527e0b581996f1c69e49d
mutation/bs2-l1 d5cc04084743a48d1fd64719b300bc770903a739
mutation/bs2-l2 7231effd54c0855212de61dd3bd682d441eb76f9
mutation/bs2-w1 f3e9b83be6eb044b1c611e8bac0b520522d1cfe5
mutation/bs2-r1 60902658258d7bf945f58a568164582bc488eb8c
mutation/bs2-y1 57c6a2b066e359c5872541472bf733236f74d309
mutation/bs2-p1 963d7889396db98374717b9706051346db74a12b
mutation/bs2-p2 3694a3343c1ede7703030f378374c58db8dcb6c9
mutation/bs2-p3 2b9f53ef0ff2260d35ef8a801750d860ed1fa5b1
mutation/bs2-s1 27a0cbd22d84f15fc91d966c3cb9bee861598f3f
mutation/bs2-n1 6a0b4d9c8e90161d8fc58a3d3f502927e85eece8
mutation/bs2-n2 17c12a608e11968f22ad36bdc49ae71fc09b6519
mutation/bs2-n3 020e7a50268c7aa9bd134f3a54f5a81ae4277e9c

## Red runs on main
32a86674076e655ec6ed5da862df3383171e24e6 red run 43167797113
471aeb57d66affa5492605114cc3096e30edd980 red run 43160530143

## Next
None

## Open issues and deviations
Run 43167797113 cause: DCO job failed in check_test_names.py because test description was renamed in dto_purity_test.dart; fixed by b31520c10d8e051561dfba47795871b1243162a2
Updated firebase (to 13.3.0) and firebase-tools (to 15.36.0) in firestore_rules_test/package.json so that dependency check with future date --today 2026-11-26 passes without exception.
When testing check_dependencies with --today 2026-11-26 in core, dart-lang/setup-dart v1.8.2 (released 2026-11-11 17:59 UTC) exceeds the 14-day grace window, whereas on today (2026-11-12) it is pending (1 day old) and exits 0 as expected across all three repos.
Run 43160530143 cause: Shard 1 failed in docs_truth_test DT2 because core workflow path in deviations section was parsed as a missing app repo path; fixed by 6242a466fe7576e20b5605c18374518e59c9e5b2
Prior to starting Step 1, uncommitted changes were detected in vtt-engine-core and dangerously_nerdy_5e_toolkit. In core, the hunks in core/.github/workflows/ci.yml, pubspec.yaml, and scripts/retire_mutation_branches.sh matched origin/mutation/bs11-t2, origin/mutation/bs11-d6, and origin/mutation/bs11-s2 respectively. In the app, firestore_rules_test/package.json and scripts/check_dependencies.py matched origin/mutation/bs11-o1 and core's origin/mutation/bs11-f2. All hunks were verified to be leftover Bonus slice 1.1 mutation edits and restored via git restore . to achieve clean working trees at starting heads.
Bonus slice 1.1 run 42933658992 cause: DCO job failed in dependency check self-test DC36 due to missing environment mock in test fixture; fixed by 0e6e26776b43d26af942fa1d17c70b130d6599bd
Bonus slice 1.1 run 43136058234 cause: dependencies job failed on setup-dart target check due to unhandled grace window on min-sdk; fixed by a570912f39a03889a1c76b03482ed9c680e2df3a
Bonus slice 1.1 run 43138329996 cause: DCO job failed in notes check with undisclosed core red run 38 on 348048672c2de49c750d98cfea929680a6296140 in kevinburkeland/vtt-engine-core; fixed by 988468957a16c45ca4f38e2b97214406a497e7dc
Bonus slice 1.1 run 42936489472 cause: cancelled since a higher priority waiting request for main existed when push 9dceefe2 was made without waiting; fixed by 9dceefe249a6d74238de035ae25ee53f3c84557f
Bonus slice 1.1 run 43148551869 cause: cancelled since a higher priority waiting request for main existed when push 940cee32 was made without waiting; fixed by 940cee3278338d690958548695ee1f856b870300
