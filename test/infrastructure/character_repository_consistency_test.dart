import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/domain/core_types.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/domain/entity_reference.dart';
import 'package:dangerously_nerdy_5e_toolkit/domain/models/character_models.dart';
import 'package:dangerously_nerdy_5e_toolkit/domain/models/party_purse.dart';
import 'package:dangerously_nerdy_5e_toolkit/infrastructure/repositories/local_character_repository.dart';
import 'package:dangerously_nerdy_5e_toolkit/services/persistence/character_persistence_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final heroA = Character(
    id: const EntityId(slug: 'aragorn', ruleset: RulesetVersion.v2024),
    name: 'Aragorn',
    speciesRef: const EntityReference<DomainEntity>(
      refType: EntityType.species,
      slug: 'human',
      displayName: 'Human',
    ),
    progression: const CharacterProgression(
      classes: [
        ClassLevelProgression(
          classRef: EntityReference<DomainEntity>(
            refType: EntityType.classDefinition,
            slug: 'ranger',
            displayName: 'Ranger',
          ),
          level: 5,
          hitDie: 'd10',
          isStartingClass: true,
        ),
      ],
    ),
    baseScores: const AbilityScores(
      strength: 16,
      dexterity: 14,
      constitution: 16,
      intelligence: 10,
      wisdom: 14,
      charisma: 14,
    ),
    resources: const CharacterResourcePool(
      currentHp: 44,
      tempHp: 7,
    ),
    purse: const PartyPurse().setCoins(gp: 120, sp: 50, nodeId: 'init'),
  );

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('LocalCharacterRepository & CharacterPersistenceService Consistency', () {
    test('Saving via CharacterPersistenceService is immediately visible to LocalCharacterRepository', () async {
      final persistence = CharacterPersistenceService();
      final repository = LocalCharacterRepository();

      await persistence.saveCharacter(heroA);

      final loaded = await repository.getCharacter(heroA.id.slug);
      expect(loaded, isNotNull);
      expect(loaded!.name, 'Aragorn');
      expect(loaded.resources.currentHp, 44);
      expect(loaded.resources.tempHp, 7);
      expect(loaded.purse.gp, 120);
      expect(loaded.purse.sp, 50);
    });

    test('Saving via LocalCharacterRepository is immediately visible to CharacterPersistenceService', () async {
      final persistence = CharacterPersistenceService();
      final repository = LocalCharacterRepository();

      final updatedHero = heroA.copyWith(
        resources: heroA.resources.copyWith(currentHp: 28, tempHp: 0),
        purse: heroA.purse.setCoins(gp: 45, nodeId: 'local'),
      );

      await repository.saveRoster([updatedHero]);

      final loaded = await persistence.getCharacter(heroA.id.slug);
      expect(loaded, isNotNull);
      expect(loaded!.resources.currentHp, 28);
      expect(loaded.resources.tempHp, 0);
      expect(loaded.purse.gp, 45);
    });

    test('Zero stale cache split-brain across multiple interleaved writes', () async {
      final persistence = CharacterPersistenceService();
      final repository = LocalCharacterRepository();

      // Initial save
      await persistence.saveCharacter(heroA);

      // Read from repo
      var char = await repository.getCharacter(heroA.id.slug);
      expect(char!.resources.currentHp, 44);

      // Update via persistence (simulate user damage)
      final damaged = heroA.copyWith(
        resources: heroA.resources.copyWith(currentHp: 19),
      );
      await persistence.saveCharacter(damaged);

      // Read again from repo without stale cache returning 44
      char = await repository.getCharacter(heroA.id.slug);
      expect(char!.resources.currentHp, 19, reason: 'Repository must not cache stale character objects');
    });
  });
}
