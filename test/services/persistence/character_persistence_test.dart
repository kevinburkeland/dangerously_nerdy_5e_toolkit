import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/domain/core_types.dart';
import 'package:dangerously_nerdy_5e_toolkit/services/persistence/character_persistence_service.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('CharacterPersistenceService Tests', () {
    test('Default starter roster provides standard heroes', () {
      final roster = CharacterPersistenceService.getDefaultStarterRoster();
      expect(roster.length, 3);
      expect(roster.any((c) => c.name == 'Valeros Ironclad'), isTrue);
      expect(roster.any((c) => c.name == 'Eldrin Shadowbane'), isTrue);
      expect(roster.any((c) => c.name == 'Lyra Sunseeker'), isTrue);
    });

    test('loadCharacters returns starter roster if SharedPreferences is empty', () async {
      final service = CharacterPersistenceService();
      final characters = await service.loadCharacters();
      expect(characters.length, 3);
      expect(characters.first.name, 'Valeros Ironclad');
    });

    test('saveCharacter adds a new character and persists', () async {
      final service = CharacterPersistenceService();
      final starter = CharacterPersistenceService.getDefaultStarterRoster().first;
      final customChar = starter.copyWith(
        id: const EntityId(slug: 'gideon-dawnbringer', ruleset: RulesetVersion.v2024),
        name: 'Gideon Dawnbringer',
      );

      final updated = await service.saveCharacter(customChar);
      expect(updated.length, 4);
      expect(updated.any((c) => c.name == 'Gideon Dawnbringer'), isTrue);

      final loaded = await service.loadCharacters();
      expect(loaded.length, 4);
      expect(loaded.any((c) => c.name == 'Gideon Dawnbringer'), isTrue);
    });

    test('deleteCharacter removes character by slug and persists', () async {
      final service = CharacterPersistenceService();
      final initial = await service.loadCharacters();
      expect(initial.any((c) => c.id.slug == 'lyra-sunseeker'), isTrue);

      final updated = await service.deleteCharacter('lyra-sunseeker');
      expect(updated.length, 2);
      expect(updated.any((c) => c.id.slug == 'lyra-sunseeker'), isFalse);

      final loaded = await service.loadCharacters();
      expect(loaded.length, 2);
      expect(loaded.any((c) => c.id.slug == 'lyra-sunseeker'), isFalse);
    });

    test('saveActiveCharacterId and loadActiveCharacterId roundtrips correctly', () async {
      final service = CharacterPersistenceService();
      expect(await service.loadActiveCharacterId(), isNull);

      await service.saveActiveCharacterId('eldrin-shadowbane');
      expect(await service.loadActiveCharacterId(), 'eldrin-shadowbane');
    });
  });
}
