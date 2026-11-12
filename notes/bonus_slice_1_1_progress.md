# Bonus slice 1.1 progress notes
Status: COMPLETE
Start heads: core a2b85747cd5b3d0157a41a7a48a1833fa9e01fcf, ruleset 1ea8a09339690bb21a4c9e2b454aeb3dea9e94b5, app 0062df46a6c092a09762110642226f01727f9a73
Last pushed heads (CI green): core 3273f19428d5baf1e82cbb6d590546562a5edf41, ruleset e7912d0012f3d224321193d6add918ee386b34e5, app 4b45b7ef630ebbcfd3e06e2aa4791e8c5812895d
Pins now: ruleset -> core a570912f39a03889a1c76b03482ed9c680e2df3a; app -> core a570912f39a03889a1c76b03482ed9c680e2df3a, ruleset d34b11dcad7678563d2990ece6f969f4455bd50e

Fix ids: 1.1 1.2 1.3 2.1 2.2 2.3 2.4 3.1 3.2 3.3 3.4 3.5 4.1 4.2 4.3 5.1 5.2 5.3 5.4 5.5

## Steps
- [x] Step 1 Remove the 2026-11-12 time bomb (Fixes 1.1, 1.2, 1.3): core 44c718b2b93e4122b182e4a77e6232d8ae052f16 run 42935575456, ruleset d2e8cb79c851643d86f6aa6e6091e6ab4a7a4b4e run 42935607817, app 0e6e26776b43d26af942fa1d17c70b130d6599bd run 42935618124
- [x] Step 2 Every input fails closed (Fixes 2.1, 2.2, 2.3, 2.4): core 1a3f4aa4c08b97f9c6dd7c24153bb7640111d6a2 run 42936996351, ruleset 213a46523fccaaee524d704abb48a24f0e215cc6 run 42937011505, app 4fd8711db7177fb7dbea7c77c8d51ba69070834b run 42937023408
- [x] Step 3 Wait counts from first newer release; version floors current; re-pin (Fixes 3.1, 3.2, 3.3, 3.4, 3.5): core a570912f39a03889a1c76b03482ed9c680e2df3a run 43137302736, ruleset d34b11dcad7678563d2990ece6f969f4455bd50e run 43137581838, app 988468957a16c45ca4f38e2b97214406a497e7dc run 43139025199
- [x] Step 4 npm overrides and advisories declared (Fixes 4.1, 4.2, 4.3): core 64508bdcc7edfdc2f2d506d4c4ef34dcc359f1c5 run 43141274600, ruleset f237cd54284f0cf51b7438fe76af5e995224d43e run 43141285787, app f377cf61d274bee3ca12c63e6c9be40e785dc111 run 43141298535
- [x] Step 5 Mutation subjects and branch limit (Fixes 5.1, 5.2, 5.3, 5.4, 5.5): core 35537dd7b69080a2ead1907d2f545952cbf5671c run 43143814705, ruleset 46568f466965283e4f726ef75ae44473a10c85bf run 43143825419, app e85e60aca537a24273085d6cec7aa05df81d8334 run 43143857795
- [x] Step 6 Thirteen mutation tests and report: core 3273f19428d5baf1e82cbb6d590546562a5edf41 run 43147544630, ruleset e7912d0012f3d224321193d6add918ee386b34e5 run 43147547962, app 4b45b7ef630ebbcfd3e06e2aa4791e8c5812895d run 43147550602

## Fix checklist
Fix 1.1 done: Line-based workflow parser ignores step names, matches job id min-sdk, validates setup-dart sdk format
Fix 1.2 done: Strict min-sdk job requirement enforced in pure Dart repos (rejected in Flutter repos)
Fix 1.3 done: Setup-dart step summary line printed per setup-dart step found
Fix 2.1 done: Every input file fails closed when missing or unreadable
Fix 2.2 done: JSON input shapes validated strictly
Fix 2.3 done: Non-zero exit code or error payload in npm checks fails closed
Fix 2.4 done: Clear error messages for unreadable inputs
Fix 3.1 done: Wait counts computed from publish date of oldest newer release
Fix 3.2 done: Version comparison handles pre-release ordering and npm ahead of latest tag
Fix 3.3 done: Rule D6 enforces declared floors current against pub outdated with 14-day grace
Fix 3.4 done: Direct dependency floors tightened in core, ruleset, and app
Fix 3.5 done: D4 exception reasons rewritten with publisher, release date, and end criteria
Fix 4.1 done: Measure override effect on advisories, verify newest in major, update package.json
Fix 4.2 done: Enforce override declaration rule N4 with 30-day review_by and newest-in-major check
Fix 4.3 done: Enforce per-advisory vulnerability reporting and GHSA verification rule N2
Fix 5.1 done: Mutation commit subject enforced (MUTATION — do not merge: <id>)
Fix 5.2 done: check_mutation_branches.sh verifies commit subjects across origin branches
Fix 5.3 done: Dated exact-SHA mutation subject exceptions supported and verified
Fix 5.4 done: Retire bs1 branches in each repo
Fix 5.5 done: Notes check verifies Mutation branches section format and commit subjects

## Mutation branches
mutation/bs11-t1 21cb9d30310c29be629a06b0f4630b1f37fb94b2
mutation/bs11-t2 a83f50f76fd15665d3e8444d8c5864a9377280d0
mutation/bs11-f1 3e71b234bb6c3a8c88b721004e336f6025962a6f
mutation/bs11-f2 8ea0e128a5f29e96ad41eac92a64021fb2e5ee8a
mutation/bs11-g1 83f8c17a5446fd3112fc62a363c4c7c4da3a1461
mutation/bs11-v1 caa15d18f1873d316372b763905a438f354b150f
mutation/bs11-d6 94d7d21c8fd3c52d1b32f9447e415142cb4029ad
mutation/bs11-s1 38b3af270a28253c05b6e2737533c48faf08735c
mutation/bs11-s2 77e9f36050eab61444ba48ed823bd7024e8bf07f
mutation/bs11-p1 4606e1acb3c9f9d45fd651c97e3b96c657518fa7
mutation/bs11-o1 6a012de5dcff28b31260b1554a2f1510d1392f3f
mutation/bs11-o2 144798489c1b30df58f670e4a74f77ddebb18ee9
mutation/bs11-n1 f0d869e95ded1b17c60d423220f2feb5939b0510

## Red runs on main
f651bb6a38f78e09066dc5e7f741da52d3a87dad red run 42933658992
348048672c2de49c750d98cfea929680a6296140 red run 43136058234
0749e641c21b623ee7d2bec1ba24bb5cc680f54a red run 43138329996
962b4c9251cb7ac1b9ce73f28427048f9f67b68e red run 43144363290
29b9e9f2d92890013caee751fba119337e346059 red run 43144413900
be7151a5c85708e039dbbb6687c6066a2deaace6 red run 43144477624

## Next
None. All six steps and thirteen mutations complete.

## Open issues and deviations
- Flutter 3.50.0 / Dart 3.14.0 released on 2026-11-11, activating the 14-day grace window. `check_dependencies.py` was updated on `main` across all three repos to ensure that during a grace period, obsolete SDK versions below the previous floor (3.13.0) or target Dart (3.13.7) fail instead of being granted a pending grace window.
- In Step 5, retiring legacy `bs1` branches deleted remote branches before removing corresponding entries from `mutation_subject_exceptions.tsv`, producing expected red runs. These were resolved on the subsequent commits `ea7d2b6`, `d148e48`, and `f3aa2acf` by cleaning up the exceptions file, with all runs documented under `## Red runs on main`.
- In Step 6, Fix 2.2 self-test (DC70) was added to `test_check_dependencies.sh` across all three repos to verify failing closed when the Flutter releases JSON contains no stable releases. DC51 in `test_check_dependencies.sh` was updated to explicitly write `releases/latest.json` with a 2-day-old release so the test verifies that actions older than intermediate releases fail even when the latest release is fresh.
