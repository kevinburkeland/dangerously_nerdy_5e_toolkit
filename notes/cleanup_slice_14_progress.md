# Cleanup slice 14 progress notes
Status: IN PROGRESS
Start heads: core 0ac9fd681bd514bca1a76b84e6eb7b69092d4c67, ruleset 9f44a7f3553b9c64d0f3f089e13f9e8dddf95b8b, app e188a91003a941672e9429408fe8b857133fb086
Last pushed heads (CI green): core 8691313bf85cd25052df48d97ff874690d405094, ruleset dca5db4a5f5928634ae828598e5d0b9bef532599, app e0cf227c3bc80a90b3614bf1e125b907b5f74e88
Pins now: ruleset -> core 87011633eb26d170a67b7992132cae9866cd297b; app -> core 87011633eb26d170a67b7992132cae9866cd297b, ruleset dca5db4a5f5928634ae828598e5d0b9bef532599
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
- [x] Step 2 Old mutation evidence: app b8ab1698a741eda36111d7b7a70b6305bf0172c6 run 44611441496
- [x] Step 3 Spell formulas use the spellcasting modifier: ruleset 862a6f64e1d61d01fa3017f3ba27f6549c107514 run 44614156424, app characterization 57c0c1f9d3dd4b85f99da4b2badd62e765055b40 run 44614852758, app a9ae2d699606ea41acf1b14c66721199c34ce35b run 44622396688
- [x] Step 4 Inventory, versions, super-conversion bar: core 8691313bf85cd25052df48d97ff874690d405094 run 44625994045, ruleset dca5db4a5f5928634ae828598e5d0b9bef532599 run 44626002074, app 9e3bd933eebd7fd2d0fdfb17f664d3a06eb3fed0 (all code/test/build jobs green; red run disclosed below)
- [x] Step 5 Sync and identity: app e0cf227c3bc80a90b3614bf1e125b907b5f74e88 run 44633009813
- [ ] Step 6 Purity
- [ ] Step 7 Core encoding and split, big-file bars, duplicate tests
- [ ] Step 8 Campaign dialogs split
- [ ] Step 9 Mutations and report

## Fix checklist
Fix 1.1 done: [Retire cs13] Retired 3 core, 5 ruleset, and 14 app cs13 mutation branches with 22 archive tags into MANIFEST.tsv and mutations/cs13
Fix 1.2 done: [The three slice 11 reasons are restored] Restored the three slice 11 renamed-test reasons in removed_test_names.txt and updated check_srd_terms.py and test_check_srd_terms.sh (SR20-SR22)
Fix 1.3 done: [Removed-test rows are append-only] Added append-only marker to removed_test_names.txt and history prefix walk to check_test_names.py and test_check_test_names.sh (TN16-TN22)
Fix 1.4 done: [A look-ahead run of the dependency check] Ran check_dependencies.py with 14-day look-ahead across all three repos and upgraded dbus to 0.8.1 and firebase-tools to 15.37.0 in pubspec.lock, package.json, and package-lock.json
Fix 2.1 done: [Bonus slice 1.1 mutations proven from their archives] Proved all 13 Bonus slice 1.1 archived mutations at base_sha and today's head and recorded them in mutation_evidence_backfill.md
Fix 2.2 done: [The cs5 archives are checked end to end] Verified all 7 ruleset and 8 app cs5 archives end to end, pushed lightweight archive/cs5-* tags, and documented the squashed cs5-g2 archive in mutation_evidence_backfill.md
Fix 2.3 done: [Slice 7 S1 to S4 each show their own catch] Proved cs7-s1 through cs7-s4 from their archives and at today's head and recorded each distinct catch in mutation_evidence_backfill.md
Fix 3.1 done: [The ruleset gives each class's spellcasting modifier] Added EvaluatedCharacterStats.spellcastingModifiers keyed identically to spellAttackBonuses (empty for non-spellcasters) with a 360-seed law test and re-pinned the ruleset in the app
Fix 3.2 done: [mod in a spell formula is the caster's spellcasting modifier] Resolved DiceModTerm in castSpell via SpellCastFormulaResolver with multiclass selection, no-spellcasting-modifier rejection and SnackBar in SpellCard and InteractiveSpellTile, and bundled-spell plus 520-seed laws
Fix 3.3 done: [A formula part that can't be read makes the formula unreadable] Tightened parseSpellFormulaField fallback to reject any signed non-match token while keeping plain descriptive words allowed, verified by bundled-spell and 520-seed generated laws
Fix 4.1 done: [Inventory is read-only on every construction path] Probed slice 12 head getters (inventory, cantrips, spellsKnown, activeGrants), wrapped Character.inventory once in factory Character via List.unmodifiable with 120-seed law, kept map goldens byte-identical, and re-pinned the ruleset in the app
Fix 4.2 done: [A malformed version fails closed] Updated shared check_dependencies.py parse_semver to fail closed on malformed or invalid short versions with DC75-DC76 self-tests across all three repos and passed live dependency checks in all three repos
Fix 4.3 done: [The super-conversion bar reads closures and prints lines] Upgraded ruleset no_super_conversion_bar_test.dart scanSuperConversions to mask comments and strings, detect closures on super.<name>, and report path:line with controls first
Fix 5.1 done: [Legacy room state carries the genesis clock] Switched CampaignProfileDto.toDomain legacy roomState.titleTimestamp from legacy_import to HybridLogicalClock.genesis with a 220-seed plus control law test
Fix 5.2 done: [Stopping sync forgets the old campaign] Reset RoomSyncOrchestrator sequence, last emitted profile, tracked rules set, and applied-profile deduplication caches in stopSynchronization with a lifecycle test
Fix 5.3 done: [SHA-256 comes from package crypto] Replaced the hand-written SHA-256 in CryptoUtils.sha256Hex with package:crypto sha256 verified by NIST KATs, 1050 seeded strings, and block-edge lengths
Fix 5.4 done: [One PartyRoomService, and app type names are unique] Extended unique_type_names_law_test.dart to app-internal top-level declarations, deleted unused duplicate PartyRoomService, and updated DI, tests, removed_test_names.txt, and codebase_map.md

## Mutation branches
None

## Red runs on main
965cc87801560b92c92ac86b40b9472d6815709b red run 44626433270
9e3bd933eebd7fd2d0fdfb17f664d3a06eb3fed0 red run 44627656241
968a5f013be8d3aa14c81b2d250c0f6115181282 red run 44629210882

## Resets
None

## Next
Implement Step 6: transitive purity bar (Fix 6.1), pure LogSink port and Crashlytics sink (Fix 6.2), and plain-Dart DPR calculator math with moved compute wrappers (Fix 6.3).

## Open issues and deviations
- Fix 1.4 look-ahead run (--today 2026-12-03) passed in core and the ruleset, and found dbus (0.8.0 -> 0.8.1) and firebase-tools (15.36.0 -> 15.37.0) crossing the 14-day window in the app; both were updated in Step 1.
- Fix 2.2 cs5-g2: the two original Cleanup slice 5 commits can no longer be found; archive/cs5-g2 holds the squashed single-commit version 9d8e528ba899586b7ba5f23933e7c021d75236f6.
- Fix 2.3 cs7-s1: at base_sha on Flutter 3.50.0, flutter analyze control reported deprecated_member_use infos; today's head run cleanly proved the single argument_type_not_assignable catch.
- Fix 3.2 Barkskin (v2024): bundled rollFormula '10 + mod' is not a damage or healing roll in the SRD (open question whether its data should carry a rollFormula at all); before Fix 3.2 castSpell rolled 0 dice + 10, after Fix 3.2 WIS 16 Cleric rolls 0 dice + 13 and non-spellcaster gets null with no-spellcasting-modifier SnackBar.
- Fix 4.1 Character constructor: wrapping inventory once via List.unmodifiable required making Character(...) a factory constructor delegating to const Character._(...); updated const Character(...) call sites in ruleset and app tests and updated character_typed_contract_law_test.dart line 89 to assert element identity and identical(c.inventory, c.inventory) rather than identical(c.inventory, mutableInput).
- Fix 5.1 saved legacy data: legacy campaigns already upgraded and re-saved under the old legacy_import timestamp retain that saved clock and can still collide if two devices saved divergent names before Fix 5.1; all newly upgraded legacy records use HybridLogicalClock.genesis.
- Fix 5.4 test references: five test files (rather than three) referenced the deleted duplicate PartyRoomService (di_graph_law_test.dart, injection_container_test.dart, local_replica_identity_store_test.dart, room_state_reconciliation_service_test.dart, crdt_pass_3_3_1_test.dart).
Run 44626433270 cause: const Character replacement script accidentally touched frozen legacy storage fixtures under test/fixtures/legacy_storage/, caught by LC3 MANIFEST.json sha256 check; fixed by 9e3bd933eebd7fd2d0fdfb17f664d3a06eb3fed0
Run 44627656241 cause: check_notes_shas failed because the prior red run on 965cc87801560b92c92ac86b40b9472d6815709b was not yet disclosed in progress notes; fixed by b683a896da1387406a85c9b30b72049213f0a219
Run 44629210882 cause: DT2 in docs_truth_test flagged non-literal E1..E9 path syntax in Step 4 progress notes; fixed by 2185c60d9df938369f19a13e58e2bf956a4cf069
