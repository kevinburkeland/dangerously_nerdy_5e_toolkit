import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/app_settings.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/domain/core_types.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/domain/spell_monster_equipment.dart';
import 'package:dangerously_nerdy_5e_toolkit/services/persistence/app_backup_service.dart';
import 'package:dangerously_nerdy_5e_toolkit/services/persistence/homebrew_persistence_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AppBackupService Homebrew & Compendium Integration Tests', () {
    late AppBackupService backupService;
    late HomebrewPersistenceService homebrewService;

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      backupService = AppBackupService();
      homebrewService = HomebrewPersistenceService();
    });

    test('exports full backup containing homebrew spells, monsters, and items', () async {
      // 1. Save sample homebrew entities
      const spell = Spell(
        id: EntityId(slug: 'hellfire-blast', ruleset: RulesetVersion.homebrew),
        name: 'Hellfire Blast',
        level: 2,
        school: 'Evocation',
        castingTime: CastingTime(cost: 1, actionType: ActionType.action),
        duration: SpellDuration(type: DurationType.instantaneous),
        range: '60 feet',
        components: SpellComponents(v: true, s: true),
        descriptionMarkdown: 'Blasts with hellfire.',
        damageMath: [EvaluationMath(diceFormula: '3d10', damageType: DamageType.fire)],
      );
      await homebrewService.saveCustomSpell(spell);

      const monster = Monster(
        id: EntityId(slug: 'hell-hound-alpha', ruleset: RulesetVersion.homebrew),
        name: 'Hell Hound Alpha',
        size: 'Large',
        monsterType: 'Fiend',
        alignment: 'Lawful Evil',
        armorClass: 16,
        hitPoints: 68,
        hitDieFormula: '8d10 + 24',
        challengeRating: '4',
        actionsMarkdown: '**Fire Breath**: 6d6 fire damage.',
      );
      await homebrewService.saveCustomMonster(monster);

      const item = EquipmentItem(
        id: EntityId(slug: 'flame-tongue-greatsword', ruleset: RulesetVersion.homebrew),
        name: 'Flame Tongue Greatsword',
        itemType: 'Weapon',
        rarity: 'Rare',
        requiresAttunement: true,
        descriptionMarkdown: 'Deals extra 2d6 fire damage on hit.',
      );
      await homebrewService.saveCustomItem(item);

      // 2. Export full backup
      final backupJson = await backupService.exportFullBackupJson(const AppSettings());
      expect(backupJson, isNotEmpty);

      final decoded = json.decode(backupJson) as Map<String, dynamic>;
      expect(decoded['schemaVersion'], equals(3));
      expect((decoded['customSpells'] as List).length, equals(1));
      expect((decoded['customMonsters'] as List).length, equals(1));
      expect((decoded['customItems'] as List).length, equals(1));
      expect(decoded['customSpells'][0]['name'], equals('Hellfire Blast'));
      expect(decoded['customMonsters'][0]['name'], equals('Hell Hound Alpha'));
      expect(decoded['customItems'][0]['name'], equals('Flame Tongue Greatsword'));
    });

    test('imports full backup restoring all homebrew entities to storage', () async {
      final sampleBackup = {
        'schemaVersion': 3,
        'exportedAt': DateTime.now().toIso8601String(),
        'settings': {},
        'dicePresets': [],
        'dprProfiles': [],
        'customSpells': [
          {
            'id': {'slug': 'astral-smite', 'ruleset': 'homebrew'},
            'name': 'Astral Smite',
            'level': 3,
            'school': 'Evocation',
            'castingTime': {'cost': 1, 'actionType': 'bonusAction'},
            'duration': {'type': 'instantaneous', 'durationSeconds': 0, 'requiresConcentration': false},
            'range': 'Self',
            'components': {'v': true, 's': false, 'm': false, 'materialCostGp': 0, 'consumesMaterial': false},
            'descriptionMarkdown': 'Extra radiant damage.',
            'damageMath': [
              {'diceFormula': '4d8', 'damageType': 'radiant'}
            ],
            'relatedEntityRefs': [],
            'customProperties': {},
          }
        ],
        'customMonsters': [
          {
            'id': {'slug': 'astral-dreadnought-spawn', 'ruleset': 'homebrew'},
            'name': 'Astral Dreadnought Spawn',
            'size': 'Gargantuan',
            'monsterType': 'Monstrosity',
            'alignment': 'Unaligned',
            'armorClass': 18,
            'hitPoints': 200,
            'hitDieFormula': '18d20 + 90',
            'challengeRating': '14',
            'actionsMarkdown': '**Bite**: +12 to hit, 4d10+7 force.',
            'innateSpells': [],
            'attackMath': [],
            'customProperties': {},
          }
        ],
        'customItems': [
          {
            'id': {'slug': 'astral-shard', 'ruleset': 'homebrew'},
            'name': 'Astral Shard',
            'itemType': 'Wondrous Item',
            'rarity': 'Rare',
            'requiresAttunement': true,
            'descriptionMarkdown': 'Grants teleportation on spellcast.',
            'customProperties': {},
          }
        ],
      };

      final result = await backupService.importFullBackupJson(json.encode(sampleBackup));

      expect(result.success, isTrue);
      expect(result.restoredHomebrewSpellsCount, equals(1));
      expect(result.restoredHomebrewMonstersCount, equals(1));
      expect(result.restoredHomebrewItemsCount, equals(1));

      // Verify entities are now readable from HomebrewPersistenceService
      final spells = await homebrewService.loadCustomSpells();
      final monsters = await homebrewService.loadCustomMonsters();
      final items = await homebrewService.loadCustomItems();

      expect(spells.first.name, equals('Astral Smite'));
      expect(monsters.first.name, equals('Astral Dreadnought Spawn'));
      expect(items.first.name, equals('Astral Shard'));
    });
  });
}
