# Cleanup slice 15 progress notes
Status: IN PROGRESS
Start heads: core ec9f155cbdce8315b0d84213842ddf8a22e46a66, ruleset e49258140498c919eb91808c1d48da20870cfd7d, app 058f7bda940ed634413328f798c779f3c7644e86
Last pushed heads (CI green): core 73007473fedbaaeb2778776dcbe55fc127c4ce79, ruleset 72c62b2295d6311e636bca28e8c740de8fde61d0, app 5f751d470fa962d860e3682ffa89fcd5954dd436
Pins now: ruleset -> core ec9f155cbdce8315b0d84213842ddf8a22e46a66; app -> core ec9f155cbdce8315b0d84213842ddf8a22e46a66, ruleset e49258140498c919eb91808c1d48da20870cfd7d
Fix ids: 1.1 1.2 1.3 1.4 2.1 2.2 3.1 3.2 4.1 4.2 5.1 5.2 5.3 5.4 6.1 6.2 7.1 7.2 7.3 8.1 8.2
Mutation ids: C1 R1 R2 R3 A1 D1 L1 H1 H2 G1 W1 P1 F1 I1 S1 S2

## Fix titles
Fix 1.1: Retire cs14
Fix 1.2: The barrel floor rule has a failing case
Fix 1.3: The cast resolver reads addsAbilityMod from the scaling rule
Fix 1.4: A look-ahead run of the dependency check
Fix 2.1: Every campaign dialog opens with a list of any size
Fix 2.2: Disperse Loot works with a roster
Fix 3.1: The host role is given to each sync session
Fix 3.2: Stopping sync forgets the host role
Fix 4.1: Arena match goldens for fixed seeds
Fix 4.2: A damage-defense table for every bundled creature
Fix 5.1: Damage defenses from stat-block text live in the ruleset
Fix 5.2: Attack rolls and the Shield reaction live in the ruleset
Fix 5.3: Save DCs live in the ruleset
Fix 5.4: Monster proficiency follows the SRD table above CR 20
Fix 6.1: The arena engine is split by concern
Fix 6.2: The arena rules folder is plain Dart
Fix 7.1: Characterization tests for the DM dashboard
Fix 7.2: The DM dashboard has no service-locator fallbacks
Fix 7.3: The DM dashboard is split
Fix 8.1: Characterization tests for the party room screen
Fix 8.2: The party room screen is split

## Steps
- [x] Step 1 Retire, barrel case, scaling flag, look-ahead: core 73007473fedbaaeb2778776dcbe55fc127c4ce79 run 45262883355, ruleset 72c62b2295d6311e636bca28e8c740de8fde61d0 run 45262983455, app 5f751d470fa962d860e3682ffa89fcd5954dd436 run 45264114586
- [ ] Step 2 Campaign dialogs with lists
- [ ] Step 3 Host role per session
- [ ] Step 4 Arena goldens
- [ ] Step 5 Arena rules into the ruleset
- [ ] Step 6 Arena engine split
- [ ] Step 7 DM dashboard
- [ ] Step 8 Party room screen
- [ ] Step 9 Mutations and report

## Fix checklist
Fix 1.1 done: [Retire cs14] Retired all cs14 mutation branches across core, ruleset, and app with archive tags and manifests.
Fix 1.2 done: [The barrel floor rule has a failing case] Added self-test cases 21-24 to scripts/test_check_coverage_floor.sh in core and ruleset (byte-identical).
Fix 1.3 done: [The cast resolver reads addsAbilityMod from the scaling rule] Updated lib/providers/spell_cast_formula_resolver.dart to read addsAbilityMod from SpellScalingFormula instead of customProperties and added test/providers/spell_cast_formula_resolver_test.dart.
Fix 1.4 done: [A look-ahead run of the dependency check] Ran 14-day look-ahead (2026-12-07) in all three repos; upgraded cli_util locally in core/ruleset and upgraded 7 pub packages plus file_picker floor in app pubspec.yaml/pubspec.lock.

## Mutation branches
None

## Red runs on main
None

## Resets
None

## Next
Write the Fix 2.1 campaign dialogs list-size law and completeness bar, confirm DisperseLootDialog fails with non-empty rosters, then fix its layout in Fix 2.2.

## Open issues and deviations
- Fix 1.2: Prompt stated "case 19 (around line 262) proves the passing case only. Nothing proves a file with real code still fails at 0.0." Existing scripts/test_check_coverage_floor.sh already had case 20 ("non-barrel file lowering floor to 0.0 still fails"); new cases 21-24 continued numbering and all four passed as guards on the existing check_coverage_floor.py.
- Fix 1.4: Look-ahead (--today 2026-12-07) in app also flagged T1 (Flutter SDK pin 3.50.0 behind newest stable 3.50.1, released 2026-11-20, 3 days old today). Not bumped because pubspec.yaml pins exact Flutter version 3.50.0 and local SDK is 3.50.0; today's dependency check passes within the 14-day grace period.
