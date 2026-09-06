import 'package:flutter/foundation.dart';
import '../animated_object.dart';
import 'loot_models.dart';

/// Entity Types bindable within a session or room node
enum SessionRefType {
  character,
  monster,
  npc,
  lootContainer;

  String get displayName => switch (this) {
        SessionRefType.character => 'Player Character',
        SessionRefType.monster => 'Monster',
        SessionRefType.npc => 'NPC',
        SessionRefType.lootContainer => 'Loot Container',
      };
}

/// Contextual pointer linking characters, monsters, or objects to a room or graph node
@immutable
class RoomEntityLink {
  final SessionRefType refType;
  final String entityId;
  final String displayName;
  final String? notes;
  final Map<String, dynamic>? position; // e.g. {"x": 2, "y": 5}
  final bool isIsolatedClone; // If true, runtime modifications don't mutate parent template
  final Map<String, dynamic>? cloneRuntimeData; // HP, condition overrides for clones

  const RoomEntityLink({
    required this.refType,
    required this.entityId,
    required this.displayName,
    this.notes,
    this.position,
    this.isIsolatedClone = false,
    this.cloneRuntimeData,
  });

  RoomEntityLink copyWith({
    SessionRefType? refType,
    String? entityId,
    String? displayName,
    String? notes,
    Map<String, dynamic>? position,
    bool? isIsolatedClone,
    Map<String, dynamic>? cloneRuntimeData,
  }) {
    return RoomEntityLink(
      refType: refType ?? this.refType,
      entityId: entityId ?? this.entityId,
      displayName: displayName ?? this.displayName,
      notes: notes ?? this.notes,
      position: position ?? this.position,
      isIsolatedClone: isIsolatedClone ?? this.isIsolatedClone,
      cloneRuntimeData: cloneRuntimeData ?? this.cloneRuntimeData,
    );
  }

  Map<String, dynamic> toMap() => {
        'refType': refType.name,
        'entityId': entityId,
        'displayName': displayName,
        'notes': notes,
        'position': position,
        'isIsolatedClone': isIsolatedClone,
        'cloneRuntimeData': cloneRuntimeData,
      };

  factory RoomEntityLink.fromMap(Map<String, dynamic> map) {
    final typeStr = map['refType']?.toString() ?? 'character';
    final refType = SessionRefType.values.firstWhere(
      (t) => t.name == typeStr,
      orElse: () => SessionRefType.character,
    );

    return RoomEntityLink(
      refType: refType,
      entityId: map['entityId']?.toString() ?? '',
      displayName: map['displayName']?.toString() ?? '',
      notes: map['notes']?.toString(),
      position: map['position'] != null
          ? Map<String, dynamic>.from(map['position'] as Map)
          : null,
      isIsolatedClone: map['isIsolatedClone'] == true,
      cloneRuntimeData: map['cloneRuntimeData'] != null
          ? Map<String, dynamic>.from(map['cloneRuntimeData'] as Map)
          : null,
    );
  }
}

/// Dynamic Combat and Turn-Tracker Participant in an active room encounter
@immutable
class EncounterParticipant {
  final String participantId;
  final RoomEntityLink entityLink;
  final int initiativeScore;
  final int initiativeTieBreaker;
  final int currentHp;
  final int maxHp;
  final int tempHp;
  final int armorClass;
  final List<String> activeConditions;
  final bool isDefeated;
  final bool isActiveTurn;

  const EncounterParticipant({
    required this.participantId,
    required this.entityLink,
    this.initiativeScore = 10,
    this.initiativeTieBreaker = 0,
    required this.currentHp,
    required this.maxHp,
    this.tempHp = 0,
    this.armorClass = 10,
    this.activeConditions = const [],
    this.isDefeated = false,
    this.isActiveTurn = false,
  });

  EncounterParticipant copyWith({
    String? participantId,
    RoomEntityLink? entityLink,
    int? initiativeScore,
    int? initiativeTieBreaker,
    int? currentHp,
    int? maxHp,
    int? tempHp,
    int? armorClass,
    List<String>? activeConditions,
    bool? isDefeated,
    bool? isActiveTurn,
  }) {
    return EncounterParticipant(
      participantId: participantId ?? this.participantId,
      entityLink: entityLink ?? this.entityLink,
      initiativeScore: initiativeScore ?? this.initiativeScore,
      initiativeTieBreaker: initiativeTieBreaker ?? this.initiativeTieBreaker,
      currentHp: currentHp ?? this.currentHp,
      maxHp: maxHp ?? this.maxHp,
      tempHp: tempHp ?? this.tempHp,
      armorClass: armorClass ?? this.armorClass,
      activeConditions: activeConditions ?? this.activeConditions,
      isDefeated: isDefeated ?? this.isDefeated,
      isActiveTurn: isActiveTurn ?? this.isActiveTurn,
    );
  }

  Map<String, dynamic> toMap() => {
        'participantId': participantId,
        'entityLink': entityLink.toMap(),
        'initiativeScore': initiativeScore,
        'initiativeTieBreaker': initiativeTieBreaker,
        'currentHp': currentHp,
        'maxHp': maxHp,
        'tempHp': tempHp,
        'armorClass': armorClass,
        'activeConditions': activeConditions,
        'isDefeated': isDefeated,
        'isActiveTurn': isActiveTurn,
      };

  factory EncounterParticipant.fromMap(Map<String, dynamic> map) {
    return EncounterParticipant(
      participantId: map['participantId']?.toString() ?? '',
      entityLink: RoomEntityLink.fromMap(
          Map<String, dynamic>.from(map['entityLink'] as Map? ?? {})),
      initiativeScore: (map['initiativeScore'] as num?)?.toInt() ?? 10,
      initiativeTieBreaker:
          (map['initiativeTieBreaker'] as num?)?.toInt() ?? 0,
      currentHp: (map['currentHp'] as num?)?.toInt() ?? 10,
      maxHp: (map['maxHp'] as num?)?.toInt() ?? 10,
      tempHp: (map['tempHp'] as num?)?.toInt() ?? 0,
      armorClass: (map['armorClass'] as num?)?.toInt() ?? 10,
      activeConditions: (map['activeConditions'] as List? ?? [])
          .whereType<String>()
          .toList(),
      isDefeated: map['isDefeated'] == true,
      isActiveTurn: map['isActiveTurn'] == true,
    );
  }
}

/// Root Node Representation of a dynamic Dungeon Room or Session Graph State
@immutable
class RoomNodeState {
  final String roomId;
  final String roomCode;
  final String title;
  final String description;
  final List<RoomEntityLink> entityLinks;
  final List<LootContainer> containers;
  final List<EncounterParticipant> activeEncounter;
  final List<AnimatedObjectInstance> activeMinions;
  final Map<String, dynamic> customProperties;

  const RoomNodeState({
    required this.roomId,
    required this.roomCode,
    required this.title,
    this.description = '',
    this.entityLinks = const [],
    this.containers = const [],
    this.activeEncounter = const [],
    this.activeMinions = const [],
    this.customProperties = const {},
  });

  RoomNodeState copyWith({
    String? roomId,
    String? roomCode,
    String? title,
    String? description,
    List<RoomEntityLink>? entityLinks,
    List<LootContainer>? containers,
    List<EncounterParticipant>? activeEncounter,
    List<AnimatedObjectInstance>? activeMinions,
    Map<String, dynamic>? customProperties,
  }) {
    return RoomNodeState(
      roomId: roomId ?? this.roomId,
      roomCode: roomCode ?? this.roomCode,
      title: title ?? this.title,
      description: description ?? this.description,
      entityLinks: entityLinks ?? this.entityLinks,
      containers: containers ?? this.containers,
      activeEncounter: activeEncounter ?? this.activeEncounter,
      activeMinions: activeMinions != null
          ? List<AnimatedObjectInstance>.from(activeMinions)
          : this.activeMinions,
      customProperties: customProperties ?? this.customProperties,
    );
  }

  Map<String, dynamic> toMap() => {
        'roomId': roomId,
        'roomCode': roomCode,
        'title': title,
        'description': description,
        'entityLinks': entityLinks.map((e) => e.toMap()).toList(),
        'containers': containers.map((c) => c.toMap()).toList(),
        'activeEncounter': activeEncounter.map((e) => e.toMap()).toList(),
        'activeMinions': activeMinions.map((m) => m.toMap()).toList(),
        'customProperties': customProperties,
      };

  factory RoomNodeState.fromMap(Map<String, dynamic> map) {
    final rawMinions = map['activeMinions'] as List? ?? [];
    final minionsList = <AnimatedObjectInstance>[];
    for (final raw in rawMinions) {
      if (raw is Map) {
        try {
          minionsList.add(
              AnimatedObjectInstance.fromMap(Map<String, dynamic>.from(raw)));
        } catch (_) {}
      }
    }

    return RoomNodeState(
      roomId: map['roomId']?.toString() ?? '',
      roomCode: map['roomCode']?.toString() ?? '',
      title: map['title']?.toString() ?? 'Room',
      description: map['description']?.toString() ?? '',
      entityLinks: (map['entityLinks'] as List? ?? [])
          .whereType<Map>()
          .map((e) => RoomEntityLink.fromMap(Map<String, dynamic>.from(e)))
          .toList(),
      containers: (map['containers'] as List? ?? [])
          .whereType<Map>()
          .map((c) => LootContainer.fromMap(Map<String, dynamic>.from(c)))
          .toList(),
      activeEncounter: (map['activeEncounter'] as List? ?? [])
          .whereType<Map>()
          .map((e) =>
              EncounterParticipant.fromMap(Map<String, dynamic>.from(e)))
          .toList(),
      activeMinions: minionsList,
      customProperties:
          Map<String, dynamic>.from(map['customProperties'] as Map? ?? {}),
    );
  }
}
