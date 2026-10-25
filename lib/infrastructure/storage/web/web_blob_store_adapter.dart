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

  Future<T> _runTransaction<T>(
    String mode,
    void Function(
      web.IDBObjectStore store,
      void Function(T value) deliver,
      void Function(web.IDBRequest request, void Function() onOk) bind,
      web.IDBTransaction tx,
    ) body,
  ) async {
    final db = await _getDb();
    final completer = Completer<T>();
    T? result;
    bool hasResult = false;

    final tx = db.transaction('blobs'.toJS, mode);

    void abortWith(Object error, [StackTrace? stackTrace]) {
      if (!completer.isCompleted) {
        completer.completeError(error, stackTrace);
      }
      try {
        tx.abort();
      } catch (_) {
        // intentional: ignore error if transaction is already closing/aborted
      }
    }

    tx.oncomplete = ((web.Event event) {
      if (!completer.isCompleted) {
        if (hasResult) {
          completer.complete(result as T);
        } else {
          completer.complete(null as T);
        }
      }
    }).toJS;

    tx.onerror = ((web.Event event) {
      if (!completer.isCompleted) {
        completer.completeError(
          StateError('Transaction error: ${tx.error?.message}'),
        );
      }
    }).toJS;

    tx.onabort = ((web.Event event) {
      if (!completer.isCompleted) {
        completer.completeError(
          StateError('Transaction aborted: ${tx.error?.message}'),
        );
      }
    }).toJS;

    void deliver(T value) {
      result = value;
      hasResult = true;
    }

    void bind(web.IDBRequest request, void Function() onOk) {
      request.onsuccess = ((web.Event event) {
        try {
          onOk();
        } catch (e, st) {
          abortWith(e, st);
        }
      }).toJS;

      request.onerror = ((web.Event event) {
        abortWith(StateError('Request error: ${request.error?.message}'));
      }).toJS;
    }

    try {
      final store = tx.objectStore('blobs');
      body(store, deliver, bind, tx);
    } catch (e, st) {
      abortWith(e, st);
    }

    return completer.future;
  }

  (StoredBlob, List<String>)? _parseRecord(JSAny? raw) {
    if (raw == null || raw.isUndefinedOrNull) return null;
    final dartVal = raw.dartify();
    if (dartVal is! Map) return null;

    final rawRef = dartVal['ref'];
    if (rawRef is! Map) return null;
    BlobRef ref;
    try {
      ref = BlobRef.fromMap(rawRef.cast<String, dynamic>());
    } catch (_) {
      // intentional: invalid ref data
      return null;
    }

    final rawBytes = dartVal['bytes'];
    final Uint8List bytes;
    if (rawBytes is Uint8List) {
      bytes = rawBytes;
    } else if (rawBytes is ByteBuffer) {
      bytes = rawBytes.asUint8List();
    } else {
      return null;
    }

    final rawOwners = dartVal['owners'];
    if (rawOwners is! List) return null;
    final owners = <String>[];
    for (final o in rawOwners) {
      if (o is! String) return null;
      owners.add(o);
    }

    return (StoredBlob(ref, bytes), owners);
  }

  @override
  Future<bool> has(String sha256Hex) {
    return _runTransaction<bool>('readonly', (store, deliver, bind, tx) {
      final req = store.get(sha256Hex.toJS);
      bind(req, () {
        final res = req.result;
        deliver(res != null && !res.isUndefinedOrNull);
      });
    });
  }

  @override
  Future<bool> addOwner(String sha256Hex, String campaignId) {
    return _runTransaction<bool>('readwrite', (store, deliver, bind, tx) {
      final req = store.get(sha256Hex.toJS);
      bind(req, () {
        final raw = req.result;
        if (raw == null || raw.isUndefinedOrNull) {
          deliver(false);
          return;
        }
        final parsed = _parseRecord(raw);
        if (parsed == null) {
          // Unreadable: delete and return false
          store.delete(sha256Hex.toJS);
          deliver(false);
          return;
        }
        final (stored, owners) = parsed;
        final verdict = verifyBlob(stored.ref, stored.bytes);
        if (verdict != BlobVerdict.ok) {
          // Fails verifyBlob: delete and return false
          store.delete(sha256Hex.toJS);
          deliver(false);
          return;
        }
        if (!owners.contains(campaignId)) {
          owners.add(campaignId);
          final record = {
            'ref': stored.ref.toMap(),
            'bytes': stored.bytes.toJS,
            'owners': owners,
          }.jsify()!;
          store.put(record, sha256Hex.toJS);
        }
        deliver(true);
      });
    });
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

    await _runTransaction<void>('readwrite', (store, deliver, bind, tx) {
      final req = store.get(ref.sha256Hex.toJS);
      bind(req, () {
        final raw = req.result;
        if (raw == null || raw.isUndefinedOrNull) {
          // New entry
          final record = {
            'ref': ref.toMap(),
            'bytes': bytes.toJS,
            'owners': [campaignId],
          }.jsify()!;
          store.put(record, ref.sha256Hex.toJS);
          return;
        }
        final parsed = _parseRecord(raw);
        if (parsed == null) {
          // Bad record (unreadable): replace it with fresh record
          final record = {
            'ref': ref.toMap(),
            'bytes': bytes.toJS,
            'owners': [campaignId],
          }.jsify()!;
          store.put(record, ref.sha256Hex.toJS);
          return;
        }
        final (stored, owners) = parsed;
        final existingVerdict = verifyBlob(stored.ref, stored.bytes);
        if (existingVerdict != BlobVerdict.ok) {
          // Bad record (damaged bytes): replace it with fresh record
          final record = {
            'ref': ref.toMap(),
            'bytes': bytes.toJS,
            'owners': [campaignId],
          }.jsify()!;
          store.put(record, ref.sha256Hex.toJS);
          return;
        }
        // Good record: only add owner
        if (!owners.contains(campaignId)) {
          owners.add(campaignId);
          final record = {
            'ref': stored.ref.toMap(),
            'bytes': stored.bytes.toJS,
            'owners': owners,
          }.jsify()!;
          store.put(record, ref.sha256Hex.toJS);
        }
      });
    });
  }

  @override
  Future<StoredBlob> get(String sha256Hex) async {
    final res = await _runTransaction<({StoredBlob? blob, bool notFound, BlobVerdict? verdict})>(
      'readwrite',
      (store, deliver, bind, tx) {
        final req = store.get(sha256Hex.toJS);
        bind(req, () {
          final raw = req.result;
          if (raw == null || raw.isUndefinedOrNull) {
            deliver((blob: null, notFound: true, verdict: null));
            return;
          }
          final parsed = _parseRecord(raw);
          if (parsed == null) {
            store.delete(sha256Hex.toJS);
            deliver((blob: null, notFound: false, verdict: null));
            return;
          }
          final (stored, _) = parsed;
          final verdict = verifyBlob(stored.ref, stored.bytes);
          if (verdict != BlobVerdict.ok) {
            store.delete(sha256Hex.toJS);
            deliver((blob: null, notFound: false, verdict: verdict));
            return;
          }
          deliver((blob: stored, notFound: false, verdict: null));
        });
      },
    );

    if (res.notFound) {
      throw BlobNotFoundException(sha256Hex);
    }
    if (res.blob == null) {
      throw BlobCorruptException(sha256Hex, res.verdict);
    }
    return res.blob!;
  }

  @override
  Future<void> releaseCampaign(String campaignId) {
    return _runTransaction<void>('readwrite', (store, deliver, bind, tx) {
      final cursorReq = store.openCursor();
      bind(cursorReq, () {
        final cursor = cursorReq.result as web.IDBCursorWithValue?;
        if (cursor == null) {
          return;
        }
        final parsed = _parseRecord(cursor.value);
        if (parsed == null) {
          // Bad record (unreadable): delete it
          cursor.delete();
          cursor.continue_();
          return;
        }
        final (stored, owners) = parsed;
        final verdict = verifyBlob(stored.ref, stored.bytes);
        if (verdict != BlobVerdict.ok) {
          // Bad record (damaged bytes): delete it
          cursor.delete();
          cursor.continue_();
          return;
        }
        if (owners.contains(campaignId)) {
          owners.remove(campaignId);
          if (owners.isEmpty) {
            cursor.delete();
          } else {
            final record = {
              'ref': stored.ref.toMap(),
              'bytes': stored.bytes.toJS,
              'owners': owners,
            }.jsify()!;
            cursor.update(record);
          }
        }
        cursor.continue_();
      });
    });
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
