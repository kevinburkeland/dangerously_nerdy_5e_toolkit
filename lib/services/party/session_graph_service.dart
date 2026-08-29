import 'package:flutter/foundation.dart';
import '../../models/domain/character_models.dart';
import '../../models/domain/loot_models.dart';
import '../../models/domain/session_graph_models.dart';
import '../../models/party/party_purse.dart';
import '../repository/reference_resolver.dart';
import '../rules/character_stat_calculator.dart';
import '../rules/inventory_transaction_service.dart';

/// Aggregated Passive Party Metrics for DM Screen and Room Hazard checks
@immutable
class PartyPassiveMetrics {
  final int highestPassivePerception;
  final String highestPassivePerceptionCharacter;
  final int highestPassiveInvestigation;
  final String highestPassiveInvestigationCharacter;
  final int highestPassiveInsight;
  final String highestPassiveInsightCharacter;
  final int lowestArmorClass;
  final int totalPartyHp;
  final int activePartyCount;

  const PartyPassiveMetrics({
    required this.highestPassivePerception,
    required this.highestPassivePerceptionCharacter,
    required this.highestPassiveInvestigation,
    required this.highestPassiveInvestigationCharacter,
    required this.highestPassiveInsight,
    required this.highestPassiveInsightCharacter,
    required this.lowestArmorClass,
    required this.totalPartyHp,
    required this.activePartyCount,
  });
}

/// Service managing Room Node states, Entity Linking, and Session Graph Interactions
class SessionGraphService {
  /// Binds an entity link (character, monster, or NPC) to a room node
  static RoomNodeState bindEntityToRoom(RoomNodeState room, RoomEntityLink link) {
    final links = List<RoomEntityLink>.from(room.entityLinks);
    final idx = links.indexWhere((l) => l.entityId == link.entityId && l.refType == link.refType);
    if (idx != -1) {
      links[idx] = link;
    } else {
      links.add(link);
    }
    return room.copyWith(entityLinks: links);
  }

  /// Removes an entity link from a room node
  static RoomNodeState unbindEntityFromRoom(RoomNodeState room, String entityId) {
    final links = List<RoomEntityLink>.from(room.entityLinks)
      ..removeWhere((l) => l.entityId == entityId);
    return room.copyWith(entityLinks: links);
  }

  /// Adds a loot container to a room node
  static RoomNodeState addContainerToRoom(RoomNodeState room, LootContainer container) {
    final containers = List<LootContainer>.from(room.containers);
    final idx = containers.indexWhere((c) => c.containerId == container.containerId);
    if (idx != -1) {
      containers[idx] = container;
    } else {
      containers.add(container);
    }
    return room.copyWith(containers: containers);
  }

  /// Instantiates an isolated combat clone participant for an encounter
  static EncounterParticipant instantiateCombatParticipant({
    required RoomEntityLink entityLink,
    required int currentHp,
    required int maxHp,
    required int armorClass,
    int initiative = 10,
    int initiativeTieBreaker = 0,
  }) {
    final participantId = 'part-${entityLink.entityId}-${DateTime.now().millisecondsSinceEpoch}';
    return EncounterParticipant(
      participantId: participantId,
      entityLink: entityLink,
      initiativeScore: initiative,
      initiativeTieBreaker: initiativeTieBreaker,
      currentHp: currentHp,
      maxHp: maxHp,
      armorClass: armorClass,
    );
  }

  /// Aggregates passive stats across all active party characters
  static PartyPassiveMetrics aggregatePartyPassives({
    required List<Character> partyCharacters,
    required ReferenceResolver resolver,
  }) {
    if (partyCharacters.isEmpty) {
      return const PartyPassiveMetrics(
        highestPassivePerception: 10,
        highestPassivePerceptionCharacter: 'None',
        highestPassiveInvestigation: 10,
        highestPassiveInvestigationCharacter: 'None',
        highestPassiveInsight: 10,
        highestPassiveInsightCharacter: 'None',
        lowestArmorClass: 10,
        totalPartyHp: 0,
        activePartyCount: 0,
      );
    }

    int highestPerception = 0;
    String perceptionLeader = '';

    int highestInvestigation = 0;
    String investigationLeader = '';

    int highestInsight = 0;
    String insightLeader = '';

    int lowestAc = 999;
    int totalHp = 0;

    for (final char in partyCharacters) {
      final stats = CharacterStatCalculator.compute(char, resolver);

      if (stats.passivePerception > highestPerception) {
        highestPerception = stats.passivePerception;
        perceptionLeader = char.name;
      }
      if (stats.passiveInvestigation > highestInvestigation) {
        highestInvestigation = stats.passiveInvestigation;
        investigationLeader = char.name;
      }
      if (stats.passiveInsight > highestInsight) {
        highestInsight = stats.passiveInsight;
        insightLeader = char.name;
      }

      if (stats.armorClass < lowestAc) {
        lowestAc = stats.armorClass;
      }
      totalHp += stats.maxHp;
    }

    return PartyPassiveMetrics(
      highestPassivePerception: highestPerception,
      highestPassivePerceptionCharacter: perceptionLeader,
      highestPassiveInvestigation: highestInvestigation,
      highestPassiveInvestigationCharacter: investigationLeader,
      highestPassiveInsight: highestInsight,
      highestPassiveInsightCharacter: insightLeader,
      lowestArmorClass: lowestAc == 999 ? 10 : lowestAc,
      totalPartyHp: totalHp,
      activePartyCount: partyCharacters.length,
    );
  }

  /// Executes an atomic loot transfer from a room container to a character
  static ({RoomNodeState updatedRoom, Character updatedCharacter}) transferRoomLoot({
    required RoomNodeState room,
    required String containerId,
    required Character targetCharacter,
    required String itemInstanceId,
    int quantity = 1,
    PartyPurse? currency,
  }) {
    final containerIdx = room.containers.indexWhere((c) => c.containerId == containerId);
    if (containerIdx == -1) {
      throw ArgumentError('Container $containerId not found in room ${room.roomCode}.');
    }

    final targetContainer = room.containers[containerIdx];
    final result = InventoryTransactionService.transferFromContainerToCharacter(
      sourceContainer: targetContainer,
      destinationCharacter: targetCharacter,
      instanceId: itemInstanceId,
      quantity: quantity,
      currency: currency,
    );

    final updatedContainers = List<LootContainer>.from(room.containers);
    updatedContainers[containerIdx] = result.updatedContainer;

    final updatedRoom = room.copyWith(containers: updatedContainers);
    return (
      updatedRoom: updatedRoom,
      updatedCharacter: result.updatedCharacter,
    );
  }
}
