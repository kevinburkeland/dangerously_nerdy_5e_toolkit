import 'dart:async';
import 'dart:convert';
import 'package:meta/meta.dart';
import '../../domain/crdt/crdt_or_set.dart';
import '../../domain/models/campaign_profile.dart';
import '../../domain/ports/i_campaign_repository.dart';
import '../../infrastructure/dtos/campaign_profile_dto.dart';
import '../../infrastructure/dtos/crdt/crdt_or_set_dto.dart';
import 'cascading_transport_router.dart';
import 'clock_sync_service.dart';
import 'room_connection_telemetry.dart';
import 'room_state_reconciliation_service.dart';

/// Application service orchestrating bidirectional synchronization between
/// the cascading P2P network transport mesh and local IndexedDB/Hive persistence.
///
/// Employs a mutex lock ([_isProcessingNetworkPayload]) to cancel echo loops
/// when network payloads are persisted and reactive database streams re-emit.
class RoomSyncOrchestrator {
  final CascadingTransportRouter router;
  final ICampaignRepository campaignRepo;
  final RoomStateReconciliationService reconciliationService;
  final ClockSyncService clockSyncService;
  final bool isHost;
  final String hostNodeId;
  final Duration telemetryInterval;
  final Duration milestoneInterval;

  StreamSubscription<String>? _networkSub;
  StreamSubscription<CampaignProfile?>? _localDbSub;
  StreamSubscription<TransportState>? _transportStateSub;
  Timer? _milestoneTimer;
  Timer? _telemetryTimer;

  bool _isProcessingNetworkPayload = false;
  CrdtOrSet<String> _trackedRulesSet = const CrdtOrSet<String>();
  final StreamController<RoomConnectionTelemetry> _telemetryController =
      StreamController<RoomConnectionTelemetry>.broadcast();

  RoomSyncOrchestrator({
    required this.router,
    required this.campaignRepo,
    required this.reconciliationService,
    required this.clockSyncService,
    this.isHost = false,
    this.hostNodeId = 'dm-host-prime',
    this.telemetryInterval = const Duration(seconds: 2),
    this.milestoneInterval = const Duration(minutes: 5),
  });

  /// Visible for testing and debugging sync lock state.
  bool get isProcessingNetworkPayload => _isProcessingNetworkPayload;

  /// Returns whether synchronization is actively listening to transport and DB streams.
  bool get isSynchronizing => _networkSub != null && _localDbSub != null;

  /// Current in-memory tracked CRDT set (exposed for inspection and testing).
  @visibleForTesting
  CrdtOrSet<String> get trackedRulesSet => _trackedRulesSet;

  @visibleForTesting
  set trackedRulesSet(CrdtOrSet<String> set) => _trackedRulesSet = set;

  /// Activates bidirectional synchronization and begins telemetry polling.
  void startSynchronization() {
    _networkSub = router.watchIncomingPayloads().listen(_handleIncomingPayload);
    _localDbSub = campaignRepo.watchActiveProfile().listen(_handleLocalProfileChange);
    _transportStateSub = router.onStateChanged.listen((_) => _emitTelemetry());

    _startTelemetryMonitor();

    if (isHost) {
      _startMilestoneFlushTimer();
    }
  }

  /// Reactive stream broadcasting connection telemetry snapshots.
  Stream<RoomConnectionTelemetry> watchTelemetry() => _telemetryController.stream;

  void _emitTelemetry() {
    if (_telemetryController.isClosed) return;
    _telemetryController.add(RoomConnectionTelemetry(
      state: router.currentState,
      peerCount: router.peerLastSeen.length,
      isHost: isHost,
    ));
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
    _isProcessingNetworkPayload = true;

    try {
      final decoded = jsonDecode(jsonPayload);
      if (decoded is! Map<String, dynamic>) return;

      final type = decoded['type']?.toString();

      if (type == 'room_sync_full') {
        final payloadData = decoded['payload'];
        if (payloadData is! Map) return;

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
          await campaignRepo.saveProfileImmediate(updatedProfile);
        }
      }
    } catch (_) {
      // Safely ignore malformed network payloads
    } finally {
      // Release lock safely after reactive stream microtasks finish firing
      scheduleMicrotask(() => _isProcessingNetworkPayload = false);
    }
  }

  /// Handles local profile changes emitted by the campaign repository.
  @visibleForTesting
  Future<void> handleLocalProfileChange(CampaignProfile? profile) =>
      _handleLocalProfileChange(profile);

  Future<void> _handleLocalProfileChange(CampaignProfile? profile) async {
    if (profile == null || _isProcessingNetworkPayload) return;

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
      await router.broadcastPayload(payload);
    } catch (_) {}
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
        DateTime.now().toUtc().millisecondsSinceEpoch + clockSyncService.currentOffsetMs;

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

  /// Cancels all subscriptions, timers, and closes the telemetry stream.
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
    if (!_telemetryController.isClosed) {
      _telemetryController.close();
    }
  }
}
