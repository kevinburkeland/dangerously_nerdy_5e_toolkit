# Cleanup slice 10.1 progress notes
Status: IN PROGRESS
Start heads: core b82634e38ae7fc57c9d8a57e0b4bcb96c724a21a, ruleset 08d7d7c0cf860055a8c387a3ca61829d200f253e, app 857ac8e271b882885e5251a53bdc09ad20aa6ede
Last pushed heads (CI green): core b82634e38ae7fc57c9d8a57e0b4bcb96c724a21a, ruleset 08d7d7c0cf860055a8c387a3ca61829d200f253e, app 3cf9945e7525d620bb5f0a6c7211fd138bd80da6
Pins now: ruleset -> core 59d7178dea6527a18a2cac3b7fe0f110fb93717a; app -> core 59d7178dea6527a18a2cac3b7fe0f110fb93717a, ruleset 8174dfcd51706f7998dd4907b19cb3ce950581a4
Fix ids: 2.1 2.2 3.1 3.2 3.3 3.4 3.5 3.6 4.1 4.2 4.3 4.4 4.5 5.1 5.2 5.3 6.1 6.2 6.3 6.4 6.5 6.6

## Steps
- [x] Step 1 Retire cs10: app 7df7c8787daeb9a6490202146d290c83ae941c95 run 42313342876
- [x] Step 2 Two small fixes from the slice 10 review: app 3cf9945e7525d620bb5f0a6c7211fd138bd80da6 run 42315746680
- [ ] Step 3 Combat actions carry data, not callbacks
- [ ] Step 4 Colour and icon values, and the glyph token split
- [ ] Step 5 Creatures and summons hold plain values
- [ ] Step 6 The rest of models hold plain values
- [ ] Step 7 Mutations and report

## Fix checklist
Fix 2.1 done: check_notes_shas.py verifies Fix checklist against Fix ids with NS23-NS31 self-tests in test_check_notes_shas.sh.
Fix 2.2 done: PartyRoomService.newInstance restored isolated DiceRoomService.newInstance default with isolation test and updated test setups.

## Red runs on main
None

## Next
Pin today's combat action buttons with characterization test, then turn CharacterCombatAction into pure data without callbacks.

## Open issues and deviations
In DiceRoomService, removed visibleForTesting annotation from DiceRoomService.newInstance so PartyRoomService.newInstance can instantiate it without triggering analyzer warnings or requiring an ignore comment.
