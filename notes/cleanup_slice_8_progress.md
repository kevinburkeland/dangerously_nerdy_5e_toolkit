# Cleanup slice 8 progress notes
Status: IN PROGRESS
Start heads: core fa35b438bc6dbfa589989ad903268c401d9bf6b5, ruleset 4bf82201da6fb2bb55ff2d50665a14e6768bec65, app 3308efc0b6c4ec71e75a6df7ace12032f43abf58
Last pushed heads (CI green): core fa35b438bc6dbfa589989ad903268c401d9bf6b5, ruleset 4bf82201da6fb2bb55ff2d50665a14e6768bec65, app e5659096e7840a37b17f6cface723a8055cfda26
Pins now: ruleset -> core 59d7178dea6527a18a2cac3b7fe0f110fb93717a; app -> core 59d7178dea6527a18a2cac3b7fe0f110fb93717a, ruleset 8174dfcd51706f7998dd4907b19cb3ce950581a4

## Steps
- [x] Step 1 Retire cs7: app 96cd84b463619c3e9e07bdd8acbdc02271ec3faf run 41962127437
- [x] Step 2 App CI split by test file: app e5659096e7840a37b17f6cface723a8055cfda26 run 41963984251
- [ ] Step 3 One analysis options file per repo
- [ ] Step 4 Dynamic ceiling back down
- [ ] Step 5 Notes check verifies CI run ids
- [ ] Step 6 Mutations and report

## Next
Step 3: add root-only analysis_options.yaml check in scripts/check_strict_analysis.sh across all three repos.

## Open issues and deviations
After retiring cs7 mutation branches, git checkout in fresh CI clone did not fetch the 8 unreferenced mutation branch heads that were referenced in notes/cleanup_slice_7_progress.md line 14, causing CI check_notes_shas to fail. Pushed archive/cs7-* tags to origin to allow actions/checkout to fetch the archived mutation commit objects without leaving mutation heads open.
