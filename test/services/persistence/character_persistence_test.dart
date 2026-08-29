import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/domain/character_models.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/domain/core_types.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/domain/entity_reference.dart';
import 'package:dangerously_nerdy_5e_toolkit/services/persistence/character_persistence_service.dart';
import 'package:dangerously_nerdy_5e_toolkit/services/rules/character_factory.dart';

Character _createTestHero(String slug, String name) {
  return CharacterFactory.createLevel1Character(
    CharacterCreationRequest(
      characterName: name,
      ruleset: RulesetVersion.v2024,
      speciesRef: const EntityReference(
        refType: EntityType.species,
        slug: 'human',
        displayName: 'Human',
      ),
      backgroundRef: const EntityReference(
        refType: EntityType.background,
        slug: 'soldier',
        displayName: 'Soldier',
      ),
      startingClassSlug: 'fighter',
      startingClassDisplayName: 'Fighter',
      startingClassHitDie: 'd10',
      baseScores: const AbilityScores.standardArray(),
      bonusScores: const AbilityScores(strength: 2, constitution: 1),
    ),
  ).copyWith(
    id: EntityId(slug: slug, ruleset: RulesetVersion.v2024),
    name: name,
  );
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('CharacterPersistenceService Tests', () {
    test('loadCharacters returns empty list when SharedPreferences is empty', () async {
      final service = CharacterPersistenceService();
      final characters = await service.loadCharacters();
      expect(characters.isEmpty, isTrue);
    });

    test('saveCharacter adds a new character and persists', () async {
      final service = CharacterPersistenceService();
      final customChar = _createTestHero('gideon-dawnbringer', 'Gideon Dawnbringer');

      final updated = await service.saveCharacter(customChar);
      expect(updated.length, 1);
      expect(updated.any((c) => c.name == 'Gideon Dawnbringer'), isTrue);

      final loaded = await service.loadCharacters();
      expect(loaded.length, 1);
      expect(loaded.any((c) => c.name == 'Gideon Dawnbringer'), isTrue);
    });

    test('deleteCharacter removes character by slug and persists', () async {
      final service = CharacterPersistenceService();
      final hero1 = _createTestHero('hero-1', 'Hero One');
      final hero2 = _createTestHero('hero-2', 'Hero Two');

      await service.saveRoster([hero1, hero2]);
      final initial = await service.loadCharacters();
      expect(initial.length, 2);
      expect(initial.any((c) => c.id.slug == 'hero-1'), isTrue);

      final updated = await service.deleteCharacter('hero-1');
      expect(updated.length, 1);
      expect(updated.any((c) => c.id.slug == 'hero-1'), isFalse);
      expect(updated.any((c) => c.id.slug == 'hero-2'), isTrue);

      final loaded = await service.loadCharacters();
      expect(loaded.length, 1);
      expect(loaded.any((c) => c.id.slug == 'hero-1'), isFalse);
    });

    test('saveActiveCharacterId and loadActiveCharacterId roundtrips correctly', () async {
      final service = CharacterPersistenceService();
      expect(await service.loadActiveCharacterId(), isNull);

      await service.saveActiveCharacterId('custom-hero-slug');
      expect(await service.loadActiveCharacterId(), 'custom-hero-slug');
    });
  });
}
