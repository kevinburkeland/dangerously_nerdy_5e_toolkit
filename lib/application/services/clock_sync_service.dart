import 'package:vtt_engine_core/ports/i_network_time_port.dart';

/// Application service responsible for synchronizing local physical clock with an
/// authoritative network time source to protect the CRDT engine from clock-skew
/// and clock-spoofing attacks.
class ClockSyncService {
  final INetworkTimePort networkTimePort;
  final int Function() _localTimeProvider;
  int _offsetMs = 0;

  ClockSyncService({
    required this.networkTimePort,
    int Function()? localTimeProvider,
  }) : _localTimeProvider = localTimeProvider ??
            (() => DateTime.now().toUtc().millisecondsSinceEpoch);

  /// Current physical time offset in milliseconds to be applied to local time.
  int get currentOffsetMs => _offsetMs;

  /// Current synchronized network time in milliseconds.
  int get currentNetworkTimeMs => _localTimeProvider() + _offsetMs;

  /// Synchronizes local clock offset against the authoritative network time port.
  /// If the network port throws or is unreachable, safely falls back to a 0ms offset.
  Future<void> synchronizeClock() async {
    try {
      final networkTime = await networkTimePort.getNetworkTimeMs();
      final localTime = _localTimeProvider();
      _offsetMs = networkTime - localTime;
    } catch (_) {
      // Fallback to 0 offset if network is unreachable or malformed
      _offsetMs = 0;
    }
  }
}
