import 'dart:async';
import 'dart:convert';
import 'package:meta/meta.dart';
import '../../domain/crdt/crdt_or_set.dart';
import '../../domain/models/campaign_profile.dart';
import '../../domain/ports/i_campaign_repository.dart';
import '../../domain/ports/i_p2p_transport_port.dart';
import '../../infrastructure/dtos/campaign_profile_dto.dart';
import '../../infrastructure/dtos/crdt/crdt_or_set_dto.dart';
import '../../services/logging_service.dart';
import 'clock_sync_service.dart';
import 'room_state_reconciliation_service.dart';

/// Application service bridging P2P transport with local persistence.
///
/// Orchestrates bidirectional real-time state synchronization:
/// 1. Subscribes to incoming P2P network payloads, deserializes them, executes CRDT merge
///    reconciliation, and persists them immediately to local storage.
/// 2. Subscribes to local campaign profile mutations, encodes them, and broadcasts them across the mesh.
/// 3. Enforces an echo-cancellation mutex (`_isProcessingNetworkPayload`) to prevent local reactive
///    stream updates triggered by network writes from bouncing back out over the wire.
/// 4. Operates a periodic milestone flush on host nodes to prune expired tombstones.
class RoomSyncOrchestrator {
  final IP2pTransportPort transportPort;
  final ICampaignRepository campaignRepo;
  final RoomStateReconciliationService reconciliationService;
  final ClockSyncService clockSyncService;
  final bool isHost;
  final Duration milestoneInterval;
  final String hostNodeId;

  StreamSubscription<String>? _networkSub;
  StreamSubscription<CampaignProfile?>? _localDbSub;
  Timer? _milestoneTimer;

  bool _isProcessingNetworkPayload = false;

  /// In-memory tombstone tracking for CRDT collections (e.g. pinned rules or minion IDs)
  /// reconciled across peers and pruned during host milestones.
  CrdtOrSet<String> _trackedRulesSet = const CrdtOrSet<String>();

  RoomSyncOrchestrator({
    required this.transportPort,
    required this.campaignRepo,
    required this.reconciliationService,
    required this.clockSyncService,
    this.isHost = false,
    this.milestoneInterval = const Duration(minutes: 5),
    this.hostNodeId = 'dm-host-node',
  });

  /// Indicates whether an inbound network payload is currently being ingested and saved.
  /// Used by tests and outbound broadcast filters to prevent echo loops.
  bool get isProcessingNetworkPayload => _isProcessingNetworkPayload;

  /// Returns whether synchronization is actively listening to transport and DB streams.
  bool get isSynchronizing => _networkSub != null && _localDbSub != null;

  /// Current in-memory tracked CRDT set (exposed for inspection and testing).
  @visibleForTesting
  CrdtOrSet<String> get trackedRulesSet => _trackedRulesSet;

  @visibleForTesting
  set trackedRulesSet(CrdtOrSet<String> set) => _trackedRulesSet = set;

  /// Begins bidirectional synchronization between network transport and local database.
  void startSynchronization() {
    _networkSub = transportPort.watchIncomingPayloads().listen(_handleIncomingPayload);
    _localDbSub = campaignRepo.watchActiveProfile().listen(_handleLocalProfileChange);

    if (isHost) {
      _startMilestoneFlushTimer();
    }
  }

  /// Handles incoming JSON payloads from the P2P transport.
  @visibleForTesting
  Future<void> handleIncomingPayload(String jsonPayload) => _handleIncomingPayload(jsonPayload);

  Future<void> _handleIncomingPayload(String jsonPayload) async {
    // 1. Lock outbound broadcasts to prevent echo loops
    _isProcessingNetworkPayload = true;

    try {
      final dynamic decoded = jsonDecode(jsonPayload);
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
    } catch (e, st) {
      LoggingService().logNonFatal(
        e,
        st,
        reason: 'Error processing incoming network payload in RoomSyncOrchestrator',
      );
    } finally {
      // 2. Release lock after DB stream microtask has completed
      scheduleMicrotask(() => _isProcessingNetworkPayload = false);
    }
  }

  /// Handles local profile changes emitted by the campaign repository.
  @visibleForTesting
  Future<void> handleLocalProfileChange(CampaignProfile? profile) => _handleLocalProfileChange(profile);

  Future<void> _handleLocalProfileChange(CampaignProfile? profile) async {
    if (profile == null || _isProcessingNetworkPayload) return;

    final dto = CampaignProfileDto.fromDomain(profile);
    final payloadMap = <String, dynamic>{
      'type': 'room_sync_full',
      'payload': dto.toMap(),
      'timestamp': DateTime.now().toUtc().millisecondsSinceEpoch + clockSyncService.currentOffsetMs,
    };

    // Attach tracked CRDT set state if populated
    if (_trackedRulesSet.items.isNotEmpty || _trackedRulesSet.tombstones.isNotEmpty) {
      payloadMap['pinned_rules_crdt'] = CrdtOrSetDto.toMap<String>(
        _trackedRulesSet,
        (val) => val,
      );
    }

    final payload = jsonEncode(payloadMap);

    try {
      await transportPort.broadcastPayload(payload);
    } catch (e, st) {
      LoggingService().logNonFatal(
        e,
        st,
        reason: 'Failed to broadcast local profile change via transportPort',
      );
    }
  }

  /// Initiates the host milestone periodic timer.
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

  /// Stops all synchronization, cancels network and database subscriptions,
  /// and terminates active milestone timers.
  void stopSynchronization() {
    _networkSub?.cancel();
    _networkSub = null;
    _localDbSub?.cancel();
    _localDbSub = null;
    _milestoneTimer?.cancel();
    _milestoneTimer = null;
  }
}
