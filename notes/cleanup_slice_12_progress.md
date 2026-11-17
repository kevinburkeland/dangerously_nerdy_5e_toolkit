# Cleanup slice 12 progress notes
Status: IN PROGRESS
Start heads: core f71ae361d3be4eea36e50cbd67e28baa19903b6c, ruleset d9334641b75b17993ec8bd53a90e7c612abec04c, app 8ce29311c9398ddd8949905cdba661cd60747730
Last pushed heads (CI green): core da68079cede34fb9664e9a9a7c9a60f661a83e22, ruleset e4b36f30fe078168eae1e9b1b599d4a9f3bdd007, app 78970de6344897b144d2f793c8c2887c8838eca5
Pins now: ruleset -> core 0617617e954e0add7898a00cf5f9b4ec3334525e; app -> core 0617617e954e0add7898a00cf5f9b4ec3334525e, ruleset d9334641b75b17993ec8bd53a90e7c612abec04c
Fix ids: 1.1 1.2 2.1 2.2 3.1 3.2 4.1 4.2 4.3 5.1 5.2 6.1 6.2 6.3 7.1 7.2 7.3 7.4 8.1
Mutation ids: G1 G2 Q1 V1 V2 A1 A2 S1 W1 W2 B1 P1 P2 E1 T1 S2 C1

## Fix titles
Fix 1.1: minimatch and the npm exception rows before their dates
Fix 1.2: A look-ahead run of the dependency check
Fix 2.1: Retire cs11
Fix 2.2: A step row names that step's own head
Fix 3.1: Input data can only be opened through the accessor
Fix 3.2: Optional fields are schema rows too
Fix 4.1: The dice bar reads every string literal
Fix 4.2: The remaining dice sites go through DiceExpression
Fix 4.3: No invented die when a formula can't be read
Fix 5.1: Models declare no callback types, with no file allowlist
Fix 5.2: The ruleset denylist test scans what its name says
Fix 6.1: Pure ruleset tests move to the ruleset
Fix 6.2: Coverage floors in core and ruleset that only go up
Fix 6.3: No pure ruleset test in the app
Fix 7.1: Attack odds in the ruleset, exact
Fix 7.2: Save odds in the ruleset, exact
Fix 7.3: Save damage and Evasion in the ruleset
Fix 7.4: The DPR calculator and the arena use them
Fix 8.1: CharacterDto is a thin codec

## Steps
- [x] Step 1 minimatch and the npm rows before their dates: app c04474c5ac2a94bdd09d95b6a95a06f58f850b17 run 44134284094
- [x] Step 2 Retire, and step rows: core 2bfb58a0ab55130b2e01f6efa3c6e2bc066fff2f run 44135485377, ruleset e8528d1181100419393c07e1094b4b05e1243f37 run 44135517061, app ed339e0499b4566b24a03923b542c6b61e6449cf run 44139659617
- [x] Step 3 Guarded dependency input: core da68079cede34fb9664e9a9a7c9a60f661a83e22 run 44174667146, ruleset e4b36f30fe078168eae1e9b1b599d4a9f3bdd007 run 44174680574, app 5b2c6552c425d88d4cba9734a403ac2b92afd3e2 run 44174697411
- [x] Step 4 The dice bar reads strings, and the last dice sites: app 78970de6344897b144d2f793c8c2887c8838eca5 run 44193767266
- [ ] Step 5 Models callback rule, and the ruleset denylist test
- [ ] Step 6 Ruleset tests come home, with coverage floors
- [ ] Step 7 Attack odds, save odds and save damage come home
- [ ] Step 8 CharacterDto
- [ ] Step 9 Mutations and report

## Fix checklist
Fix 1.1 done: [minimatch and the npm exception rows before their dates] Bumped minimatch override to 11.0.9, reviewed 5 N4 overrides in firestore_rules_test/package.json, and extended review dates to 2026-12-17 in dependency_exceptions.tsv
Fix 1.2 done: [A look-ahead run of the dependency check] Ran look-ahead check on core, ruleset, and app with --today 2026-12-01; updated firebase to 13.4.0, actions/setup-java to v6.3.0, and upgraded pub dependencies to pass clean
Fix 2.1 done: [Retire cs11] Retired cs11 mutation branches across core (3), ruleset (3), and app (13) with 19 archive tags
Fix 2.2 done: [A step row names that step's own head] Taught check_notes_shas.py strict descendant checks for step rows, froze slice 11 notes, and added NS67-NS72 self-tests
Fix 3.1 done: [Input data can only be opened through the accessor] Wrapped all external dependency input files and HTTP JSON payloads in _GuardedDict / _GuardedList with 64 SCHEMA paths; direct unchecked subscript access fails closed.
Fix 3.2 done: [Optional fields are schema rows too] Registered all optional and nullable fields in SCHEMA table with explicit documented reasons, enforcing type checking, non-empty validation, and table-driven fail-closed law in DC72 across 363 damage cases and 22 allowed-valid cases.
Fix 4.1 done: [The dice bar reads every string literal] Replaced line-based RegExp scanner in dice_reading_bar_test.dart with DartStringLiteralReader to extract all string literals, multiline strings, adjacent concatenations, and raw strings, matching dice patterns via isDicePattern; 16 positive and 14 negative controls pass.
Fix 4.2 done: [The remaining dice sites go through DiceExpression] Migrated all 12 hand-written dice regex sites across stat_block_acl_parser.dart, dpr_models.dart, spell_dto.dart, homebrew_ingestor.dart, candidate_detector.dart, dnd5e_ingestion_capability.dart, and dnd5e_class_field_extractor.dart to DiceExpression; characterization tests pass across all 28 sites.
Fix 4.3 done: [No invented die when a formula can't be read] Removed 1d10 private fallbacks in CharacterSheetController.rollSpellDamage and _rollUpcastSpellDamage; verified with 500-seed property law test that unparseable formulas produce zero dice.
Fix 5.1 done: [Models declare no callback types, with no file allowlist] Removed BudgetCalculator and replaced with budgetBySpellLevel map table; built Rule P2 (a) forbidding function typedefs in lib/models/ and deleted kRuleP2Allowlist.
Fix 5.2 done: [The ruleset denylist test scans what its name says] Refactored srd_legal_compliance_test.dart in vtt-ruleset-dnd5e to scan lib/ against compliance/srd_denylist.txt and added meta-test verifying non-existsSync assertions.

## Mutation branches
None

## Red runs on main
964d3fc2909f195c0030b2ad225b941ef8e8e0a2 cancelled run 44135308908
60d41a75dbfe9ca36f5f5bf1aecc86d1d3a5a57f red run 44135584591
2c3738cd1c2abd8f73f31b36757d2de5007e651f cancelled run 44191916989
7e0e20bfafdbde23a0a3ddbe01686b6bc99fda0d red run 44192285916
2ac32da6a6502812afb25a7a35896a2939a6007b red run 44194718959
d2f7e2bbfb49c1da85f12fd742728730f2c9bab1 red run 44199708231

## Next
Step 5: Models callback rule, and the ruleset denylist test.

## Open issues and deviations
- Working tree at start heads contained leftover uncommitted mutation changes from slice 11 (arena_combatant.dart, campaign_registry_service.dart, PRIVACY_POLICY.md in app; dnd_5e_combat_resolver.dart, dice_expression.dart, character_stat_calculator.dart in ruleset); verified identical to cs11 branches and restored clean with git checkout -- before baseline tests.
- check_notes_shas.py requires GITHUB_TOKEN=$(gh auth token) locally to avoid GitHub API 403 rate limits on unauthenticated requests.
- Look-ahead dependency check with --today 2026-12-01 revealed new releases for actions/setup-java (v6.3.0), firebase npm (13.4.0), and 6 pub packages with floors; updated to newest releases to maintain green look-ahead across all repos.
- Both denylist tests in vtt-ruleset-dnd5e test/compliance/srd_legal_compliance_test.dart check the same denylist (compliance/srd_denylist.txt); historically Test 1 focused on WotC monster names while Test 2 audits comprehensive non-SRD terms. Both names are retained per prompt instructions.
Cleanup slice 11 notes Step 1 app row correction: 9075eaceb054e1a5ff3862d01022cbe5f810ce24 run 43507783982
Run 44135308908 cause: cancelled on 964d3fc2909f195c0030b2ad225b941ef8e8e0a2 when push 60d41a75dbfe9ca36f5f5bf1aecc86d1d3a5a57f was made; fixed by 60d41a75dbfe9ca36f5f5bf1aecc86d1d3a5a57f
Run 44135584591 cause: failed on 60d41a75dbfe9ca36f5f5bf1aecc86d1d3a5a57f due to undisclosed cancelled run on 964d3fc2909f195c0030b2ad225b941ef8e8e0a2 and GHSA-fc5q-39xc-vjpf; fixed by e3b9966f7c74541e6a506119903a02d435337351
Run 44191916989 cause: cancelled on 2c3738cd1c2abd8f73f31b36757d2de5007e651f when push 7e0e20bfafdbde23a0a3ddbe01686b6bc99fda0d was made; fixed by 7e0e20bfafdbde23a0a3ddbe01686b6bc99fda0d
Run 44192285916 cause: failed on 7e0e20bfafdbde23a0a3ddbe01686b6bc99fda0d due to test names ratchet in dice reading bar; fixed by 4128506a769a31b8bbe58f0242330663e1e2d366
Run 44194718959 cause: failed on 2ac32da6a6502812afb25a7a35896a2939a6007b due to typo in Step 4 commit SHA; fixed by 9bc6d310ec63778b9845665e3c17e33800ce8c21
Run 44199708231 cause: failed on d2f7e2bbfb49c1da85f12fd742728730f2c9bab1 due to stale codebase_map.md generated folder index following removal of BudgetCalculator in Fix 5.1; fixed by a2d589d93ff02c396e4856dba72587b78b42e2dc
