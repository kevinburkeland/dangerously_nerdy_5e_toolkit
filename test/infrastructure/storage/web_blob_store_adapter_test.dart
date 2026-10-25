@TestOn('browser')
library;

import 'dart:async';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';
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

    group('W7: five unreadable record shapes reject on get with verdict == null, has becomes false', () {
      final shapes = {
        'plain string': 'just a plain string'.toJS,
        'ref missing': {
          'bytes': Uint8List(10).toJS,
          'owners': ['c1'.toJS].toJS,
        }.jsify()!,
        'ref.byteSize is oops': {
          'ref': {
            'sha256Hex': 'aa' * 32,
            'byteSize': 'oops',
            'width': 100,
            'height': 100,
            'format': 'webp',
          },
          'bytes': Uint8List(10).toJS,
          'owners': ['c1'.toJS].toJS,
        }.jsify()!,
        'bytes is a string': {
          'ref': {
            'sha256Hex': 'bb' * 32,
            'byteSize': 10,
            'width': 100,
            'height': 100,
            'format': 'webp',
          },
          'bytes': 'not_a_byte_array',
          'owners': ['c1'.toJS].toJS,
        }.jsify()!,
        'owners is a number': {
          'ref': {
            'sha256Hex': 'cc' * 32,
            'byteSize': 10,
            'width': 100,
            'height': 100,
            'format': 'webp',
          },
          'bytes': Uint8List(10).toJS,
          'owners': 42,
        }.jsify()!,
      };

      for (final entry in shapes.entries) {
        test('W7 (${entry.key}): get throws BlobCorruptException(verdict == null), has is false', () async {
          final hash = 'deadbeef' * 8;
          await _insertRawRecord(dbName, hash, entry.value);

          final adapter = createAdapter();
          await expectLater(
            adapter.get(hash).timeout(const Duration(seconds: 2)),
            throwsA(
              predicate<BlobCorruptException>(
                (e) => e.sha256Hex == hash && e.verdict == null,
              ),
            ),
          );

          expect(await adapter.has(hash).timeout(const Duration(seconds: 2)), isFalse);
        });
      }
    });

    group('W8: five unreadable record shapes handle addOwner, put, and releaseCampaign cleanly', () {
      final shapes = {
        'plain string': 'just a plain string'.toJS,
        'ref missing': {
          'bytes': Uint8List(10).toJS,
          'owners': ['c1'.toJS].toJS,
        }.jsify()!,
        'ref.byteSize is oops': {
          'ref': {
            'sha256Hex': 'aa' * 32,
            'byteSize': 'oops',
            'width': 100,
            'height': 100,
            'format': 'webp',
          },
          'bytes': Uint8List(10).toJS,
          'owners': ['c1'.toJS].toJS,
        }.jsify()!,
        'bytes is a string': {
          'ref': {
            'sha256Hex': 'bb' * 32,
            'byteSize': 10,
            'width': 100,
            'height': 100,
            'format': 'webp',
          },
          'bytes': 'not_a_byte_array',
          'owners': ['c1'.toJS].toJS,
        }.jsify()!,
        'owners is a number': {
          'ref': {
            'sha256Hex': 'cc' * 32,
            'byteSize': 10,
            'width': 100,
            'height': 100,
            'format': 'webp',
          },
          'bytes': Uint8List(10).toJS,
          'owners': 42,
        }.jsify()!,
      };

      for (final entry in shapes.entries) {
        test('W8 (${entry.key}): addOwner returns false and removes record, put succeeds, releaseCampaign completes', () async {
          final bytes = _makeWebp(500);
          final ref = _makeRef(bytes, BlobFormat.webp);
          final hash = ref.sha256Hex;

          // 1. addOwner returns false and record is gone
          final dbName1 = '${dbName}_w8_add_${entry.key.replaceAll(' ', '_')}';
          await _insertRawRecord(dbName1, hash, entry.value);
          final adapter1 = BlobStoreAdapter(databaseName: dbName1);
          adaptersToClose.add(adapter1);
          expect(await adapter1.addOwner(hash, 'new_owner').timeout(const Duration(seconds: 2)), isFalse);
          expect(await adapter1.has(hash).timeout(const Duration(seconds: 2)), isFalse);
          await adapter1.close();
          await _deleteIndexedDb(dbName1);

          // 2. put of good bytes under hash succeeds, get returns good bytes, releasing campaign removes it
          final dbName2 = '${dbName}_w8_put_${entry.key.replaceAll(' ', '_')}';
          await _insertRawRecord(dbName2, hash, entry.value);
          final adapter2 = BlobStoreAdapter(databaseName: dbName2);
          adaptersToClose.add(adapter2);
          await adapter2.put(ref, bytes, campaignId: 'c1').timeout(const Duration(seconds: 2));
          final stored = await adapter2.get(hash).timeout(const Duration(seconds: 2));
          expect(stored.bytes, equals(bytes));
          await adapter2.releaseCampaign('c1').timeout(const Duration(seconds: 2));
          expect(await adapter2.has(hash).timeout(const Duration(seconds: 2)), isFalse);
          await adapter2.close();
          await _deleteIndexedDb(dbName2);

          // 3. releaseCampaign('x') completes and record is gone
          final dbName3 = '${dbName}_w8_rel_${entry.key.replaceAll(' ', '_')}';
          await _insertRawRecord(dbName3, hash, entry.value);
          final adapter3 = BlobStoreAdapter(databaseName: dbName3);
          adaptersToClose.add(adapter3);
          await adapter3.releaseCampaign('x').timeout(const Duration(seconds: 2));
          expect(await adapter3.has(hash).timeout(const Duration(seconds: 2)), isFalse);
          await adapter3.close();
          await _deleteIndexedDb(dbName3);
        });
      }
    });

    test('W9: readable record with flipped byte: addOwner returns false and deletes; put replaces with good bytes', () async {
      final goodBytes = _makeWebp(1024);
      final ref = _makeRef(goodBytes, BlobFormat.webp);
      final hash = ref.sha256Hex;

      final damagedBytes = Uint8List.fromList(goodBytes);
      damagedBytes[15] ^= 0xFF;

      final damagedRecord = {
        'ref': ref.toMap(),
        'bytes': damagedBytes.toJS,
        'owners': ['campaign_A'],
      }.jsify()!;

      // 1. addOwner(hash, 'B') returns false and record is gone
      final dbName1 = '${dbName}_w9_addOwner';
      await _insertRawRecord(dbName1, hash, damagedRecord);
      final adapter1 = BlobStoreAdapter(databaseName: dbName1);
      adaptersToClose.add(adapter1);
      expect(await adapter1.addOwner(hash, 'campaign_B').timeout(const Duration(seconds: 2)), isFalse);
      expect(await adapter1.has(hash).timeout(const Duration(seconds: 2)), isFalse);
      await adapter1.close();
      await _deleteIndexedDb(dbName1);

      // 2. In fresh database with damaged record: put of good bytes succeeds and get returns good bytes
      final dbName2 = '${dbName}_w9_put';
      await _insertRawRecord(dbName2, hash, damagedRecord);
      final adapter2 = BlobStoreAdapter(databaseName: dbName2);
      adaptersToClose.add(adapter2);
      await adapter2.put(ref, goodBytes, campaignId: 'campaign_B').timeout(const Duration(seconds: 2));
      final stored = await adapter2.get(hash).timeout(const Duration(seconds: 2));
      expect(stored.bytes, equals(goodBytes));
      await adapter2.close();
      await _deleteIndexedDb(dbName2);
    });

    group('W10: aborted transaction throws within 2s, leaves store unchanged; control succeeds', () {
      Future<({BlobStoreAdapter adapter, AbortRecorder recorder})> createWrappingAdapter({
        required String targetDbName,
        required bool shouldAbort,
      }) async {
        final recorder = AbortRecorder();
        Future<web.IDBDatabase> wrappingOpener() async {
          final openCompleter = Completer<web.IDBDatabase>();
          final openReq = web.window.indexedDB.open(targetDbName, 1);
          openReq.onupgradeneeded = ((web.IDBVersionChangeEvent _) {
            final db = openReq.result as web.IDBDatabase;
            if (!db.objectStoreNames.contains('blobs')) {
              db.createObjectStore('blobs');
            }
          }).toJS;
          openReq.onsuccess = ((web.Event _) {
            openCompleter.complete(openReq.result as web.IDBDatabase);
          }).toJS;
          openReq.onerror = ((web.Event _) {
            openCompleter.completeError(StateError('Failed to open test IDB'));
          }).toJS;
          final db = await openCompleter.future;

          final origTxFn = (db as JSObject).getProperty<JSFunction>('transaction'.toJS);
          final txWrapper = ((JSAny storeNames, JSAny? mode) {
            final tx = origTxFn.callAsFunction(db, storeNames, mode) as web.IDBTransaction;
            if (shouldAbort) {
              final origObjectStoreFn = (tx as JSObject).getProperty<JSFunction>('objectStore'.toJS);
              var seenFirstRequestInTx = false;

              final objectStoreWrapper = ((JSAny name) {
                final store = origObjectStoreFn.callAsFunction(tx, name) as web.IDBObjectStore;
                final origGet = (store as JSObject).getProperty<JSFunction>('get'.toJS);
                final origOpenCursor = (store as JSObject).getProperty<JSFunction>('openCursor'.toJS);

                void intercept(web.IDBRequest req) {
                  if (seenFirstRequestInTx) return;
                  seenFirstRequestInTx = true;
                  req.addEventListener(
                    'success',
                    ((web.Event _) {
                      recorder.firstRequestSucceeded = true;
                      scheduleMicrotask(() {
                        try {
                          tx.abort();
                        } catch (_) {}
                      });
                    }).toJS,
                  );
                }

                final getWrapper = ((JSAny key) {
                  final req = origGet.callAsFunction(store, key) as web.IDBRequest;
                  scheduleMicrotask(() => intercept(req));
                  return req;
                }).toJS;

                final openCursorWrapper = (([JSAny? query, JSAny? direction]) {
                  final req = (query != null
                      ? (direction != null
                          ? origOpenCursor.callAsFunction(store, query, direction)
                          : origOpenCursor.callAsFunction(store, query))
                      : origOpenCursor.callAsFunction(store)) as web.IDBRequest;
                  scheduleMicrotask(() => intercept(req));
                  return req;
                }).toJS;

                (store as JSObject).setProperty('get'.toJS, getWrapper);
                (store as JSObject).setProperty('openCursor'.toJS, openCursorWrapper);
                return store;
              }).toJS;

              (tx as JSObject).setProperty('objectStore'.toJS, objectStoreWrapper);
            }
            return tx;
          }).toJS;

          (db as JSObject).setProperty('transaction'.toJS, txWrapper);
          return db;
        }

        final adapter = BlobStoreAdapter(databaseName: targetDbName, opener: wrappingOpener);
        adaptersToClose.add(adapter);
        return (adapter: adapter, recorder: recorder);
      }

      test('W10: aborted put of new blob throws within 2s, has is false', () async {
        final bytes = _makeWebp(500);
        final ref = _makeRef(bytes, BlobFormat.webp);

        final wrapped = await createWrappingAdapter(targetDbName: dbName, shouldAbort: true);
        await expectLater(
          wrapped.adapter.put(ref, bytes, campaignId: 'c1').timeout(const Duration(seconds: 2)),
          throwsA(anything),
        );
        expect(wrapped.recorder.firstRequestSucceeded, isTrue);

        final verifyAdapter = BlobStoreAdapter(databaseName: dbName);
        adaptersToClose.add(verifyAdapter);
        expect(await verifyAdapter.has(ref.sha256Hex).timeout(const Duration(seconds: 2)), isFalse);
      });

      test('W10: aborted addOwner of new owner throws within 2s, new owner was not recorded', () async {
        final bytes = _makeWebp(500);
        final ref = _makeRef(bytes, BlobFormat.webp);

        // Pre-store with regular adapter
        final setupAdapter = createAdapter();
        await setupAdapter.put(ref, bytes, campaignId: 'c_orig').timeout(const Duration(seconds: 2));
        await setupAdapter.close();

        // Aborted addOwner
        final wrapped = await createWrappingAdapter(targetDbName: dbName, shouldAbort: true);
        await expectLater(
          wrapped.adapter.addOwner(ref.sha256Hex, 'c_new').timeout(const Duration(seconds: 2)),
          throwsA(anything),
        );
        expect(wrapped.recorder.firstRequestSucceeded, isTrue);

        // Releasing original owner deletes blob because c_new was never recorded
        final verifyAdapter = BlobStoreAdapter(databaseName: dbName);
        adaptersToClose.add(verifyAdapter);
        await verifyAdapter.releaseCampaign('c_orig').timeout(const Duration(seconds: 2));
        expect(await verifyAdapter.has(ref.sha256Hex).timeout(const Duration(seconds: 2)), isFalse);
      });

      test('W10: aborted releaseCampaign throws within 2s, blob is still stored', () async {
        final bytes = _makeWebp(500);
        final ref = _makeRef(bytes, BlobFormat.webp);

        // Pre-store with regular adapter
        final setupAdapter = createAdapter();
        await setupAdapter.put(ref, bytes, campaignId: 'c_keep').timeout(const Duration(seconds: 2));
        await setupAdapter.close();

        // Aborted releaseCampaign
        final wrapped = await createWrappingAdapter(targetDbName: dbName, shouldAbort: true);
        await expectLater(
          wrapped.adapter.releaseCampaign('c_keep').timeout(const Duration(seconds: 2)),
          throwsA(anything),
        );
        expect(wrapped.recorder.firstRequestSucceeded, isTrue);

        // Blob is still stored
        final verifyAdapter = BlobStoreAdapter(databaseName: dbName);
        adaptersToClose.add(verifyAdapter);
        expect(await verifyAdapter.has(ref.sha256Hex).timeout(const Duration(seconds: 2)), isTrue);
      });

      test('W10: control with abort switched off: put, addOwner, releaseCampaign all succeed', () async {
        final bytes = _makeWebp(500);
        final ref = _makeRef(bytes, BlobFormat.webp);

        final wrapped = await createWrappingAdapter(targetDbName: dbName, shouldAbort: false);
        final adapter = wrapped.adapter;

        // put succeeds
        await adapter.put(ref, bytes, campaignId: 'c_orig').timeout(const Duration(seconds: 2));
        expect(await adapter.has(ref.sha256Hex).timeout(const Duration(seconds: 2)), isTrue);

        // addOwner succeeds
        expect(await adapter.addOwner(ref.sha256Hex, 'c_new').timeout(const Duration(seconds: 2)), isTrue);

        // release c_orig: still there because c_new owns it
        await adapter.releaseCampaign('c_orig').timeout(const Duration(seconds: 2));
        expect(await adapter.has(ref.sha256Hex).timeout(const Duration(seconds: 2)), isTrue);

        // release c_new: now gone
        await adapter.releaseCampaign('c_new').timeout(const Duration(seconds: 2));
        expect(await adapter.has(ref.sha256Hex).timeout(const Duration(seconds: 2)), isFalse);
      });
    });

    group('G1: concurrent put and get of damaged/unreadable record (0b)', () {
      test('G1a: race get and put on damaged record (5 iterations)', () async {
        for (var i = 0; i < 5; i++) {
          final testDbName = '${dbName}_g1a_$i';
          final goodBytes = _makeWebp(500);
          final ref = _makeRef(goodBytes, BlobFormat.webp);
          final hash = ref.sha256Hex;
          final damagedBytes = Uint8List.fromList(goodBytes);
          damagedBytes[20] ^= 0xFF;
          final damagedRecord = {
            'ref': ref.toMap(),
            'bytes': damagedBytes.toJS,
            'owners': ['old'],
          }.jsify()!;

          await _insertRawRecord(testDbName, hash, damagedRecord);
          final adapter = BlobStoreAdapter(databaseName: testDbName);
          adaptersToClose.add(adapter);

          final getFuture = adapter.get(hash);
          final putFuture = adapter.put(ref, goodBytes, campaignId: 'c2');

          Object? getResult;
          try {
            getResult = await getFuture.timeout(const Duration(seconds: 2));
          } catch (e) {
            getResult = e;
          }
          expect(
            getResult,
            anyOf(
              isA<BlobCorruptException>(),
              predicate<StoredBlob>((b) => b.bytes.length == goodBytes.length),
            ),
          );

          await putFuture.timeout(const Duration(seconds: 2));

          expect(await adapter.has(hash).timeout(const Duration(seconds: 2)), isTrue);
          final stored = await adapter.get(hash).timeout(const Duration(seconds: 2));
          expect(stored.bytes, equals(goodBytes));

          await adapter.releaseCampaign('c2').timeout(const Duration(seconds: 2));
          expect(await adapter.has(hash).timeout(const Duration(seconds: 2)), isFalse);

          await adapter.close();
          await _deleteIndexedDb(testDbName);
        }
      });

      test('G1b: same race with put started first and get second', () async {
        final testDbName = '${dbName}_g1b';
        final goodBytes = _makeWebp(500);
        final ref = _makeRef(goodBytes, BlobFormat.webp);
        final hash = ref.sha256Hex;
        final damagedBytes = Uint8List.fromList(goodBytes);
        damagedBytes[20] ^= 0xFF;
        final damagedRecord = {
          'ref': ref.toMap(),
          'bytes': damagedBytes.toJS,
          'owners': ['old'],
        }.jsify()!;

        await _insertRawRecord(testDbName, hash, damagedRecord);
        final adapter = BlobStoreAdapter(databaseName: testDbName);
        adaptersToClose.add(adapter);

        final putFuture = adapter.put(ref, goodBytes, campaignId: 'c2');
        final getFuture = adapter.get(hash);

        await putFuture.timeout(const Duration(seconds: 2));
        Object? getResult;
        try {
          getResult = await getFuture.timeout(const Duration(seconds: 2));
        } catch (e) {
          getResult = e;
        }
        expect(
          getResult,
          anyOf(
            isA<BlobCorruptException>(),
            predicate<StoredBlob>((b) => b.bytes.length == goodBytes.length),
          ),
        );

        expect(await adapter.has(hash).timeout(const Duration(seconds: 2)), isTrue);
        final stored = await adapter.get(hash).timeout(const Duration(seconds: 2));
        expect(stored.bytes, equals(goodBytes));

        await adapter.releaseCampaign('c2').timeout(const Duration(seconds: 2));
        expect(await adapter.has(hash).timeout(const Duration(seconds: 2)), isFalse);

        await adapter.close();
        await _deleteIndexedDb(testDbName);
      });

      test('G1c: same as G1a with unreadable record (ref.byteSize is oops)', () async {
        final testDbName = '${dbName}_g1c';
        final goodBytes = _makeWebp(500);
        final ref = _makeRef(goodBytes, BlobFormat.webp);
        final hash = ref.sha256Hex;
        final badRefMap = ref.toMap();
        badRefMap['byteSize'] = 'oops';
        final unreadableRecord = {
          'ref': badRefMap,
          'bytes': goodBytes.toJS,
          'owners': ['old'],
        }.jsify()!;

        await _insertRawRecord(testDbName, hash, unreadableRecord);
        final adapter = BlobStoreAdapter(databaseName: testDbName);
        adaptersToClose.add(adapter);

        final getFuture = adapter.get(hash);
        final putFuture = adapter.put(ref, goodBytes, campaignId: 'c2');

        Object? getResult;
        try {
          getResult = await getFuture.timeout(const Duration(seconds: 2));
        } catch (e) {
          getResult = e;
        }
        expect(
          getResult,
          anyOf(
            isA<BlobCorruptException>(),
            predicate<StoredBlob>((b) => b.bytes.length == goodBytes.length),
          ),
        );

        await putFuture.timeout(const Duration(seconds: 2));

        expect(await adapter.has(hash).timeout(const Duration(seconds: 2)), isTrue);
        final stored = await adapter.get(hash).timeout(const Duration(seconds: 2));
        expect(stored.bytes, equals(goodBytes));

        await adapter.releaseCampaign('c2').timeout(const Duration(seconds: 2));
        expect(await adapter.has(hash).timeout(const Duration(seconds: 2)), isFalse);

        await adapter.close();
        await _deleteIndexedDb(testDbName);
      });

      test('G1d: control with calls one after the other', () async {
        final testDbName = '${dbName}_g1d';
        final goodBytes = _makeWebp(500);
        final ref = _makeRef(goodBytes, BlobFormat.webp);
        final hash = ref.sha256Hex;
        final damagedBytes = Uint8List.fromList(goodBytes);
        damagedBytes[20] ^= 0xFF;
        final damagedRecord = {
          'ref': ref.toMap(),
          'bytes': damagedBytes.toJS,
          'owners': ['old'],
        }.jsify()!;

        await _insertRawRecord(testDbName, hash, damagedRecord);
        final adapter = BlobStoreAdapter(databaseName: testDbName);
        adaptersToClose.add(adapter);

        try {
          await adapter.get(hash).timeout(const Duration(seconds: 2));
        } on BlobCorruptException catch (_) {}

        await adapter.put(ref, goodBytes, campaignId: 'c2').timeout(const Duration(seconds: 2));

        expect(await adapter.has(hash).timeout(const Duration(seconds: 2)), isTrue);
        final stored = await adapter.get(hash).timeout(const Duration(seconds: 2));
        expect(stored.bytes, equals(goodBytes));

        await adapter.releaseCampaign('c2').timeout(const Duration(seconds: 2));
        expect(await adapter.has(hash).timeout(const Duration(seconds: 2)), isFalse);

        await adapter.close();
        await _deleteIndexedDb(testDbName);
      });
    });
  });
}

Future<void> _insertRawRecord(String dbName, String sha256Hex, JSAny record) async {
  final openCompleter = Completer<web.IDBDatabase>();
  final openReq = web.window.indexedDB.open(dbName, 1);
  openReq.onupgradeneeded = ((web.IDBVersionChangeEvent _) {
    final db = openReq.result as web.IDBDatabase;
    if (!db.objectStoreNames.contains('blobs')) {
      db.createObjectStore('blobs');
    }
  }).toJS;
  openReq.onsuccess = ((web.Event _) {
    openCompleter.complete(openReq.result as web.IDBDatabase);
  }).toJS;
  openReq.onerror = ((web.Event _) {
    openCompleter.completeError(StateError('Failed to open test IDB'));
  }).toJS;
  final db = await openCompleter.future;

  final tx = db.transaction('blobs'.toJS, 'readwrite');
  final store = tx.objectStore('blobs');
  store.put(record, sha256Hex.toJS);

  final txCompleter = Completer<void>();
  tx.oncomplete = ((web.Event _) => txCompleter.complete()).toJS;
  tx.onerror = ((web.Event _) => txCompleter.completeError(StateError('Raw put failed'))).toJS;
  await txCompleter.future;
  db.close();
}

class AbortRecorder {
  bool firstRequestSucceeded = false;
}
