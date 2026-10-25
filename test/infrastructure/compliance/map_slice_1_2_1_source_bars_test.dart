import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Map Slice 1.2.1 Source Bars Compliance', () {
    test('SB6: In web_blob_store_adapter.dart: db.transaction( appears exactly once; .onabort at least once; dartify() exactly once', () {
      final file = File('lib/infrastructure/storage/web/web_blob_store_adapter.dart');
      expect(file.existsSync(), isTrue, reason: 'web_blob_store_adapter.dart must exist');
      final content = file.readAsStringSync();

      const dbTxToken = 'db.transaction' '(';
      const onabortToken = '.on' 'abort';
      const dartifyToken = 'dart' 'ify()';

      final dbTxCount = dbTxToken.allMatches(content).length;
      final onabortCount = onabortToken.allMatches(content).length;
      final dartifyCount = dartifyToken.allMatches(content).length;

      expect(dbTxCount, equals(1), reason: 'db.transaction( must appear exactly once in web_blob_store_adapter.dart');
      expect(onabortCount, greaterThanOrEqualTo(1), reason: '.onabort must appear at least once in web_blob_store_adapter.dart');
      expect(dartifyCount, equals(1), reason: 'dartify() must appear exactly once in web_blob_store_adapter.dart');

      // Controls: breaking text triggers scanner
      const badDbTx = 'final tx1 = db.transaction' '(); final tx2 = db.transaction' '();';
      expect(dbTxToken.allMatches(badDbTx).length, equals(2));

      const noOnabort = 'void test() { final x = 1; }';
      expect(onabortToken.allMatches(noOnabort).length, equals(0));

      const badDartify = 'final a = x.dart' 'ify(); final b = y.dart' 'ify();';
      expect(dartifyToken.allMatches(badDartify).length, equals(2));
    });

    test('SB7: In webrtc_mesh_adapter.dart: _blobMessagesController.close() and _blobPeersChangedController.close() do not appear', () {
      final file = File('lib/infrastructure/adapters/p2p/webrtc_mesh_adapter.dart');
      expect(file.existsSync(), isTrue, reason: 'webrtc_mesh_adapter.dart must exist');
      final content = file.readAsStringSync();

      const blobMsgClose = '_blobMessagesController.' 'close()';
      const blobPeersClose = '_blobPeersChangedController.' 'close()';

      expect(content.contains(blobMsgClose), isFalse, reason: '_blobMessagesController.close() must not appear in webrtc_mesh_adapter.dart');
      expect(content.contains(blobPeersClose), isFalse, reason: '_blobPeersChangedController.close() must not appear in webrtc_mesh_adapter.dart');

      // Controls: breaking text triggers scanner
      const badMsgClose = 'await _blobMessagesController.' 'close();';
      expect(badMsgClose.contains(blobMsgClose), isTrue);

      const badPeersClose = 'await _blobPeersChangedController.' 'close();';
      expect(badPeersClose.contains(blobPeersClose), isTrue);
    });

    test('SB8: No line in any file under lib/ contains both setProperty and transaction', () {
      const setPropertyToken = 'set' 'Property';
      const transactionToken = 'trans' 'action';

      final libDir = Directory('lib');
      final files = libDir
          .listSync(recursive: true)
          .whereType<File>()
          .where((f) => f.path.endsWith('.dart'))
          .toList();

      expect(files, isNotEmpty);

      final violations = <String>[];
      for (final file in files) {
        final lines = file.readAsLinesSync();
        for (var i = 0; i < lines.length; i++) {
          final line = lines[i];
          if (line.contains(setPropertyToken) && line.contains(transactionToken)) {
            violations.add('${file.path}:${i + 1}: $line');
          }
        }
      }

      expect(violations, isEmpty, reason: 'No line in any file under lib/ may contain both setProperty and transaction: $violations');

      // Control: broken line in memory triggers violation
      const badLine = 'db.set' 'Property("trans' 'action", fn);';
      expect(badLine.contains(setPropertyToken) && badLine.contains(transactionToken), isTrue);
    });
  });
}
