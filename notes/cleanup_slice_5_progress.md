# Cleanup slice 5 progress notes
Status: IN PROGRESS
Start heads: core 59d7178dea6527a18a2cac3b7fe0f110fb93717a, ruleset 85e43ff3bd1628e3dd43f29145f4c99996b580c8, app 12d9961f18614080b20cc0ac63c0185434f3757b
Last pushed heads (CI green): core caf09939ce2a3e5c942bf9d22da9f1dd7cb7cf99, ruleset 93dec7b4582f6fbf918667c4faee4587db875471, app 7f1d1af7ef248bfb32d2e057ba3b018eecad64df
Pins now: ruleset -> core 59d7178dea6527a18a2cac3b7fe0f110fb93717a; app -> core 59d7178dea6527a18a2cac3b7fe0f110fb93717a, ruleset 85e43ff3bd1628e3dd43f29145f4c99996b580c8

## Steps
- [x] Step 1 Retire cs41: core 13f4f84d0fab332490b8d0dcbc1609f7124d752d run 40761057967, ruleset f90b46a902ac16709f51cceadaa8b8c9676eb690 run 40761080847, app 26707e9c60328d3a96661022b7fbfaa738e1e582 run 40761148654
- [x] Step 2 Lost tests and the test-name ratchet: core caf09939ce2a3e5c942bf9d22da9f1dd7cb7cf99 run 40764851573, ruleset 1b96b9f2910787383bb8f8e0292723c5cf8c39b9 run 40764855709, app 0acec2ee0aa4825946fa5c26b52a8eb9c0b29a24 run 40764859362
- [x] Step 3 One settings table: app 7f1d1af7ef248bfb32d2e057ba3b018eecad64df run 40767671428
- [x] Step 4 Ruleset docs truth: ruleset 93dec7b4582f6fbf918667c4faee4587db875471 run 40770095951
- [ ] Step 5 Damage order (ruleset, then app)
- [ ] Step 6 Dice expression (ruleset, then app)
- [ ] Step 7 Mutations and report

## Next
Implement Step 5a in the ruleset: add adjustDamageForDefenses and DA1 to DA4 law tests.

## Open issues and deviations
None.
