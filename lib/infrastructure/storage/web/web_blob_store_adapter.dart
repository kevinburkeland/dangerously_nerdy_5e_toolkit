import 'dart:async';
import 'dart:js_interop';
import 'dart:typed_data';
import 'package:web/web.dart' as web;
import 'package:vtt_engine_core/vtt_engine_core.dart';
import '../../../application/blob/blob_store_port.dart';
import '../../../application/blob/blob_verifier.dart';

class BlobStoreAdapter implements BlobStorePort {
  final String _databaseName;
  final Future<web.IDBDatabase> Function()? _customOpener;

  Future<web.IDBDatabase>? _dbFuture;
  bool _failedToOpen = false;
  String? _openErrorMessage;

  BlobStoreAdapter({
    String? databaseName,
    Future<web.IDBDatabase> Function()? opener,
  })  : _databaseName = databaseName ?? 'dn5e_blobs',
        _customOpener = opener;

  Future<web.IDBDatabase> _getDb() async {
    if (_failedToOpen) {
      throw BlobStoreUnavailableException(
        _openErrorMessage ?? 'Blob store database is unavailable',
      );
    }

    if (_dbFuture != null) {
      try {
        return await _dbFuture!;
      } catch (e) {
        _failedToOpen = true;
        _openErrorMessage = e.toString();
        throw BlobStoreUnavailableException('Failed to open database: $e');
      }
    }

    final opener = _customOpener ?? () => _defaultOpener(_databaseName);
    final future = opener();
    _dbFuture = future;

    try {
      return await future;
    } catch (e) {
      _failedToOpen = true;
      _openErrorMessage = e.toString();
      throw BlobStoreUnavailableException('Failed to open database: $e');
    }
  }

  static Future<web.IDBDatabase> _defaultOpener(String dbName) {
    final completer = Completer<web.IDBDatabase>();
    final idb = web.window.indexedDB;
    // ignore: unnecessary_null_comparison
    if (idb == null) {
      completer.completeError(
        const BlobStoreUnavailableException('IndexedDB not supported'),
      );
      return completer.future;
    }

    final req = idb.open(dbName, 1);

    req.onupgradeneeded = ((web.IDBVersionChangeEvent event) {
      final db = req.result as web.IDBDatabase;
      if (!db.objectStoreNames.contains('blobs')) {
        db.createObjectStore('blobs');
      }
    }).toJS;

    req.onsuccess = ((web.Event event) {
      completer.complete(req.result as web.IDBDatabase);
    }).toJS;

    req.onerror = ((web.Event event) {
      completer.completeError(
        BlobStoreUnavailableException(
          'Failed to open IndexedDB database "$dbName": ${req.error?.message}',
        ),
      );
    }).toJS;

    req.onblocked = ((web.Event event) {
      completer.completeError(
        const BlobStoreUnavailableException('Database open request blocked'),
      );
    }).toJS;

    return completer.future;
  }

  @override
  Future<bool> has(String sha256Hex) async {
    final db = await _getDb();
    final completer = Completer<bool>();

    final tx = db.transaction('blobs'.toJS, 'readonly');
    final store = tx.objectStore('blobs');
    final req = store.get(sha256Hex.toJS);

    req.onsuccess = ((web.Event event) {
      final res = req.result;
      completer.complete(res != null && !res.isUndefinedOrNull);
    }).toJS;

    req.onerror = ((web.Event event) {
      completer.completeError(
        StateError('Failed to read from IndexedDB: ${req.error?.message}'),
      );
    }).toJS;

    tx.onerror = ((web.Event event) {
      if (!completer.isCompleted) {
        completer.completeError(
          StateError('Transaction failed: ${tx.error?.message}'),
        );
      }
    }).toJS;

    return completer.future;
  }

  @override
  Future<bool> addOwner(String sha256Hex, String campaignId) async {
    final db = await _getDb();
    final completer = Completer<bool>();

    final tx = db.transaction('blobs'.toJS, 'readwrite');
    final store = tx.objectStore('blobs');
    final req = store.get(sha256Hex.toJS);

    req.onsuccess = ((web.Event event) {
      final res = req.result;
      if (res == null || res.isUndefinedOrNull) {
        completer.complete(false);
        return;
      }

      final data = (res as JSObject).dartify() as Map<Object?, Object?>;
      final rawOwners = data['owners'] as List<Object?>? ?? [];
      final owners = rawOwners.map((e) => e.toString()).toList();

      if (!owners.contains(campaignId)) {
        owners.add(campaignId);
        data['owners'] = owners;
        store.put(data.jsify()!, sha256Hex.toJS);
      }
      completer.complete(true);
    }).toJS;

    req.onerror = ((web.Event event) {
      completer.completeError(
        StateError('Failed to add owner in IndexedDB: ${req.error?.message}'),
      );
    }).toJS;

    tx.onerror = ((web.Event event) {
      if (!completer.isCompleted) {
        completer.completeError(
          StateError('Transaction failed: ${tx.error?.message}'),
        );
      }
    }).toJS;

    return completer.future;
  }

  @override
  Future<void> put(
    BlobRef ref,
    Uint8List bytes, {
    required String campaignId,
  }) async {
    final verdict = verifyBlob(ref, bytes);
    if (verdict != BlobVerdict.ok) {
      throw BlobRejectedException(verdict);
    }

    final db = await _getDb();
    final completer = Completer<void>();

    final tx = db.transaction('blobs'.toJS, 'readwrite');
    final store = tx.objectStore('blobs');
    final req = store.get(ref.sha256Hex.toJS);

    req.onsuccess = ((web.Event event) {
      final res = req.result;
      if (res != null && !res.isUndefinedOrNull) {
        // Entry already exists: only add the owner
        final data = (res as JSObject).dartify() as Map<Object?, Object?>;
        final rawOwners = data['owners'] as List<Object?>? ?? [];
        final owners = rawOwners.map((e) => e.toString()).toList();
        if (!owners.contains(campaignId)) {
          owners.add(campaignId);
          data['owners'] = owners;
          store.put(data.jsify()!, ref.sha256Hex.toJS);
        }
      } else {
        // New entry
        final record = {
          'ref': ref.toMap(),
          'bytes': bytes.toJS,
          'owners': [campaignId],
        }.jsify()!;
        store.put(record, ref.sha256Hex.toJS);
      }
    }).toJS;

    req.onerror = ((web.Event event) {
      if (!completer.isCompleted) {
        completer.completeError(
          StateError('Failed to put blob in IndexedDB: ${req.error?.message}'),
        );
      }
    }).toJS;

    tx.oncomplete = ((web.Event event) {
      if (!completer.isCompleted) {
        completer.complete();
      }
    }).toJS;

    tx.onerror = ((web.Event event) {
      if (!completer.isCompleted) {
        completer.completeError(
          StateError('Transaction failed on put: ${tx.error?.message}'),
        );
      }
    }).toJS;

    return completer.future;
  }

  @override
  Future<StoredBlob> get(String sha256Hex) async {
    final db = await _getDb();
    final completer = Completer<Map<String, dynamic>>();

    final tx = db.transaction('blobs'.toJS, 'readonly');
    final store = tx.objectStore('blobs');
    final req = store.get(sha256Hex.toJS);

    req.onsuccess = ((web.Event event) {
      final res = req.result;
      if (res == null || res.isUndefinedOrNull) {
        completer.completeError(BlobNotFoundException(sha256Hex));
        return;
      }

      final data = (res as JSObject).dartify() as Map<Object?, Object?>;
      final rawRef = (data['ref'] as Map<Object?, Object?>).cast<String, dynamic>();
      final bytes = data['bytes'] as Uint8List;
      completer.complete({
        'ref': BlobRef.fromMap(rawRef),
        'bytes': bytes,
      });
    }).toJS;

    req.onerror = ((web.Event event) {
      completer.completeError(
        StateError('Failed to read blob from IndexedDB: ${req.error?.message}'),
      );
    }).toJS;

    tx.onerror = ((web.Event event) {
      if (!completer.isCompleted) {
        completer.completeError(
          StateError('Transaction error: ${tx.error?.message}'),
        );
      }
    }).toJS;

    final result = await completer.future;
    final ref = result['ref'] as BlobRef;
    final bytes = result['bytes'] as Uint8List;

    final verdict = verifyBlob(ref, bytes);
    if (verdict != BlobVerdict.ok) {
      await _deleteEntry(db, sha256Hex);
      throw BlobCorruptException(sha256Hex, verdict);
    }

    return StoredBlob(ref, bytes);
  }

  Future<void> _deleteEntry(web.IDBDatabase db, String sha256Hex) {
    final completer = Completer<void>();
    final tx = db.transaction('blobs'.toJS, 'readwrite');
    final store = tx.objectStore('blobs');
    store.delete(sha256Hex.toJS);

    tx.oncomplete = ((web.Event event) => completer.complete()).toJS;
    tx.onerror = ((web.Event event) => completer.completeError(
          StateError('Delete failed: ${tx.error?.message}'),
        )).toJS;

    return completer.future;
  }

  @override
  Future<void> releaseCampaign(String campaignId) async {
    final db = await _getDb();
    final completer = Completer<void>();

    final tx = db.transaction('blobs'.toJS, 'readwrite');
    final store = tx.objectStore('blobs');
    final cursorReq = store.openCursor();

    cursorReq.onsuccess = ((web.Event event) {
      final cursor = cursorReq.result as web.IDBCursorWithValue?;
      if (cursor == null) {
        return;
      }

      final data = (cursor.value as JSObject).dartify() as Map<Object?, Object?>;
      final rawOwners = data['owners'] as List<Object?>? ?? [];
      final owners = rawOwners.map((e) => e.toString()).toList();

      if (owners.contains(campaignId)) {
        owners.remove(campaignId);
        if (owners.isEmpty) {
          cursor.delete();
        } else {
          data['owners'] = owners;
          cursor.update(data.jsify()!);
        }
      }
      cursor.continue_();
    }).toJS;

    cursorReq.onerror = ((web.Event event) {
      if (!completer.isCompleted) {
        completer.completeError(
          StateError('Cursor error in releaseCampaign: ${cursorReq.error?.message}'),
        );
      }
    }).toJS;

    tx.oncomplete = ((web.Event event) {
      if (!completer.isCompleted) {
        completer.complete();
      }
    }).toJS;

    tx.onerror = ((web.Event event) {
      if (!completer.isCompleted) {
        completer.completeError(
          StateError('Transaction failed on releaseCampaign: ${tx.error?.message}'),
        );
      }
    }).toJS;

    return completer.future;
  }

  Future<void> close() async {
    if (_dbFuture != null) {
      try {
        final db = await _dbFuture!;
        db.close();
      } catch (_) {
        // intentional: database was already closed or closing
      }
    }
  }
}
