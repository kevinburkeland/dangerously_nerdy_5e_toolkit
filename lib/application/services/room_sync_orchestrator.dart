import 'dart:async';
import 'dart:collection';
import 'package:collection/collection.dart';
import 'package:meta/meta.dart';
import 'package:mutex/mutex.dart';
import 'package:uuid/uuid.dart';
import 'package:vtt_engine_core/crdt/crdt_or_set.dart';
import 'package:vtt_engine_core/models/campaign_profile.dart';
import 'package:vtt_engine_core/ports/i_campaign_repository.dart';
import 'package:vtt_engine_core/ports/i_p2p_transport_port.dart';
import 'package:vtt_engine_core/ports/i_room_sync_payload_port.dart';
import 'cascading_transport_router.dart';
import 'clock_sync_service.dart';
import 'room_connection_telemetry.dart';
import 'room_state_reconciliation_service.dart';
import 'package:vtt_engine_core/models/party_purse.dart';
import '../../services/dice_room_service.dart';

/// Application service orchestrating bidirectional synchronization between
/// the cascading P2P network transport mesh and local IndexedDB/Hive persistence.
///
/// Employs granular mutation tokens and an applied profile hash ring to eliminate echo loops
/// when network payloads are persisted, without holding blocking mutex locks over disk I/O.
class RoomSyncOrchestrator {
  final IP2pTransportPort transportPort;
  final ICampaignRepository campaignRepo;
  final RoomStateReconciliationService reconciliationService;
  final ClockSyncService clockSyncService;
  final DiceRoomService diceRoomService;
  final IRoomSyncPayloadPort payloadMapper;
  final bool isHost;
  final String localNodeId;

  /// Backwards-compatible alias for [localNodeId].
  @Deprecated('Use localNodeId instead')
  String get hostNodeId => localNodeId;
  final Duration telemetryInterval;
  final Duration milestoneInterval;
  final Duration heartbeatTtl;

  CascadingTransportRouter? get router =>
      transportPort is CascadingTransportRouter
          ? (transportPort as CascadingTransportRouter)
          : null;

  StreamSubscription<String>? _networkSub;
  StreamSubscription<CampaignProfile?>? _localDbSub;
  StreamSubscription<TransportState>? _transportStateSub;
  Timer? _milestoneTimer;
  Timer? _telemetryTimer;

  static const int maxProcessedPayloadHashes = 500;
  final LinkedHashMap<String, bool> _processedPayloadHashes =
      LinkedHashMap<String, bool>();
  final Map<String, int> _lastSeenSequenceByNode = <String, int>{};
  final int Function() _localTimeProvider;

  final Mutex _syncMutex = Mutex();
  final Set<int> _appliedProfileHashRing = <int>{};
  static const int maxAppliedHashRingSize = 100;
  bool _isApplyingRemoteSync = false;
  int _localSequenceNumber = 0;
  int _lastProfileSyncTimestamp = 0;
  CampaignProfile? _lastEmittedProfile;
  CrdtOrSet<String> _trackedRulesSet = const CrdtOrSet<String>.empty();
  StreamController<RoomConnectionTelemetry> _telemetryController =
      StreamController<RoomConnectionTelemetry>.broadcast(sync: false);
  final StreamController<SyncErrorEvent> _deadLetterController =
      StreamController<SyncErrorEvent>.broadcast(sync: false);

  /// Reactive stream broadcasting sync errors, dead letters, and schema mismatches.
  Stream<SyncErrorEvent> get deadLetterStream => _deadLetterController.stream;

  RoomSyncOrchestrator({
    IP2pTransportPort? transportPort,
    CascadingTransportRouter? router,
    required this.campaignRepo,
    required this.reconciliationService,
    required this.clockSyncService,
    DiceRoomService? diceRoomService,
    IRoomSyncPayloadPort? payloadMapper,
    int Function()? localTimeProvider,
    this.isHost = false,
    String? localNodeId,
    @Deprecated('Use localNodeId instead') String? hostNodeId,
    this.telemetryInterval = const Duration(seconds: 2),
    this.milestoneInterval = const Duration(minutes: 5),
    Duration? heartbeatTtl,
  })  : localNodeId = localNodeId ?? hostNodeId ?? const Uuid().v4(),
        transportPort = transportPort ?? router!,
        diceRoomService = diceRoomService ?? DiceRoomService(),
        payloadMapper = payloadMapper ??
            IRoomSyncPayloadPort.defaultProvider?.call() ??
            const _NoOpRoomSyncPayloadPort(),
        _localTimeProvider =
            localTimeProvider ?? (() => clockSyncService.currentNetworkTimeMs),
        heartbeatTtl = heartbeatTtl ?? (transportPort ?? router)!.heartbeatTtl,
        assert(
          transportPort != null || router != null,
          'Must provide either transportPort or router',
        );

  /// Tracked payload hashes for deduplication (exposed for testing).
  @visibleForTesting
  Set<String> get processedPayloadHashes =>
      Set.unmodifiable(_processedPayloadHashes.keys);

  bool _isDuplicatePayload(String payloadHash) {
    if (_processedPayloadHashes.containsKey(payloadHash)) {
      _processedPayloadHashes.remove(payloadHash);
      _processedPayloadHashes[payloadHash] = true;
      return true;
    }
    _processedPayloadHashes[payloadHash] = true;
    if (_processedPayloadHashes.length > maxProcessedPayloadHashes) {
      _processedPayloadHashes.remove(_processedPayloadHashes.keys.first);
    }
    return false;
  }

  /// Last processed timestamp for room_sync_full payloads.
  int get lastProfileSyncTimestamp => _lastProfileSyncTimestamp;

  /// Visible for testing and debugging sync lock state.
  bool get isProcessingNetworkPayload => _syncMutex.isLocked;

  /// Returns whether synchronization is actively listening to transport and DB streams.
  bool get isSynchronizing => _networkSub != null && _localDbSub != null;

  /// Current in-memory tracked CRDT set (exposed for inspection and testing).
  @visibleForTesting
  CrdtOrSet<String> get trackedRulesSet => _trackedRulesSet;

  @visibleForTesting
  set trackedRulesSet(CrdtOrSet<String> set) => _trackedRulesSet = set;

  /// Activates bidirectional synchronization and begins telemetry polling.
  void startSynchronization() {
    if (isSynchronizing) return;
    if (_telemetryController.isClosed) {
      _telemetryController =
          StreamController<RoomConnectionTelemetry>.broadcast(sync: false);
    }
    _networkSub =
        transportPort.watchIncomingPayloads().listen(_handleIncomingPayload);
    _localDbSub =
        campaignRepo.watchActiveProfile().listen(_handleLocalProfileChange);
    if (transportPort is CascadingTransportRouter) {
      _transportStateSub = (transportPort as CascadingTransportRouter)
          .onStateChanged
          .listen((_) => _emitTelemetry());
    }

    _startTelemetryMonitor();

    if (isHost) {
      _startMilestoneFlushTimer();
    }
  }

  /// Returns the current telemetry snapshot synchronously.
  RoomConnectionTelemetry get currentTelemetry => RoomConnectionTelemetry(
        state: transportPort.currentState,
        peerCount: transportPort.peerLastSeen.length,
        isHost: isHost,
      );

  /// Reactive stream broadcasting connection telemetry snapshots.
  /// Immediately emits the latest [currentTelemetry] to each new subscriber upon listening.
  Stream<RoomConnectionTelemetry> watchTelemetry() {
    if (_telemetryController.isClosed) {
      _telemetryController =
          StreamController<RoomConnectionTelemetry>.broadcast(sync: false);
    }
    late StreamController<RoomConnectionTelemetry> subController;
    StreamSubscription<RoomConnectionTelemetry>? sub;

    subController = StreamController<RoomConnectionTelemetry>.broadcast(
      sync: false,
      onListen: () {
        subController.add(currentTelemetry);
        sub = _telemetryController.stream.listen(
          (t) {
            if (!subController.isClosed) subController.add(t);
          },
          onError: (err, st) {
            if (!subController.isClosed) subController.addError(err, st);
          },
        );
      },
      onCancel: () {
        sub?.cancel();
        if (!subController.isClosed) {
          subController.close();
        }
      },
    );

    return subController.stream;
  }

  void _emitTelemetry() {
    if (_telemetryController.isClosed) return;
    _telemetryController.add(currentTelemetry);
  }

  void _startTelemetryMonitor() {
    _telemetryTimer?.cancel();
    _emitTelemetry();
    _telemetryTimer = Timer.periodic(telemetryInterval, (_) {
      _emitTelemetry();
    });
  }

  void _recordAppliedProfileHash(int hash) {
    _appliedProfileHashRing.add(hash);
    if (_appliedProfileHashRing.length > maxAppliedHashRingSize) {
      _appliedProfileHashRing.remove(_appliedProfileHashRing.first);
    }
  }

  /// Handles incoming JSON payloads from the P2P transport.
  @visibleForTesting
  Future<void> handleIncomingPayload(String jsonPayload) =>
      _handleIncomingPayload(jsonPayload);

  Future<void> _handleIncomingPayload(String jsonPayload) async {
    // 1. Prevent LRU Deduplication Poisoning: parse payload first and discard
    // unknown/malformed payloads prior to updating the LRU cache.
    final message = payloadMapper.parsePayload(jsonPayload);
    if (message is UnknownSyncMessage) return;

    final payloadHash = payloadMapper.computePayloadHash(jsonPayload);
    if (_isDuplicatePayload(payloadHash)) {
      return;
    }

    if (message.originNodeId.isNotEmpty &&
        message.originNodeId == localNodeId) {
      return;
    }

    CampaignProfile? profileToSave;

    // 2. Narrow Critical Section: restrict mutex lock strictly to in-memory state
    // reconciliation, vector clock updates, and CRDT joins.
    await _syncMutex.protect(() async {
      try {
        // Per-node vector clock tracking: record maximum sequence observed per node
        // Out-of-order relays and offline burst mutations merge deterministically via CRDTs rather than being dropped
        if (message.originNodeId.isNotEmpty && message.originSeq > 0) {
          final currentSeq = _lastSeenSequenceByNode[message.originNodeId] ?? 0;
          if (message.originSeq > currentSeq) {
            _lastSeenSequenceByNode[message.originNodeId] = message.originSeq;
          }
        }

        switch (message) {
          case FullProfileSyncMessage msg:
            final remoteProfile = msg.profile;
            final localProfile = campaignRepo.activeProfile;

            if (localProfile != null && localProfile.id == remoteProfile.id) {
              // Reconcile pinned rules CRDT set if present
              if (msg.pinnedRulesDelta != null) {
                _trackedRulesSet =
                    _trackedRulesSet.merge(msg.pinnedRulesDelta!);
              }

              // Reconcile party purse CRDT delta if present in envelope
              PartyPurse effectiveRemotePurse = remoteProfile.partyPurse;
              if (msg.purseDelta != null) {
                effectiveRemotePurse =
                    effectiveRemotePurse.merge(msg.purseDelta!);
              }
              final remoteWithPurse =
                  remoteProfile.copyWith(partyPurse: effectiveRemotePurse);

              // Reconcile sub-resources deterministically at field-level via CRDTs
              final reconciledProfile = reconciliationService.reconcileProfile(
                local: localProfile,
                remote: remoteWithPurse,
                inboundTimestampMs: msg.timestamp,
                localTimestampMs: _lastProfileSyncTimestamp,
              );

              if (msg.timestamp > _lastProfileSyncTimestamp) {
                _lastProfileSyncTimestamp = msg.timestamp;
              }

              _recordAppliedProfileHash(reconciledProfile.hashCode);
              _lastEmittedProfile = reconciledProfile;
              profileToSave = reconciledProfile;
            }

          case PurseDeltaSyncMessage msg:
            final localProfile = campaignRepo.activeProfile;
            if (localProfile != null) {
              // Converge purse via CvRDT PN-counter lattice join
              final updatedPurse = localProfile.partyPurse.merge(msg.purse);
              if (updatedPurse != localProfile.partyPurse) {
                final updatedProfile =
                    localProfile.copyWith(partyPurse: updatedPurse);
                _recordAppliedProfileHash(updatedProfile.hashCode);
                _lastEmittedProfile = updatedProfile;
                profileToSave = updatedProfile;
              }
            }

          case OrSetDeltaSyncMessage msg:
            final localProfile = campaignRepo.activeProfile;
            if (localProfile != null) {
              _trackedRulesSet = _trackedRulesSet.merge(msg.rulesSet);

              // Reflect merged active values into profile's pinned rules
              final updatedProfile = localProfile.copyWith(
                pinnedRuleIds: _trackedRulesSet.activeValues.toSet(),
              );

              _recordAppliedProfileHash(updatedProfile.hashCode);
              _lastEmittedProfile = updatedProfile;
              profileToSave = updatedProfile;
            }

          case DiceRollSyncMessage msg:
            diceRoomService.ingestRemoteRoll(msg.roll);

          case UnknownSyncMessage():
            break;
        }
      } catch (error, stackTrace) {
        if (!_deadLetterController.isClosed) {
          _deadLetterController.add(SyncErrorEvent(
            error: error,
            stackTrace: stackTrace,
            rawPayload: jsonPayload,
            parsedMessage: message,
          ));
        }
        var isDebug = false;
        assert(() {
          isDebug = true;
          return true;
        }());
        if (isDebug) {
          rethrow;
        }
      }
    });

    // 3. Decouple disk I/O and repository event dispatches outside the mutex lock
    if (profileToSave != null) {
      _isApplyingRemoteSync = true;
      try {
        await campaignRepo.saveProfileImmediate(profileToSave!);
      } finally {
        scheduleMicrotask(() {
          _isApplyingRemoteSync = false;
        });
      }
    }
  }

  /// Handles local profile changes emitted by the campaign repository.
  @visibleForTesting
  Future<void> handleLocalProfileChange(CampaignProfile? profile) =>
      _handleLocalProfileChange(profile);

  Future<void> _handleLocalProfileChange(CampaignProfile? profile) async {
    if (profile == null) return;
    if (_isApplyingRemoteSync) {
      return;
    }
    if (_appliedProfileHashRing.contains(profile.hashCode)) {
      return;
    }

    String? payloadToSend;

    await _syncMutex.protect(() async {
      final last = _lastEmittedProfile;
      _lastEmittedProfile = profile;

      // Focused CRDT delta: if only partyPurse mutated, emit crdt_purse_delta
      if (last != null &&
          last.id == profile.id &&
          last.partyPurse != profile.partyPurse &&
          last.name == profile.name &&
          last.notesMarkdown == profile.notesMarkdown &&
          last.pinnedRuleIds == profile.pinnedRuleIds &&
          last.roomState == profile.roomState &&
          const ListEquality()
              .equals(last.partyCharacterIds, profile.partyCharacterIds)) {
        payloadToSend = payloadMapper.serializePurseDelta(
          campaignId: profile.id,
          purse: profile.partyPurse,
          originNodeId: localNodeId,
          originSeq: ++_localSequenceNumber,
          timestamp: _localTimeProvider(),
        );
        return;
      }

      // Focused CRDT delta: if only pinnedRuleIds mutated, emit crdt_or_set_delta
      if (last != null &&
          last.id == profile.id &&
          last.pinnedRuleIds != profile.pinnedRuleIds &&
          last.partyPurse == profile.partyPurse &&
          last.name == profile.name &&
          last.notesMarkdown == profile.notesMarkdown &&
          last.roomState == profile.roomState &&
          const ListEquality()
              .equals(last.partyCharacterIds, profile.partyCharacterIds)) {
        payloadToSend = payloadMapper.serializeOrSetDelta(
          campaignId: profile.id,
          rulesSet: _trackedRulesSet,
          originNodeId: localNodeId,
          originSeq: ++_localSequenceNumber,
          timestamp: _localTimeProvider(),
        );
        return;
      }

      payloadToSend = payloadMapper.serializeFullProfileSync(
        profile: profile,
        originNodeId: localNodeId,
        originSeq: ++_localSequenceNumber,
        timestamp: _localTimeProvider(),
        trackedRulesSet: _trackedRulesSet,
      );
    });

    if (payloadToSend != null) {
      try {
        await transportPort.broadcastPayload(payloadToSend!);
      } catch (_) {}
    }
  }

  void _startMilestoneFlushTimer() {
    _milestoneTimer?.cancel();
    _milestoneTimer = Timer.periodic(milestoneInterval, (_) async {
      await executeHostMilestoneFlush();
    });
  }

  /// Host milestone flush execution: prunes tombstones and commits state.
  Future<void> executeHostMilestoneFlush() async {
    final activeProfile = campaignRepo.activeProfile;
    if (activeProfile == null) return;

    final authoritativeTimestamp =
        _localTimeProvider() - (heartbeatTtl.inMilliseconds * 2);

    // Prune tracked CRDT tombstones older than the milestone snapshot
    if (_trackedRulesSet.tombstones.isNotEmpty) {
      _trackedRulesSet = reconciliationService.executeMilestonePrune<String>(
        _trackedRulesSet,
        authoritativeTimestamp,
        localNodeId,
      );
    }

    // Persist immediately to establish the snapshot boundary
    _isApplyingRemoteSync = true;
    try {
      await campaignRepo.saveProfileImmediate(activeProfile);
    } finally {
      scheduleMicrotask(() {
        _isApplyingRemoteSync = false;
      });
    }
  }

  /// Cancels all subscriptions, timers, and emits offline telemetry.
  void stopSynchronization() {
    _networkSub?.cancel();
    _networkSub = null;
    _localDbSub?.cancel();
    _localDbSub = null;
    _transportStateSub?.cancel();
    _transportStateSub = null;
    _milestoneTimer?.cancel();
    _milestoneTimer = null;
    _telemetryTimer?.cancel();
    _telemetryTimer = null;
    _lastProfileSyncTimestamp = 0;
    _isApplyingRemoteSync = false;
    _processedPayloadHashes.clear();
    _lastSeenSequenceByNode.clear();
    _emitTelemetry();
  }

  /// Permanently tears down the orchestrator and closes the telemetry controller.
  void dispose() {
    stopSynchronization();
    if (!_telemetryController.isClosed) {
      _telemetryController.close();
    }
    if (!_deadLetterController.isClosed) {
      _deadLetterController.close();
    }
  }
}

/// Fallback no-op implementation of [IRoomSyncPayloadPort] when not configured.
class _NoOpRoomSyncPayloadPort implements IRoomSyncPayloadPort {
  const _NoOpRoomSyncPayloadPort();

  @override
  String computePayloadHash(String jsonPayload) => '';

  @override
  IncomingRoomSyncMessage parsePayload(String jsonPayload) =>
      const UnknownSyncMessage();

  @override
  String serializeFullProfileSync({
    required CampaignProfile profile,
    required String originNodeId,
    required int originSeq,
    required int timestamp,
    CrdtOrSet<String>? trackedRulesSet,
  }) =>
      '';

  @override
  String serializePurseDelta({
    required String campaignId,
    required PartyPurse purse,
    required String originNodeId,
    required int originSeq,
    required int timestamp,
  }) =>
      '';

  @override
  String serializeOrSetDelta({
    required String campaignId,
    required CrdtOrSet<String> rulesSet,
    required String originNodeId,
    required int originSeq,
    required int timestamp,
  }) =>
      '';
}

/// Represents an unhandled error, dead-letter, or distributed CRDT schema mismatch.
@immutable
class SyncErrorEvent {
  final Object error;
  final StackTrace stackTrace;
  final String rawPayload;
  final IncomingRoomSyncMessage? parsedMessage;

  const SyncErrorEvent({
    required this.error,
    required this.stackTrace,
    required this.rawPayload,
    this.parsedMessage,
  });
}
