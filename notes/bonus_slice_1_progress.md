# Bonus slice 1 progress notes
Status: IN PROGRESS
Start heads: core b82634e38ae7fc57c9d8a57e0b4bcb96c724a21a, ruleset 08d7d7c0cf860055a8c387a3ca61829d200f253e, app 7d75f4d47e3b33f956d4e16e32e75f470ce3ae5c
Last pushed heads (CI green): core a2b85747cd5b3d0157a41a7a48a1833fa9e01fcf, ruleset 1ea8a09339690bb21a4c9e2b454aeb3dea9e94b5, app 691bcc17e58de52df512c619fac7907030b727f3
Pins now: ruleset -> core a2b85747cd5b3d0157a41a7a48a1833fa9e01fcf; app -> core a2b85747cd5b3d0157a41a7a48a1833fa9e01fcf, ruleset 1ea8a09339690bb21a4c9e2b454aeb3dea9e94b5

## Steps
- [x] Step 1 Baselines and notes, cs101 not retired: app 957eb1aa76a11dcf2d162784a5bec893fd647187 run 42879365351
- [x] Step 2 Dependency check script and self-tests: core 4a200b7a027c36fc02160a7eeaf499ccffaad7f8 run 42892822190, ruleset 8711fd8d63dd98b416c903670602d096ed70111f run 42892827166, app 240776ab616a0a8c7f8e4cd704f1c40d3524fd32 run 42896977684
- [x] Step 3 Core up to date, check wired: core a2b85747cd5b3d0157a41a7a48a1833fa9e01fcf run 42899091099
- [x] Step 4 Ruleset up to date, pins new core, check wired: ruleset 1ea8a09339690bb21a4c9e2b454aeb3dea9e94b5 run 42900115722
- [x] Step 5 App Dart side up to date, pins new core and ruleset: app 691bcc17e58de52df512c619fac7907030b727f3 run 42903111444
- [ ] Step 6 App npm, Node and Actions up to date, check wired
- [ ] Step 7 Mutations and report

## Red runs on main
0056d57830c631fd773749387d7a8712a49c1063 red run 42892540687
884e551e6023aeb23bef0c6f7daeeb707e0d9485 red run 42892544528
92d3cbe2b4acdce8f5f9df734e6ffa6548ab7de9 red run 42892830042
fe64d2a351625e5442a7341dfaad6799f2326d4c red run 42893701058
13cb543461a4e29d776322f8837b9c3019838d38 red run 42894859027
03ecf86c9dedd173bb3eafeaaec8165096e8ed14 red run 42895786358
fc10bd64e33c717a7740fab0deb410d0936ce885 red run 42898410673
d1d79397e02738761d38d0ec4bf05cd49316c3ed red run 42901443343

## Next
Step 6: App npm, Node, and Actions up to date, check wired in CI.

## Open issues and deviations
cs101 not retired, script refused the commit subjects, deferred by the prompt.
0056d57830c631fd773749387d7a8712a49c1063 (core), 884e551e6023aeb23bef0c6f7daeeb707e0d9485 (ruleset), and e44215536d03f5ccee7e8ec37e712381979472f4 (app) failed in CI because test_check_dependencies.sh passed --today to test fixture cases DC1-DC34 while the runner environment had GITHUB_ACTIONS=true, triggering DC35 refusal; fixed in 4a200b7a027c36fc02160a7eeaf499ccffaad7f8 (core), 8711fd8d63dd98b416c903670602d096ed70111f (ruleset), and 92d3cbe2b4acdce8f5f9df734e6ffa6548ab7de9 (app) by unsetting GITHUB_ACTIONS at the start of test_check_dependencies.sh.
92d3cbe2b4acdce8f5f9df734e6ffa6548ab7de9 failed in CI on test_check_notes_shas.sh NS31 due to unauthenticated GitHub API rate limiting (HTTP 403); fixed in fe64d2a351625e5442a7341dfaad6799f2326d4c by passing GITHUB_TOKEN to the self-test step in release.yml.
fe64d2a351625e5442a7341dfaad6799f2326d4c failed in CI on check_notes_shas.py because the preceding red runs were not yet documented in notes/bonus_slice_1_progress.md; fixed by documenting all red runs.
13cb543461a4e29d776322f8837b9c3019838d38 failed in CI on docs_truth_test.dart DT2 because sibling workflow ci.yml was backticked in the Next section but only exists in core and ruleset; fixed by removing backticks around sibling workflow references.
03ecf86c9dedd173bb3eafeaaec8165096e8ed14 failed in CI on docs_truth_test.dart DT2 because the explanation text for 13cb5434 itself backticked the sibling path; fixed by unbackticking it.
fc10bd64e33c717a7740fab0deb410d0936ce885 failed in CI on Dart 3.13.7 static analysis due to prefer_initializing_formals; fixed in a2b85747cd5b3d0157a41a7a48a1833fa9e01fcf by renaming internal backing fields.
d1d79397e02738761d38d0ec4bf05cd49316c3ed failed in CI on check_notes_shas.py because fc10bd64e33c717a7740fab0deb410d0936ce885 was not yet documented under Red runs on main, and unit test shards 1 and 2 failed on ratchets (big file and dynamic count) lowered by dart fix; fixed by disclosing red runs and lowering ratchets.



