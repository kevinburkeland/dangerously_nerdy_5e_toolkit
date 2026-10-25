@TestOn('browser')
library;

import 'dart:async';
import 'dart:js_interop';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:web/web.dart' as web;
import 'package:dangerously_nerdy_5e_toolkit/application/blob/blob_store_port.dart';
import 'package:dangerously_nerdy_5e_toolkit/application/blob/blob_verifier.dart';
import 'package:dangerously_nerdy_5e_toolkit/infrastructure/storage/web/web_blob_store_adapter.dart';
import 'package:vtt_engine_core/vtt_engine_core.dart';

Uint8List _makeWebp(int size) {
  final bytes = Uint8List(size);
  bytes[0] = 0x52; // R
  bytes[1] = 0x49; // I
  bytes[2] = 0x46; // F
  bytes[3] = 0x46; // F
  bytes[8] = 0x57; // W
  bytes[9] = 0x45; // E
  bytes[10] = 0x42; // B
  bytes[11] = 0x50; // P
  for (var i = 12; i < size; i++) {
    bytes[i] = (i * 31) & 0xFF;
  }
  return bytes;
}

BlobRef _makeRef(Uint8List bytes, BlobFormat format) {
  final hash = sha256.convert(bytes).toString();
  return BlobRef(
    sha256Hex: hash,
    byteSize: bytes.length,
    width: 100,
    height: 100,
    format: format,
  );
}

Future<void> _deleteIndexedDb(String dbName) {
  final completer = Completer<void>();
  final req = web.window.indexedDB.deleteDatabase(dbName);
  req.onsuccess = ((web.Event _) {
    if (!completer.isCompleted) completer.complete();
  }).toJS;
  req.onerror = ((web.Event _) {
    if (!completer.isCompleted) completer.complete();
  }).toJS;
  req.onblocked = ((web.Event _) {
    if (!completer.isCompleted) completer.complete();
  }).toJS;
  return completer.future;
}

void main() {
  var dbCounter = 0;

  group('Web BlobStoreAdapter (IndexedDB)', () {
    late String dbName;
    final adaptersToClose = <BlobStoreAdapter>[];

    setUp(() {
      dbName = 'dn5e_blobs_test_${DateTime.now().millisecondsSinceEpoch}_${dbCounter++}';
      adaptersToClose.clear();
    });

    tearDown(() async {
      for (final a in adaptersToClose) {
        await a.close();
      }
      await _deleteIndexedDb(dbName);
    });

    BlobStoreAdapter createAdapter({Future<web.IDBDatabase> Function()? opener}) {
      final adapter = BlobStoreAdapter(databaseName: dbName, opener: opener);
      adaptersToClose.add(adapter);
      return adapter;
    }

    test('W1: put, then new adapter instance: has is true and get returns bytes with same SHA-256', () async {
      final bytes = _makeWebp(1024);
      final ref = _makeRef(bytes, BlobFormat.webp);

      final adapter1 = createAdapter();
      await adapter1.put(ref, bytes, campaignId: 'c1');
      await adapter1.close();

      final adapter2 = createAdapter();
      expect(await adapter2.has(ref.sha256Hex), isTrue);

      final stored = await adapter2.get(ref.sha256Hex);
      expect(stored.ref.sha256Hex, equals(ref.sha256Hex));
      expect(stored.bytes, equals(bytes));
      expect(sha256.convert(stored.bytes).toString(), equals(ref.sha256Hex));
    });

    test('W2: put with one flipped byte: throws BlobRejectedException(wrongHash) and has is false', () async {
      final bytes = _makeWebp(1024);
      final ref = _makeRef(bytes, BlobFormat.webp);

      // Flip a byte after signature
      final corruptBytes = Uint8List.fromList(bytes);
      corruptBytes[15] ^= 0x55;

      final adapter = createAdapter();
      await expectLater(
        adapter.put(ref, corruptBytes, campaignId: 'c1'),
        throwsA(
          predicate<BlobRejectedException>(
            (e) => e.verdict == BlobVerdict.wrongHash,
          ),
        ),
      );

      expect(await adapter.has(ref.sha256Hex), isFalse);
    });

    test('W3: campaigns A and B own one blob. Release A: still there. Release B: gone.', () async {
      final bytes = _makeWebp(2048);
      final ref = _makeRef(bytes, BlobFormat.webp);

      final adapter = createAdapter();
      await adapter.put(ref, bytes, campaignId: 'c_A');
      await adapter.addOwner(ref.sha256Hex, 'c_B');

      expect(await adapter.has(ref.sha256Hex), isTrue);

      // Release A: still there because B owns it
      await adapter.releaseCampaign('c_A');
      expect(await adapter.has(ref.sha256Hex), isTrue);

      // Release B: gone
      await adapter.releaseCampaign('c_B');
      expect(await adapter.has(ref.sha256Hex), isFalse);
    });

    test('W4: record with flipped byte straight into IndexedDB: get throws BlobCorruptException, has is false', () async {
      final bytes = _makeWebp(1024);
      final ref = _makeRef(bytes, BlobFormat.webp);

      final adapter1 = createAdapter();
      await adapter1.put(ref, bytes, campaignId: 'c1');
      await adapter1.close();

      // Open raw IndexedDB connection and corrupt the bytes in the record
      final openCompleter = Completer<web.IDBDatabase>();
      final openReq = web.window.indexedDB.open(dbName, 1);
      openReq.onsuccess = ((web.Event _) {
        openCompleter.complete(openReq.result as web.IDBDatabase);
      }).toJS;
      openReq.onerror = ((web.Event _) {
        openCompleter.completeError(StateError('Failed to open test IDB'));
      }).toJS;
      final rawDb = await openCompleter.future;

      final tx = rawDb.transaction('blobs'.toJS, 'readwrite');
      final store = tx.objectStore('blobs');
      final getReq = store.get(ref.sha256Hex.toJS);
      final mutateCompleter = Completer<void>();
      getReq.onsuccess = ((web.Event _) {
        final res = getReq.result;
        final data = (res as JSObject).dartify() as Map<Object?, Object?>;
        final rawBytes = data['bytes'];
        final Uint8List oldBytes;
        if (rawBytes is Uint8List) {
          oldBytes = rawBytes;
        } else if (rawBytes is ByteBuffer) {
          oldBytes = rawBytes.asUint8List();
        } else {
          oldBytes = Uint8List.fromList((rawBytes as List).cast<int>());
        }
        final corrupted = Uint8List.fromList(oldBytes);
        corrupted[15] ^= 0xFF;
        data['bytes'] = corrupted.toJS;
        store.put(data.jsify()!, ref.sha256Hex.toJS);
        mutateCompleter.complete();
      }).toJS;
      await mutateCompleter.future;

      final txCompleter = Completer<void>();
      tx.oncomplete = ((web.Event _) => txCompleter.complete()).toJS;
      tx.onerror = ((web.Event _) => txCompleter.completeError(StateError('raw tx failed'))).toJS;
      await txCompleter.future;
      rawDb.close();

      // Create new adapter instance
      final adapter2 = createAdapter();
      await expectLater(
        adapter2.get(ref.sha256Hex),
        throwsA(
          predicate<BlobCorruptException>(
            (e) => e.sha256Hex == ref.sha256Hex && e.verdict == BlobVerdict.wrongHash,
          ),
        ),
      );

      // And afterwards, has is false (entry was deleted on corruption)
      expect(await adapter2.has(ref.sha256Hex), isFalse);
    });

    test('W5: opener that throws: each of 5 methods throws BlobStoreUnavailableException', () async {
      final adapter = createAdapter(
        opener: () => Future.error(Exception('Simulated IndexedDB failure')),
      );

      final bytes = _makeWebp(500);
      final ref = _makeRef(bytes, BlobFormat.webp);

      await expectLater(adapter.has(ref.sha256Hex), throwsA(isA<BlobStoreUnavailableException>()));
      await expectLater(adapter.addOwner(ref.sha256Hex, 'c1'), throwsA(isA<BlobStoreUnavailableException>()));
      await expectLater(adapter.put(ref, bytes, campaignId: 'c1'), throwsA(isA<BlobStoreUnavailableException>()));
      await expectLater(adapter.get(ref.sha256Hex), throwsA(isA<BlobStoreUnavailableException>()));
      await expectLater(adapter.releaseCampaign('c1'), throwsA(isA<BlobStoreUnavailableException>()));
    });

    test('W6: a 10,485,760-byte blob: put, new instance, get gives same hash', () async {
      final bigBytes = _makeWebp(10485760);
      final ref = _makeRef(bigBytes, BlobFormat.webp);

      final adapter1 = createAdapter();
      await adapter1.put(ref, bigBytes, campaignId: 'c_big');
      await adapter1.close();

      final adapter2 = createAdapter();
      expect(await adapter2.has(ref.sha256Hex), isTrue);

      final stored = await adapter2.get(ref.sha256Hex);
      expect(stored.bytes.length, equals(10485760));
      expect(sha256.convert(stored.bytes).toString(), equals(ref.sha256Hex));
    });
  });
}
