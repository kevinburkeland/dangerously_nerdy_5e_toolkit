# Cleanup slice 19 progress notes
Status: IN PROGRESS
Start heads: core 9cf861c5de25b86228e452fc079bbadcad171d15, ruleset 2f8a864345cd8c7ee38f3e00ca2d154c3df22e61, app 3f11442cb157e9c5d5cbbe966539093164a587da
Last pushed heads (CI green): core 325b293fd087a129db847cbd7dc77e052578e58b, ruleset e6abe9435125e1fdcccd6f72e4aa498afd90ab16, app db1dce6e62651525b8bec502bb14a4ba7d2be6d1
Pins now: ruleset -> core ec9f155cbdce8315b0d84213842ddf8a22e46a66; app -> core ec9f155cbdce8315b0d84213842ddf8a22e46a66, ruleset 2f8a864345cd8c7ee38f3e00ca2d154c3df22e61
Fix ids: 1.1 1.2 1.3 2.1 2.2 2.3 2.4 2.5 3.1 3.2 3.3 3.4 3.5 4.1 4.2 4.3 5.1 5.2 5.3 5.4 6.1 6.2 6.3 7.1 7.2 7.3 7.4 7.5
Mutation ids: N1 W1 B1 S1 S2 G1 T1 K1 Y1 D1 H1 I1 V1 A1 W2 P1

## Fix titles
Fix 1.1: Retire cs18
Fix 1.2: The notes self-test hint names a commit no tag holds
Fix 1.3: A look-ahead run of the dependency check
Fix 2.1: The notes checks leave the DCO job
Fix 2.2: The live notes check runs once and the workflow proves it
Fix 2.3: The mobile build jobs leave the workflow
Fix 2.4: CI writes the next shard weights file
Fix 2.5: Test files go to shards by measured time
Fix 3.1: A notes-only commit picks its scope from a green parent
Fix 3.2: Heavy jobs skip only on a notes-only scope
Fix 3.3: Tests that read repo text carry a tag and still run
Fix 3.4: One final job fails on an unexpected skip
Fix 3.5: The notes check verifies a notes-only run's parent
Fix 4.1: What spells and items showed before the merge is recorded for SRD names
Fix 4.2: A spell with no class list gets its classes by name again
Fix 4.3: The second-model bar matches field name and type
Fix 5.1: The dead dev dependency and the misplaced hive line go
Fix 5.2: No dart:html under lib
Fix 5.3: One opaque id helper
Fix 5.4: A declared package is used
Fix 6.1: Every existing Hive box opens with hive_ce
Fix 6.2: Hive is replaced by hive_ce
Fix 6.3: The arena combatant holds plain immutable collections
Fix 7.1: Crash reporting and Play Integrity leave the app
Fix 7.2: The android and linux folders leave
Fix 7.3: A web-only bar
Fix 7.4: The privacy policy says what the web app contacts
Fix 7.5: The privacy popup matches the policy

## Steps
- [x] Step 1 Retire, notes hint, look-ahead: core 7a106702af112e61e5e6e9ad1f2ef4bf401ecb81 run 46082752195, ruleset 9bb753a0201d89d6bff6c882c784270ff68225a2 run 46082754336, app e5a34edc56f67660829d4bfbb42cd220f07df09f run 46082756920
- [x] Step 2 Notes job, mobile jobs out, shards by time: app e416071b06b15f003f64e3f2d6303065744ed788 run 46102810606
- [x] Step 3 Notes-only commits run only what can change: app e639397e1c4f812e4aba1d5ab52adda0c0f327dc run 46106268842
- [x] Step 4 SRD-named spells keep their classes, type-aware model bar: app 24b45b6f49f5156afbce08053a69b29405c83a05 run 46110050813
- [x] Step 5 Dead dependency, dart:html, one id helper, used-package rule: core 325b293fd087a129db847cbd7dc77e052578e58b run 46112853313, ruleset e6abe9435125e1fdcccd6f72e4aa498afd90ab16 run 46112861156, app db1dce6e62651525b8bec502bb14a4ba7d2be6d1 run 46114001601
- [ ] Step 6 hive_ce and plain arena collections
- [ ] Step 7 Web only
- [ ] Step 8 Mutations and report

## Fix checklist
Fix 1.1 done: [Retire cs18] Retired 0 core, 4 ruleset, and 12 app cs18 mutation branches into archive tags and patch files.
Fix 1.2 done: [The notes self-test hint names a commit no tag holds] Updated require_notes_commits_present in scripts/test_check_notes_shas.sh to distinguish missing archive tags from unreachable commits and added self-test case NS84.
Fix 1.3 done: [A look-ahead run of the dependency check] Ran 14-day look-ahead dependency check in all three repos and upgraded flutter_webrtc to 1.7.0 in pubspec.yaml and pubspec.lock.
Fix 2.1 done: [The notes checks leave the DCO job] Moved the notes self-test, sibling-repo clone, and live notes SHA check out of dco into notes-shas in release.yml and cloned sibling repos at most once in test_check_notes_shas.sh.
Fix 2.2 done: [The live notes check runs once and the workflow proves it] Removed NS73 from test_check_notes_shas.sh and added scripts/check_notes_workflow.py and scripts/test_check_notes_workflow.sh wired into tests-complete.
Fix 2.3 done: [The mobile build jobs leave the workflow] Removed build-android, build-ios, and build_mobile from .github/workflows/release.yml.
Fix 2.4 done: [CI writes the next shard weights file] Added JSON file reporter uploads per shard, weights-from-reports and refresh-weights in scripts/test_shard.py, and shard-weights artifact upload in tests-complete.
Fix 2.5 done: [Test files go to shards by measured time] Committed test/shard_weights.json from the Fix 2.4 green run and updated scripts/test_shard.py and scripts/test_test_shard.sh for greedy weight-balanced sharding, validation, drift warnings, and 300-seed law.
Fix 3.1 done: [A notes-only commit picks its scope from a green parent] Added scripts/ci_scope.py and scripts/test_ci_scope.sh with 200-seed law and Decide CI scope job in release.yml.
Fix 3.2 done: [Heavy jobs skip only on a notes-only scope] Gated heavy jobs in release.yml on scope=full while running dco and notes-shas on every push.
Fix 3.3 done: [Tests that read repo text carry a tag and still run] Added dart_test.yaml, tagged 15 repo-text test files, added repo_text_tag_bar_test.dart, and added Notes text checks job in release.yml.
Fix 3.4 done: [One final job fails on an unexpected skip] Added scripts/ci_result.py, scripts/test_ci_result.sh, ci-result job in release.yml, and ci-result needs check in scripts/check_notes_workflow.py.
Fix 3.5 done: [The notes check verifies a notes-only run's parent] Updated AGENTS.md and GEMINI.md green-main rule and extended scripts/check_notes_shas.py and scripts/test_check_notes_shas.sh (NS85-NS88) to verify notes-only parent runs.
Fix 4.1 done: [What spells and items showed before the merge is recorded for SRD names] Added test/support/seeded_spell_item_input_generator.dart and recorded test/fixtures/construction_paths/expected_before_merge_generated.json at f4456bfcd5a25fd98c0d3a344fb1f84d9fca7c78.
Fix 4.2 done: [A spell with no class list gets its classes by name again] Added HomebrewLibrarySync.enrichSpellsWithSrdClasses in lib/services/persistence/homebrew/homebrew_library_sync.dart and test/services/homebrew/srd_named_homebrew_spell_differential_law_test.dart.
Fix 4.3 done: [The second-model bar matches field name and type] Upgraded test/infrastructure/compliance/no_second_spell_or_item_model_bar_test.dart to match field name and normalized type, removed SummonPreset and GlyphItemEntry, kept SpellDto and _kSharedCombatAndRollerFields with typed reasons.
Fix 5.1 done: [The dead dev dependency and the misplaced hive line go] Removed unused mutation_test and redundant direct hive from pubspec.yaml, updated 6 Dart test files to package:hive_flutter/hive_flutter.dart, and removed hive D4 exception row.
Fix 5.2 done: [No dart:html under lib] Replaced dart:html in http_fetcher_web.dart and web_lifecycle_web.dart with package:web and dart:js_interop, added no_dart_html_source_bar_test.dart, http_fetcher_status_test.dart, and web_http_fetcher_chrome_test.dart (TestOn browser).
Fix 5.3 done: [One opaque id helper] Added pure-Dart lib/domain/opaque_id.dart (CryptoRNG Uuid v4), added opaque_id_test.dart and opaque_id_source_bar_test.dart, and migrated UUID and weak timestamp/random id sites under lib/.
Fix 5.4 done: [A declared package is used] Added rule D7 (every declared package must be used) to scripts/check_dependencies.py with DC77-DC85 self-tests and synced byte-identical scripts across core, ruleset, and app.

## Mutation branches
None

## Red runs on main
c647df2189075d97ce2a20cf92c4ba32cb876905 red run 46101601044
049d0abe73b60f4aa2a1987b10dec681f88de541 red run 46103352911
70dbc44588d5c8ac65825bf7cd3b90385526492b red run 46103846241
da1072bafe5f9e9403c81a75ad502ac843c3f24e red run 46105210208
05898dca8072924ce8089e02e6506695391478c3 red run 46109192904
07cfc7d2b3f6a3c85ee20599e4c1a6c63c44f292 red run 46112621262
b01ffa6256ad99130623b77196d0bbb4b981afa4 red run 46112631848
1f98b8cd7e264ad825663bb08c98363fdf292b2f cancelled run 46112638581
4cf45242d487d3c0fbae252f6b86003e3c87b036 red run 46112869852

## Resets
None

## Next
Begin Step 6: migrate from hive/hive_flutter to hive_ce/hive_ce_flutter and replace fast_immutable_collections in ArenaCombatant with plain unmodifiable collections.

## Open issues and deviations
Factual check on B1: on today's repos, commit 59d7178dea6527a18a2cac3b7fe0f110fb93717a is reachable from origin/main and archive tags in vtt-engine-core, so a fresh full clone of all three repos with archive tags fetched passes NS31; NS84 therefore uses a throwaway core repo with an archive tag that lacks that commit to exercise the unreachable-commit branch.
Run 46101601044 cause: actions/download-artifact pinned to v7.0.0 failed dependency check A1 (newest is v8.0.2); fixed by 2b2ad2fe902fc8081e860977bfacd63e6700a511
Run 46103352911 cause: Next section named uncreated CI scope script path before Step 3, failing docs_truth_test.dart; fixed by c1df2b272871a80dab381150542f00bdaf5c3348
Run 46103846241 cause: cause line for the earlier red run still named uncreated CI scope script path; fixed by 89be5b52f67744f938b718b944308f863d2f1d48
Run 46105210208 cause: test_ci_scope.sh case (f) missed mkdir -p notes after checkout main on runner; fixed by b687f42b650e5e8bf25b2b1670cbfc2c11279641
Run 46109192904 cause: unnecessary import of vtt_engine_core in differential law failed flutter analyze; fixed by c14e1e6267155d068b9238daacda4b216b75ff1f
Factual check on E1: DmReferenceItem in lib/models/dm_screen_data.dart still matches 3 EquipmentItem fields by both name and type (String cost, String cost2014, String cost2024), not only rules2014/rules2024; kept its existing exemption row with those 3 fields named so the bar stays green.
Run 46112621262 cause: DC77 in test_check_dependencies.sh lacked fake_async mock HTTP fixtures in core; fixed by 325b293fd087a129db847cbd7dc77e052578e58b
Run 46112631848 cause: DC77 in test_check_dependencies.sh lacked fake_async mock HTTP fixtures in ruleset; fixed by e6abe9435125e1fdcccd6f72e4aa498afd90ab16
Run 46112638581 cause: superseded by DC77 HTTP fixture fix; fixed by 4cf45242d487d3c0fbae252f6b86003e3c87b036
Run 46112869852 cause: web_http_fetcher_chrome_test.dart lacked TestOn browser, opaque_id.dart in utils violated domain-to-utils layer rule, codebase_map.md and big_file_ratchet needed refresh, and earlier red runs needed disclosure; fixed by c3dea98049f2e41d77ea314f95ce435df1d264a1
