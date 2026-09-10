import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:dangerously_nerdy_5e_toolkit/domain/models/campaign_profile.dart';
import 'package:dangerously_nerdy_5e_toolkit/infrastructure/dtos/character_dto.dart';
import 'package:dangerously_nerdy_5e_toolkit/infrastructure/repositories/local_campaign_repository.dart';
import 'package:dangerously_nerdy_5e_toolkit/infrastructure/repositories/local_character_repository.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/domain/character_models.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/domain/core_types.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/domain/entity_reference.dart';
import 'package:dangerously_nerdy_5e_toolkit/services/app_services.dart';
import 'package:dangerously_nerdy_5e_toolkit/services/persistence/app_database_service.dart';

class _RecordingDatabaseService extends AppDatabaseService {
  final Map<String, Map<String, dynamic>> writtenData = {};
  int putCalls = 0;
  int deleteCalls = 0;

  _RecordingDatabaseService() : super.custom();

  @override
  Future<void> put(String boxName, String key, dynamic value) async {
    putCalls++;
    writtenData.putIfAbsent(boxName, () => {})[key] = value;
  }

  @override
  dynamic get(String boxName, String key, {dynamic defaultValue}) {
    return writtenData[boxName]?[key] ?? defaultValue;
  }

  @override
  Future<void> delete(String boxName, String key) async {
    deleteCalls++;
    writtenData[boxName]?.remove(key);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _RecordingDatabaseService mockDb;
  late LocalCharacterRepository charRepo;
  late LocalCampaignRepository campRepo;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    mockDb = _RecordingDatabaseService();
    charRepo = LocalCharacterRepository(db: mockDb);
    campRepo = LocalCampaignRepository(db: mockDb, characterRepo: charRepo);
  });

  tearDown(() async {
    await AppServices.instance.debouncedStorage.flushAll();
    campRepo.dispose();
  });

  const testHero = Character(
    id: EntityId(slug: 'char_test_hero', ruleset: RulesetVersion.v2024),
    name: 'Thorin Oakenshield',
    speciesRef: EntityReference(refType: EntityType.species, slug: 'dwarf', displayName: 'Dwarf'),
    baseScores: AbilityScores(strength: 14, dexterity: 10, constitution: 14, intelligence: 10, wisdom: 10, charisma: 10),
    progression: CharacterProgression(classes: []),
    resources: CharacterResourcePool(),
  );

  const legacyHero = Character(
    id: EntityId(slug: 'legacy_wizard', ruleset: RulesetVersion.v2024),
    name: 'Gandalf the Grey',
    speciesRef: EntityReference(refType: EntityType.species, slug: 'human', displayName: 'Human'),
    baseScores: AbilityScores(strength: 10, dexterity: 10, constitution: 10, intelligence: 16, wisdom: 14, charisma: 12),
    progression: CharacterProgression(classes: []),
    resources: CharacterResourcePool(),
  );

  group('Single-Source Persistence Verification Tests', () {
    test('saveCharacter writes to AppDatabaseService box and bypasses SharedPreferences', () async {
      final initialPrefs = await SharedPreferences.getInstance();
      expect(initialPrefs.getKeys(), isEmpty);

      await charRepo.saveCharacter(testHero);
      // Flush debounced write
      await AppServices.instance.debouncedStorage.flushAll();

      // Verify database write
      expect(mockDb.writtenData.containsKey(AppDatabaseService.boxCharacters), isTrue);
      final charBox = mockDb.writtenData[AppDatabaseService.boxCharacters]!;
      expect(charBox.containsKey('saved_characters_roster_v1'), isTrue);
      final rawList = charBox['saved_characters_roster_v1'] as List<dynamic>;
      expect(rawList.length, equals(1));
      expect(rawList.first['name'], equals('Thorin Oakenshield'));

      // Verify SharedPreferences received zero writes
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getKeys(), isEmpty,
          reason: 'No SharedPreferences setString/put calls should occur during standard saveCharacter');
    });

    test('saveProfile writes to AppDatabaseService box and bypasses SharedPreferences', () async {
      final initialPrefs = await SharedPreferences.getInstance();
      expect(initialPrefs.getKeys(), isEmpty);

      final profile = CampaignProfile.defaultProfile(
        id: 'camp_iron_peaks',
        name: 'Iron Peaks Campaign',
      );

      await campRepo.saveProfileImmediate(profile);

      // Verify database write
      expect(mockDb.writtenData.containsKey(AppDatabaseService.boxCampaignProfiles), isTrue);
      final campBox = mockDb.writtenData[AppDatabaseService.boxCampaignProfiles]!;
      expect(campBox.containsKey('dn5e_campaign_profile_camp_iron_peaks'), isTrue);

      // Verify SharedPreferences received zero writes
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getKeys(), isEmpty,
          reason: 'No SharedPreferences setString/setStringList calls should occur during standard saveProfile');
    });

    test('retains SharedPreferences read strictly inside load methods as one-time legacy fallback', () async {
      final legacyJson = json.encode([CharacterDto.fromDomain(legacyHero).toMap()]);

      // Seed SharedPreferences with legacy roster
      SharedPreferences.setMockInitialValues({
        'saved_characters_roster_v1': legacyJson,
      });

      // DB is initially empty
      expect(mockDb.writtenData[AppDatabaseService.boxCharacters], isNull);

      // Load characters should fallback to SharedPreferences and migrate to DB
      final loaded = await charRepo.loadCharacters();
      expect(loaded.length, equals(1));
      expect(loaded.first.name, equals('Gandalf the Grey'));

      // Flushed to database box during migration
      expect(mockDb.writtenData[AppDatabaseService.boxCharacters]?['saved_characters_roster_v1'], isNotNull);
    });
  });
}
