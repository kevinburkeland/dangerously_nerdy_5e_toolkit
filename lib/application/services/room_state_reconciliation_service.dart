import 'package:vtt_engine_core/crdt/crdt_lww_register.dart';
import 'package:vtt_engine_core/crdt/crdt_or_set.dart';
import 'package:vtt_engine_core/crdt/hybrid_logical_clock.dart';
import 'package:vtt_engine_core/models/campaign_profile.dart';
import 'package:vtt_engine_core/models/party_purse.dart';
import '../../models/domain/loot_models.dart';
import '../../models/domain/session_graph_models.dart';
import '../../models/party/party_event.dart';

/// Application service orchestrating CRDT state reconciliation, tombstone retention/causal safety policies,
/// and deterministic field-level campaign profile merging.
class RoomStateReconciliationService {
  final int Function() _networkTimeProvider;

  RoomStateReconciliationService({
    required int Function() networkTimeProvider,
  }) : _networkTimeProvider = networkTimeProvider;

  /// Retains all tombstones in [targetSet] indefinitely until causal stability can be proven.
  ///
  /// In an open or partially-connected distributed system, elapsed time, network time,
  /// and heartbeat timeouts cannot prove that an offline replica has received and observed
  /// a deletion. Pruning tombstones prematurely allows reconnecting replicas to resurrect
  /// deleted entities.
  ///
  /// Future extension point: True causal compaction requires protocol-level causal
  /// acknowledgement (e.g., per-replica version vectors or consensus-based compaction epochs)
  /// proving that every replica in the system has observed the deletion before a tombstone
  /// can be safely collected.
  CrdtOrSet<T> retainTombstones<T>(CrdtOrSet<T> targetSet) {
    return targetSet;
  }

  /// Retains tombstones indefinitely.
  ///
  /// Deprecated: Wall-clock or elapsed-time thresholds cannot guarantee that all replicas have
  /// causally observed the deletion. Pruning based on time alone causes deleted entities to be
  /// resurrected when offline replicas reconnect with older additions.
  ///
  /// This method is retained for API compatibility, but does not prune tombstones based on elapsed time.
  @Deprecated('Elapsed time does not guarantee causal acknowledgement. Tombstones are retained indefinitely.')
  CrdtOrSet<T> safePrune<T>(
    CrdtOrSet<T> targetSet,
    HybridLogicalClock candidateThreshold, {
    int safeBufferMs = 0,
  }) {
    // Correctness over premature compaction: elapsed time does not prove causal acknowledgement.
    // Retain tombstones indefinitely to prevent stale replica resurrection.
    return retainTombstones(targetSet);
  }

  /// Retains tombstones indefinitely.
  ///
  /// Deprecated: Milestone timestamps do not guarantee causal acknowledgement by offline replicas.
  /// Pruning based on milestone age or network time alone causes deleted entities to be resurrected
  /// when an offline replica reconnects.
  ///
  /// This method is retained for API compatibility, but does not prune tombstones based on elapsed time.
  @Deprecated('Milestone timestamps do not guarantee causal acknowledgement. Tombstones are retained indefinitely.')
  CrdtOrSet<T> executeMilestonePrune<T>(
    CrdtOrSet<T> targetSet,
    int milestoneEpochMs,
    String hostNodeId, {
    int safeBufferMs = 0,
  }) {
    // Correctness over premature compaction: retain tombstones indefinitely.
    return retainTombstones(targetSet);
  }

  /// Reconciles an incoming remote [CampaignProfile] with the [local] campaign state.
  /// Merges distinct sub-resources (notes, party purse, party roster, room metadata, minions, encounters)
  /// deterministically using pure CRDT convergence instead of wholesale overwriting the local profile.
  /// Executes the pure canonical aggregate join over two valid [CampaignProfile] instances.
  ///
  /// Throws [StateError] on any invalid state or unversioned collision.
  CampaignProfile joinValid(CampaignProfile a, CampaignProfile b) {
    return CampaignProfile.join(a, b);
  }

  /// Reconciles an incoming remote [CampaignProfile] with the [local] campaign state.
  /// Merges distinct sub-resources deterministically and symmetrically using pure CRDT convergence.
  CampaignProfile reconcileProfile({
    required CampaignProfile local,
    required CampaignProfile remote,
    int? inboundTimestampMs,
    int? localTimestampMs,
  }) {
    return reconcileProfileSafely(
      local: local,
      remote: remote,
      inboundTimestampMs: inboundTimestampMs,
      localTimestampMs: localTimestampMs,
    ).profile;
  }

  /// Reconciles [local] and [remote] campaign profiles with narrow per-subresource fault isolation.
  ///
  /// Independent sub-resources (notes, party purse, active minions, active encounters,
  /// containers, entity links, customProperties) are reconciled separately.
  /// If an invalid CRDT collision or unversioned divergence occurs in one subresource,
  /// that offending subresource is isolated (retaining the local value) and recorded as a fault,
  /// while all unrelated healthy sub-resources continue to merge safely.
  ReconciliationResult reconcileProfileSafely({
    required CampaignProfile local,
    required CampaignProfile remote,
    int? inboundTimestampMs,
    int? localTimestampMs,
  }) {
    if (runtimeType != RoomStateReconciliationService) {
      final merged = reconcileProfile(
        local: local,
        remote: remote,
        inboundTimestampMs: inboundTimestampMs,
        localTimestampMs: localTimestampMs,
      );
      return ReconciliationResult(profile: merged, fieldFaults: const []);
    }

    if (local.id != remote.id) {
      throw StateError(
        'CampaignProfile id mismatch: "${local.id}" vs "${remote.id}".',
      );
    }

    if (local.rulesetId != remote.rulesetId) {
      throw StateError(
        'Incompatible ruleset edition: "${local.rulesetId}" vs "${remote.rulesetId}".',
      );
    }

    final faults = <ReconciliationFieldFault>[];

    // 1. Root metadata: name, createdAt, lastPlayedAt
    String mergedName = local.name;
    try {
      if (local.name == remote.name) {
        mergedName = local.name;
      } else if (local.name.isEmpty) {
        mergedName = remote.name;
      } else if (remote.name.isEmpty) {
        mergedName = local.name;
      } else {
        throw StateError(
          'Divergent unversioned campaign name: "${local.name}" vs "${remote.name}".',
        );
      }
    } catch (e, st) {
      faults.add(ReconciliationFieldFault(field: 'name', error: e, stackTrace: st));
      mergedName = local.name;
    }

    final mergedCreatedAt =
        local.createdAt.isBefore(remote.createdAt) ? local.createdAt : remote.createdAt;
    final mergedLastPlayedAt =
        local.lastPlayedAt.isAfter(remote.lastPlayedAt) ? local.lastPlayedAt : remote.lastPlayedAt;

    // 2. Notes: LWW CRDT register merge with fault isolation
    CrdtLwwRegister<String> mergedNotesRegister = local.notesRegister;
    PartyEvent? droppedNotesEvent;
    try {
      mergedNotesRegister = local.notesRegister.merge(remote.notesRegister);

      // Audit and record dropped delta if two non-empty divergent notes were merged
      if (local.notesRegister.value != remote.notesRegister.value &&
          local.notesRegister.value.isNotEmpty &&
          remote.notesRegister.value.isNotEmpty) {
        final loser = remote.notesRegister.timestamp.isAfter(local.notesRegister.timestamp)
            ? local.notesRegister
            : remote.notesRegister;
        droppedNotesEvent = PartyEvent(
          id: 'conflict_notes_${loser.timestamp.physicalTime}_${loser.timestamp.nodeId}',
          roomCode: local.roomState.roomCode.isNotEmpty
              ? local.roomState.roomCode
              : local.roomState.roomId,
          type: 'notesConflictOverwrite',
          playerName: loser.timestamp.nodeId,
          details: loser.value,
          timestamp: DateTime.fromMillisecondsSinceEpoch(
            loser.timestamp.physicalTime > 0
                ? loser.timestamp.physicalTime
                : _networkTimeProvider(),
            isUtc: true,
          ),
        );
      }
    } catch (e, st) {
      faults.add(ReconciliationFieldFault(field: 'notesRegister', error: e, stackTrace: st));
      mergedNotesRegister = local.notesRegister;
    }

    // 3. Party Purse: CvRDT lattice join across PN-counters with fault isolation
    PartyPurse mergedPurse = local.partyPurse;
    try {
      mergedPurse = local.partyPurse.merge(remote.partyPurse);
    } catch (e, st) {
      faults.add(ReconciliationFieldFault(field: 'partyPurse', error: e, stackTrace: st));
      mergedPurse = local.partyPurse;
    }

    // 4. Change Log: deduplicated by event ID, sorted deterministically by timestamp & id
    List<PartyEvent> mergedChangeLog = local.changeLog;
    try {
      final combinedLocal = droppedNotesEvent != null
          ? [...local.changeLog, droppedNotesEvent]
          : local.changeLog;
      mergedChangeLog = _mergeChangeLogs(combinedLocal, remote.changeLog);
    } catch (e, st) {
      faults.add(ReconciliationFieldFault(field: 'changeLog', error: e, stackTrace: st));
      mergedChangeLog = local.changeLog;
    }

    // 5. Party Roster: Set-like membership respecting removals in changelog, deterministically sorted
    List<String> mergedPartyCharacterIds = local.partyCharacterIds;
    try {
      mergedPartyCharacterIds = _mergePartyRosters(
        local: local.partyCharacterIds,
        remote: remote.partyCharacterIds,
        changeLog: mergedChangeLog,
      );
    } catch (e, st) {
      faults.add(ReconciliationFieldFault(field: 'partyCharacterIds', error: e, stackTrace: st));
      mergedPartyCharacterIds = local.partyCharacterIds;
    }

    // 6. Pinned Rules: Pure set union
    final mergedPinnedRules = local.pinnedRuleIds.union(remote.pinnedRuleIds);

    // 7. Room Node State: Sub-resource reconciliation with narrow fault isolation
    final roomRecon = _reconcileRoomStateSafely(
      local: local.roomState,
      remote: remote.roomState,
    );
    faults.addAll(roomRecon.fieldFaults);

    final mergedProfile = local.copyWith(
      name: mergedName,
      createdAt: mergedCreatedAt,
      lastPlayedAt: mergedLastPlayedAt,
      notesRegister: mergedNotesRegister,
      partyPurse: mergedPurse,
      partyCharacterIds: mergedPartyCharacterIds,
      pinnedRuleIds: mergedPinnedRules,
      roomState: roomRecon.roomState,
      changeLog: mergedChangeLog,
    );

    return ReconciliationResult(
      profile: mergedProfile,
      fieldFaults: List.unmodifiable(faults),
    );
  }

  _RoomReconciliationResult _reconcileRoomStateSafely({
    required RoomNodeState local,
    required RoomNodeState remote,
  }) {
    final faults = <ReconciliationFieldFault>[];

    String mergedRoomId = local.roomId;
    try {
      if (local.roomId == remote.roomId) {
        mergedRoomId = local.roomId;
      } else if (local.roomId.isEmpty) {
        mergedRoomId = remote.roomId;
      } else if (remote.roomId.isEmpty) {
        mergedRoomId = local.roomId;
      } else {
        throw StateError(
          'RoomNodeState roomId mismatch: "${local.roomId}" vs "${remote.roomId}".',
        );
      }
    } catch (e, st) {
      faults.add(ReconciliationFieldFault(field: 'roomState.roomId', error: e, stackTrace: st));
      mergedRoomId = local.roomId;
    }

    String mergedRoomCode = local.roomCode;
    try {
      if (local.roomCode == remote.roomCode) {
        mergedRoomCode = local.roomCode;
      } else if (local.roomCode.isEmpty) {
        mergedRoomCode = remote.roomCode;
      } else if (remote.roomCode.isEmpty) {
        mergedRoomCode = local.roomCode;
      } else {
        throw StateError(
          'RoomNodeState roomCode mismatch: "${local.roomCode}" vs "${remote.roomCode}".',
        );
      }
    } catch (e, st) {
      faults.add(ReconciliationFieldFault(field: 'roomState.roomCode', error: e, stackTrace: st));
      mergedRoomCode = local.roomCode;
    }

    String mergedTitle = local.title;
    try {
      if (local.title == remote.title) {
        mergedTitle = local.title;
      } else if (local.title.isEmpty) {
        mergedTitle = remote.title;
      } else if (remote.title.isEmpty) {
        mergedTitle = local.title;
      } else {
        throw StateError(
          'Divergent unversioned room title: "${local.title}" vs "${remote.title}".',
        );
      }
    } catch (e, st) {
      faults.add(ReconciliationFieldFault(field: 'roomState.title', error: e, stackTrace: st));
      mergedTitle = local.title;
    }

    String mergedDescription = local.description;
    try {
      if (local.description == remote.description) {
        mergedDescription = local.description;
      } else if (local.description.isEmpty) {
        mergedDescription = remote.description;
      } else if (remote.description.isEmpty) {
        mergedDescription = local.description;
      } else {
        throw StateError(
          'Divergent unversioned room description: "${local.description}" vs "${remote.description}".',
        );
      }
    } catch (e, st) {
      faults.add(ReconciliationFieldFault(field: 'roomState.description', error: e, stackTrace: st));
      mergedDescription = local.description;
    }

    // Minions: OR-Set merge with fault isolation
    CrdtOrSet<dynamic> mergedMinions = local.activeMinions;
    try {
      mergedMinions = local.activeMinions.merge(remote.activeMinions);
    } catch (e, st) {
      faults.add(ReconciliationFieldFault(field: 'roomState.activeMinions', error: e, stackTrace: st));
      mergedMinions = local.activeMinions;
    }

    // Encounter: OR-Set merge with fault isolation
    CrdtOrSet<EncounterParticipant> mergedEncounter = local.activeEncounter;
    try {
      mergedEncounter = local.activeEncounter.merge(remote.activeEncounter);
    } catch (e, st) {
      faults.add(ReconciliationFieldFault(field: 'roomState.activeEncounter', error: e, stackTrace: st));
      mergedEncounter = local.activeEncounter;
    }

    // Custom properties: per-key merge with fault isolation
    Map<String, dynamic> mergedCustomProperties = local.customProperties;
    try {
      final allKeys = {...local.customProperties.keys, ...remote.customProperties.keys}.toList()..sort();
      final props = <String, dynamic>{};
      for (final key in allKeys) {
        if (local.customProperties.containsKey(key) && remote.customProperties.containsKey(key)) {
          final valA = local.customProperties[key];
          final valB = remote.customProperties[key];
          if (valA != valB) {
            throw StateError(
              'Divergent unversioned customProperties key "$key": "$valA" vs "$valB".',
            );
          }
          props[key] = valA;
        } else if (local.customProperties.containsKey(key)) {
          props[key] = local.customProperties[key];
        } else {
          props[key] = remote.customProperties[key];
        }
      }
      mergedCustomProperties = props;
    } catch (e, st) {
      faults.add(ReconciliationFieldFault(field: 'roomState.customProperties', error: e, stackTrace: st));
      mergedCustomProperties = local.customProperties;
    }

    // Entity links: map by entityId, join, sort deterministically
    List<RoomEntityLink> mergedLinks = local.entityLinks;
    try {
      final linksMapA = <String, RoomEntityLink>{};
      for (final l in local.entityLinks) {
        linksMapA[l.entityId] = l;
      }
      final linksMapB = <String, RoomEntityLink>{};
      for (final l in remote.entityLinks) {
        linksMapB[l.entityId] = l;
      }
      final allLinkIds = <String>{...linksMapA.keys, ...linksMapB.keys}.toList()..sort();
      final list = <RoomEntityLink>[];
      for (final id in allLinkIds) {
        final linkA = linksMapA[id];
        final linkB = linksMapB[id];
        if (linkA != null && linkB != null) {
          list.add(RoomEntityLink.join(linkA, linkB));
        } else if (linkA != null) {
          list.add(linkA);
        } else if (linkB != null) {
          list.add(linkB);
        }
      }
      mergedLinks = list;
    } catch (e, st) {
      faults.add(ReconciliationFieldFault(field: 'roomState.entityLinks', error: e, stackTrace: st));
      mergedLinks = local.entityLinks;
    }

    // Entity instances: map by instanceId, join, sort deterministically
    List<EntityInstance> mergedInstances = local.entityInstances;
    try {
      final instMapA = <String, EntityInstance>{};
      for (final i in local.entityInstances) {
        instMapA[i.instanceId] = i;
      }
      final instMapB = <String, EntityInstance>{};
      for (final i in remote.entityInstances) {
        instMapB[i.instanceId] = i;
      }
      final allInstIds = <String>{...instMapA.keys, ...instMapB.keys}.toList()..sort();
      final list = <EntityInstance>[];
      for (final id in allInstIds) {
        final instA = instMapA[id];
        final instB = instMapB[id];
        if (instA != null && instB != null) {
          list.add(EntityInstance.join(instA, instB));
        } else if (instA != null) {
          list.add(instA);
        } else if (instB != null) {
          list.add(instB);
        }
      }
      mergedInstances = list;
    } catch (e, st) {
      faults.add(ReconciliationFieldFault(field: 'roomState.entityInstances', error: e, stackTrace: st));
      mergedInstances = local.entityInstances;
    }

    // Containers: map by containerId, join, sort deterministically
    List<LootContainer> mergedContainers = local.containers;
    try {
      final cMapA = <String, LootContainer>{};
      for (final c in local.containers) {
        cMapA[c.containerId] = c;
      }
      final cMapB = <String, LootContainer>{};
      for (final c in remote.containers) {
        cMapB[c.containerId] = c;
      }
      final allCIds = <String>{...cMapA.keys, ...cMapB.keys}.toList()..sort();
      final list = <LootContainer>[];
      for (final id in allCIds) {
        final cA = cMapA[id];
        final cB = cMapB[id];
        if (cA != null && cB != null) {
          list.add(LootContainer.join(cA, cB));
        } else if (cA != null) {
          list.add(cA);
        } else if (cB != null) {
          list.add(cB);
        }
      }
      mergedContainers = list;
    } catch (e, st) {
      faults.add(ReconciliationFieldFault(field: 'roomState.containers', error: e, stackTrace: st));
      mergedContainers = local.containers;
    }

    final mergedRoomState = RoomNodeState(
      roomId: mergedRoomId,
      roomCode: mergedRoomCode,
      title: mergedTitle,
      description: mergedDescription,
      entityLinks: mergedLinks,
      entityInstances: mergedInstances,
      containers: mergedContainers,
      activeEncounter: mergedEncounter,
      activeMinions: mergedMinions,
      customProperties: mergedCustomProperties,
    );

    return _RoomReconciliationResult(
      roomState: mergedRoomState,
      fieldFaults: listOrEmpty(faults),
    );
  }

  List<T> listOrEmpty<T>(List<T> list) => List.unmodifiable(list);

  List<PartyEvent> _mergeChangeLogs(
    List<PartyEvent> local,
    List<PartyEvent> remote,
  ) {
    final eventMap = <String, PartyEvent>{};
    for (final ev in local) {
      eventMap[ev.id] = ev;
    }
    for (final ev in remote) {
      if (eventMap.containsKey(ev.id)) {
        if (eventMap[ev.id] != ev) {
          throw StateError(
            'Divergent PartyEvent under same event id "${ev.id}".',
          );
        }
      } else {
        eventMap[ev.id] = ev;
      }
    }
    final list = eventMap.values.toList()
      ..sort((a, b) {
        final cmp = a.timestamp.compareTo(b.timestamp);
        if (cmp != 0) return cmp;
        return a.id.compareTo(b.id);
      });
    return list;
  }

  List<String> _mergePartyRosters({
    required List<String> local,
    required List<String> remote,
    required List<PartyEvent> changeLog,
  }) {
    final removed = <String>{};
    for (final event in changeLog) {
      if (event.type == 'characterRemove' || event.type == 'playerLeave') {
        if (event.details.trim().isNotEmpty) {
          removed.add(event.details.trim());
        }
      }
    }

    final activeRoster = <String>{
      ...local,
      ...remote,
    }..removeAll(removed);

    return activeRoster.toList()..sort();
  }
}

/// Represents the result of aggregate reconciliation, including any isolated field faults.
class ReconciliationResult {
  final CampaignProfile profile;
  final List<ReconciliationFieldFault> fieldFaults;
  bool get hasFaults => fieldFaults.isNotEmpty;

  const ReconciliationResult({
    required this.profile,
    this.fieldFaults = const [],
  });
}

/// Detailed fault recorded when an individual subresource fails during aggregate reconciliation.
class ReconciliationFieldFault {
  final String field;
  final Object error;
  final StackTrace? stackTrace;

  const ReconciliationFieldFault({
    required this.field,
    required this.error,
    this.stackTrace,
  });

  @override
  String toString() => 'ReconciliationFieldFault($field: $error)';
}

class _RoomReconciliationResult {
  final RoomNodeState roomState;
  final List<ReconciliationFieldFault> fieldFaults;

  const _RoomReconciliationResult({
    required this.roomState,
    required this.fieldFaults,
  });
}

