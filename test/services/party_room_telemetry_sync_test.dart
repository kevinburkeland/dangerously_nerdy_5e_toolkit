import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:dangerously_nerdy_5e_toolkit/infrastructure/dtos/character_telemetry_dto.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/dm_screen_data.dart' show DmRulesEdition;
import 'package:dangerously_nerdy_5e_toolkit/models/domain/character_draft.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/domain/character_models.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/domain/core_types.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/domain/entity_reference.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/party/party_session_state.dart';
import 'package:dangerously_nerdy_5e_toolkit/services/party/party_room_service.dart';
import 'package:dangerously_nerdy_5e_toolkit/services/rules/character_factory.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Party Room Telemetry Sync & Payload Compression', () {
    test('telemetry packet size is < 1.5 KB (down from ~30 KB legacy sheet) with zero markdown', () {
      final draft = CharacterDraft()
        ..characterName = 'Archmage Mordenkainen the Elder'
        ..rulesEdition = DmRulesEdition.v2024
        ..speciesRef = const EntityReference(
          refType: EntityType.species,
          slug: 'human',
          displayName: 'Human',
        )
        ..backgroundRef = const EntityReference(
          refType: EntityType.background,
          slug: 'acolyte',
          displayName: 'Acolyte',
        )
        ..startingClassRef = const EntityReference(
          refType: EntityType.classDefinition,
          slug: 'wizard',
          displayName: 'Wizard',
        )
        ..startingClassHitDie = 'd6'
        ..baseScores = const AbilityScores(
          strength: 10,
          dexterity: 14,
          constitution: 16,
          intelligence: 20,
          wisdom: 15,
          charisma: 12,
        )
        ..selectedSkills = {
          SkillType.arcana: SkillProficiencyLevel.expertise,
          SkillType.history: SkillProficiencyLevel.proficient,
          SkillType.investigation: SkillProficiencyLevel.proficient,
        };

      var character = CharacterFactory.buildFromDraft(draft);

      // Add heavy narrative text, long backstory, complex items, and large markdown blobs
      final longBackstory = 'A' * 5000;
      final longNotes = 'B' * 10000;
      final longFeatures = '### Arcane Tradition: Evocation\n${'C' * 8000}';

      character = character.copyWith(
        customProperties: {
          'backstoryMarkdown': longBackstory,
          'notesMarkdown': longNotes,
          'featuresMarkdown': longFeatures,
        },
        inventory: [
          const InventoryItemInstance(
            instanceId: 'staff-1',
            itemRef: EntityReference(
              refType: EntityType.equipment,
              slug: 'staff-of-the-magi',
              displayName: 'Staff of the Magi',
            ),
            isEquipped: true,
          ),
          const InventoryItemInstance(
            instanceId: 'robe-1',
            itemRef: EntityReference(
              refType: EntityType.equipment,
              slug: 'robe-of-the-archmagi',
              displayName: 'Robe of the Archmagi',
            ),
            isEquipped: true,
          ),
        ],
      );

      // Legacy full character serialization
      final legacyJson = jsonEncode(character.toMap());
      final legacyByteSize = utf8.encode(legacyJson).length;
      expect(legacyByteSize, greaterThan(20000), reason: 'Legacy character sheet should be heavy');

      // Pointer-based Telemetry serialization
      final dto = character.toTelemetryDto();
      final telemetryMap = dto.toMap();
      final telemetryJson = jsonEncode(telemetryMap);
      final telemetryByteSize = utf8.encode(telemetryJson).length;

      // Assert telemetry is strictly under 1.5 KB (1536 bytes)
      expect(telemetryByteSize, lessThan(1500),
          reason: 'Telemetry packet must be compact (< 1.5 KB). Actual: $telemetryByteSize bytes');
      expect(telemetryByteSize, lessThan(legacyByteSize ~/ 10),
          reason: 'Telemetry should be over 90% smaller than legacy payload');

      // Assert complete absence of heavy markdown and proprietary rules text in network packet
      expect(telemetryJson.contains(longBackstory.substring(0, 100)), isFalse);
      expect(telemetryJson.contains(longNotes.substring(0, 100)), isFalse);
      expect(telemetryJson.contains(longFeatures.substring(0, 100)), isFalse);
      expect(telemetryJson.contains('featuresMarkdown'), isFalse);
      expect(telemetryJson.contains('backstoryMarkdown'), isFalse);
      expect(telemetryJson.contains('notesMarkdown'), isFalse);
    });

    test('PartySessionState serializes and deserializes partyTelemetry seamlessly', () {
      final telemetry1 = CharacterTelemetryDto(
        id: 'hero-1',
        name: 'Thorin',
        speciesSlug: 'dwarf',
        classPointers: const [
          ClassLevelPointerDto(classSlug: 'fighter', level: 3),
        ],
        currentHp: 28,
        maxHp: 32,
      );

      final telemetry2 = CharacterTelemetryDto(
        id: 'hero-2',
        name: 'Lyra',
        speciesSlug: 'elf',
        classPointers: const [
          ClassLevelPointerDto(classSlug: 'wizard', level: 3),
        ],
        currentHp: 18,
        maxHp: 20,
      );

      final now = DateTime.now();
      final session = PartySessionState(
        roomCode: 'TEST99',
        campaignName: 'Test Campaign',
        hostKeyHash: 'hash123',
        characterRoster: const ['Thorin', 'Lyra'],
        partyTelemetry: {
          'Thorin': telemetry1,
          'Lyra': telemetry2,
        },
        lastUpdated: now,
        expiresAt: now.add(const Duration(hours: 4)),
      );

      final map = session.toMap();
      expect(map.containsKey('partyTelemetry'), isTrue);
      expect(map['partyTelemetry'], isA<Map>());

      final restored = PartySessionState.fromMap(map);
      expect(restored.partyTelemetry.length, 2);
      expect(restored.partyTelemetry['Thorin']?.speciesSlug, 'dwarf');
      expect(restored.partyTelemetry['Thorin']?.currentHp, 28);
      expect(restored.partyTelemetry['Lyra']?.speciesSlug, 'elf');
      expect(restored.partyTelemetry['Lyra']?.currentHp, 18);
    });

    test('PartySessionState hydrates partyTelemetry from legacy sharedCharacters if incoming from older client', () {
      final legacyIncomingMap = {
        'roomCode': 'LEGACY01',
        'campaignName': 'Legacy Campaign',
        'characterRoster': ['Old Hero'],
        'sharedCharacters': {
          'Old Hero': {
            'id': {'slug': 'old-hero'},
            'name': 'Old Hero',
            'speciesRef': {'slug': 'human'},
            'progression': {
              'classes': [
                {
                  'classRef': {'slug': 'cleric'},
                  'level': 4,
                }
              ]
            },
            'resources': {
              'currentHp': 30,
              'maxHp': 35,
            },
          }
        }
      };

      final session = PartySessionState.fromMap(legacyIncomingMap);
      expect(session.partyTelemetry.containsKey('Old Hero'), isTrue);
      final tele = session.partyTelemetry['Old Hero']!;
      expect(tele.name, 'Old Hero');
      expect(tele.speciesSlug, 'human');
      expect(tele.currentHp, 30);
      expect(tele.maxHp, 35);
      expect(tele.classPointers.first.classSlug, 'cleric');
    });

    test('PartyRoomService links character and broadcasts minified telemetry map', () async {
      final partyService = PartyRoomService();
      final draft = CharacterDraft()
        ..characterName = 'Sir Reginald'
        ..rulesEdition = DmRulesEdition.v2024
        ..speciesRef = const EntityReference(
          refType: EntityType.species,
          slug: 'human',
          displayName: 'Human',
        )
        ..backgroundRef = const EntityReference(
          refType: EntityType.background,
          slug: 'noble',
          displayName: 'Noble',
        )
        ..startingClassRef = const EntityReference(
          refType: EntityType.classDefinition,
          slug: 'paladin',
          displayName: 'Paladin',
        )
        ..startingClassHitDie = 'd10'
        ..baseScores = const AbilityScores(
          strength: 16,
          dexterity: 10,
          constitution: 14,
          intelligence: 8,
          wisdom: 12,
          charisma: 16,
        );

      final character = CharacterFactory.buildFromDraft(draft);

      final session = await partyService.linkCharacterToCampaign(
        roomCode: 'PALADIN_ROOM',
        character: character,
        existingRosterName: 'Sir Reginald',
        isNewImport: true,
      );

      expect(session.partyTelemetry.containsKey('Sir Reginald'), isTrue);
      final tele = session.partyTelemetry['Sir Reginald']!;
      expect(tele.name, 'Sir Reginald');
      expect(tele.speciesSlug, 'human');
      expect(tele.classPointers.first.classSlug, 'paladin');

      // Also verify sharedCharacters has the minified map for backward compatibility
      expect(session.sharedCharacters.containsKey('Sir Reginald'), isTrue);
      final sharedMap = session.sharedCharacters['Sir Reginald']!;
      expect(sharedMap['n'], 'Sir Reginald');
      expect(sharedMap['sp'], 'human');
      expect(sharedMap.containsKey('featuresMarkdown'), isFalse);
    });
  });
}
