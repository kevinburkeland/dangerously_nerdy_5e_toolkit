# Cleanup slice 6 progress notes
Status: IN PROGRESS
Start heads: core caf099312ced27dc49919124fdace59a91b4a673, ruleset 8174dfcd51706f7998dd4907b19cb3ce950581a4, app c669f797ff45649625395e46400bc4da002c7328
Last pushed heads (CI green): core 3776d5b5f5eb3d33bfa07cbef48280a4179bb78e, ruleset 854ae142393a7b69120deeed046d307106715f6c, app 22386975a4371dd1916c9b7c871351dab3f374fc
Pins now: ruleset -> core 59d7178dea6527a18a2cac3b7fe0f110fb93717a; app -> core 59d7178dea6527a18a2cac3b7fe0f110fb93717a, ruleset 8174dfcd51706f7998dd4907b19cb3ce950581a4

## Steps
- [x] Step 1 Retire cs5: ruleset e1ba90e0c88351c9145c2c724d428dc28a4c5ca0 run 41736444224, app 668337e06933b0be70d48be1274b986fc9fa7b5e run 41736504226
- [x] Step 2 Ratchet sees renamed and moved test files: core 3776d5b5f5eb3d33bfa07cbef48280a4179bb78e run 41739087970, ruleset 854ae142393a7b69120deeed046d307106715f6c run 41739091762, app f2ecceaeb7662e1b91548211c9761c8c8b0bb93e run 41739095611
- [x] Step 3 Real SHAs in notes, checked in CI: app d196b14d2868b501448fa7fb29d5d0b043b5afc3 run 41741689041
- [x] Step 4 Reachability law with a starting list: app 22386975a4371dd1916c9b7c871351dab3f374fc run 41747325546
- [ ] Step 5 Re-export shims and wrappers out
- [ ] Step 6 Dead features out, list empty
- [ ] Step 7 Mutations and report

## Next
Implement Step 5: Delete 21 re-export shims/wrappers, repoint ~20 test importers directly to upstream or live code, adjust DT1c folder floor to 49, update docs, regenerate codebase map, and verify tests and test-name ratchet.

## Open issues and deviations
In ruleset, mutation/cs5-g2 had two commits on origin instead of one. Per user instruction, squashed into a single commit with identical tree before retirement.
