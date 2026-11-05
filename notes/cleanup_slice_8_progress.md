# Cleanup slice 8 progress notes
Status: IN PROGRESS
Start heads: core fa35b438bc6dbfa589989ad903268c401d9bf6b5, ruleset 4bf82201da6fb2bb55ff2d50665a14e6768bec65, app 3308efc0b6c4ec71e75a6df7ace12032f43abf58
Last pushed heads (CI green): core 5ef3fb32b6d0aa2af31ab118ce1063ab1c7be9b4, ruleset caa0cab3b69badc57ed4b19516b7b2447a7a038c, app ae67a5799aa901b513e444e1abcdc9191ced86d3
Pins now: ruleset -> core 59d7178dea6527a18a2cac3b7fe0f110fb93717a; app -> core 59d7178dea6527a18a2cac3b7fe0f110fb93717a, ruleset 8174dfcd51706f7998dd4907b19cb3ce950581a4

## Steps
- [x] Step 1 Retire cs7: app 96cd84b463619c3e9e07bdd8acbdc02271ec3faf run 41962127437
- [x] Step 2 App CI split by test file: app e5659096e7840a37b17f6cface723a8055cfda26 run 41963984251
- [x] Step 3 One analysis options file per repo: core 5ef3fb32b6d0aa2af31ab118ce1063ab1c7be9b4 run 41965005166, ruleset caa0cab3b69badc57ed4b19516b7b2447a7a038c run 41965014649, app ae67a5799aa901b513e444e1abcdc9191ced86d3 run 41965023442
- [ ] Step 4 Dynamic ceiling back down
- [ ] Step 5 Notes check verifies CI run ids
- [ ] Step 6 Mutations and report

## Next
Step 4: lower dynamic ceiling in webrtc_mesh_adapter and homebrew_persistence_service, update dynamic ratchet test.

## Open issues and deviations
After retiring cs7 mutation branches, git checkout in fresh CI clone did not fetch the 8 unreferenced mutation branch heads that were referenced in notes/cleanup_slice_7_progress.md line 14, causing CI check_notes_shas to fail. Pushed archive/cs7-* tags to origin to allow actions/checkout to fetch the archived mutation commit objects without leaving mutation heads open.
