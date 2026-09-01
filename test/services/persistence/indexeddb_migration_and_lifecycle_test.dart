import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/domain/character_models.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/domain/core_types.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/domain/entity_reference.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/domain/spell_monster_equipment.dart';
import 'package:dangerously_nerdy_5e_toolkit/services/persistence/app_database_service.dart';
import 'package:dangerously_nerdy_5e_toolkit/services/persistence/character_persistence_service.dart';
import 'package:dangerously_nerdy_5e_toolkit/services/persistence/debounced_storage_service.dart';
import 'package:dangerously_nerdy_5e_toolkit/services/persistence/homebrew_persistence_service.dart';

void main() {
  group('IndexedDB / Database Persistence & Web Lifecycle Tests', () {
    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      await AppDatabaseService.instance.resetForTesting();
    });

    test('AppDatabaseService stores, retrieves, and deletes values with in-memory fallback', () async {
      final db = AppDatabaseService.instance;
      await db.put(AppDatabaseService.boxCharacters, 'test_key', {'name': 'Grog'});

      final value = db.get(AppDatabaseService.boxCharacters, 'test_key');
      expect(value, equals({'name': 'Grog'}));

      final keys = db.getKeys(AppDatabaseService.boxCharacters);
      expect(keys, contains('test_key'));

      await db.delete(AppDatabaseService.boxCharacters, 'test_key');
      expect(db.get(AppDatabaseService.boxCharacters, 'test_key'), isNull);
    });

    test('CharacterPersistenceService migrates legacy SharedPreferences and persists to database', () async {
      const legacyChar = Character(
        id: EntityId(slug: 'legacy-hero', ruleset: RulesetVersion.v2024),
        name: 'Legacy Hero',
        speciesRef: EntityReference(refType: EntityType.species, slug: 'human', displayName: 'Human'),
        baseScores: AbilityScores(strength: 10, dexterity: 10, constitution: 10, intelligence: 10, wisdom: 10, charisma: 10),
        progression: CharacterProgression(classes: []),
        resources: CharacterResourcePool(),
      );

      // Seed SharedPreferences with legacy character
      SharedPreferences.setMockInitialValues({
        'saved_characters_roster_v1': json.encode([legacyChar.toMap()]),
      });

      final charService = CharacterPersistenceService();
      final loaded = await charService.loadCharacters();
      expect(loaded.length, equals(1));
      expect(loaded.first.id.slug, equals('legacy-hero'));

      // Save a new character
      const newChar = Character(
        id: EntityId(slug: 'new-mage', ruleset: RulesetVersion.v2024),
        name: 'New Mage',
        speciesRef: EntityReference(refType: EntityType.species, slug: 'elf', displayName: 'Elf'),
        baseScores: AbilityScores(strength: 10, dexterity: 10, constitution: 10, intelligence: 10, wisdom: 10, charisma: 10),
        progression: CharacterProgression(classes: []),
        resources: CharacterResourcePool(),
      );
      await charService.saveCharacter(newChar);

      final updatedRoster = await charService.loadCharacters();
      expect(updatedRoster.map((c) => c.id.slug), containsAll(['legacy-hero', 'new-mage']));

      // Delete a character
      await charService.deleteCharacter('legacy-hero');
      final finalRoster = await charService.loadCharacters();
      expect(finalRoster.map((c) => c.id.slug), contains('new-mage'));
      expect(finalRoster.map((c) => c.id.slug), isNot(contains('legacy-hero')));
    });

    test('HomebrewPersistenceService stores and loads custom spells seamlessly in database', () async {
      final homebrewService = HomebrewPersistenceService();
      const customSpell = Spell(
        id: EntityId(slug: 'hellish-rebuke-plus', ruleset: RulesetVersion.homebrew),
        name: 'Hellish Rebuke Plus',
        level: 2,
        school: 'Evocation',
        castingTime: CastingTime(cost: 1, actionType: ActionType.reaction),
        range: '60 ft',
        duration: SpellDuration(type: DurationType.instantaneous),
        components: SpellComponents(v: true, s: true),
        descriptionMarkdown: 'Blasts back with double fire.',
      );

      await homebrewService.saveCustomSpell(
        customSpell,
        rawPayload: {'source': '5eTools', 'name': 'Hellish Rebuke Plus'},
      );

      final loadedSpells = await homebrewService.loadCustomSpells();
      expect(loadedSpells.length, equals(1));
      expect(loadedSpells.first.id.slug, equals('hellish-rebuke-plus'));

      final rawPayloads = await homebrewService.loadRawPayloads(EntityType.spell);
      expect(rawPayloads.length, equals(1));
      expect(rawPayloads.first['source'], equals('5eTools'));

      await homebrewService.deleteCustomSpell('hellish-rebuke-plus');
      final afterDelete = await homebrewService.loadCustomSpells();
      expect(afterDelete, isEmpty);
    });

    test('DebouncedStorageService.flushAllSync executes pending tasks synchronously before runtime death', () async {
      final storage = DebouncedStorageService();
      bool taskExecuted = false;

      storage.scheduleWrite(
        'rapid_character_hp_edit',
        () async {
          taskExecuted = true;
        },
        duration: const Duration(seconds: 10),
      );

      expect(storage.hasPendingTasks, isTrue);
      expect(taskExecuted, isFalse);

      // Trigger synchronous unload flush
      storage.flushAllSync();

      expect(storage.hasPendingTasks, isFalse);
      // Allow microtask resolution
      await Future<void>.delayed(const Duration(milliseconds: 10));
      expect(taskExecuted, isTrue);
    });
  });
}
