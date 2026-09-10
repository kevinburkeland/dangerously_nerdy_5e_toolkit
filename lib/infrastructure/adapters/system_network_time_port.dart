import '../../domain/ports/i_network_time_port.dart';

/// Concrete adapter implementing [INetworkTimePort] using local UTC system time.
/// Provides safe zero-dependency time synchronization fallback.
class SystemNetworkTimePort implements INetworkTimePort {
  const SystemNetworkTimePort();

  @override
  Future<int> getNetworkTimeMs() async {
    return DateTime.now().toUtc().millisecondsSinceEpoch;
  }
}
