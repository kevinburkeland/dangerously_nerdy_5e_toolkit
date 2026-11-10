# Bonus slice 1 progress notes
Status: IN PROGRESS
Start heads: core b82634e38ae7fc57c9d8a57e0b4bcb96c724a21a, ruleset 08d7d7c0cf860055a8c387a3ca61829d200f253e, app 7d75f4d47e3b33f956d4e16e32e75f470ce3ae5c
Last pushed heads (CI green): core 4a200b7a027c36fc02160a7eeaf499ccffaad7f8, ruleset 8711fd8d63dd98b416c903670602d096ed70111f, app 957eb1aa76a11dcf2d162784a5bec893fd647187
Pins now: ruleset -> core 59d7178dea6527a18a2cac3b7fe0f110fb93717a; app -> core 59d7178dea6527a18a2cac3b7fe0f110fb93717a, ruleset 8174dfcd51706f7998dd4907b19cb3ce950581a4

## Steps
- [x] Step 1 Baselines and notes, cs101 not retired: app 957eb1aa76a11dcf2d162784a5bec893fd647187 run 42879365351
- [x] Step 2 Dependency check script and self-tests: core 4a200b7a027c36fc02160a7eeaf499ccffaad7f8 run 42892822190, ruleset 8711fd8d63dd98b416c903670602d096ed70111f run 42892827166
- [ ] Step 3 Core up to date, check wired
- [ ] Step 4 Ruleset up to date, pins new core, check wired
- [ ] Step 5 App Dart side up to date, pins new core and ruleset
- [ ] Step 6 App npm, Node and Actions up to date, check wired
- [ ] Step 7 Mutations and report

## Red runs on main
0056d57830c631fd773749387d7a8712a49c1063 red run 42892540687
884e551e6023aeb23bef0c6f7daeeb707e0d9485 red run 42892544528
92d3cbe2b4acdce8f5f9df734e6ffa6548ab7de9 red run 42892830042
fe64d2a351625e5442a7341dfaad6799f2326d4c red run 42893701058
13cb543461a4e29d776322f8837b9c3019838d38 red run 42894859027

## Next
Step 3: Core up to date (core pubspec.yaml, sdk constraint ^3.13.0, lints ^6.1.0), fix 3 analyzer findings in core lib/, update core CI workflow, wire dependencies job and weekly dependencies workflow, run checks and land.

## Open issues and deviations
cs101 not retired, script refused the commit subjects, deferred by the prompt.
0056d57830c631fd773749387d7a8712a49c1063 (core), 884e551e6023aeb23bef0c6f7daeeb707e0d9485 (ruleset), and e44215536d03f5ccee7e8ec37e712381979472f4 (app) failed in CI because test_check_dependencies.sh passed --today to test fixture cases DC1-DC34 while the runner environment had GITHUB_ACTIONS=true, triggering DC35 refusal; fixed in 4a200b7a027c36fc02160a7eeaf499ccffaad7f8 (core), 8711fd8d63dd98b416c903670602d096ed70111f (ruleset), and 92d3cbe2b4acdce8f5f9df734e6ffa6548ab7de9 (app) by unsetting GITHUB_ACTIONS at the start of test_check_dependencies.sh.
92d3cbe2b4acdce8f5f9df734e6ffa6548ab7de9 failed in CI on test_check_notes_shas.sh NS31 due to unauthenticated GitHub API rate limiting (HTTP 403); fixed in fe64d2a351625e5442a7341dfaad6799f2326d4c by passing GITHUB_TOKEN to the self-test step in release.yml.
fe64d2a351625e5442a7341dfaad6799f2326d4c failed in CI on check_notes_shas.py because the preceding red runs were not yet documented in notes/bonus_slice_1_progress.md; fixed by documenting all red runs.
13cb543461a4e29d776322f8837b9c3019838d38 failed in CI on docs_truth_test.dart DT2 because .github/workflows/ci.yml was backticked in the Next section but only exists in core and ruleset; fixed by removing backticks around sibling workflow references.



