import 'package:flutter_test/flutter_test.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/srd_summons/srd_summons_library.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/dm_screen_data.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/spellbook_data.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/magic_items/magic_item_library.dart';

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
