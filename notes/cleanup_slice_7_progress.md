# Cleanup slice 7 progress notes
Status: IN PROGRESS
Start heads: core 3776d5b5f5eb3d33bfa07cbef48280a4179bb78e, ruleset 854ae142393a7b69120deeed046d307106715f6c, app b4badc20ec5b78a937f2f9405f57f913dbaaf121
Last pushed heads (CI green): core fa35b438bc6dbfa589989ad903268c401d9bf6b5, ruleset 4bf82201da6fb2bb55ff2d50665a14e6768bec65, app ef6628d077280ef046cdb3fc54af714355a51243
Pins now: ruleset -> core 59d7178dea6527a18a2cac3b7fe0f110fb93717a; app -> core 59d7178dea6527a18a2cac3b7fe0f110fb93717a, ruleset 8174dfcd51706f7998dd4907b19cb3ce950581a4

## Steps
- [x] Step 1 Retire cs6: core fa35b438bc6dbfa589989ad903268c401d9bf6b5 run 41903199666, ruleset 4bf82201da6fb2bb55ff2d50665a14e6768bec65 run 41903217036, app 0a131ac9c7bdd41af68b3d7b6ed2d48e088ee4c4 run 41903240468
- [x] Step 2 Removal list reasons and header: app 88c8fb049e08be49930863b8626cff9c8469bded run 41906212814
- [x] Step 3 Dynamic ratchet and implicit-dynamic ceilings: app 7f25f230956365bf7c415cf694777736faa76c42 run 41909642471
- [x] Step 4 Strict casts: callbacks and guarded reads: app ef6628d077280ef046cdb3fc54af714355a51243 run 41938271463
- [ ] Step 5 Strict casts: the rest
- [ ] Step 6 Strict casts on, with a canary
- [ ] Step 7 Mutations and report

## Next
Step 5: strict casts part 2: the remaining 24 sites and two test fixes.

## Open issues and deviations
None.

