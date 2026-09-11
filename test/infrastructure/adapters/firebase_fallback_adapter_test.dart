import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dangerously_nerdy_5e_toolkit/infrastructure/adapters/p2p/firebase_fallback_adapter.dart';

void main() {
  group('FirebaseFallbackAdapter Relay Tests', () {
    late List<Map<String, dynamic>> writtenMessages;
    late FirebaseFallbackAdapter adapter;

    setUp(() {
      writtenMessages = [];
      adapter = FirebaseFallbackAdapter(
        onWriteMessage: (path, data) async {
          writtenMessages.add({'path': path, 'data': data});
        },
      );
    });

    tearDown(() async {
      await adapter.disconnect();
    });

    test('Initializes and broadcasts payload to relay messages collection with expireAt TTL', () async {
      await adapter.initializeRoom('RELAY-ROOM', 'node-cloud');

      final before = DateTime.now().add(const Duration(minutes: 59));
      const testPayload = '{"crdt":"update","hp":42}';
      await adapter.broadcastPayload(testPayload);
      final after = DateTime.now().add(const Duration(minutes: 61));

      expect(writtenMessages.length, 1);
      final written = writtenMessages.first;
      expect(written['path'], startsWith('rooms/RELAY-ROOM/relay_messages/'));
      expect(written['data']['senderId'], 'node-cloud');
      expect(written['data']['payload'], testPayload);
      expect(written['data']['expireAt'], isA<Timestamp>());
      final expireAtDate = (written['data']['expireAt'] as Timestamp).toDate();
      expect(expireAtDate.isAfter(before), isTrue);
      expect(expireAtDate.isBefore(after), isTrue);
    });

    test('watchIncomingPayloads emits messages from relay stream', () async {
      await adapter.initializeRoom('RELAY-ROOM', 'node-cloud');

      final received = <String>[];
      final sub = adapter.watchIncomingPayloads().listen(received.add);

      adapter.emitIncomingPayload('{"event":"roll","result":20}');
      await Future<void>.delayed(Duration.zero);

      expect(received, ['{"event":"roll","result":20}']);
      await sub.cancel();
    });
  });
}
