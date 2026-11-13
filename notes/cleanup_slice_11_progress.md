# Cleanup slice 11 progress notes
Status: IN PROGRESS
Start heads: core 8d9b3ea509bca5e78c21298924d06963c938321f, ruleset 016a09556cd3e522593248a83aa22f982fcb6adc, app 5889a4d16927984a006a166791614836270b437b
Last pushed heads (CI green): core bbd4956fdd2d5dfe6d74c544d63dd3966f33d4bb, ruleset a894bc85d584525fa4111660e73ed075460d22e1, app 5889a4d16927984a006a166791614836270b437b
Pins now: ruleset -> core 0617617e954e0add7898a00cf5f9b4ec3334525e; app -> core 0617617e954e0add7898a00cf5f9b4ec3334525e, ruleset a19c4acd1a35b1f29420ca3824a214766c694f91
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
- [ ] Step 3 The dependency check fails closed by schema
- [ ] Step 4 One import reader, the package rule, and P2
- [ ] Step 5 SRD names out, and massive damage
- [ ] Step 6 Sync deltas, room creation, and the privacy policy
- [ ] Step 7 One dice reader
- [ ] Step 8 Mutations and report

## Fix checklist
Fix 1.1 done: [setup-dart v1.8.2 in core and ruleset] Updated dart-lang/setup-dart pins to v1.8.2 in core and ruleset ci.yml and dependencies.yml
Fix 1.2 done: [glob 14.0.6 in the app's npm overrides] Updated glob override to 14.0.6 in package.json, package-lock.json, and dependency_exceptions.tsv
Fix 2.1 done: [Retire bs2] Retired bs2 branches across core (4), ruleset (2), and app (7) with archive tags
Fix 2.2 done: [Retire cs101 and its exception rows] Taught retire script to drop matching prefix rows in mutation_subject_exceptions.tsv, retired 12 cs101 branches, and deleted all 12 rows
Fix 2.3 done: [Mutation ids are fixed and checked] check_notes_shas validates Mutation ids line byte-identity, token uniqueness, and matching branches at COMPLETE and IN PROGRESS
Fix 2.4 done: [A fix commit is in the same repo and after the red run] check_notes_shas validates cause lines point to descendant commits in the same repo
Fix 2.5 done: [The test-name ratchet refuses live and invented names] check_test_names refuses rows for live tests and names that never existed, removed live DTO purity row

## Mutation branches
None

## Red runs on main
0447ece03df8722a19a0937f86dbc374457790de cancelled run 43510726706
06e8ad23c8199366971b8658a89488158fa85d09 red run 43510818731

## Next
Start Step 3: Implement dynamic schema-driven fail-closed law in check_dependencies.py and verify closure.

## Open issues and deviations
Run 43510726706 cause: cancelled since a higher priority waiting request for main existed when push 06e8ad23 was made; fixed by 06e8ad23c8199366971b8658a89488158fa85d09
Run 43510818731 cause: DCO job failed in check_notes_shas.py with undisclosed cancelled run on 0447ece03df8722a19a0937f86dbc374457790de; fixed by bd330f5dc22f5010a3b6cc27c2e6eba4c1e878d4
Bonus slice 2 notes run 42936489472 cause correction: cancelled by the push of 4fd8711db7177fb7dbea7c77c8d51ba69070834b
When running the app dependency check with --today 2026-12-11, all five N4 rows in dependency_exceptions.tsv fail rule E1 because their review_by date 2026-12-10 is in the past on 2026-12-11; recorded as a known review date for Kevin without changing those rows.
When running the app dependency check with --today 2026-11-26, transitive dependency android_file_picker 2.1.5 (resolvable 2.1.6 published 2026-11-12) also exceeded the 14-day grace window, so pubspec.lock was updated to 2.1.6 alongside glob 14.0.6.
