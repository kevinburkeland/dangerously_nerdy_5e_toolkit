import 'package:flutter_test/flutter_test.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/characters/srd_classes_library.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/characters/srd_backgrounds_library.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/characters/srd_species_library.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/monster_codex_data.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/magic_items/magic_item_library.dart';

void main() {
  group('SRD Legal Compliance & Product Identity Invariant Suite', () {
    final piPattern = RegExp(
      r"\b(Eberron|Faer[uû]n|Toril|Ravnica|Krynn|Athas|Barovia|Spelljammer|Planescape|Waterdeep|Baldur'?s Gate|Neverwinter|Harper|Harpers|Zhentarim|Lord'?s Alliance|Emerald Enclave|Order of the Gauntlet|Dragonmark|Dragonmarks|Dragonmarked|Warforged|Kalashtar|Shifter|Changeling|Simic Hybrid|Vedalken|Githyanki|Githzerai|Beholder|Mind Flayer|Illithid|Gith|Displacer Beast|Gauth|Carrion Crawler|Umber Hulk|Slaad|Yuan-ti|Beholderkin|Bigby|Tasha|Mordenkainen|Otiluke|Drawmij|Rary|Leomund|Evard|Tenser|Aganazzar|Melf|Elminster|Drizzt|Strahd|Acererak)\b",
      caseSensitive: false,
    );

    test('SrdClassesLibrary.allOptions contains zero Product Identity tokens', () {
      final options = SrdClassesLibrary.allOptions;
      expect(options, isNotEmpty);

      for (final opt in options) {
        expect(
          piPattern.firstMatch(opt.name),
          isNull,
          reason: 'Class feature option name "${opt.name}" violates Product Identity rules.',
        );
        expect(
          piPattern.firstMatch(opt.descriptionMarkdown),
          isNull,
          reason: 'Class feature option "${opt.name}" description violates Product Identity rules.',
        );
      }
    });

    test('SrdBackgroundsLibrary.allBackgrounds contains zero Product Identity tokens', () {
      final backgrounds = SrdBackgroundsLibrary.allBackgrounds;
      expect(backgrounds, isNotEmpty);

      for (final bg in backgrounds) {
        expect(
          piPattern.firstMatch(bg.name),
          isNull,
          reason: 'Background name "${bg.name}" violates Product Identity rules.',
        );
        expect(
          piPattern.firstMatch(bg.descriptionMarkdown),
          isNull,
          reason: 'Background "${bg.name}" descriptionMarkdown violates Product Identity rules.',
        );
      }
    });

    test('SrdSpeciesLibrary.allSpecies contains zero Product Identity tokens', () {
      final speciesList = SrdSpeciesLibrary.allSpecies;
      expect(speciesList, isNotEmpty);

      for (final species in speciesList) {
        expect(
          piPattern.firstMatch(species.name),
          isNull,
          reason: 'Species name "${species.name}" violates Product Identity rules.',
        );
        expect(
          piPattern.firstMatch(species.traitsMarkdown),
          isNull,
          reason: 'Species "${species.name}" traitsMarkdown violates Product Identity rules.',
        );
      }
    });

    test('MonsterCodexLibrary.allMonsters contains zero Product Identity tokens', () {
      final monsters = MonsterCodexLibrary.allMonsters;
      expect(monsters, isNotEmpty);

      for (final monster in monsters) {
        expect(
          piPattern.firstMatch(monster.name),
          isNull,
          reason: 'Monster name "${monster.name}" violates Product Identity rules.',
        );
        if (monster.name2014 != null) {
          expect(
            piPattern.firstMatch(monster.name2014!),
            isNull,
            reason: 'Monster name2014 "${monster.name2014}" violates Product Identity rules.',
          );
        }
        if (monster.name2024 != null) {
          expect(
            piPattern.firstMatch(monster.name2024!),
            isNull,
            reason: 'Monster name2024 "${monster.name2024}" violates Product Identity rules.',
          );
        }

        // Check statBlock2014 traits
        for (final trait in monster.statBlock2014.traits) {
          expect(
            piPattern.firstMatch(trait.name),
            isNull,
            reason: 'Monster "${monster.name}" (2014) trait name "${trait.name}" violates Product Identity rules.',
          );
          expect(
            piPattern.firstMatch(trait.description),
            isNull,
            reason: 'Monster "${monster.name}" (2014) trait "${trait.name}" description violates Product Identity rules.',
          );
        }

        // Check statBlock2024 traits
        for (final trait in monster.statBlock2024.traits) {
          expect(
            piPattern.firstMatch(trait.name),
            isNull,
            reason: 'Monster "${monster.name}" (2024) trait name "${trait.name}" violates Product Identity rules.',
          );
          expect(
            piPattern.firstMatch(trait.description),
            isNull,
            reason: 'Monster "${monster.name}" (2024) trait "${trait.name}" description violates Product Identity rules.',
          );
        }
      }
    });

    test('MagicItemLibrary.allItems contains zero Product Identity tokens', () {
      final items = MagicItemLibrary.allItems;
      expect(items, isNotEmpty);

      for (final item in items) {
        expect(
          piPattern.firstMatch(item.name),
          isNull,
          reason: 'Magic item name "${item.name}" violates Product Identity rules.',
        );
        if (item.name2014 != null) {
          expect(
            piPattern.firstMatch(item.name2014!),
            isNull,
            reason: 'Magic item name2014 "${item.name2014}" violates Product Identity rules.',
          );
        }
        if (item.name2024 != null) {
          expect(
            piPattern.firstMatch(item.name2024!),
            isNull,
            reason: 'Magic item name2024 "${item.name2024}" violates Product Identity rules.',
          );
        }
        expect(
          piPattern.firstMatch(item.rules2014.description),
          isNull,
          reason: 'Magic item "${item.name}" (2014) description violates Product Identity rules.',
        );
        expect(
          piPattern.firstMatch(item.rules2024.description),
          isNull,
          reason: 'Magic item "${item.name}" (2024) description violates Product Identity rules.',
        );
        expect(
          piPattern.firstMatch(item.rules2014.summary),
          isNull,
          reason: 'Magic item "${item.name}" (2014) summary violates Product Identity rules.',
        );
        expect(
          piPattern.firstMatch(item.rules2024.summary),
          isNull,
          reason: 'Magic item "${item.name}" (2024) summary violates Product Identity rules.',
        );
      }
    });
  });
}
