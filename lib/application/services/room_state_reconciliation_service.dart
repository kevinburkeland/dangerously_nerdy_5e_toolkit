import 'package:vtt_engine_core/crdt/crdt_lww_register.dart';
import 'package:vtt_engine_core/crdt/crdt_or_set.dart';
import 'package:vtt_engine_core/crdt/hybrid_logical_clock.dart';
import 'package:vtt_engine_core/models/campaign_profile.dart';
import 'package:vtt_engine_core/models/party_purse.dart';
import 'package:vtt_engine_core/rules/ruleset_edition.dart';
import 'package:vtt_engine_core/utils/aggregate_join_utils.dart';
import '../../models/domain/loot_models.dart';
import '../../models/domain/session_graph_models.dart';
import '../../models/party/party_event.dart';

/// Application service orchestrating CRDT state reconciliation, tombstone retention/causal safety policies,
/// and deterministic field-level campaign profile merging with narrow subresource fault isolation.
class RoomStateReconciliationService {
  RoomStateReconciliationService({
    int Function()? networkTimeProvider,
  });

  /// Retains all tombstones in [targetSet] indefinitely until causal stability can be proven.
  CrdtOrSet<T> retainTombstones<T>(CrdtOrSet<T> targetSet) {
    return targetSet;
  }

  @Deprecated('Elapsed time does not guarantee causal acknowledgement. Tombstones are retained indefinitely.')
  CrdtOrSet<T> safePrune<T>(
    CrdtOrSet<T> targetSet,
    HybridLogicalClock candidateThreshold, {
    int safeBufferMs = 0,
  }) {
    return retainTombstones(targetSet);
  }

  @Deprecated('Milestone timestamps do not guarantee causal acknowledgement. Tombstones are retained indefinitely.')
  CrdtOrSet<T> executeMilestonePrune<T>(
    CrdtOrSet<T> targetSet,
    int milestoneEpochMs,
    String hostNodeId, {
    int safeBufferMs = 0,
  }) {
    return retainTombstones(targetSet);
  }

  /// Reconciles an incoming remote [CampaignProfile] with the [local] campaign state.
  /// Executes the pure canonical aggregate join over two valid [CampaignProfile] instances.
  ///
  /// Throws [StateError] on any invalid state or unversioned collision.
  CampaignProfile joinValid(CampaignProfile a, CampaignProfile b) {
    return CampaignProfile.join(a, b);
  }

  /// Reconciles an incoming remote [CampaignProfile] with the [local] campaign state.
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
  /// Delegates each independent subresource join directly to canonical engine helpers.
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

    final canonicalEdition = local.edition == remote.edition
        ? local.edition
        : RulesetIdentifier(local.rulesetId);

    final faults = <ReconciliationFieldFault>[];

    // 1. Root metadata: name, createdAt, lastPlayedAt
    String mergedName = local.name;
    try {
      mergedName = joinUnversionedString(
        local.name,
        remote.name,
        fieldName: 'CampaignProfile.name',
      );
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
    try {
      mergedNotesRegister = local.notesRegister.merge(remote.notesRegister);
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

    // 4. Change Log: canonical changelog join with fault isolation
    List<PartyEvent> mergedChangeLog = local.changeLog;
    try {
      mergedChangeLog = joinChangeLog(local.changeLog, remote.changeLog);
    } catch (e, st) {
      faults.add(ReconciliationFieldFault(field: 'changeLog', error: e, stackTrace: st));
      mergedChangeLog = local.changeLog;
    }

    // 5. Party Roster: canonical CRDT OR-set join with fault isolation
    CrdtOrSet<String> mergedPartyRoster = local.partyRoster;
    try {
      mergedPartyRoster = joinPartyRosterCrdt(local.partyRoster, remote.partyRoster);
    } catch (e, st) {
      faults.add(ReconciliationFieldFault(field: 'partyRoster', error: e, stackTrace: st));
      mergedPartyRoster = local.partyRoster;
    }

    // 6. Pinned Rules: canonical CRDT OR-set join with fault isolation
    CrdtOrSet<String> mergedPinnedRules = local.pinnedRules;
    try {
      mergedPinnedRules = joinPinnedRules(local.pinnedRules, remote.pinnedRules);
    } catch (e, st) {
      faults.add(ReconciliationFieldFault(field: 'pinnedRules', error: e, stackTrace: st));
      mergedPinnedRules = local.pinnedRules;
    }

    // 7. Room Node State: Sub-resource reconciliation with narrow fault isolation
    final roomRecon = _reconcileRoomStateSafely(
      local: local.roomState,
      remote: remote.roomState,
    );
    faults.addAll(roomRecon.fieldFaults);

    final mergedProfile = local.copyWith(
      name: mergedName,
      edition: canonicalEdition,
      createdAt: mergedCreatedAt,
      lastPlayedAt: mergedLastPlayedAt,
      notesRegister: mergedNotesRegister,
      partyPurse: mergedPurse,
      partyRoster: mergedPartyRoster,
      pinnedRules: mergedPinnedRules,
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
      mergedRoomId = joinImmutableId(
        local.roomId,
        remote.roomId,
        fieldName: 'RoomNodeState.roomId',
      );
    } catch (e, st) {
      faults.add(ReconciliationFieldFault(field: 'roomState.roomId', error: e, stackTrace: st));
      mergedRoomId = local.roomId;
    }

    String mergedRoomCode = local.roomCode;
    try {
      mergedRoomCode = joinImmutableId(
        local.roomCode,
        remote.roomCode,
        fieldName: 'RoomNodeState.roomCode',
      );
    } catch (e, st) {
      faults.add(ReconciliationFieldFault(field: 'roomState.roomCode', error: e, stackTrace: st));
      mergedRoomCode = local.roomCode;
    }

    String mergedTitle = local.title;
    try {
      mergedTitle = joinUnversionedString(
        local.title,
        remote.title,
        fieldName: 'RoomNodeState.title',
      );
    } catch (e, st) {
      faults.add(ReconciliationFieldFault(field: 'roomState.title', error: e, stackTrace: st));
      mergedTitle = local.title;
    }

    String mergedDescription = local.description;
    try {
      mergedDescription = joinUnversionedString(
        local.description,
        remote.description,
        fieldName: 'RoomNodeState.description',
      );
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

    // Custom properties: canonical per-key join with fault isolation
    Map<String, dynamic> mergedCustomProperties = local.customProperties;
    try {
      mergedCustomProperties = joinCustomProperties(
        local.customProperties,
        remote.customProperties,
        context: 'RoomNodeState.customProperties',
      );
    } catch (e, st) {
      faults.add(ReconciliationFieldFault(field: 'roomState.customProperties', error: e, stackTrace: st));
      mergedCustomProperties = local.customProperties;
    }

    // Entity links: canonical OR-Set join with fault isolation
    CrdtOrSet<RoomEntityLink> mergedLinks = local.entityLinksCrdt;
    try {
      mergedLinks = joinEntityLinks(local.entityLinksCrdt, remote.entityLinksCrdt);
    } catch (e, st) {
      faults.add(ReconciliationFieldFault(field: 'roomState.entityLinks', error: e, stackTrace: st));
      mergedLinks = local.entityLinksCrdt;
    }

    // Entity instances: canonical join with fault isolation
    List<EntityInstance> mergedInstances = local.entityInstances;
    try {
      mergedInstances = joinEntityInstances(local.entityInstances, remote.entityInstances);
    } catch (e, st) {
      faults.add(ReconciliationFieldFault(field: 'roomState.entityInstances', error: e, stackTrace: st));
      mergedInstances = local.entityInstances;
    }

    // Containers: canonical join with fault isolation
    List<LootContainer> mergedContainers = local.containers;
    try {
      mergedContainers = joinContainers(local.containers, remote.containers);
    } catch (e, st) {
      faults.add(ReconciliationFieldFault(field: 'roomState.containers', error: e, stackTrace: st));
      mergedContainers = local.containers;
    }

    final mergedRoomState = RoomNodeState(
      roomId: mergedRoomId,
      roomCode: mergedRoomCode,
      title: mergedTitle,
      description: mergedDescription,
      entityLinksCrdt: mergedLinks,
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
