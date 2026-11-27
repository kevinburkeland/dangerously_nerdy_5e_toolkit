# Cleanup slice 18 progress notes
Status: COMPLETE
Start heads: core 0af9c2b66e9216b04cbc1f688482e5675ffab6cd, ruleset 343f48dcacf42a7c339a76cab4cc225cecaa19b0, app d0ec577035660eda7054495ab5673be005bcbecc
Last pushed heads (CI green): core 9cf861c5de25b86228e452fc079bbadcad171d15, ruleset 2f8a864345cd8c7ee38f3e00ca2d154c3df22e61, app c4be9d372d41ea7d375b4836514ff1fd902ad1ac
Pins now: ruleset -> core ec9f155cbdce8315b0d84213842ddf8a22e46a66; app -> core ec9f155cbdce8315b0d84213842ddf8a22e46a66, ruleset 2f8a864345cd8c7ee38f3e00ca2d154c3df22e61
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
- [x] Step 4 Monster catalog, stored-format and construction pins: app aabb4298707beb86958802d8effa0d3cd7a4c9f3 run 46046586130
- [x] Step 5 One stat block model: ruleset 4250e200118ed79810841e91036f00a7a789fcb8 run 46048859007, app 54a194ddff2e095753a0db37426cee8b8ab0b4fd run 46050233827
- [x] Step 6 One monster model: ruleset 6cf3557d466c81aff13e8b2ce244b5f9795a2250 run 46053205742, app 0d3d1dff19adff9c7dee833ea0dadcb5ecd1a7e2 run 46057237191
- [x] Step 7 Unknown monster facts stay unknown: ruleset 2f8a864345cd8c7ee38f3e00ca2d154c3df22e61 run 46059406094, app 3c08450dbe98f16a4946b1e056743de79e51eb34 run 46061722419
- [x] Step 8 Mutations and report: app c4be9d372d41ea7d375b4836514ff1fd902ad1ac run 46062601522

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
Fix 4.1 done: [The bundled monster and summon catalog is pinned] Added test/support/monster_golden_serializer.dart, opt-in test/support/generate_step4_monster_fixtures.dart, test/fixtures/catalog_goldens/monster_catalog_golden.json (343 bundled monsters across both editions, 15 summon presets, 87 summon stat blocks) and monster_lookups_golden.json, and field-by-field guard test/infrastructure/catalog/monster_catalog_goldens_test.dart with zero lib/ changes.
Fix 4.2 done: [Stored and newly built monsters are pinned] Added 12 stored monster fixtures (string/map/list customProperties, markdown traits/actions, minimal id+name, individual missing F-16 fields, and unreadable CR) across stored JSON, both bundle exports, app backup, and DM backup under test/fixtures/stored_formats/ with monster_stored_format_load_law_test.dart, plus fixed construction-path inputs (4 paths, 14 cases) under test/fixtures/construction_paths/monsters/ with monster_construction_paths_law_test.dart and inventory bar.
Fix 5.1 done: [One stat block model] Moved MinionStatBlock, CreatureTrait, CreatureAction, and SummonCategory into ruleset MonsterStatBlock (monster_stat_block.dart) with toMap/fromMap/copyWith/equality/hashCode and 500-seed round-trip laws, migrated all 13 bundled bestiary and summon preset files via idempotent tool/migrate_bundled_stat_blocks.py (zero non-class/non-presentation diffs, byte-identical second run), deleted app MinionStatBlock, lowered six big-file ceilings, and verified all Step 4, arena, DPR, and UI goldens pass unedited.
Fix 5.2 done: [Monster presentation is attached by id] Extracted all 397 bundled stat block accentColor values into lib/models/monster_codex/monster_presentation_registry.dart (kBundledMonsterAccentArgb) and moved the homebrew creature-type accent fallback rule from MonsterHomebrewExt.toMinionStatBlock into resolveMonsterAccentArgb with Step 4 presentation goldens passing unedited.
Fix 6.1 done: [One monster model] Unified MonsterItem into ruleset Monster (holding statBlock2014 and statBlock2024, deriving shared combat facts from statBlock2024 while emitting all 13 legacy map keys in toMap, plus Monster.singleEdition and 500-seed round-trip laws), migrated all 5 bundled bestiary files via idempotent tool/migrate_bundled_monsters.py (zero other diffs, byte-identical second run), deleted app MonsterItem and MonsterHomebrewExt, lowered five bestiary big-file ceilings and kDynamicCeiling to 1025, and verified all Step 4, slice 17, arena, DPR, character map, and UI goldens pass unedited.
Fix 6.2 done: [Old stored monsters load into the one model] Implemented pre-Cleanup slice 18 legacy hydration in ruleset Monster.fromMap via hydrateLegacyMonsterStatBlock with a 200-seed ruleset parity law against the deleted app converter copied from Step 5 head 591b12489f9eadfb411d5f434923b882b5b71241, and verified monster_stored_format_load_law_test.dart passes with unchanged fixtures.
Fix 6.3 done: [No second model for a monster] Widened test/infrastructure/compliance/no_second_spell_or_item_model_bar_test.dart to ruleset Monster and MonsterStatBlock with zero new exemption rows, refactored MinionStats (lib/models/domain/minion_instance.dart) to hold MonsterStatBlock by reference, and verified the bar failed on Step 5 head (flagging MonsterItem and MinionStats) and passes on Step 6 head with all controls green.
Fix 7.1 done: [A monster's missing facts stay unknown] Made the seven F-16 monster facts (size, type, alignment, AC, HP, hit dice, CR) nullable with zero invented defaults in ruleset Monster, MonsterStatBlock, hydrateLegacyMonsterStatBlock, and fromMap (backed by 200-seed unknown-facts laws), removed invented defaults in app forms/parsers/importers, updated every lib/ reader (em-dash in displays, pre-match arena refusal naming missing facts, null DPR and unknown DPR sorted last), lowered two big-file ceilings, and added bundled_monster_facts_completeness_test.dart, arena_missing_facts_refusal_test.dart, and no_null_monster_fact_defaults_bar_test.dart.
Fix 7.2 done: [An unreadable challenge rating is not CR 0] Made crValue and challengeRatingValue return parseChallengeRating directly (null when unreadable, zero ?? 0 fallbacks), kept unreadable CR text as written without a forced CR prefix, restricted unknown CR to All CR only sorted last in both CR sorts (ties by name) with XP unknown, and added monster_codex_unknown_cr_test.dart and no_cr_zero_fallback_bar_test.dart.
Fix 7.3 done: [The named fixture changes for unknown facts] Updated only test/fixtures/stored_formats/expected_loaded_monsters.json and test/fixtures/construction_paths/monsters/expected_monster_paths.json in dedicated commit 3c08450dbe98f16a4946b1e056743de79e51eb34 with zero unexpected field diffs and zero changes to bundled monster catalog goldens, arena/DPR goldens, slice 17 goldens, or legacy load law.

## Mutation branches
mutation/cs18-r1 601533e3af299dd5bd61e45a8bac2f73e75e95e8
mutation/cs18-r2 930b0d4d78ca871a1fc103fd669308b33e70e2de
mutation/cs18-r3 b1a0baf6cb87ff722d071eb5a723290408a07e3e
mutation/cs18-r4 b4e8bdb9d66870ce89d5bf82be0daf65d783c4e0
mutation/cs18-n1 34198e1868b4439b080fe050c8442f8543cd67fa
mutation/cs18-x1 536f4444b95e5e4d87856b264ec33b99e592bddf
mutation/cs18-p1 ea8cd2553e3cacbae1fea667a62180f650efc45b
mutation/cs18-p2 156c3033daf86fd46077f23ac50a4840f88ded24
mutation/cs18-p3 cb23b116d62d90b5777170426f9cae228fc90fb3
mutation/cs18-s1 9de41c7544b61f23fdd846cdc0799d9bfd33c8a9
mutation/cs18-s2 9d3bd3d6c23b450db056160b08bd02fbbc84249c
mutation/cs18-d1 aabca37230fbfb1b5f09c6afa0527caaa6c6946c
mutation/cs18-m1 98d9db5d50b3b4e67f5e87d719e36320025e6173
mutation/cs18-m2 10851093973d6ea476607bbded4f9f1154796744
mutation/cs18-u1 ea4acae88fa4aee9782c891b2232caa169cfd65b
mutation/cs18-u2 6a34010eb53dcd1229e95e9c9af8faee2e707ea5

## Red runs on main
cd1a0589d922aa2f06e814dbb267de14c9aa789b red run 45931535844
6f9f098bce85c4a974a23c257dda98c9ccf874fa red run 46052955247
101158ef2968a0f3b4fa9b7088d2a2fd122aa61d red run 46055346755
4b24d418772a7d6b8b5da3e0d733995d48407462 red run 46056344144

## Resets
None

## Next
None (Cleanup slice 18 COMPLETE).

## Open issues and deviations
- Step 8 Mutation P1 deviation: lib/widgets/homebrew/spell_builder_dialog.dart has no class-list selector, so mutation/cs18-p1 drops the range field (passing 'Self') instead of classes; Fix 2.3 path law fails naming lib/widgets/homebrew/spell_builder_dialog.dart, the input id, and range.
- Step 8 Mutation M1 deviation: Monster.fromMap resides in vtt-ruleset-dnd5e while the mutation table assigns M1 to the app repo, so mutation/cs18-m1 strips list-typed customProperties['resist'] in HomebrewPersistenceService before calling Monster.fromMap; Fix 4.2 stored-format law fails naming hb-full-props-maps-lists and damageResistances.
- Fix 7.1 out-of-scope defaults left for a later slice: ruleset monster_stat_block.dart defaults six ability scores to 10 (lines 187-192, 359-364), speed to '30 ft.' (lines 186, 358), senses to 'passive Perception 10' (lines 199, 371), and languages to '—' (lines 200, 372); ruleset monster.dart hydrateLegacyMonsterStatBlock defaults ability scores to 10 (lines 57-58) and senses to 'passive Perception 10' (line 335); ruleset character_models.dart defaults character languages to ['Common'] (lines 875, 935, 1545).
- Fix 7.1 bundled completeness guard: all 343 bundled monsters and 87 summon stat blocks state sizeDisplay, typeDisplay, alignment, ac, maxHp, and crDisplay; hitDice is omitted only on the five Animate Objects fixed-HP constructs (ao_tiny through ao_huge), which have fixed HP with no hit dice formula in SRD 5.1/5.2.1.
- Fix 6.3: On Step 5 head, the widened shape bar flagged both MonsterItem (deleted in Step 6) and MinionStats in lib/models/domain/minion_instance.dart (which duplicated ac, maxHp, strScore, and dexScore). MinionStats was refactored to hold MonsterStatBlock by reference instead of adding a new exemption row.
- Step 1 ruleset commit 188c03912b1d7d2a5313502885275f52275be3a2 changed only test files and the changelog, so the app did not re-pin ruleset in Step 1.
- Fix 1.2: TestWidgetsFlutterBinding resets debugPrint to debugPrintOverride right before dumping a Multiple exceptions batch, so Choice 2 captures dumped error records via ZoneSpecification(print: ...) inside CharacterizationErrorCapture.run rather than assigning debugPrint directly; this does not assign FlutterError.onError.
- Fix 2.1/2.3: lib/widgets/homebrew/equipment_builder_dialog.dart has no cost field and lib/widgets/homebrew/spell_builder_dialog.dart has no class-list selector, so cost and spell-class membership are covered through the parser, importer, and DTO paths without adding new UI fields to either form.
- Note from prompt cross-check: lib/infrastructure/dtos/spell_dto.dart exists, whereas no equipment_item_dto.dart file exists under lib/infrastructure/dtos/.
- Fix 3.1: Dedicated golden rekey commit 607272c6cfcbd509122e0f75c09f214c90d25d05 rekeyed 641 of 675 entries in test/fixtures/catalog_goldens/item_rules_view_golden.json with zero non-id value changes; ReferenceResolver also normalizes legacy hyphenated bundled equipment slugs so existing character inventory references remain valid while MagicItemLibrary.findById stays strict.
- Fix 3.2: Widening the shape-based bar with rules2014/rules2024 as model-specific matched three non-DTO classes in lib/ besides SpellDto: DmReferenceItem (lib/models/dm_screen_data.dart — DM rules reference card with List<String> rules2014/rules2024), SummonPreset (lib/models/srd_summons/summon_preset.dart — summon squad preset with display strings alongside spellId), and GlyphItemEntry (lib/models/glyph_gallery_data.dart — 29 illustrative Glyph Gallery entries, 7 not in MagicItemLibrary). All four rows are explicitly named with one-line reasons in kSecondModelExemptions.
Run 45931535844 cause: flutter analyze flagged deprecated package:flutter/material.dart import in test/support/characterization_error_guard_test.dart; fixed by 73cbecded5cd8084137b32bfaf89b8eb67ddfc14
Run 46052955247 cause: ruleset dart analyze --fatal-infos flagged one unnecessary_import in monster.dart and three prefer_const_constructors in monster_law_test.dart; fixed by 6cf3557d466c81aff13e8b2ce244b5f9795a2250
Run 46055346755 cause: dynamic_ratchet_test.dart required lowering kDynamicCeiling to 1025 and check_test_names.py flagged three test names accidentally renamed during MonsterItem sweep; fixed by 4b24d418772a7d6b8b5da3e0d733995d48407462
Run 46056344144 cause: NS73 flagged undisclosed Step 6 ruleset and app red runs before notes update; fixed by 9180ff8327356b16ac2b9f38ac2528e61b16ec6a
