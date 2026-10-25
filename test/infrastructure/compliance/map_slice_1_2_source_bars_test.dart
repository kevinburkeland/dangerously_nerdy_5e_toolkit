import 'dart:io';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:dangerously_nerdy_5e_toolkit/application/blob/blob_store_port.dart';
import 'package:dangerously_nerdy_5e_toolkit/infrastructure/storage/stub/stub_blob_store_adapter.dart';
import 'package:vtt_engine_core/vtt_engine_core.dart';

void main() {
  group('Map Slice 1.2 Source Bars Compliance', () {
    test('SB1: implements BlobStorePort appears exactly twice under lib/ (web and stub)', () {
      const token = 'implements' ' BlobStorePort';
      final libDir = Directory('lib');
      final matches = <String>[];

      for (final file in libDir.listSync(recursive: true)) {
        if (file is File && file.path.endsWith('.dart')) {
          final content = file.readAsStringSync();
          if (content.contains(token)) {
            matches.add(file.path);
          }
        }
      }

      expect(matches, hasLength(2));
      expect(
        matches.any((p) => p.endsWith('web_blob_store_adapter.dart')),
        isTrue,
        reason: 'Expected web_blob_store_adapter.dart to implement BlobStorePort',
      );
      expect(
        matches.any((p) => p.endsWith('stub_blob_store_adapter.dart')),
        isTrue,
        reason: 'Expected stub_blob_store_adapter.dart to implement BlobStorePort',
      );

      // Control: broken in-memory text produces hit
      const controlText = 'class FakeStore ' 'implements' ' BlobStorePort {}';
      expect(controlText.contains(token), isTrue);
    });

    test('SB2: application/blob files and store adapters contain no Hive, hive or openBox', () {
      final forbidden = [
        'Hi' 've',
        'hi' 've',
        'open' 'Box',
      ];

      final filesToCheck = <File>[];
      final blobAppDir = Directory('lib/application/blob');
      if (blobAppDir.existsSync()) {
        for (final f in blobAppDir.listSync()) {
          if (f is File && f.path.endsWith('.dart')) {
            filesToCheck.add(f);
          }
        }
      }
      filesToCheck.add(File('lib/infrastructure/storage/web/web_blob_store_adapter.dart'));
      filesToCheck.add(File('lib/infrastructure/storage/stub/stub_blob_store_adapter.dart'));

      for (final file in filesToCheck) {
        final content = file.readAsStringSync();
        for (final token in forbidden) {
          expect(
            content.contains(token),
            isFalse,
            reason: '${file.path} contains forbidden token $token',
          );
        }
      }

      // Control: in-memory string with forbidden token produces hit
      for (final token in forbidden) {
        final badString = 'void test() { final x = "$token"; }';
        expect(badString.contains(token), isTrue);
      }
    });

    test('SB3: application/blob files contain no forbidden imports or coupling', () {
      final forbidden = [
        'broadcast' 'Payload',
        'IP2p' 'TransportPort',
        'package:' 'flutter',
        'flutter_' 'webrtc',
        'package:' 'web',
        'dart:' 'js_interop',
        'dart:' 'io',
      ];

      final blobAppDir = Directory('lib/application/blob');
      final files = blobAppDir
          .listSync()
          .whereType<File>()
          .where((f) => f.path.endsWith('.dart'))
          .toList();

      expect(files, isNotEmpty);

      for (final file in files) {
        final content = file.readAsStringSync();
        for (final token in forbidden) {
          expect(
            content.contains(token),
            isFalse,
            reason: '${file.path} contains forbidden token $token',
          );
        }
      }

      // Control: in-memory string with forbidden token produces hit
      for (final token in forbidden) {
        final badString = 'import "$token";';
        expect(badString.contains(token), isTrue);
      }
    });

    test('SB4: webrtc_mesh_adapter.dart invariants: exact call counts', () {
      final adapterFile = File('lib/infrastructure/adapters/p2p/webrtc_mesh_adapter.dart');
      final content = adapterFile.readAsStringSync();

      const token1 = '_connectionFactory' '.createConnection';
      const token2 = 'RTCDataChannelMessage' '.fromBinary';
      const token3 = '_incomingPayloadsController' '.add';

      int countOccurrences(String text, String token) {
        var count = 0;
        var idx = 0;
        while ((idx = text.indexOf(token, idx)) != -1) {
          count++;
          idx += token.length;
        }
        return count;
      }

      expect(countOccurrences(content, token1), equals(1),
          reason: '$token1 must appear exactly once');
      expect(countOccurrences(content, token2), equals(1),
          reason: '$token2 must appear exactly once');
      expect(countOccurrences(content, token3), equals(1),
          reason: '$token3 must appear exactly once');

      // Control: in-memory text with 0 or 2 occurrences fails the assertion
      expect(countOccurrences('no token here', token1), equals(0));
      expect(countOccurrences('$token1 and again $token1', token1), equals(2));
    });

    test('SB5: stub adapter throws BlobStoreUnavailableException on each of 5 methods', () async {
      const adapter = BlobStoreAdapter();
      final dummyRef = BlobRef(
        sha256Hex: '0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef',
        byteSize: 100,
        width: 10,
        height: 10,
        format: BlobFormat.webp,
      );

      await expectLater(adapter.has('0123'), throwsA(isA<BlobStoreUnavailableException>()));
      await expectLater(adapter.addOwner('0123', 'c1'), throwsA(isA<BlobStoreUnavailableException>()));
      await expectLater(adapter.put(dummyRef, Uint8List(100), campaignId: 'c1'),
          throwsA(isA<BlobStoreUnavailableException>()));
      await expectLater(adapter.get('0123'), throwsA(isA<BlobStoreUnavailableException>()));
      await expectLater(adapter.releaseCampaign('c1'), throwsA(isA<BlobStoreUnavailableException>()));

      // Control: check that an exception of a different type does not match
      expect(
        () => throw StateError('not unavailable'),
        throwsA(isNot(isA<BlobStoreUnavailableException>())),
      );
    });
  });
}
