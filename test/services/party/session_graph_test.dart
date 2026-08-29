import 'package:flutter_test/flutter_test.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/domain/core_types.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/domain/character_models.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/domain/entity_reference.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/domain/loot_models.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/domain/session_graph_models.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/party/party_purse.dart';
import 'package:dangerously_nerdy_5e_toolkit/services/party/session_graph_service.dart';
import 'package:dangerously_nerdy_5e_toolkit/services/repository/layered_priority_repository.dart';
import 'package:dangerously_nerdy_5e_toolkit/services/repository/reference_resolver.dart';

void main() {
  group('SessionGraphService & Room Integration Tests', () {
    late LayeredPriorityRepository repository;
    late ReferenceResolver resolver;

    late Character rogue;
    late Character cleric;

    setUp(() {
      repository = LayeredPriorityRepository();
      resolver = ReferenceResolver(repository);

      rogue = Character(
        id: const EntityId(slug: 'shadow', ruleset: RulesetVersion.v2024),
        name: 'Shadow',
        speciesRef: const EntityReference(
          refType: EntityType.species,
          slug: 'elf',
          displayName: 'Elf',
        ),
        progression: const CharacterProgression(classes: [
          ClassLevelProgression(
            classRef: EntityReference(
              refType: EntityType.classDefinition,
              slug: 'rogue',
              displayName: 'Rogue',
            ),
            level: 3,
            hitDie: 'd8',
          ),
        ]),
        baseScores: const AbilityScores(
          strength: 10,
          dexterity: 16,
          constitution: 12,
          intelligence: 14,
          wisdom: 12,
          charisma: 10,
        ),
        skillProficiencies: const {
          SkillType.perception: SkillProficiencyLevel.expertise, // Expertise in perception: +2 * 2 + 1 = +5 => Passive 15
          SkillType.investigation: SkillProficiencyLevel.proficient, // +2 + 2 = +4 => Passive 14
        },
        resources: const CharacterResourcePool(currentHp: 21),
      );

      cleric = Character(
        id: const EntityId(slug: 'solaris', ruleset: RulesetVersion.v2024),
        name: 'Solaris',
        speciesRef: const EntityReference(
          refType: EntityType.species,
          slug: 'human',
          displayName: 'Human',
        ),
        progression: const CharacterProgression(classes: [
          ClassLevelProgression(
            classRef: EntityReference(
              refType: EntityType.classDefinition,
              slug: 'cleric',
              displayName: 'Cleric',
            ),
            level: 3,
            hitDie: 'd8',
          ),
        ]),
        baseScores: const AbilityScores(
          strength: 14,
          dexterity: 10,
          constitution: 14,
          intelligence: 10,
          wisdom: 16,
          charisma: 12,
        ),
        skillProficiencies: const {
          SkillType.insight: SkillProficiencyLevel.proficient, // +3 + 2 = +5 => Passive 15
        },
        resources: const CharacterResourcePool(currentHp: 24),
      );
    });

    test('binds entity links to room node', () {
      var room = const RoomNodeState(
        roomId: 'room-101',
        roomCode: 'DUNGEON-A',
        title: 'Ancient Crypt',
      );

      const linkRogue = RoomEntityLink(
        refType: SessionRefType.character,
        entityId: 'shadow',
        displayName: 'Shadow the Rogue',
        position: {'x': 1, 'y': 2},
      );

      room = SessionGraphService.bindEntityToRoom(room, linkRogue);
      expect(room.entityLinks.length, equals(1));
      expect(room.entityLinks.first.entityId, equals('shadow'));

      room = SessionGraphService.unbindEntityFromRoom(room, 'shadow');
      expect(room.entityLinks.isEmpty, isTrue);
    });

    test('aggregates party passive stats across multiple characters', () {
      final metrics = SessionGraphService.aggregatePartyPassives(
        partyCharacters: [rogue, cleric],
        resolver: resolver,
      );

      expect(metrics.activePartyCount, equals(2));
      expect(metrics.highestPassivePerception, equals(15));
      expect(metrics.highestPassivePerceptionCharacter, equals('Shadow'));
      expect(metrics.highestPassiveInsight, equals(15));
      expect(metrics.highestPassiveInsightCharacter, equals('Solaris'));
      expect(metrics.totalPartyHp, equals(45)); // 21 + 24
    });

    test('instantiates isolated combat clone participant', () {
      const link = RoomEntityLink(
        refType: SessionRefType.monster,
        entityId: 'goblin-boss',
        displayName: 'Goblin Boss',
        isIsolatedClone: true,
      );

      final participant = SessionGraphService.instantiateCombatParticipant(
        entityLink: link,
        currentHp: 21,
        maxHp: 21,
        armorClass: 15,
        initiative: 17,
      );

      expect(participant.currentHp, equals(21));
      expect(participant.armorClass, equals(15));
      expect(participant.initiativeScore, equals(17));
      expect(participant.entityLink.isIsolatedClone, isTrue);
    });

    test('distributes room container loot to target character atomically', () {
      const initialChest = LootContainer(
        containerId: 'chest-crypt',
        name: 'Gilded Sarcophagus Chest',
        items: [
          InventoryItemInstance(
            instanceId: 'item-ruby',
            itemRef: EntityReference(
              refType: EntityType.equipment,
              slug: 'ruby-of-the-war-mage',
              displayName: 'Ruby of the War Mage',
            ),
            quantity: 1,
            requiresAttunement: true,
          ),
        ],
        purse: PartyPurse(gp: 250),
      );

      var room = const RoomNodeState(
        roomId: 'room-crypt',
        roomCode: 'CRYPT-01',
        title: 'Crypt',
        containers: [initialChest],
      );

      final transferOutcome = SessionGraphService.transferRoomLoot(
        room: room,
        containerId: 'chest-crypt',
        targetCharacter: rogue,
        itemInstanceId: 'item-ruby',
        quantity: 1,
        currency: const PartyPurse(gp: 100),
      );

      final updatedRoom = transferOutcome.updatedRoom;
      final updatedRogue = transferOutcome.updatedCharacter;

      // Sarcophagus items emptied and 150 gp remaining
      expect(updatedRoom.containers.first.items.isEmpty, isTrue);
      expect(updatedRoom.containers.first.purse.gp, equals(150));

      // Rogue has Ruby and +100 gp
      expect(updatedRogue.inventory.last.itemRef.slug, equals('ruby-of-the-war-mage'));
      expect(updatedRogue.purse.gp, equals(100));
    });
  });
}
