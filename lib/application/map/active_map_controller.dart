import 'dart:async';
import 'dart:typed_data';

import 'package:vtt_engine_core/vtt_engine_core.dart';

import '../blob/blob_channel_port.dart';
import '../blob/blob_store_port.dart';
import '../blob/blob_transfer_service.dart';

/// Returns the active map of the active profile if present, otherwise empty.
Iterable<BlobRef> activeMapServableRefs(ICampaignRepository repo) {
  final activeRef = repo.activeProfile?.activeMapRegister.value;
  if (activeRef == null) {
    return const [];
  }
  return [activeRef];
}

sealed class ActiveMapViewState {
  const ActiveMapViewState();
}

final class MapNone extends ActiveMapViewState {
  const MapNone();

  @override
  bool operator ==(Object other) => identical(this, other) || other is MapNone;

  @override
  int get hashCode => 0;

  @override
  String toString() => 'MapNone()';
}

final class MapLoading extends ActiveMapViewState {
  const MapLoading();

  @override
  bool operator ==(Object other) => identical(this, other) || other is MapLoading;

  @override
  int get hashCode => 1;

  @override
  String toString() => 'MapLoading()';
}

final class MapDownloading extends ActiveMapViewState {
  final int chunksReceived;
  final int chunksTotal;

  const MapDownloading(this.chunksReceived, this.chunksTotal);

  int get percent =>
      chunksTotal > 0 ? (chunksReceived * 100 ~/ chunksTotal) : 0;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MapDownloading &&
          chunksReceived == other.chunksReceived &&
          chunksTotal == other.chunksTotal;

  @override
  int get hashCode => Object.hash(chunksReceived, chunksTotal);

  @override
  String toString() => 'MapDownloading($chunksReceived/$chunksTotal)';
}

final class MapWaitingForPeer extends ActiveMapViewState {
  const MapWaitingForPeer();

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is MapWaitingForPeer;

  @override
  int get hashCode => 2;

  @override
  String toString() => 'MapWaitingForPeer()';
}

final class MapConnecting extends ActiveMapViewState {
  const MapConnecting();

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is MapConnecting;

  @override
  int get hashCode => 3;

  @override
  String toString() => 'MapConnecting()';
}

final class MapRelayOnly extends ActiveMapViewState {
  const MapRelayOnly();

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is MapRelayOnly;

  @override
  int get hashCode => 4;

  @override
  String toString() => 'MapRelayOnly()';
}

final class MapStoreUnavailable extends ActiveMapViewState {
  final String message;

  const MapStoreUnavailable(this.message);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MapStoreUnavailable && message == other.message;

  @override
  int get hashCode => message.hashCode;

  @override
  String toString() => 'MapStoreUnavailable($message)';
}

final class MapReady extends ActiveMapViewState {
  final BlobRef ref;
  final Uint8List bytes;

  const MapReady(this.ref, this.bytes);

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is MapReady && ref == other.ref;

  @override
  int get hashCode => ref.hashCode;

  @override
  String toString() => 'MapReady(${ref.sha256Hex})';
}

final class MapFailed extends ActiveMapViewState {
  final Object error;

  const MapFailed(this.error);

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is MapFailed && error == other.error;

  @override
  int get hashCode => error.hashCode;

  @override
  String toString() => 'MapFailed($error)';
}

class _MapTarget {
  final String? campaignId;
  final BlobRef? ref;

  const _MapTarget(this.campaignId, this.ref);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is _MapTarget &&
          campaignId == other.campaignId &&
          ref == other.ref;

  @override
  int get hashCode => Object.hash(campaignId, ref);
}

class ActiveMapController {
  final ICampaignRepository campaignRepo;
  final BlobTransferService transfer;
  final BlobStorePort store;
  final BlobChannelPort channel;
  final TransportState Function() transportState;
  final Duration retryInterval;

  ActiveMapViewState _current = const MapNone();
  final StreamController<ActiveMapViewState> _stateController =
      StreamController<ActiveMapViewState>.broadcast(sync: true);

  bool _started = false;
  bool _disposed = false;
  bool _isFetching = false;
  int _generation = 0;

  _MapTarget? _currentTarget;
  String? _campaignId;
  BlobRef? _targetRef;
  Set<String> _previousPeers = const {};

  StreamSubscription<CampaignProfile?>? _profileSub;
  StreamSubscription<Set<String>>? _peersSub;
  StreamSubscription<BlobDownloadProgress>? _progressSub;
  Timer? _retryTimer;

  ActiveMapController({
    required this.campaignRepo,
    required this.transfer,
    required this.store,
    required this.channel,
    required this.transportState,
    this.retryInterval = const Duration(seconds: 15),
  });

  ActiveMapViewState get current => _current;

  String? get campaignId => _campaignId;

  bool get isStarted => _started;

  Stream<ActiveMapViewState> get states {
    late final StreamController<ActiveMapViewState> controller;
    StreamSubscription<ActiveMapViewState>? sub;
    controller = StreamController<ActiveMapViewState>.broadcast(
      sync: true,
      onListen: () {
        controller.add(_current);
        sub = _stateController.stream.listen(
          controller.add,
          onError: controller.addError,
        );
      },
      onCancel: () {
        sub?.cancel();
      },
    );
    return controller.stream;
  }

  void start() {
    if (_started || _disposed) return;
    _started = true;
    transfer.start();
    _profileSub = campaignRepo.watchActiveProfile().listen(_onProfileChanged);
    _peersSub = channel.onBlobPeersChanged.listen(_onPeersChanged);
    _progressSub = transfer.downloadProgress.listen(_onDownloadProgress);
    _onProfileChanged(campaignRepo.activeProfile);
  }

  void _onProfileChanged(CampaignProfile? profile) {
    if (_disposed) return;
    final newTarget = _MapTarget(profile?.id, profile?.activeMapRegister.value);
    if (_currentTarget == newTarget) {
      return;
    }
    _currentTarget = newTarget;
    final gen = ++_generation;
    _campaignId = newTarget.campaignId;
    _targetRef = newTarget.ref;

    if (newTarget.ref == null) {
      _stopRetryTimer();
      _transitionTo(const MapNone());
      return;
    }

    _transitionTo(const MapLoading());
    _fetchCurrentTarget(gen);
  }

  Future<void> _fetchCurrentTarget(int gen) async {
    if (_disposed) return;
    if (gen != _generation) return;
    final ref = _targetRef;
    final cId = _campaignId;
    if (ref == null || cId == null) return;

    _isFetching = true;
    try {
      final result = await transfer.fetch(ref, campaignId: cId);
      if (gen != _generation || _disposed) return;

      if (result is BlobFetched) {
        try {
          final stored = await store.get(ref.sha256Hex);
          if (gen != _generation || _disposed) return;
          _stopRetryTimer();
          _transitionTo(MapReady(ref, stored.bytes));
        } on BlobNotFoundException {
          if (gen != _generation || _disposed) return;
          _transitionTo(const MapWaitingForPeer());
          _startRetryTimerIfNeeded();
        } on BlobCorruptException {
          if (gen != _generation || _disposed) return;
          _transitionTo(const MapWaitingForPeer());
          _startRetryTimerIfNeeded();
        }
      } else if (result is BlobFetchIncomplete) {
        switch (result.reason) {
          case BlobIncompleteReason.notAvailable:
          case BlobIncompleteReason.corrupt:
            _transitionTo(const MapWaitingForPeer());
            _startRetryTimerIfNeeded();
          case BlobIncompleteReason.noDirectPeers:
            if (transportState() == TransportState.fallbackRelay) {
              _transitionTo(const MapRelayOnly());
            } else {
              _transitionTo(const MapConnecting());
            }
            _startRetryTimerIfNeeded();
        }
      }
    } on BlobStoreUnavailableException catch (e) {
      if (gen != _generation || _disposed) return;
      _stopRetryTimer();
      _transitionTo(MapStoreUnavailable(e.message));
    } catch (e) {
      if (gen != _generation || _disposed) return;
      _stopRetryTimer();
      _transitionTo(MapFailed(e));
    } finally {
      if (gen == _generation) {
        _isFetching = false;
      }
    }
  }

  void _onPeersChanged(Set<String> peers) {
    if (_disposed) return;
    final hasNewPeer = peers.any((p) => !_previousPeers.contains(p));
    _previousPeers = peers;
    if (hasNewPeer && _isRetryingState(_current) && !_isFetching) {
      _fetchCurrentTarget(_generation);
    }
  }

  void _onDownloadProgress(BlobDownloadProgress p) {
    if (_disposed) return;
    if (_targetRef == null || p.sha256Hex != _targetRef!.sha256Hex) {
      return;
    }
    if (_current is MapLoading ||
        _current is MapDownloading ||
        _isRetryingState(_current)) {
      _transitionTo(MapDownloading(p.chunksReceived, p.chunksTotal));
    }
  }

  bool _isRetryingState(ActiveMapViewState state) {
    return state is MapWaitingForPeer ||
        state is MapConnecting ||
        state is MapRelayOnly;
  }

  void _startRetryTimerIfNeeded() {
    if (_disposed) return;
    if (_retryTimer != null && _retryTimer!.isActive) return;
    _retryTimer = Timer.periodic(retryInterval, (_) {
      if (_isRetryingState(_current) && !_isFetching) {
        _fetchCurrentTarget(_generation);
      }
    });
  }

  void _stopRetryTimer() {
    _retryTimer?.cancel();
    _retryTimer = null;
  }

  void _transitionTo(ActiveMapViewState next) {
    if (_disposed) return;
    _current = next;
    _stateController.add(next);
  }

  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _profileSub?.cancel();
    _peersSub?.cancel();
    _progressSub?.cancel();
    _stopRetryTimer();
    _stateController.close();
  }
}
