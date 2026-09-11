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

    test('disconnect closes incoming payloads stream and re-initialization reopens cleanly', () async {
      await adapter.initializeRoom('ROOM-1', 'node-1');

      bool isDone = false;
      final sub = adapter.watchIncomingPayloads().listen(
        (_) {},
        onDone: () {
          isDone = true;
        },
      );

      await adapter.disconnect();
      await Future<void>.delayed(Duration.zero);

      expect(isDone, isTrue, reason: 'Incoming payloads stream should be closed on disconnect');
      await sub.cancel();

      // Re-initialize and verify clean stream re-opening
      await adapter.initializeRoom('ROOM-2', 'node-2');
      final receivedAfterReconnect = <String>[];
      final sub2 = adapter.watchIncomingPayloads().listen(receivedAfterReconnect.add);

      adapter.emitIncomingPayload('{"message":"reconnected"}');
      await Future<void>.delayed(Duration.zero);

      expect(receivedAfterReconnect, ['{"message":"reconnected"}']);
      await sub2.cancel();
    });

    test('tolerates clock skew with 30-second query threshold and deduplicates message IDs', () async {
      final now = DateTime.now().millisecondsSinceEpoch;
      await adapter.initializeRoom('ROOM-SKEW', 'node-skew');

      expect(adapter.lastQueryThreshold, isNotNull);
      // Query threshold must be buffered 30 seconds into the past
      expect(adapter.lastQueryThreshold!, lessThanOrEqualTo(now - 29000));
      expect(adapter.lastQueryThreshold!, greaterThanOrEqualTo(now - 31000));

      final received = <String>[];
      final sub = adapter.watchIncomingPayloads().listen(received.add);

      // Emit first message with specific ID
      adapter.emitIncomingPayload('{"action":"cast_spell","id":1}', messageId: 'msg-duplicate-1');
      await Future<void>.delayed(Duration.zero);

      expect(received.length, 1);
      expect(adapter.processedMessageIds, contains('msg-duplicate-1'));

      // Re-emit with identical message ID (e.g. from skewed Firestore query)
      adapter.emitIncomingPayload('{"action":"cast_spell","id":1}', messageId: 'msg-duplicate-1');
      await Future<void>.delayed(Duration.zero);

      // Must be dropped by deduplicator
      expect(received.length, 1);

      // Emit with distinct message ID
      adapter.emitIncomingPayload('{"action":"cast_spell","id":2}', messageId: 'msg-unique-2');
      await Future<void>.delayed(Duration.zero);

      expect(received.length, 2);
      expect(adapter.processedMessageIds, contains('msg-unique-2'));

      await sub.cancel();
    });

    test('enforces maxProcessedMessageIds LRU bound and clears tracking on disconnect', () async {
      await adapter.initializeRoom('ROOM-LRU', 'node-lru');

      final received = <String>[];
      final sub = adapter.watchIncomingPayloads().listen(received.add);

      for (int i = 0; i < 505; i++) {
        adapter.emitIncomingPayload('{"index":$i}', messageId: 'msg-$i');
      }
      await Future<void>.delayed(Duration.zero);

      expect(received.length, 505);
      expect(adapter.processedMessageIds.length, equals(FirebaseFallbackAdapter.maxProcessedMessageIds));
      // First 5 messages should have been evicted from the LRU cache
      expect(adapter.processedMessageIds.contains('msg-0'), isFalse);
      expect(adapter.processedMessageIds.contains('msg-4'), isFalse);
      expect(adapter.processedMessageIds.contains('msg-504'), isTrue);

      // Disconnect clears tracking
      await adapter.disconnect();
      expect(adapter.processedMessageIds, isEmpty);

      await sub.cancel();
    });
  });
}
