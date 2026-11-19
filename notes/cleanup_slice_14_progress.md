# Cleanup slice 14 progress notes
Status: IN PROGRESS
Start heads: core 0ac9fd681bd514bca1a76b84e6eb7b69092d4c67, ruleset 9f44a7f3553b9c64d0f3f089e13f9e8dddf95b8b, app e188a91003a941672e9429408fe8b857133fb086
Last pushed heads (CI green): core 2d2958aa9789441e6ecd63554c83a1467b44a24d, ruleset a7bdb929c65f641eea686e86d79b4da6b529cafd, app 4bcc143a5588323f8790fc40968b6c02c60d4086
Pins now: ruleset -> core 87011633eb26d170a67b7992132cae9866cd297b; app -> core 87011633eb26d170a67b7992132cae9866cd297b, ruleset 0562855170a8e74d351e01d6c0c5333cd75451d9
Fix ids: 1.1 1.2 1.3 1.4 2.1 2.2 2.3 3.1 3.2 3.3 4.1 4.2 4.3 5.1 5.2 5.3 5.4 6.1 6.2 6.3 7.1 7.2 7.3 7.4 8.1 8.2
Mutation ids: E1 B1 V1 K1 L1 M1 B2 S1 S2 T1 G1 Z1 H1 U1 P1 C1

## Fix titles
Fix 1.1: Retire cs13
Fix 1.2: The three slice 11 reasons are restored
Fix 1.3: Removed-test rows are append-only
Fix 1.4: A look-ahead run of the dependency check
Fix 2.1: Bonus slice 1.1 mutations proven from their archives
Fix 2.2: The cs5 archives are checked end to end
Fix 2.3: Slice 7 S1 to S4 each show their own catch
Fix 3.1: The ruleset gives each class's spellcasting modifier
Fix 3.2: mod in a spell formula is the caster's spellcasting modifier
Fix 3.3: A formula part that can't be read makes the formula unreadable
Fix 4.1: Inventory is read-only on every construction path
Fix 4.2: A malformed version fails closed
Fix 4.3: The super-conversion bar reads closures and prints lines
Fix 5.1: Legacy room state carries the genesis clock
Fix 5.2: Stopping sync forgets the old campaign
Fix 5.3: SHA-256 comes from package crypto
Fix 5.4: One PartyRoomService, and app type names are unique
Fix 6.1: The purity bar walks imports transitively
Fix 6.2: Logging goes through a pure port
Fix 6.3: The DPR engine's math is plain Dart
Fix 7.1: Sets have a canonical encoding
Fix 7.2: Core's session graph file is split by type
Fix 7.3: Core and the ruleset get a big-file bar
Fix 7.4: Duplicate ruleset test files are removed
Fix 8.1: Characterization tests for every campaign dialog
Fix 8.2: One file per campaign dialog

## Steps
- [x] Step 1 Retire, removed-test rows, look-ahead: core 2d2958aa9789441e6ecd63554c83a1467b44a24d run 44597536910, ruleset a7bdb929c65f641eea686e86d79b4da6b529cafd run 44597542250, app 4bcc143a5588323f8790fc40968b6c02c60d4086 run 44597550345
- [ ] Step 2 Old mutation evidence
- [ ] Step 3 Spell formulas use the spellcasting modifier
- [ ] Step 4 Inventory, versions, super-conversion bar
- [ ] Step 5 Sync and identity
- [ ] Step 6 Purity
- [ ] Step 7 Core encoding and split, big-file bars, duplicate tests
- [ ] Step 8 Campaign dialogs split
- [ ] Step 9 Mutations and report

## Fix checklist
Fix 1.1 done: [Retire cs13] Retired 3 core, 5 ruleset, and 14 app cs13 mutation branches with 22 archive tags into MANIFEST.tsv and mutations/cs13
Fix 1.2 done: [The three slice 11 reasons are restored] Restored the three slice 11 renamed-test reasons in removed_test_names.txt and updated check_srd_terms.py and test_check_srd_terms.sh (SR20-SR22)
Fix 1.3 done: [Removed-test rows are append-only] Added append-only marker to removed_test_names.txt and history prefix walk to check_test_names.py and test_check_test_names.sh (TN16-TN22)
Fix 1.4 done: [A look-ahead run of the dependency check] Ran check_dependencies.py with 14-day look-ahead across all three repos and upgraded dbus to 0.8.1 and firebase-tools to 15.37.0 in pubspec.lock, package.json, and package-lock.json

## Mutation branches
None

## Red runs on main
None

## Resets
None

## Next
Prove the Bonus slice 1.1, Cleanup slice 5, and Cleanup slice 7 archived mutations in Step 2 and record the results in the backfill evidence table.

## Open issues and deviations
- Fix 1.4 look-ahead run (--today 2026-12-03) passed in core and the ruleset, and found dbus (0.8.0 -> 0.8.1) and firebase-tools (15.36.0 -> 15.37.0) crossing the 14-day window in the app; both were updated in Step 1.
