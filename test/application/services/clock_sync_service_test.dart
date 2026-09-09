import 'package:flutter_test/flutter_test.dart';
import 'package:dangerously_nerdy_5e_toolkit/application/services/clock_sync_service.dart';
import 'package:dangerously_nerdy_5e_toolkit/domain/crdt/hybrid_logical_clock.dart';
import 'package:dangerously_nerdy_5e_toolkit/domain/ports/i_network_time_port.dart';

class MockNetworkTimePort implements INetworkTimePort {
  int? timeToReturn;
  Exception? exceptionToThrow;

  @override
  Future<int> getNetworkTimeMs() async {
    if (exceptionToThrow != null) {
      throw exceptionToThrow!;
    }
    return timeToReturn ?? DateTime.now().toUtc().millisecondsSinceEpoch;
  }
}

void main() {
  group('ClockSyncService Tests', () {
    late MockNetworkTimePort mockPort;

    setUp(() {
      mockPort = MockNetworkTimePort();
    });

    test('calculates correct negative offset when local clock is ahead (spoofed)', () async {
      const trueNetworkTime = 1700000000000;
      const spoofedLocalTime = 1700000000000 + 86400000; // 1 day ahead

      mockPort.timeToReturn = trueNetworkTime;

      final service = ClockSyncService(
        networkTimePort: mockPort,
        localTimeProvider: () => spoofedLocalTime,
      );

      await service.synchronizeClock();

      expect(service.currentOffsetMs, equals(-86400000));

      // Verify that HLC initialized with this offset returns the true network time
      final hlc = HybridLogicalClock.now(
        'node-alpha',
        offsetMs: service.currentOffsetMs,
        timeProvider: () => spoofedLocalTime,
      );
      expect(hlc.physicalTime, equals(trueNetworkTime));
    });

    test('calculates correct positive offset when local clock is lagging behind', () async {
      const trueNetworkTime = 1700000000000;
      const laggingLocalTime = 1700000000000 - 5000; // 5 seconds behind

      mockPort.timeToReturn = trueNetworkTime;

      final service = ClockSyncService(
        networkTimePort: mockPort,
        localTimeProvider: () => laggingLocalTime,
      );

      await service.synchronizeClock();

      expect(service.currentOffsetMs, equals(5000));
    });

    test('falls back to 0ms offset when network port throws exception', () async {
      mockPort.exceptionToThrow = Exception('Network unreachable (503)');

      final service = ClockSyncService(
        networkTimePort: mockPort,
        localTimeProvider: () => 1700000000000,
      );

      await service.synchronizeClock();

      expect(service.currentOffsetMs, equals(0));
    });

    test('Clock Spoofing Mitigation: 1 year future spoof is neutralized by negative offset', () async {
      final nowUtc = DateTime.now().toUtc().millisecondsSinceEpoch;
      const oneYearMs = 365 * 24 * 60 * 60 * 1000;
      final spoofedFutureTime = nowUtc + oneYearMs;

      mockPort.timeToReturn = nowUtc;

      final service = ClockSyncService(
        networkTimePort: mockPort,
        localTimeProvider: () => spoofedFutureTime,
      );

      await service.synchronizeClock();

      expect(service.currentOffsetMs, equals(-oneYearMs));

      // Create HLC while passing offset and the mocked future machine clock
      final hlc = HybridLogicalClock.now(
        'spoofed-node',
        offsetMs: service.currentOffsetMs,
        timeProvider: () => spoofedFutureTime,
      );

      // Verify physical time is anchored to true time, ignoring the 1-year future spoof
      expect((hlc.physicalTime - nowUtc).abs(), lessThanOrEqualTo(50));
    });
  });
}
