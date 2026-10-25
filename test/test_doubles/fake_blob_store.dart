import 'dart:typed_data';
import 'package:dangerously_nerdy_5e_toolkit/application/blob/blob_store_port.dart';
import 'package:dangerously_nerdy_5e_toolkit/application/blob/blob_verifier.dart';
import 'package:vtt_engine_core/vtt_engine_core.dart';

class PutAttempt {
  final BlobRef ref;
  final Uint8List bytes;
  final String campaignId;

  const PutAttempt(this.ref, this.bytes, this.campaignId);
}

class FakeBlobStore implements BlobStorePort {
  final Map<String, StoredBlob> _blobs = {};
  final Map<String, Set<String>> _owners = {};
  final List<PutAttempt> putAttempts = [];

  bool throwOnPut = false;
  Exception? putException;

  int get count => _blobs.length;

  bool hasSync(String sha256Hex) => _blobs.containsKey(sha256Hex);
  StoredBlob? getSync(String sha256Hex) => _blobs[sha256Hex];

  /// Directly stores without verification (useful for setting up corrupt test fixtures).
  void insertRawCorruptEntry(BlobRef ref, Uint8List bytes, {required String campaignId}) {
    _blobs[ref.sha256Hex] = StoredBlob(ref, bytes);
    _owners.putIfAbsent(ref.sha256Hex, () => {}).add(campaignId);
  }

  @override
  Future<bool> has(String sha256Hex) async {
    return _blobs.containsKey(sha256Hex);
  }

  @override
  Future<bool> addOwner(String sha256Hex, String campaignId) async {
    if (!_blobs.containsKey(sha256Hex)) {
      return false;
    }
    _owners.putIfAbsent(sha256Hex, () => {}).add(campaignId);
    return true;
  }

  @override
  Future<void> put(
    BlobRef ref,
    Uint8List bytes, {
    required String campaignId,
  }) async {
    putAttempts.add(PutAttempt(ref, bytes, campaignId));

    if (throwOnPut) {
      throw putException ?? StateError('FakeBlobStore: simulated write failure on put');
    }

    final verdict = verifyBlob(ref, bytes);
    if (verdict != BlobVerdict.ok) {
      throw BlobRejectedException(verdict);
    }

    if (_blobs.containsKey(ref.sha256Hex)) {
      _owners.putIfAbsent(ref.sha256Hex, () => {}).add(campaignId);
      return;
    }

    _blobs[ref.sha256Hex] = StoredBlob(ref, bytes);
    _owners.putIfAbsent(ref.sha256Hex, () => {}).add(campaignId);
  }

  @override
  Future<StoredBlob> get(String sha256Hex) async {
    final stored = _blobs[sha256Hex];
    if (stored == null) {
      throw BlobNotFoundException(sha256Hex);
    }

    final verdict = verifyBlob(stored.ref, stored.bytes);
    if (verdict != BlobVerdict.ok) {
      _blobs.remove(sha256Hex);
      _owners.remove(sha256Hex);
      throw BlobCorruptException(sha256Hex, verdict);
    }

    return stored;
  }

  @override
  Future<void> releaseCampaign(String campaignId) async {
    final toRemove = <String>[];
    for (final entry in _owners.entries) {
      entry.value.remove(campaignId);
      if (entry.value.isEmpty) {
        toRemove.add(entry.key);
      }
    }

    for (final hash in toRemove) {
      _blobs.remove(hash);
      _owners.remove(hash);
    }
  }

  Set<String> getOwners(String sha256Hex) =>
      Set.unmodifiable(_owners[sha256Hex] ?? {});
}
