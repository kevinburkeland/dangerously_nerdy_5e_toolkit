import 'package:flutter_test/flutter_test.dart';
import 'package:dangerously_nerdy_5e_toolkit/infrastructure/adapters/p2p/local_wifi_adapter.dart';

void main() {
  group('LocalWifiAdapter Unit Tests', () {
    test('Default initializeRoom throws UnsupportedError to trigger waterfall step down', () async {
      final adapter = LocalWifiAdapter();
      expect(adapter.isInitialized, isFalse);

      expect(
        () => adapter.initializeRoom('ROOM-LAN', 'node-1'),
        throwsUnsupportedError,
      );
      expect(adapter.isInitialized, isFalse);
    });

    test('Custom onInitialize configures room successfully', () async {
      String? initializedRoom;
      String? initializedNode;

      final adapter = LocalWifiAdapter(
        onInitialize: (room, node) async {
          initializedRoom = room;
          initializedNode = node;
        },
      );

      await adapter.initializeRoom('room-lan', 'node-1');

      expect(adapter.isInitialized, isTrue);
      expect(adapter.roomCode, 'ROOM-LAN');
      expect(adapter.localNodeId, 'node-1');
      expect(initializedRoom, 'ROOM-LAN');
      expect(initializedNode, 'node-1');
    });

    test('broadcastPayload requires initialization and invokes onBroadcast', () async {
      String? broadcasted;
      final adapter = LocalWifiAdapter(
        onInitialize: (r, n) async {},
        onBroadcast: (payload) async {
          broadcasted = payload;
        },
      );

      expect(
        () => adapter.broadcastPayload('{"test":1}'),
        throwsStateError,
      );

      await adapter.initializeRoom('ROOM-LAN', 'node-1');
      await adapter.broadcastPayload('{"test":1}');

      expect(broadcasted, '{"test":1}');
    });

    test('watchIncomingPayloads receives emitted incoming payloads', () async {
      final adapter = LocalWifiAdapter();
      final received = <String>[];
      final sub = adapter.watchIncomingPayloads().listen(received.add);

      adapter.emitIncomingPayload('{"peer":"hello"}');
      await Future<void>.delayed(Duration.zero);

      expect(received, ['{"peer":"hello"}']);

      await sub.cancel();
      await adapter.disconnect();
    });

    test('disconnect resets state and invokes onDisconnect', () async {
      bool disconnected = false;
      final adapter = LocalWifiAdapter(
        onInitialize: (r, n) async {},
        onDisconnect: () async {
          disconnected = true;
        },
      );

      await adapter.initializeRoom('ROOM-LAN', 'node-1');
      expect(adapter.isInitialized, isTrue);

      await adapter.disconnect();
      expect(adapter.isInitialized, isFalse);
      expect(adapter.roomCode, isNull);
      expect(adapter.localNodeId, isNull);
      expect(disconnected, isTrue);
    });
  });
}
