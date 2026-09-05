import 'package:flutter_test/flutter_test.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/characters/srd_backgrounds_library.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/characters/srd_classes_library.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/characters/srd_equipment_library.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/characters/srd_feats_library.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/characters/srd_species_library.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/characters/subclass_spells_library.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/dm_screen_data.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/magic_items/magic_item_library.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/monster_codex_data.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/spellbook_data.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/srd_summons/srd_summons_library.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/tables/srd_loot_tables.dart';

void main() {
  group('SRD & Open Gaming License / CC-BY-4.0 Legality Audit', () {
    // List of known trademarked / Product Identity terms that are NOT in SRD 5.1/5.2
    const forbiddenProductIdentity = [
      'beholder',
      'mind flayer',
      'illithid',
      'carrion crawler',
      'displacer beast',
      'githyanki',
      'githzerai',
      'slaad',
      'umber hulk',
      'yuan-ti',
      'kuo-toa',
      'tasha\'s',
      'bigby\'s',
      'mordenkainen\'s',
      'leomund\'s',
      'drawmij\'s',
      'nystul\'s',
      'otiluke\'s',
      'otto\'s',
      'rary\'s',
      'tenser\'s',
      'evard\'s',
      'melf\'s',
    ];

    test('SRD summons library contains no WotC Product Identity terms in names or descriptions', () {
      final allPresets = SrdSummonsLibrary.allPresets;
      expect(allPresets, isNotEmpty);

      for (final preset in allPresets) {
        final lowerName = preset.name.toLowerCase();
        final lowerDesc = preset.description.toLowerCase();

        for (final forbidden in forbiddenProductIdentity) {
          expect(
            lowerName.contains(forbidden),
            isFalse,
            reason: 'Preset "${preset.name}" contains Product Identity term "$forbidden"',
          );
          expect(
            lowerDesc.contains(forbidden),
            isFalse,
            reason: 'Preset description in "${preset.name}" contains Product Identity term "$forbidden"',
          );
        }

        for (final statBlock in preset.statBlocks) {
          final lowerMonsterName = statBlock.name.toLowerCase();
          for (final forbidden in forbiddenProductIdentity) {
            expect(
              lowerMonsterName.contains(forbidden),
              isFalse,
              reason: 'Minion stat block "${statBlock.name}" contains Product Identity term "$forbidden"',
            );
          }
        }
      }
    });

    test('DM Reference Screen items contain no WotC Product Identity terms', () {
      const items = DmScreenLibrary.allItems;
      expect(items, isNotEmpty);

      for (final item in items) {
        final title = item.title.toLowerCase();
        final summary = item.summary.toLowerCase();
        final rules14 = item.rules2014.join(' ').toLowerCase();
        final rules24 = item.rules2024.join(' ').toLowerCase();
        final tags = item.tags.join(' ').toLowerCase();

        for (final forbidden in forbiddenProductIdentity) {
          expect(
            title.contains(forbidden),
            isFalse,
            reason: 'DM Reference item "${item.title}" contains Product Identity term "$forbidden"',
          );
          expect(
            summary.contains(forbidden),
            isFalse,
            reason: 'DM Reference summary for "${item.title}" contains Product Identity term "$forbidden"',
          );
          expect(
            rules14.contains(forbidden),
            isFalse,
            reason: 'DM Reference rules2014 in "${item.title}" contains Product Identity term "$forbidden"',
          );
          expect(
            rules24.contains(forbidden),
            isFalse,
            reason: 'DM Reference rules2024 in "${item.title}" contains Product Identity term "$forbidden"',
          );
          expect(
            tags.contains(forbidden),
            isFalse,
            reason: 'DM Reference tags in "${item.title}" contains Product Identity term "$forbidden"',
          );
        }
      }
    });

    test('SRD Loot Tables contain no WotC Product Identity terms', () {
      final allTables = [
        SrdLootTables.magicItemTableA,
        SrdLootTables.magicItemTableB,
        SrdLootTables.magicItemTableC,
        SrdLootTables.magicItemTableD,
        SrdLootTables.magicItemTableE,
        SrdLootTables.magicItemTableF,
        SrdLootTables.magicItemTableG,
        SrdLootTables.magicItemTableH,
        SrdLootTables.magicItemTableI,
        SrdLootTables.trinketsTable,
      ];

      for (final table in allTables) {
        for (final entry in table.entries) {
          final label = entry.label.toLowerCase();
          final desc = (entry.description ?? '').toLowerCase();

          for (final forbidden in forbiddenProductIdentity) {
            expect(
              label.contains(forbidden),
              isFalse,
              reason: 'Loot table "${table.name}" entry "${entry.label}" contains Product Identity term "$forbidden"',
            );
            expect(
              desc.contains(forbidden),
              isFalse,
              reason: 'Loot table "${table.name}" entry description in "${entry.label}" contains Product Identity term "$forbidden"',
            );
          }
        }
      }
    });

    test('Subclass Spells Library contains no WotC Product Identity terms', () {
      final warlockSpells = SubclassSpellsLibrary.getExpandedSpells('warlock', 'great_old_one');
      final fathomlessSpells = SubclassSpellsLibrary.getExpandedSpells('warlock', 'fathomless');

      final allSpellNames = {...warlockSpells, ...fathomlessSpells};
      for (final spell in allSpellNames) {
        final lower = spell.toLowerCase();
        for (final forbidden in forbiddenProductIdentity) {
          expect(
            lower.contains(forbidden),
            isFalse,
            reason: 'Subclass expanded spell "$spell" contains Product Identity term "$forbidden"',
          );
        }
      }
    });

    test('SRD Classes and Subclasses contain no WotC Product Identity terms', () {
      final classes = SrdClassesLibrary.allClasses;
      expect(classes, isNotEmpty);

      for (final cls in classes) {
        final lowerName = cls.name.toLowerCase();
        final lowerSlug = cls.id.slug.toLowerCase();

        for (final forbidden in forbiddenProductIdentity) {
          expect(
            lowerName.contains(forbidden),
            isFalse,
            reason: 'Class "${cls.name}" contains Product Identity term "$forbidden"',
          );
          expect(
            lowerSlug.contains(forbidden),
            isFalse,
            reason: 'Class slug "${cls.id.slug}" contains Product Identity term "$forbidden"',
          );
        }

        for (final sub in cls.subclasses) {
          final subName = sub.name.toLowerCase();
          final subSlug = sub.id.slug.toLowerCase();
          for (final forbidden in forbiddenProductIdentity) {
            expect(
              subName.contains(forbidden),
              isFalse,
              reason: 'Subclass "${sub.name}" contains Product Identity term "$forbidden"',
            );
            expect(
              subSlug.contains(forbidden),
              isFalse,
              reason: 'Subclass slug "${sub.id.slug}" contains Product Identity term "$forbidden"',
            );
          }
        }
      }
    });

    test('SRD Species Library contains no WotC Product Identity terms', () {
      final species = SrdSpeciesLibrary.allSpecies;
      expect(species, isNotEmpty);

      for (final sp in species) {
        final lowerName = sp.name.toLowerCase();
        final lowerTraits = sp.traitsMarkdown.toLowerCase();

        for (final forbidden in forbiddenProductIdentity) {
          expect(
            lowerName.contains(forbidden),
            isFalse,
            reason: 'Species "${sp.name}" contains Product Identity term "$forbidden"',
          );
          expect(
            lowerTraits.contains(forbidden),
            isFalse,
            reason: 'Species traits in "${sp.name}" contains Product Identity term "$forbidden"',
          );
        }
      }
    });

    test('SRD Feats Library contains no WotC Product Identity terms', () {
      final feats = SrdFeatsLibrary.allFeats;
      expect(feats, isNotEmpty);

      for (final feat in feats) {
        final lowerName = feat.name.toLowerCase();
        final lowerDesc = feat.descriptionMarkdown.toLowerCase();

        for (final forbidden in forbiddenProductIdentity) {
          expect(
            lowerName.contains(forbidden),
            isFalse,
            reason: 'Feat "${feat.name}" contains Product Identity term "$forbidden"',
          );
          expect(
            lowerDesc.contains(forbidden),
            isFalse,
            reason: 'Feat description in "${feat.name}" contains Product Identity term "$forbidden"',
          );
        }
      }
    });

    test('SRD Backgrounds Library contains no WotC Product Identity terms', () {
      final backgrounds = SrdBackgroundsLibrary.allBackgrounds;
      expect(backgrounds, isNotEmpty);

      for (final bg in backgrounds) {
        final lowerName = bg.name.toLowerCase();
        final lowerDesc = bg.descriptionMarkdown.toLowerCase();

        for (final forbidden in forbiddenProductIdentity) {
          expect(
            lowerName.contains(forbidden),
            isFalse,
            reason: 'Background "${bg.name}" contains Product Identity term "$forbidden"',
          );
          expect(
            lowerDesc.contains(forbidden),
            isFalse,
            reason: 'Background description in "${bg.name}" contains Product Identity term "$forbidden"',
          );
        }
      }
    });

    test('SRD Equipment Library contains no WotC Product Identity terms', () {
      final packages = SrdEquipmentLibrary.allPackages;
      expect(packages, isNotEmpty);

      for (final pkg in packages) {
        final lowerName = pkg.name.toLowerCase();
        final lowerSub = pkg.subtitle.toLowerCase();

        for (final forbidden in forbiddenProductIdentity) {
          expect(
            lowerName.contains(forbidden),
            isFalse,
            reason: 'Package "${pkg.name}" contains Product Identity term "$forbidden"',
          );
          expect(
            lowerSub.contains(forbidden),
            isFalse,
            reason: 'Package subtitle in "${pkg.name}" contains Product Identity term "$forbidden"',
          );
        }

        for (final item in pkg.items) {
          final itemName = item.itemRef.displayName.toLowerCase();
          for (final forbidden in forbiddenProductIdentity) {
            expect(
              itemName.contains(forbidden),
              isFalse,
              reason: 'Equipment item "$itemName" in "${pkg.name}" contains Product Identity term "$forbidden"',
            );
          }
        }
      }
    });

    test('Monster Codex Library contains no WotC Product Identity terms', () {
      final monsters = MonsterCodexLibrary.allMonsters;
      expect(monsters, isNotEmpty);

      for (final monster in monsters) {
        final lowerName = monster.name.toLowerCase();
        final lowerId = monster.id.toLowerCase();
        final lowerDiff = (monster.diffSummary ?? '').toLowerCase();

        for (final forbidden in forbiddenProductIdentity) {
          expect(
            lowerName.contains(forbidden),
            isFalse,
            reason: 'Monster "${monster.name}" contains Product Identity term "$forbidden"',
          );
          expect(
            lowerId.contains(forbidden),
            isFalse,
            reason: 'Monster ID "${monster.id}" contains Product Identity term "$forbidden"',
          );
          expect(
            lowerDiff.contains(forbidden),
            isFalse,
            reason: 'Monster diff in "${monster.name}" contains Product Identity term "$forbidden"',
          );
        }
      }
    });

    test('Spellbook Library contains no WotC Product Identity terms in spell names or IDs', () {
      final spells = SpellbookLibrary.allSpells;
      expect(spells, isNotEmpty);

      for (final spell in spells) {
        final lowerName = spell.name.toLowerCase();
        final lowerId = spell.id.toLowerCase();
        final lowerDiff = (spell.diffSummary ?? '').toLowerCase();

        for (final forbidden in forbiddenProductIdentity) {
          expect(
            lowerName.contains(forbidden),
            isFalse,
            reason: 'Spell "${spell.name}" contains Product Identity term "$forbidden"',
          );
          expect(
            lowerId.contains(forbidden),
            isFalse,
            reason: 'Spell ID "${spell.id}" contains Product Identity term "$forbidden"',
          );
          expect(
            lowerDiff.contains(forbidden),
            isFalse,
            reason: 'Spell diff summary in "${spell.name}" contains Product Identity term "$forbidden"',
          );
        }
      }
    });

    test('Magic Item Library and Crafting Rules contain no WotC Product Identity terms', () {
      final items = MagicItemLibrary.allItems;
      expect(items, isNotEmpty);

      for (final item in items) {
        final lowerName = item.name.toLowerCase();
        final lowerId = item.id.toLowerCase();
        final lowerDiff = (item.diffSummary ?? '').toLowerCase();

        for (final forbidden in forbiddenProductIdentity) {
          expect(
            lowerName.contains(forbidden),
            isFalse,
            reason: 'Item "${item.name}" contains Product Identity term "$forbidden"',
          );
          expect(
            lowerId.contains(forbidden),
            isFalse,
            reason: 'Item ID "${item.id}" contains Product Identity term "$forbidden"',
          );
          expect(
            lowerDiff.contains(forbidden),
            isFalse,
            reason: 'Item diff in "${item.name}" contains Product Identity term "$forbidden"',
          );
        }

        // Test Crafting Details for both 2014 and 2024 editions
        for (final edition in [DmRulesEdition.v2014, DmRulesEdition.v2024]) {
          final crafting = item.getCraftingDetails(edition);
          final textBlobs = [
            crafting.primaryTool.toLowerCase(),
            crafting.alternativeTools.join(' ').toLowerCase(),
            crafting.goldCostDisplay.toLowerCase(),
            crafting.craftingTime2024Display.toLowerCase(),
            crafting.craftingTime2014Display.toLowerCase(),
            crafting.exoticIngredientCr.toLowerCase(),
            crafting.bastionFacility.toLowerCase(),
            crafting.specialNotes.join(' ').toLowerCase(),
            crafting.quickSummary.toLowerCase(),
          ];

          for (final blob in textBlobs) {
            for (final forbidden in forbiddenProductIdentity) {
              expect(
                blob.contains(forbidden),
                isFalse,
                reason: 'Crafting details for "${item.name}" ($edition) contains Product Identity term "$forbidden" in text: "$blob"',
              );
            }
          }
        }
      }
    });

    test('All presets have non-empty attribution identifiers and valid minion configurations', () {
      for (final preset in SrdSummonsLibrary.allPresets) {
        expect(preset.id, isNotEmpty);
        expect(preset.name, isNotEmpty);
        expect(preset.defaultMinionCount, greaterThanOrEqualTo(1));
        expect(preset.levelDisplay, isNotEmpty);
        expect(preset.duration, isNotEmpty);
      }
    });
  });
}
