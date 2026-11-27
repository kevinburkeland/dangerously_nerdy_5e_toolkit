# Cleanup slice 18 progress notes
Status: IN PROGRESS
Start heads: core 0af9c2b66e9216b04cbc1f688482e5675ffab6cd, ruleset 343f48dcacf42a7c339a76cab4cc225cecaa19b0, app d0ec577035660eda7054495ab5673be005bcbecc
Last pushed heads (CI green): core 9cf861c5de25b86228e452fc079bbadcad171d15, ruleset 996f39d5fc5f483ae5892573689e47149afb6144, app f2cb17bbaa7442265e78e247032d273c768dd9c3
Pins now: ruleset -> core ec9f155cbdce8315b0d84213842ddf8a22e46a66; app -> core ec9f155cbdce8315b0d84213842ddf8a22e46a66, ruleset 996f39d5fc5f483ae5892573689e47149afb6144
Fix ids: 1.1 1.2 1.3 1.4 1.5 2.1 2.2 2.3 3.1 3.2 4.1 4.2 5.1 5.2 6.1 6.2 6.3 7.1 7.2 7.3
Mutation ids: R1 R2 R3 R4 N1 X1 P1 P2 P3 S1 S2 D1 M1 M2 U1 U2

## Fix titles
Fix 1.1: Retire cs17
Fix 1.2: Characterization tests fail on every real error
Fix 1.3: The notes self-test names missing archive tags
Fix 1.4: Round-trip laws name the field that differs
Fix 1.5: A look-ahead run of the dependency check
Fix 2.1: What new homebrew records showed before the merge is recorded
Fix 2.2: No silent defaults for category, rarity or edition details
Fix 2.3: Every form and importer path writes the full record
Fix 3.1: One id per SRD item
Fix 3.2: The second-model bar matches by shape and names every exemption
Fix 4.1: The bundled monster and summon catalog is pinned
Fix 4.2: Stored and newly built monsters are pinned
Fix 5.1: One stat block model
Fix 5.2: Monster presentation is attached by id
Fix 6.1: One monster model
Fix 6.2: Old stored monsters load into the one model
Fix 6.3: No second model for a monster
Fix 7.1: A monster's missing facts stay unknown
Fix 7.2: An unreadable challenge rating is not CR 0
Fix 7.3: The named fixture changes for unknown facts

## Steps
- [x] Step 1 Retire, exception checks, tag hint, law messages, look-ahead: core 9cf861c5de25b86228e452fc079bbadcad171d15 run 45931531663, ruleset 188c03912b1d7d2a5313502885275f52275be3a2 run 45931534002, app 73cbecded5cd8084137b32bfaf89b8eb67ddfc14 run 45932116881
- [x] Step 2 New homebrew spells and items keep their data: ruleset 996f39d5fc5f483ae5892573689e47149afb6144 run 45935037900, app 72916e5d5f7260084f098a17e2584c1bf07726d7 run 45936166323
- [x] Step 3 One item id and a shape-based model bar: app f2cb17bbaa7442265e78e247032d273c768dd9c3 run 46043871170
- [ ] Step 4 Monster catalog, stored-format and construction pins
- [ ] Step 5 One stat block model
- [ ] Step 6 One monster model
- [ ] Step 7 Unknown monster facts stay unknown
- [ ] Step 8 Mutations and report

## Fix checklist
Fix 1.1 done: [Retire cs17] Retired 5 ruleset and 11 app cs17 mutation branches to archive tags with zero remaining across all three repos.
Fix 1.2 done: [Characterization tests fail on every real error] Added test/support/characterization_error_guard.dart and characterization_error_guard_test.dart, removed Multiple exceptions skips from dm_dashboard_screen_characterization_test.dart and party_room_screen_characterization_test.dart, widened 12 rich DM dashboard interaction viewports to 1600px, and used Zone print capture on the remaining overflowing tests.
Fix 1.3 done: [The notes self-test names missing archive tags] Added require_notes_commits_present and NS83 to scripts/test_check_notes_shas.sh so missing archive commits emit one hint line with the git fetch command before NS31, NS37, NS45, or NS73 runs.
Fix 1.4 done: [Round-trip laws name the field that differs] Added map_diff_helper.dart in vtt-ruleset-dnd5e and wired it into ruleset spell_law_test.dart and equipment_item_law_test.dart (test-only change; app did not re-pin).
Fix 1.5 done: [A look-ahead run of the dependency check] Ran 14-day dependency look-ahead across core, ruleset, and app with zero outdated or expiring dependencies.
Fix 2.1 done: [What new homebrew records showed before the merge is recorded] Inventoried all Spell/EquipmentItem construction sites under lib/, committed fixed form and importer inputs under test/fixtures/construction_paths/, and recorded pre-merge catalog views and class lists into expected_before_merge.json from commit f4456bfcd5a25fd98c0d3a344fb1f84d9fca7c78.
Fix 2.2 done: [No silent defaults for category, rarity or edition details] Removed constructor defaults on category, rarityTier, rules2014, and rules2024 in EquipmentItem and on rules2014 and rules2024 in Spell, added singleEdition factories sharing the single-edition hydration helpers with legacy fromMap in equipment_item.dart and spell.dart, and added 300-seed parity laws.
Fix 2.3 done: [Every form and importer path writes the full record] Wired all seven construction paths through singleEdition (removing the map-stripping hack in compendium_spell_parser.dart), updated remaining copy and sample construction sites (lowering character_sheet_tabs.dart big-file ceiling to 2393), and added test/services/homebrew/construction_paths_law_test.dart with an inventory bar and full pre-merge parity check.
Fix 3.1 done: [One id per SRD item] Deleted SrdEquipmentLibrary._withHyphenatedSlug so all bundled SRD items use canonical underscore slugs across both catalogs, added SrdEquipmentLibrary.normalizeLegacyBundledItemId for pre-Cleanup slice 18 stored records and ReferenceResolver fallback, stopped the three UI add flows from hyphenating item slugs (lowering character_sheet_tabs.dart big-file ceiling to 2391), rekeyed item_rules_view_golden.json in dedicated commit 607272c6cfcbd509122e0f75c09f214c90d25d05, and added test/models/srd_item_id_unification_law_test.dart.
Fix 3.2 done: [The second-model bar matches by shape and names every exemption] Replaced name/suffix filters in test/infrastructure/compliance/no_second_spell_or_item_model_bar_test.dart with shape-based matching over ruleset Spell and EquipmentItem fields (treating rules2014/rules2024 as model-specific and ignoring methods), added explicit per-class exemptions in kSecondModelExemptions, and verified controls for Incantation, SpellEntry, FooDetails, and reference holders.

## Mutation branches
None

## Red runs on main
cd1a0589d922aa2f06e814dbb267de14c9aa789b red run 45931535844

## Resets
None

## Next
Begin Step 4 (tests and fixtures only, zero lib/ edits): pin bundled monster and summon catalogs (Fix 4.1) and stored-format plus newly-built monster construction paths (Fix 4.2).

## Open issues and deviations
- Step 1 ruleset commit 188c03912b1d7d2a5313502885275f52275be3a2 changed only test files and the changelog, so the app did not re-pin ruleset in Step 1.
- Fix 1.2: TestWidgetsFlutterBinding resets debugPrint to debugPrintOverride right before dumping a Multiple exceptions batch, so Choice 2 captures dumped error records via ZoneSpecification(print: ...) inside CharacterizationErrorCapture.run rather than assigning debugPrint directly; this does not assign FlutterError.onError.
- Fix 2.1/2.3: lib/widgets/homebrew/equipment_builder_dialog.dart has no cost field and lib/widgets/homebrew/spell_builder_dialog.dart has no class-list selector, so cost and spell-class membership are covered through the parser, importer, and DTO paths without adding new UI fields to either form.
- Note from prompt cross-check: lib/infrastructure/dtos/spell_dto.dart exists, whereas no equipment_item_dto.dart file exists under lib/infrastructure/dtos/.
- Fix 3.1: Dedicated golden rekey commit 607272c6cfcbd509122e0f75c09f214c90d25d05 rekeyed 641 of 675 entries in test/fixtures/catalog_goldens/item_rules_view_golden.json with zero non-id value changes; ReferenceResolver also normalizes legacy hyphenated bundled equipment slugs so existing character inventory references remain valid while MagicItemLibrary.findById stays strict.
- Fix 3.2: Widening the shape-based bar with rules2014/rules2024 as model-specific matched three non-DTO classes in lib/ besides SpellDto: DmReferenceItem (lib/models/dm_screen_data.dart — DM rules reference card with List<String> rules2014/rules2024), SummonPreset (lib/models/srd_summons/summon_preset.dart — summon squad preset with display strings alongside spellId), and GlyphItemEntry (lib/models/glyph_gallery_data.dart — 29 illustrative Glyph Gallery entries, 7 not in MagicItemLibrary). All four rows are explicitly named with one-line reasons in kSecondModelExemptions.
Run 45931535844 cause: flutter analyze flagged deprecated package:flutter/material.dart import in test/support/characterization_error_guard_test.dart; fixed by 73cbecded5cd8084137b32bfaf89b8eb67ddfc14
