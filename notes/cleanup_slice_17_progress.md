# Cleanup slice 17 progress notes
Status: IN PROGRESS
Start heads: core 090797a2687d97eeebdbfae606f562520f139a3f, ruleset fa90649f62f7567a6c5c3deb388bf9b3d0e6b0dd, app 6fb83f24ffbc9a0efd44e182536a878d976d8136
Last pushed heads (CI green): core 0af9c2b66e9216b04cbc1f688482e5675ffab6cd, ruleset 8509bb5edece484f2649b0a2b511f30966a26dd6, app 2078f70adfc7ccb8212ef65a564ca71620ca5cf7
Pins now: ruleset -> core ec9f155cbdce8315b0d84213842ddf8a22e46a66; app -> core ec9f155cbdce8315b0d84213842ddf8a22e46a66, ruleset 8509bb5edece484f2649b0a2b511f30966a26dd6
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
- [ ] Step 6 One spell model
- [ ] Step 7 Homebrew storage and mappers out
- [ ] Step 8 Homebrew sync, bundles and re-parsing out
- [ ] Step 9 Mutations and report

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

## Mutation branches
None

## Red runs on main
55ac01c0068b82addb63f880371add21e9a9e8ef red run 45897009974
bfd9c9b7a324777a92448f18dedfbf892ea2f0b6 red run 45897875536

## Resets
None

## Next
Implement Step 6 (One spell model): push unified Spell with SpellEditionDetails and pre-slice-17 fromMap compatibility in vtt-ruleset-dnd5e, re-pin ruleset in the app, migrate bundled spell catalogs via an idempotent generator, delete SpellItem and spellToSpellItem, and add the no-second-model source bar.

## Open issues and deviations
- Fix 1.3 stopped per prompt instruction ("if the batch can't be unpacked, say why and stop this fix"): in Flutter's TestWidgetsFlutterBinding._runTest (binding.dart), a second FlutterError.onError overwrites _pendingExceptionDetails with a FlutterErrorDetails whose exception is a plain String ('Multiple exceptions (N) were detected...') with no list field, and test/infrastructure/compliance/no_flutter_error_on_error_override_bar_test.dart forbids assigning FlutterError.onError in any file under test/.
- Fix 1.4: on 2026-11-26, the 14-day look-ahead (2026-12-10) flagged dart_webrtc (1.8.2 -> 1.9.0) and webrtc_interface (1.5.1 -> 1.6.0) as newly behind in the app; upgraded both in pubspec.lock.
Run 45897009974 cause: docs_truth_test.dart found stale item type name in codebase_map.md and dynamic_ratchet_test.dart required lowering kDynamicCeiling from 1036 to 1035; fixed by bfd9c9b7a324777a92448f18dedfbf892ea2f0b6
Run 45897875536 cause: NS73 caught an undisclosed earlier red run before Step 5 progress notes were updated; fixed by 0fda247c82fca61d2cf6bdcdac3dc129d409a7ab
