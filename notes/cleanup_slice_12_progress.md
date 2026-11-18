# Cleanup slice 12 progress notes
Status: IN PROGRESS
Start heads: core f71ae361d3be4eea36e50cbd67e28baa19903b6c, ruleset d9334641b75b17993ec8bd53a90e7c612abec04c, app 8ce29311c9398ddd8949905cdba661cd60747730
Last pushed heads (CI green): core 3dd11fe068af9f42c1a2214fe27308737e8036f9, ruleset 18a2768cf6bd153410946c84ed8713a3d59b4775, app 0d0fae047566a0f5e7d8172ed8b6047b08b85753
Pins now: ruleset -> core 0617617e954e0add7898a00cf5f9b4ec3334525e; app -> core 0617617e954e0add7898a00cf5f9b4ec3334525e, ruleset 18a2768cf6bd153410946c84ed8713a3d59b4775
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
- [x] Step 5 Models callback rule, and the ruleset denylist test: ruleset 14726e5aa24949ae00ff7c93c4e38c62040faa92 run 44199598132, app 41db1fd867a659218347d55fdd6158466bdfc61d run 44201812932
- [x] Step 6 Ruleset tests come home, with coverage floors: core 3dd11fe068af9f42c1a2214fe27308737e8036f9 run 44208643201, ruleset b7936cfe772e14ce6c672843652ce917b10f812e run 44208674880, app 8b376186278f421302e7eaf89efd67bad3045309 run 44210286613
- [x] Step 7 Attack odds, save odds and save damage come home: ruleset 18a2768cf6bd153410946c84ed8713a3d59b4775 run 44355285074, app 0d0fae047566a0f5e7d8172ed8b6047b08b85753 run 44359835654
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
Fix 6.1 done: [Pure ruleset tests move to the ruleset] Added InMemoryEntityResolver helper in vtt-ruleset-dnd5e/test/helpers/, moved 8 pure ruleset test files to vtt-ruleset-dnd5e, deleted 6 duplicate/subset files and 8 moved files in app with test/removed_test_names.txt ratchet rows, and kept 3 near files with app collaborators.
Fix 6.2 done: [Coverage floors in core and ruleset that only go up] Added byte-identical check_coverage_floor.py, test_check_coverage_floor.sh (9/9 self-tests), and coverage_floors.tsv (core 71.0%, ruleset 57.9%) with CI enforcement.
Fix 6.3 done: [No pure ruleset test in the app] Added test/infrastructure/compliance/ruleset_tests_home_test.dart with empty allowlist, barrel expansion via dart_directive_reader.dart, and 3 controls.
Fix 7.1 done: [Attack odds in the ruleset, exact] Added D20RollMode, AttackOdds, and computeAttackOdds to vtt-ruleset-dnd5e/lib/src/combat/combat_odds.dart with exact d20 enumeration and 154,280-case oracle law verification.
Fix 7.2 done: [Save odds in the ruleset, exact] Added computeSaveFailureProbability to vtt-ruleset-dnd5e/lib/src/combat/combat_odds.dart with exact d20 enumeration and 8,680-case oracle law verification.
Fix 7.3 done: [Save damage and Evasion in the ruleset] Added SaveDamageOutcome, SaveDamageResult, and computeSaveDamage to vtt-ruleset-dnd5e/lib/src/combat/combat_odds.dart with 4,008-case oracle law verification and 100.0% coverage floor entry.
Fix 7.4 done: [The DPR calculator and the arena use them] Re-pinned vtt_ruleset_dnd5e to 18a2768cf6bd153410946c84ed8713a3d59b4775, delegated DPR odds and all 3 arena save sites to combat_odds.dart, updated characterization fixtures/tests, and lowered big_file_ratchet_test.dart ceiling for arena_combat_engine.dart to 3962.

## Mutation branches
None

## Red runs on main
964d3fc2909f195c0030b2ad225b941ef8e8e0a2 cancelled run 44135308908
60d41a75dbfe9ca36f5f5bf1aecc86d1d3a5a57f red run 44135584591
2c3738cd1c2abd8f73f31b36757d2de5007e651f cancelled run 44191916989
7e0e20bfafdbde23a0a3ddbe01686b6bc99fda0d red run 44192285916
2ac32da6a6502812afb25a7a35896a2939a6007b red run 44194718959
d2f7e2bbfb49c1da85f12fd742728730f2c9bab1 red run 44199708231
44eab9883b4ffb807f7026c8556ae8d9cdbbda9b red run 44200754828
704c265bfb1a48fce5bdbbdd15a83bcaad5ef09c red run 44354852871
2585841c44ebffc67edd723f152fff492a3679e0 red run 44354222017
d795dd5124234f83ee1be5e8270c5ecf77b45ab9 red run 44357321252
356f2c3c34d10f4744df70c02b63fe73a9af9e5e red run 44358434701

## Next
Step 8: CharacterDto is a thin codec.

## Open issues and deviations
- Working tree at start heads contained leftover uncommitted mutation changes from slice 11 (arena_combatant.dart, campaign_registry_service.dart, PRIVACY_POLICY.md in app; dnd_5e_combat_resolver.dart, dice_expression.dart, character_stat_calculator.dart in ruleset); verified identical to cs11 branches and restored clean with git checkout -- before baseline tests.
- check_notes_shas.py requires GITHUB_TOKEN=$(gh auth token) locally to avoid GitHub API 403 rate limits on unauthenticated requests.
- Look-ahead dependency check with --today 2026-12-01 revealed new releases for actions/setup-java (v6.3.0), firebase npm (13.4.0), and 6 pub packages with floors; updated to newest releases to maintain green look-ahead across all repos.
- Both denylist tests in vtt-ruleset-dnd5e/test/compliance/srd_legal_compliance_test.dart check the same denylist (vtt-ruleset-dnd5e/compliance/srd_denylist.txt); historically Test 1 focused on WotC monster names while Test 2 audits comprehensive non-SRD terms. Both names are retained per prompt instructions.
Cleanup slice 11 notes Step 1 app row correction: 9075eaceb054e1a5ff3862d01022cbe5f810ce24 run 43507783982
Run 44135308908 cause: cancelled on 964d3fc2909f195c0030b2ad225b941ef8e8e0a2 when push 60d41a75dbfe9ca36f5f5bf1aecc86d1d3a5a57f was made; fixed by 60d41a75dbfe9ca36f5f5bf1aecc86d1d3a5a57f
Run 44135584591 cause: failed on 60d41a75dbfe9ca36f5f5bf1aecc86d1d3a5a57f due to undisclosed cancelled run on 964d3fc2909f195c0030b2ad225b941ef8e8e0a2 and GHSA-fc5q-39xc-vjpf; fixed by e3b9966f7c74541e6a506119903a02d435337351
Run 44191916989 cause: cancelled on 2c3738cd1c2abd8f73f31b36757d2de5007e651f when push 7e0e20bfafdbde23a0a3ddbe01686b6bc99fda0d was made; fixed by 7e0e20bfafdbde23a0a3ddbe01686b6bc99fda0d
Run 44192285916 cause: failed on 7e0e20bfafdbde23a0a3ddbe01686b6bc99fda0d due to test names ratchet in dice reading bar; fixed by 4128506a769a31b8bbe58f0242330663e1e2d366
Run 44194718959 cause: failed on 2ac32da6a6502812afb25a7a35896a2939a6007b due to typo in Step 4 commit SHA; fixed by 9bc6d310ec63778b9845665e3c17e33800ce8c21
Run 44199708231 cause: failed on d2f7e2bbfb49c1da85f12fd742728730f2c9bab1 due to stale codebase_map.md generated folder index following removal of BudgetCalculator in Fix 5.1; fixed by a2d589d93ff02c396e4856dba72587b78b42e2dc
Run 44200754828 cause: failed on 44eab9883b4ffb807f7026c8556ae8d9cdbbda9b due to docs_truth_test.dart DT2 scanning relative ruleset test path in notes; fixed by 0e0b7d1788a01da577694875e481f9c3c9c2dcd2
Run 44354852871 cause: failed on 704c265bfb1a48fce5bdbbdd15a83bcaad5ef09c in vtt-ruleset-dnd5e due to disallowed ignore: avoid_print comment in save_and_attack_odds_law_test.dart; fixed by 18a2768cf6bd153410946c84ed8713a3d59b4775
Run 44354222017 cause: failed on 2585841c44ebffc67edd723f152fff492a3679e0 in DCO self-tests due to transient GitHub API HTTP 502 and undisclosed ruleset failure on 704c265bfb1a48fce5bdbbdd15a83bcaad5ef09c; fixed by 61f0b6ee878c508347e877f4df843ceb976ba923
Run 44357321252 cause: failed on d795dd5124234f83ee1be5e8270c5ecf77b45ab9 in Check Dependency Currency & Security due to 5 stale N2 exceptions in dependency_exceptions.tsv; fixed by 356f2c3c34d10f4744df70c02b63fe73a9af9e5e
Run 44358434701 cause: failed on 356f2c3c34d10f4744df70c02b63fe73a9af9e5e due to missing 'fixed by <sha>' suffix on the prior cause line; fixed by 276895b29b6af0c5e60363d7c01b33d00e1078ed
