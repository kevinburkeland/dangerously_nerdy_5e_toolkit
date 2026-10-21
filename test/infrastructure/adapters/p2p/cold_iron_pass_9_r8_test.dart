import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:dangerously_nerdy_5e_toolkit/infrastructure/adapters/p2p/firebase_fallback_adapter.dart';

void main() {
  group('Pass 9 R8: Relay payload size limit bar and adapter checks', () {
    test('firestore.rules payload size check matches maxRelayPayloadLength constant', () {
      final rulesFile = File('firestore.rules');
      expect(rulesFile.existsSync(), isTrue, reason: 'firestore.rules must exist');
      final content = rulesFile.readAsStringSync();

      // Ensure the comment naming maxRelayPayloadLength is present
      expect(content, contains('maxRelayPayloadLength: 999,999 characters (< 1000000)'));

      // Extract the limit from firestore.rules
      final match = RegExp(r'request\.resource\.data\.payload\.size\(\)\s*<\s*(\d+)').firstMatch(content);
      expect(match, isNotNull, reason: 'Must find payload size limit in firestore.rules');
      final rawLimit = int.parse(match!.group(1)!);
      expect(rawLimit, equals(1000000));
      // < 1000000 allows strictly up to 999,999 characters
      expect(rawLimit - 1, equals(maxRelayPayloadLength));
      expect(maxRelayPayloadLength, equals(999999));
    });

    test('broadcastPayload: 999,999 characters is sent, 1,000,000 characters throws RelayPayloadTooLargeException', () async {
      final writtenMessages = <Map<String, dynamic>>[];
      final adapter = FirebaseFallbackAdapter(
        onWriteMessage: (path, data) async {
          writtenMessages.add({'path': path, 'data': data});
        },
      );

      await adapter.initializeRoom('ROOM-R8', 'node-r8');

      // 999,999 characters: allowed
      final payload999k = 'a' * maxRelayPayloadLength;
      await adapter.broadcastPayload(payload999k);
      expect(writtenMessages.length, equals(1));
      expect((writtenMessages.first['data']['payload'] as String).length, equals(999999));

      // 1,000,000 characters: throws RelayPayloadTooLargeException and writes nothing
      final payload1m = 'b' * 1000000;
      expect(
        () => adapter.broadcastPayload(payload1m),
        throwsA(isA<RelayPayloadTooLargeException>()
            .having((e) => e.size, 'size', equals(1000000))
            .having((e) => e.limit, 'limit', equals(maxRelayPayloadLength))),
      );

      // Verify no second write occurred
      expect(writtenMessages.length, equals(1));

      await adapter.disconnect();
    });
  });
}
