# Cleanup slice 6 progress notes
Status: IN PROGRESS
Start heads: core caf099312ced27dc49919124fdace59a91b4a673, ruleset 8174dfcd51706f7998dd4907b19cb3ce950581a4, app c669f797ff45649625395e46400bc4da002c7328
Last pushed heads (CI green): core caf099312ced27dc49919124fdace59a91b4a673, ruleset e1ba90e0c88351c9145c2c724d428dc28a4c5ca0, app 668337e06933b0be70d48be1274b986fc9fa7b5e
Pins now: ruleset -> core 59d7178dea6527a18a2cac3b7fe0f110fb93717a; app -> core 59d7178dea6527a18a2cac3b7fe0f110fb93717a, ruleset 8174dfcd51706f7998dd4907b19cb3ce950581a4

## Steps
- [x] Step 1 Retire cs5: ruleset e1ba90e0c88351c9145c2c724d428dc28a4c5ca0 run 41736444224, app 668337e06933b0be70d48be1274b986fc9fa7b5e run 41736504226
- [ ] Step 2 Ratchet sees renamed and moved test files
- [ ] Step 3 Real SHAs in notes, checked in CI
- [ ] Step 4 Reachability law with a starting list
- [ ] Step 5 Re-export shims and wrappers out
- [ ] Step 6 Dead features out, list empty
- [ ] Step 7 Mutations and report

## Next
Implement Step 2: update scripts/check_test_names.py to use --no-renames, add TN9/TN10/TN11 self-tests, verify identical sha256sum across all three repos, and run against start heads.

## Open issues and deviations
In ruleset, mutation/cs5-g2 had two commits on origin instead of one. Per user instruction, squashed into a single commit with identical tree 5e198e51f0f903aba9f5c351f55e112803194ed9 before retirement.
