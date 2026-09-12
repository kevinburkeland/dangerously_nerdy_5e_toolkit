import 'dart:async';
import 'dart:convert';
import 'package:meta/meta.dart';
import 'package:mutex/mutex.dart';
import '../../domain/crdt/crdt_or_set.dart';
import '../../domain/models/campaign_profile.dart';
import '../../domain/ports/i_campaign_repository.dart';
import '../../domain/ports/i_p2p_transport_port.dart';
import '../../infrastructure/dtos/campaign_profile_dto.dart';
import '../../infrastructure/dtos/crdt/crdt_or_set_dto.dart';
import 'cascading_transport_router.dart';
import 'clock_sync_service.dart';
import 'room_connection_telemetry.dart';
import 'room_state_reconciliation_service.dart';
import '../../models/room_roll.dart';
import '../../services/dice_room_service.dart';

/// Application service orchestrating bidirectional synchronization between
/// the cascading P2P network transport mesh and local IndexedDB/Hive persistence.
///
/// Employs a mutex lock ([_isProcessingNetworkPayload]) to cancel echo loops
/// when network payloads are persisted and reactive database streams re-emit.
class RoomSyncOrchestrator {
  final IP2pTransportPort transportPort;
  final ICampaignRepository campaignRepo;
  final RoomStateReconciliationService reconciliationService;
  final ClockSyncService clockSyncService;
  final DiceRoomService diceRoomService;
  final bool isHost;
  final String hostNodeId;
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

  final Mutex _syncMutex = Mutex();
  CampaignProfile? _lastInboundProfile;
  int _lastProfileSyncTimestamp = 0;
  CrdtOrSet<String> _trackedRulesSet = const CrdtOrSet<String>();
  StreamController<RoomConnectionTelemetry> _telemetryController =
      StreamController<RoomConnectionTelemetry>.broadcast();

  RoomSyncOrchestrator({
    IP2pTransportPort? transportPort,
    CascadingTransportRouter? router,
    required this.campaignRepo,
    required this.reconciliationService,
    required this.clockSyncService,
    DiceRoomService? diceRoomService,
    this.isHost = false,
    this.hostNodeId = 'dm-host-prime',
    this.telemetryInterval = const Duration(seconds: 2),
    this.milestoneInterval = const Duration(minutes: 5),
    Duration? heartbeatTtl,
  })  : transportPort = transportPort ?? router!,
        diceRoomService = diceRoomService ?? DiceRoomService(),
        heartbeatTtl = heartbeatTtl ??
            (transportPort is CascadingTransportRouter
                ? transportPort.heartbeatTtl
                : (router?.heartbeatTtl ?? const Duration(seconds: 15))),
        assert(
          transportPort != null || router != null,
          'Must provide either transportPort or router',
        );

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
      _telemetryController = StreamController<RoomConnectionTelemetry>.broadcast();
    }
    _networkSub = transportPort.watchIncomingPayloads().listen(_handleIncomingPayload);
    _localDbSub = campaignRepo.watchActiveProfile().listen(_handleLocalProfileChange);
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
      _telemetryController = StreamController<RoomConnectionTelemetry>.broadcast();
    }
    late StreamController<RoomConnectionTelemetry> subController;
    StreamSubscription<RoomConnectionTelemetry>? sub;

    subController = StreamController<RoomConnectionTelemetry>.broadcast(
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

  /// Handles incoming JSON payloads from the P2P transport.
  @visibleForTesting
  Future<void> handleIncomingPayload(String jsonPayload) => _handleIncomingPayload(jsonPayload);

  Future<void> _handleIncomingPayload(String jsonPayload) async {
    await _syncMutex.protect(() async {
      try {
        final decoded = jsonDecode(jsonPayload);
        if (decoded is! Map<String, dynamic>) return;

        final type = decoded['type']?.toString();

        if (type == 'room_sync_full') {
          final payloadData = decoded['payload'];
          if (payloadData is! Map) return;

          final inboundTimestamp = (decoded['timestamp'] is num)
              ? (decoded['timestamp'] as num).toInt()
              : (int.tryParse(decoded['timestamp']?.toString() ?? '') ?? 0);

          if (inboundTimestamp <= _lastProfileSyncTimestamp) {
            return;
          }

          final remoteProfileDto = CampaignProfileDto.fromMap(
            Map<String, dynamic>.from(payloadData),
          );
          final remoteProfile = remoteProfileDto.toDomain();
          final localProfile = campaignRepo.activeProfile;

          if (localProfile != null && localProfile.id == remoteProfile.id) {
            // Reconcile pinned rules CRDT set if present
            if (decoded.containsKey('pinned_rules_crdt') && decoded['pinned_rules_crdt'] is Map) {
              try {
                final remoteRulesSet = CrdtOrSetDto.fromMap<String>(
                  Map<dynamic, dynamic>.from(decoded['pinned_rules_crdt'] as Map),
                  (raw) => raw.toString(),
                );
                _trackedRulesSet = _trackedRulesSet.merge(remoteRulesSet);
              } catch (_) {}
            }

            _lastProfileSyncTimestamp = inboundTimestamp;
            _lastInboundProfile = remoteProfile;
            await campaignRepo.saveProfileImmediate(remoteProfile);
          }
        } else if (type == 'crdt_or_set_delta') {
          final payloadData = decoded['payload'];
          if (payloadData is! Map) return;

          final localProfile = campaignRepo.activeProfile;
          if (localProfile != null) {
            final remoteSet = CrdtOrSetDto.fromMap<String>(
              Map<dynamic, dynamic>.from(payloadData),
              (raw) => raw.toString(),
            );

            // Execute CrdtOrSet.merge()
            _trackedRulesSet = _trackedRulesSet.merge(remoteSet);

            // Reflect merged active values into profile's pinned rules
            final updatedProfile = localProfile.copyWith(
              pinnedRuleIds: _trackedRulesSet.activeValues.toSet(),
            );
            _lastInboundProfile = updatedProfile;
            await campaignRepo.saveProfileImmediate(updatedProfile);
          }
        } else if (type == 'dice_roll') {
          final payloadData = decoded['payload'];
          if (payloadData is Map) {
            try {
              final roll = RoomRoll.fromMap(Map<String, dynamic>.from(payloadData));
              diceRoomService.ingestRemoteRoll(roll);
            } catch (_) {}
          }
        }
      } catch (_) {
        // Safely ignore malformed network payloads
      }
    });
  }

  /// Handles local profile changes emitted by the campaign repository.
  @visibleForTesting
  Future<void> handleLocalProfileChange(CampaignProfile? profile) =>
      _handleLocalProfileChange(profile);

  Future<void> _handleLocalProfileChange(CampaignProfile? profile) async {
    if (profile == null) return;
    if (_lastInboundProfile == profile) {
      _lastInboundProfile = null;
      return;
    }

    await _syncMutex.protect(() async {
      final dto = CampaignProfileDto.fromDomain(profile);
      final payloadMap = <String, dynamic>{
        'type': 'room_sync_full',
        'payload': dto.toMap(),
        'timestamp': DateTime.now().toUtc().millisecondsSinceEpoch + clockSyncService.currentOffsetMs,
      };

      if (_trackedRulesSet.items.isNotEmpty || _trackedRulesSet.tombstones.isNotEmpty) {
        payloadMap['pinned_rules_crdt'] = CrdtOrSetDto.toMap<String>(
          _trackedRulesSet,
          (val) => val,
        );
      }

      final payload = jsonEncode(payloadMap);

      try {
        await transportPort.broadcastPayload(payload);
      } catch (_) {}
    });
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
        DateTime.now().toUtc().millisecondsSinceEpoch +
        clockSyncService.currentOffsetMs -
        (heartbeatTtl.inMilliseconds * 2);

    // Prune tracked CRDT tombstones older than the milestone snapshot
    if (_trackedRulesSet.tombstones.isNotEmpty) {
      _trackedRulesSet = reconciliationService.executeMilestonePrune<String>(
        _trackedRulesSet,
        authoritativeTimestamp,
        hostNodeId,
      );
    }

    // Persist immediately to establish the snapshot boundary
    await campaignRepo.saveProfileImmediate(activeProfile);
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
    _lastInboundProfile = null;
    _emitTelemetry();
  }

  /// Permanently tears down the orchestrator and closes the telemetry controller.
  void dispose() {
    stopSynchronization();
    if (!_telemetryController.isClosed) {
      _telemetryController.close();
    }
  }
}
