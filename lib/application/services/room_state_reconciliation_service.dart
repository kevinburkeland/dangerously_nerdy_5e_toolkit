import '../../domain/crdt/crdt_or_set.dart';
import '../../domain/crdt/hybrid_logical_clock.dart';
import '../../domain/models/campaign_profile.dart';
import '../../models/domain/session_graph_models.dart';
import '../../models/party/party_event.dart';
import '../../models/party/party_purse.dart';

/// Application service orchestrating safe CRDT state reconciliation, tombstone pruning,
/// and deterministic field-level campaign profile merging.
class RoomStateReconciliationService {
  final int Function() _networkTimeProvider;

  RoomStateReconciliationService({
    int Function()? networkTimeProvider,
  }) : _networkTimeProvider =
            networkTimeProvider ?? (() => DateTime.now().toUtc().millisecondsSinceEpoch);

  /// Prunes an OR-Set only if the provided threshold timestamp has been globally
  /// acknowledged by the milestone snapshot ledger and is strictly older than network time.
  ///
  /// If [globallyAcknowledgedThreshold] is in the present or future relative to network time
  /// (due to transient clock skew or late clock sync), gracefully defers pruning and returns [targetSet]
  /// intact rather than throwing an unhandled exception that disrupts active sessions.
  CrdtOrSet<T> safePrune<T>(
    CrdtOrSet<T> targetSet,
    HybridLogicalClock globallyAcknowledgedThreshold,
  ) {
    // Safety check: ensure we aren't pruning with an unverified present or future timestamp
    final currentNetworkTime = _networkTimeProvider();
    if (globallyAcknowledgedThreshold.physicalTime >= currentNetworkTime) {
      // Gracefully defer pruning to prevent premature tombstone deletion during clock skew
      return targetSet;
    }

    return targetSet.prune(globallyAcknowledgedThreshold);
  }

  /// Prunes tombstones using an authoritative milestone timestamp provided by the ledger/server.
  CrdtOrSet<T> executeMilestonePrune<T>(
    CrdtOrSet<T> targetSet,
    int serverAcknowledgedEpochMs,
    String hostNodeId,
  ) {
    final currentNetworkTime = _networkTimeProvider();
    final safeEpoch = serverAcknowledgedEpochMs >= currentNetworkTime
        ? currentNetworkTime - 1
        : serverAcknowledgedEpochMs;

    final threshold = HybridLogicalClock(
      physicalTime: safeEpoch,
      logicalCounter: 0,
      nodeId: hostNodeId,
    );

    return targetSet.prune(threshold);
  }

  /// Reconciles an incoming remote [CampaignProfile] with the [local] campaign state.
  /// Merges distinct sub-resources (notes, party purse, party roster, room metadata, minions, encounters)
  /// deterministically instead of wholesale overwriting the local profile.
  CampaignProfile reconcileProfile({
    required CampaignProfile local,
    required CampaignProfile remote,
    required int inboundTimestampMs,
    required int localTimestampMs,
  }) {
    if (local.id != remote.id) {
      return local;
    }

    final isRemoteNewer = inboundTimestampMs >= localTimestampMs;

    // 1. Root metadata (name, edition, lastPlayedAt)
    final mergedName =
        isRemoteNewer && remote.name.isNotEmpty ? remote.name : local.name;
    final mergedLastPlayedAt = remote.lastPlayedAt.isAfter(local.lastPlayedAt)
        ? remote.lastPlayedAt
        : local.lastPlayedAt;

    // 2. Notes: LWW based on timestamp, preserving non-empty local notes if remote is empty
    final mergedNotes = isRemoteNewer && remote.notesMarkdown.isNotEmpty
        ? remote.notesMarkdown
        : (local.notesMarkdown.isNotEmpty ? local.notesMarkdown : remote.notesMarkdown);

    // 3. Party Purse: Granular field-by-field reconciliation
    final mergedPurse = _mergePartyPurse(
      local.partyPurse,
      remote.partyPurse,
      isRemoteNewer: isRemoteNewer,
    );

    // 4. Change Log: Merged and deduplicated by event ID
    final mergedChangeLog = _mergeChangeLogs(local.changeLog, remote.changeLog);

    // 5. Party Roster: Granular merge preserving order and respecting removals in changelog
    final mergedPartyCharacterIds = _mergePartyRosters(
      local: local.partyCharacterIds,
      remote: remote.partyCharacterIds,
      changeLog: mergedChangeLog,
      isRemoteNewer: isRemoteNewer,
    );

    // 6. Pinned Rules: Set Union
    final mergedPinnedRules = {...local.pinnedRuleIds, ...remote.pinnedRuleIds};

    // 7. Room Node State: Sub-resource reconciliation (activeMinions, activeEncounter, containers, entityLinks)
    final mergedRoomState = _mergeRoomState(
      local.roomState,
      remote.roomState,
      isRemoteNewer: isRemoteNewer,
    );

    return local.copyWith(
      name: mergedName,
      lastPlayedAt: mergedLastPlayedAt,
      notesMarkdown: mergedNotes,
      partyPurse: mergedPurse,
      partyCharacterIds: mergedPartyCharacterIds,
      pinnedRuleIds: mergedPinnedRules,
      roomState: mergedRoomState,
      changeLog: mergedChangeLog,
    );
  }

  RoomNodeState _mergeRoomState(
    RoomNodeState local,
    RoomNodeState remote, {
    required bool isRemoteNewer,
  }) {
    final title =
        isRemoteNewer && remote.title.isNotEmpty ? remote.title : local.title;
    final description = isRemoteNewer && remote.description.isNotEmpty
        ? remote.description
        : (local.description.isNotEmpty ? local.description : remote.description);

    // Merge activeMinions by id
    final minionMap = {for (final m in local.activeMinions) m.id: m};
    for (final m in remote.activeMinions) {
      if (!minionMap.containsKey(m.id) || isRemoteNewer) {
        minionMap[m.id] = m;
      }
    }

    // Merge activeEncounter by participantId
    final encounterMap = {for (final e in local.activeEncounter) e.participantId: e};
    for (final e in remote.activeEncounter) {
      if (!encounterMap.containsKey(e.participantId) || isRemoteNewer) {
        encounterMap[e.participantId] = e;
      }
    }

    return local.copyWith(
      title: title,
      description: description,
      activeMinions: minionMap.values.toList(),
      activeEncounter: encounterMap.values.toList(),
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

  PartyPurse _mergePartyPurse(
    PartyPurse local,
    PartyPurse remote, {
    required bool isRemoteNewer,
  }) {
    if (local == remote) return local;
    if (local.isEmpty) return remote;
    if (remote.isEmpty) return local;

    int reconcileCoin(int localCoin, int remoteCoin) {
      if (localCoin == remoteCoin) return localCoin;
      if (localCoin == 0) return remoteCoin;
      if (remoteCoin == 0) return localCoin;
      return isRemoteNewer ? remoteCoin : localCoin;
    }

    return PartyPurse(
      cp: reconcileCoin(local.cp, remote.cp),
      sp: reconcileCoin(local.sp, remote.sp),
      ep: reconcileCoin(local.ep, remote.ep),
      gp: reconcileCoin(local.gp, remote.gp),
      pp: reconcileCoin(local.pp, remote.pp),
    );
  }

  List<String> _mergePartyRosters({
    required List<String> local,
    required List<String> remote,
    required List<PartyEvent> changeLog,
    required bool isRemoteNewer,
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
