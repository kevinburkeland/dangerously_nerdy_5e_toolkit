# Cleanup slice 17 progress notes
Status: COMPLETE
Start heads: core 090797a2687d97eeebdbfae606f562520f139a3f, ruleset fa90649f62f7567a6c5c3deb388bf9b3d0e6b0dd, app 6fb83f24ffbc9a0efd44e182536a878d976d8136
Last pushed heads (CI green): core 0af9c2b66e9216b04cbc1f688482e5675ffab6cd, ruleset 343f48dcacf42a7c339a76cab4cc225cecaa19b0, app 29a21e09c2bd09a16175dd378009a6f652bb54fb
Pins now: ruleset -> core ec9f155cbdce8315b0d84213842ddf8a22e46a66; app -> core ec9f155cbdce8315b0d84213842ddf8a22e46a66, ruleset 343f48dcacf42a7c339a76cab4cc225cecaa19b0
Fix ids: 1.1 1.2 1.3 1.4 2.1 3.1 3.2 3.3 4.1 4.2 4.3 5.1 5.2 5.3 6.1 6.2 6.3 7.1 8.1 8.2
Mutation ids: R1 R2 R3 R4 R5 N1 X1 G1 C1 C2 S1 B1 Y1 H1 H2 H3

## Fix titles
Fix 1.1: Retire cs16
Fix 1.2: Every self-test case runs without a token and can run alone
Fix 1.3: Characterization tests unpack exception batches
Fix 1.4: A look-ahead run of the dependency check
Fix 2.1: Builder goldens pick spells with a high casting ability
Fix 3.1: Spell counts come from the SRD class tables in both editions
Fix 3.2: Homebrew caster classes use their own ability and progression
Fix 3.3: The named golden changes for spell counts
Fix 4.1: The bundled spell and item catalog is pinned
Fix 4.2: Stored homebrew, backup and bundle formats are pinned
Fix 4.3: The homebrew service's public behaviour is pinned
Fix 5.1: One item model
Fix 5.2: Item rules are data, not guesses from names
Fix 5.3: Old stored items load into the one model
Fix 6.1: One spell model
Fix 6.2: Old stored spells load into the one model
Fix 6.3: No second model for a spell or an item
Fix 7.1: Homebrew storage and mappers leave the service
Fix 8.1: Library sync, bundles and re-parsing leave the service
Fix 8.2: The homebrew service is a shell under 800 lines

## Steps
- [x] Step 1 Retire, self-test runner, exception batches, look-ahead: core 0af9c2b66e9216b04cbc1f688482e5675ffab6cd run 45885865321, ruleset 99adbcec6cc09d1f93f9481bae717613ded52a4d run 45885877003, app c6976b621ead2de9e0cb647fdd02cc2e502f425a run 45886234842
- [x] Step 2 Builder goldens with spell picks: app b26f30e68e9b2345310a4364ec7cec9d21b4de03 run 45888489939
- [x] Step 3 Spell counts and homebrew casters: ruleset 8e809ccf779f5749145109e4b6fbca8c0d577f41 run 45890258911, app d1bf0d9ea77077dab84278974aa49f2f08721cb7 run 45891772454
- [x] Step 4 Catalog, stored-format and homebrew pins: app e3f941e62313f623e7c7b508a3a706b20ec7e229 run 45893848977
- [x] Step 5 One item model: ruleset 8509bb5edece484f2649b0a2b511f30966a26dd6 run 45895492155, app 2078f70adfc7ccb8212ef65a564ca71620ca5cf7 run 45898829284
- [x] Step 6 One spell model: ruleset 343f48dcacf42a7c339a76cab4cc225cecaa19b0 run 45900271783, app a190f42b6405e11d1adfdc840b188de2a3694975 run 45902447861
- [x] Step 7 Homebrew storage and mappers out: app ec9f8ae93a433c8783faa8c6390ba7f7e7f50a1e run 45918879351
- [x] Step 8 Homebrew sync, bundles and re-parsing out: app 29a21e09c2bd09a16175dd378009a6f652bb54fb run 45920307100
- [x] Step 9 Mutations and report: app 239d3d970c90b87d8124c55991b4f1eb82c47c38 run 45920996031

## Fix checklist
Fix 1.1 done: [Retire cs16] Retired cs16 mutation branches across core, ruleset, and app to archive tags with none remaining.
Fix 1.2 done: [Every self-test case runs without a token and can run alone] Added per-case runner, continue-on-failure reporting, no-token stub for NS31/NS37/NS45/NS73, and cases NS79-NS82 in scripts/test_check_notes_shas.sh.
Fix 1.3 not done: [Characterization tests unpack exception batches] Stopped per prompt instruction because TestWidgetsFlutterBinding._runTest replaces _pendingExceptionDetails with a plain String holding no list field, and no_flutter_error_on_error_override_bar_test.dart forbids assigning FlutterError.onError in test files.
Fix 1.4 done: [A look-ahead run of the dependency check] Ran 14-day look-ahead in all three repos; upgraded dart_webrtc and webrtc_interface in app pubspec.lock so look-ahead passes.
Fix 2.1 done: [Builder goldens pick spells with a high casting ability] Added high-casting-ability spell-picking builds, spells-held guard, and named step-finder errors in builder_golden_harness.dart, character_builder_goldens_test.dart, and builder_goldens.json.
Fix 3.1 done: [Spell counts come from the SRD class tables in both editions] Aligned 2024 getLimitsForClass and prepared-limit messages with SRD 5.2.1 tables in spell_allocation_validator.dart and spells_step.dart, backed by srd_spell_counts_law_test.dart.
Fix 3.2 done: [Homebrew caster classes use their own ability and progression] Added CasterProgression to class_spellcaster_profile.dart, CharacterClass, and CompendiumClassParser, wired into builder_step_order.dart and level_up_wizard_controller.dart without fallback abilities, backed by homebrew_caster_progression_law_test.dart and homebrew_caster_progression_test.dart.
Fix 3.3 done: [The named golden changes for spell counts] Regenerated builder_goldens.json and level_up_goldens.json in a dedicated commit with only spell-count, count-text, and picked-spell changes.
Fix 4.1 done: [The bundled spell and item catalog is pinned] Added catalog_goldens_test.dart, catalog_golden_serializer.dart, and bundled spell, item, lookup, and item rules-view golden fixtures.
Fix 4.2 done: [Stored homebrew, backup and bundle formats are pinned] Added stored_format_load_law_test.dart and stored-format fixtures for homebrew spells and items, both bundle formats, app backup, DM backup, and expected loaded values.
Fix 4.3 done: [The homebrew service's public behaviour is pinned] Added homebrew_persistence_characterization_test.dart covering save, get, delete, sync, bundle export and import, clearing, re-parsing, and batch save across all homebrew kinds.
Fix 5.1 done: [One item model] Moved EquipmentItem with pure-Dart ItemCategory, ItemRarity, ItemEditionDetails, and edition fields into vtt_ruleset_dnd5e, migrated all bundled item catalogs and ItemPresentation registry via idempotent tool/migrate_bundled_items.py, and deleted the app item model and equipmentItemToMagicItem.
Fix 5.2 done: [Item rules are data, not guesses from names] Emitted item rules customProperties statically into bundled EquipmentItem data, deleted SrdEquipmentLibrary._mapItemToEquipmentItem, and added no_regex_item_rules_bar_test.dart.
Fix 5.3 done: [Old stored items load into the one model] Added pre-slice-17 EquipmentItem.fromMap legacy hydration backed by equipment_item_law_test.dart and verified stored_format_load_law_test.dart passes with unchanged fixtures.
Fix 6.1 done: [One spell model] Moved Spell with SpellEditionDetails, typed schoolEnum (preserving unknown homebrew schools), and edition fields into vtt_ruleset_dnd5e, migrated all bundled spells via idempotent tool/migrate_bundled_spells.py, and deleted SpellItem, app SpellEditionDetails, and spellToSpellItem.
Fix 6.2 done: [Old stored spells load into the one model] Added pre-slice-17 Spell.fromMap legacy hydration backed by spell_law_test.dart and verified stored_format_load_law_test.dart passes with unchanged fixtures.
Fix 6.3 done: [No second model for a spell or an item] Added no_second_spell_or_item_model_bar_test.dart reading canonical Spell and EquipmentItem fields from vtt_ruleset_dnd5e via package_config.json.
Fix 7.1 done: [Homebrew storage and mappers leave the service] Extracted HomebrewCategoryStore<T>, HomebrewRawPayloadStore, and HomebrewCompendiumMappers into lib/services/persistence/homebrew/, shrinking homebrew_persistence_service.dart from 3,849 to 2,815 lines with every public signature unchanged and verified by Fix 4.2, Fix 4.3, 44 homebrew tests, legacy load law, and annotated moves check.
Fix 8.1 done: [Library sync, bundles and re-parsing leave the service] Extracted HomebrewLibrarySync, HomebrewBundleIo, HomebrewClearing, HomebrewReparser (with ReparseResult re-exported from homebrew_persistence_service.dart), and dedicated HomebrewRemoteBatchSaver into lib/services/persistence/homebrew/ with zero behaviour change.
Fix 8.2 done: [The homebrew service is a shell under 800 lines] Shrunk homebrew_persistence_service.dart from 2,815 to 758 lines (all eight extracted modules 242-762 lines, zero part/part of), removed homebrew_persistence_service.dart from big_file_ratchet_test.dart (29 files left), verified moves check (0 unannotated), reachability law, layer table, import bars, all 43 homebrew tests, legacy load law, and build_web.sh.

## Mutation branches
mutation/cs17-r1 c7f70e05715b46924f35c05fea7580b9040e8d2c
mutation/cs17-r2 e3afc68b2ef95e9bb47f2b9a5bbebf0d8f058902
mutation/cs17-r3 16dea9991f66e6d0df28eb00cfb12067072fb9e9
mutation/cs17-r4 bed42240f0ef3215b83abf2363c75bf0ae8e742a
mutation/cs17-r5 68ca58c16bf9d7bde3205346802e9403e62cd3d9
mutation/cs17-n1 8e4a38c09c82aa8a31adf9d8e5bd04b7c26874f7
mutation/cs17-x1 b4a12f55ec33a02f370924fd197d131a817d23e8
mutation/cs17-g1 f0fa8a30d8e8cacf079d2863d707bcf0346a443b
mutation/cs17-c1 1e4e09bc282b6da84df8d74ca7b65accd5771d36
mutation/cs17-c2 6d71190c4ce9b2a034685604f916b41c6a80e162
mutation/cs17-s1 646d6e58d69e5e3c5904ea89608920ef2f030e8f
mutation/cs17-b1 b2d82cb9fd13ac9e988a1c2f2736a60a96a77c79
mutation/cs17-y1 67ff28d83972977883d0f86982f496cf4c190e45
mutation/cs17-h1 a7da43a906e917a58e61b8a3276b0b9d87d588ec
mutation/cs17-h2 a72a82a67f5f5a00099beb91ac5a949fc5a5bbe6
mutation/cs17-h3 8b35f8bb61ddc7eaa8db6eca8736cd03c15dcc13

## Red runs on main
55ac01c0068b82addb63f880371add21e9a9e8ef red run 45897009974
bfd9c9b7a324777a92448f18dedfbf892ea2f0b6 red run 45897875536
f6a2c64aa796e22b3de8807f9a6ac207826b4fde red run 45901741063
f6334cabbd83eebcb370fc2074a5dd753fe2cb94 red run 45903082894

## Resets
None

## Next
None — Cleanup slice 17 is COMPLETE.

## Open issues and deviations
- Step 9 mutation X1: Fix 1.3 was stopped per the prompt instruction because TestWidgetsFlutterBinding._runTest replaces _pendingExceptionDetails with a plain String and FlutterError.onError cannot be overridden in test files; consequently no Fix 1.3 unpacking helper or mixed-batch control exists, so mutation/cs17-x1 carries a clean comment-only commit with its Deviation recorded rather than a fabricated catch.
- Fix 1.3 stopped per prompt instruction ("if the batch can't be unpacked, say why and stop this fix"): in Flutter's TestWidgetsFlutterBinding._runTest (binding.dart), a second FlutterError.onError overwrites _pendingExceptionDetails with a FlutterErrorDetails whose exception is a plain String ('Multiple exceptions (N) were detected...') with no list field, and test/infrastructure/compliance/no_flutter_error_on_error_override_bar_test.dart forbids assigning FlutterError.onError in any file under test/.
- Fix 1.4: on 2026-11-26, the 14-day look-ahead (2026-12-10) flagged dart_webrtc (1.8.2 -> 1.9.0) and webrtc_interface (1.5.1 -> 1.6.0) as newly behind in the app; upgraded both in pubspec.lock.
Run 45897009974 cause: docs_truth_test.dart found stale item type name in codebase_map.md and dynamic_ratchet_test.dart required lowering kDynamicCeiling from 1036 to 1035; fixed by bfd9c9b7a324777a92448f18dedfbf892ea2f0b6
Run 45897875536 cause: NS73 caught an undisclosed earlier red run before Step 5 progress notes were updated; fixed by 0fda247c82fca61d2cf6bdcdac3dc129d409a7ab
Run 45901741063 cause: sibling_repo_reference_source_bar_test.dart flagged sibling fallback path in no_second_spell_or_item_model_bar_test.dart; fixed by 9bf34d048da3fcf4f94e16d3f4f4bc7fa821ef40
Run 45903082894 cause: docs_truth_test.dart DT2 flagged not-yet-created homebrew persistence directory path in Next section; fixed by f1d5e4a753ce61be02ac775eefbce07e5da69a76
