import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/domain/core_types.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/monster_codex_data.dart';
import 'package:dangerously_nerdy_5e_toolkit/services/importers/community_compendium_importer_service.dart';
import 'package:dangerously_nerdy_5e_toolkit/services/persistence/homebrew_persistence_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('CommunityCompendiumImporterService', () {
    late CommunityCompendiumImporterService importer;
    late HomebrewPersistenceService homebrewService;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      homebrewService = HomebrewPersistenceService();
      importer = CommunityCompendiumImporterService(homebrewService: homebrewService);
    });

    test('detects schema types accurately', () {
      expect(
        importer.detectType({'name': 'Shield', 'level': 1, 'school': 'A'}),
        equals(CompendiumImportType.spell),
      );
      expect(
        importer.detectType({'name': 'Orc', 'cr': '1/2', 'hp': {'average': 15}}),
        equals(CompendiumImportType.monster),
      );
      expect(
        importer.detectType({'name': 'Cloak of Protection', 'rarity': 'Uncommon', 'type': 'W'}),
        equals(CompendiumImportType.item),
      );
      expect(
        importer.detectType({'spell': [{'name': 'Light'}]}),
        equals(CompendiumImportType.bundle),
      );
    });

    test('imports bundle JSON, preserves dual rulesets, and synchronizes to compendium libraries', () async {
      final bundleJson = json.encode({
        'spell': [
          {
            'name': 'Healing Word',
            'source': 'PHB',
            'level': 1,
            'school': 'V',
            'time': [{'number': 1, 'unit': 'bonus'}],
            'range': {'type': 'point', 'distance': {'type': 'feet', 'amount': 60}},
            'components': {'v': true},
            'duration': [{'type': 'instant'}],
            'entries': ['A creature of your choice that you can see within range regains hit points equal to {@damage 1d4} + your spellcasting ability modifier.'],
          },
          {
            'name': 'Healing Word',
            'source': 'XPHB',
            'level': 1,
            'school': 'V',
            'time': [{'number': 1, 'unit': 'bonus'}],
            'range': {'type': 'point', 'distance': {'type': 'feet', 'amount': 60}},
            'components': {'v': true},
            'duration': [{'type': 'instant'}],
            'entries': ['A creature regains {@damage 2d4} + ability mod.'],
          }
        ],
        'monster': [
          {
            'name': 'Ancient Red Dragon',
            'source': 'MM',
            'size': ['G'],
            'type': 'dragon',
            'alignment': ['C', 'E'],
            'ac': [22],
            'hp': {'average': 546, 'formula': '28d20+152'},
            'cr': '24',
            'action': [
              {
                'name': 'Fire Breath',
                'entries': ['Deals {@damage 26d6|fire} damage.']
              }
            ]
          }
        ],
        'item': [
          {
            'name': 'Potion of Healing',
            'source': 'PHB',
            'type': 'P',
            'rarity': 'Common',
            'entries': ['You regain {@damage 2d4+2} hit points.']
          }
        ],
      });

      final result = await importer.importJsonString(bundleJson, persistAndSync: true);

      expect(result.isSuccess, isTrue);
      expect(result.spells.length, equals(2));
      expect(result.monsters.length, equals(1));
      expect(result.items.length, equals(1));

      // Check both ruleset versions co-exist without overwriting
      final spells = await homebrewService.loadCustomSpells();
      expect(spells.length, equals(2));
      expect(spells.any((s) => s.id.slug == 'healing-word' && s.id.ruleset == RulesetVersion.v2014), isTrue);
      expect(spells.any((s) => s.id.slug == 'healing-word' && s.id.ruleset == RulesetVersion.v2024), isTrue);

      // Check MonsterCodexLibrary was synced
      final customMonsters = MonsterCodexLibrary.homebrewMonsters;
      expect(customMonsters.any((m) => m.id == 'ancient-red-dragon'), isTrue);
    });

    test('handles empty or malformed JSON payloads safely', () async {
      final emptyResult = await importer.importJsonString('');
      expect(emptyResult.hasErrors, isTrue);
      expect(emptyResult.errors.first, contains('empty'));

      final invalidResult = await importer.importJsonString('not a valid json string');
      expect(invalidResult.hasErrors, isTrue);
      expect(invalidResult.errors.first, contains('JSON parse error'));
    });
  });
}
