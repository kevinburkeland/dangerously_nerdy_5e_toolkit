# Cleanup slice 5 progress notes
Status: IN PROGRESS
Start heads: core 59d7178dea6527a18a2cac3b7fe0f110fb93717a, ruleset 85e43ff3bd1628e3dd43f29145f4c99996b580c8, app 12d9961f18614080b20cc0ac63c0185434f3757b
Last pushed heads (CI green): core 13f4f84d0fab332490b8d0dcbc1609f7124d752d, ruleset f90b46a902ac16709f51cceadaa8b8c9676eb690, app 26707e9c60328d3a96661022b7fbfaa738e1e582
Pins now: ruleset -> core 59d7178dea6527a18a2cac3b7fe0f110fb93717a; app -> core 59d7178dea6527a18a2cac3b7fe0f110fb93717a, ruleset 85e43ff3bd1628e3dd43f29145f4c99996b580c8

## Steps
- [x] Step 1 Retire cs41: core 13f4f84d0fab332490b8d0dcbc1609f7124d752d run 40761057967, ruleset f90b46a902ac16709f51cceadaa8b8c9676eb690 run 40761080847, app 26707e9c60328d3a96661022b7fbfaa738e1e582 run 40761148654
- [ ] Step 2 Lost tests and the test-name ratchet
- [ ] Step 3 One settings table
- [ ] Step 4 Ruleset docs truth
- [ ] Step 5 Damage order (ruleset, then app)
- [ ] Step 6 Dice expression (ruleset, then app)
- [ ] Step 7 Mutations and report

## Next
Restore the three lost settings screen tests in the app and implement the test-name ratchet scripts in all three repos.

## Open issues and deviations
None.
