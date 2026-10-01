import 'package:vtt_engine_core/crdt/crdt_lww_register.dart';
import 'package:vtt_engine_core/crdt/crdt_or_set.dart';
import 'package:vtt_engine_core/crdt/hybrid_logical_clock.dart';
import 'package:vtt_engine_core/models/campaign_profile.dart';
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
  CampaignProfile reconcileProfile({
    required CampaignProfile local,
    required CampaignProfile remote,
    int? inboundTimestampMs,
    int? localTimestampMs,
  }) {
    if (local.id != remote.id) {
      return local;
    }

    // 1. Root metadata (name, edition, lastPlayedAt)
    final isRemoteNewer = inboundTimestampMs != null && localTimestampMs != null
        ? inboundTimestampMs >= localTimestampMs
        : !remote.lastPlayedAt.isBefore(local.lastPlayedAt);
    final mergedLastPlayedAt =
        isRemoteNewer ? remote.lastPlayedAt : local.lastPlayedAt;
    final mergedName = isRemoteNewer && remote.name.isNotEmpty
        ? remote.name
        : (local.name.isNotEmpty ? local.name : remote.name);

    // 2. Notes: Deterministic timestamp-based Last-Write-Wins overwrite backed by HLC timestamps.
    // Favors the higher HLC timestamp, logging the dropped delta to changeLog instead of infinitely
    // concatenating strings.
    final CrdtLwwRegister<String> mergedNotesRegister;
    PartyEvent? droppedNotesEvent;
    if (local.notesRegister.value != remote.notesRegister.value) {
      if (local.notesRegister.value.isEmpty) {
        mergedNotesRegister = remote.notesRegister;
      } else if (remote.notesRegister.value.isEmpty) {
        mergedNotesRegister = local.notesRegister;
      } else {
        // Deterministic Last-Write-Wins resolution favoring the higher HLC timestamp
        if (remote.notesRegister.timestamp
            .isAfter(local.notesRegister.timestamp)) {
          mergedNotesRegister = remote.notesRegister;
          droppedNotesEvent = PartyEvent(
            id: 'conflict_notes_${local.notesRegister.timestamp.physicalTime}_${local.notesRegister.timestamp.nodeId}',
            roomCode: local.roomState.roomCode.isNotEmpty
                ? local.roomState.roomCode
                : local.roomState.roomId,
            type: 'notesConflictOverwrite',
            playerName: local.notesRegister.timestamp.nodeId,
            details: local.notesRegister.value,
            timestamp: DateTime.fromMillisecondsSinceEpoch(
              local.notesRegister.timestamp.physicalTime > 0
                  ? local.notesRegister.timestamp.physicalTime
                  : _networkTimeProvider(),
              isUtc: true,
            ),
          );
        } else {
          mergedNotesRegister = local.notesRegister;
          droppedNotesEvent = PartyEvent(
            id: 'conflict_notes_${remote.notesRegister.timestamp.physicalTime}_${remote.notesRegister.timestamp.nodeId}',
            roomCode: remote.roomState.roomCode.isNotEmpty
                ? remote.roomState.roomCode
                : remote.roomState.roomId,
            type: 'notesConflictOverwrite',
            playerName: remote.notesRegister.timestamp.nodeId,
            details: remote.notesRegister.value,
            timestamp: DateTime.fromMillisecondsSinceEpoch(
              remote.notesRegister.timestamp.physicalTime > 0
                  ? remote.notesRegister.timestamp.physicalTime
                  : _networkTimeProvider(),
              isUtc: true,
            ),
          );
        }
      }
    } else {
      mergedNotesRegister = local.notesRegister.merge(remote.notesRegister);
    }

    // 3. Party Purse: Pure CvRDT lattice join over PN-counters across all denominations
    final mergedPurse = local.partyPurse.merge(remote.partyPurse);

    // 4. Change Log: Merged and deduplicated by event ID
    final combinedLocalChangeLog = droppedNotesEvent != null
        ? [...local.changeLog, droppedNotesEvent]
        : local.changeLog;
    final mergedChangeLog =
        _mergeChangeLogs(combinedLocalChangeLog, remote.changeLog);

    // 5. Party Roster: Granular merge preserving order and respecting removals in changelog
    final mergedPartyCharacterIds = _mergePartyRosters(
      local: local.partyCharacterIds,
      remote: remote.partyCharacterIds,
      changeLog: mergedChangeLog,
    );

    // 6. Pinned Rules: Set Union
    final mergedPinnedRules = {...local.pinnedRuleIds, ...remote.pinnedRuleIds};

    // 7. Room Node State: Pure CRDT sub-resource reconciliation (activeMinions, activeEncounter)
    final mergedRoomState = _mergeRoomState(
      local.roomState,
      remote.roomState,
    );

    return local.copyWith(
      name: mergedName,
      lastPlayedAt: mergedLastPlayedAt,
      notesRegister: mergedNotesRegister,
      partyPurse: mergedPurse,
      partyCharacterIds: mergedPartyCharacterIds,
      pinnedRuleIds: mergedPinnedRules,
      roomState: mergedRoomState,
      changeLog: mergedChangeLog,
    );
  }

  RoomNodeState _mergeRoomState(
    RoomNodeState local,
    RoomNodeState remote,
  ) {
    final title = remote.title.isNotEmpty && remote.title != local.title
        ? remote.title
        : local.title;
    final description =
        remote.description.isNotEmpty && remote.description != local.description
            ? remote.description
            : (local.description.isNotEmpty
                ? local.description
                : remote.description);

    // Pure CRDT OR-Set merges for minions and encounters with tombstone tracking
    final mergedMinions = local.activeMinions.merge(remote.activeMinions);
    final mergedEncounter = local.activeEncounter.merge(remote.activeEncounter);

    // Merge containers and entityLinks deduplicated by ID
    final entityLinkMap = <String, RoomEntityLink>{};
    for (final l in local.entityLinks) {
      entityLinkMap[l.entityId] = l;
    }
    for (final r in remote.entityLinks) {
      entityLinkMap[r.entityId] = r;
    }

    final containerMap = <String, LootContainer>{};
    for (final c in local.containers) {
      containerMap[c.containerId] = c;
    }
    for (final c in remote.containers) {
      containerMap[c.containerId] = c;
    }

    return local.copyWith(
      title: title,
      description: description,
      entityLinks: entityLinkMap.values.toList(),
      containers: containerMap.values.toList(),
      activeMinions: mergedMinions,
      activeEncounter: mergedEncounter,
    );
  }

  List<PartyEvent> _mergeChangeLogs(
    List<PartyEvent> local,
    List<PartyEvent> remote,
  ) {
    final eventMap = <String, PartyEvent>{};
    for (final ev in local) {
      eventMap[ev.id] = ev;
    }
    for (final ev in remote) {
      eventMap[ev.id] = ev;
    }
    final list = eventMap.values.toList()
      ..sort((a, b) => a.timestamp.compareTo(b.timestamp));
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

    final merged = <String>[];
    for (final id in local) {
      if (!removed.contains(id) && !merged.contains(id)) {
        merged.add(id);
      }
    }
    for (final id in remote) {
      if (!removed.contains(id) && !merged.contains(id)) {
        merged.add(id);
      }
    }
    return merged;
  }
}
