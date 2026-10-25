import 'dart:typed_data';
import 'package:vtt_engine_core/vtt_engine_core.dart';
import 'blob_verifier.dart';

class StoredBlob {
  final BlobRef ref;
  final Uint8List bytes;

  const StoredBlob(this.ref, this.bytes);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is StoredBlob &&
          ref == other.ref &&
          _bytesEqual(bytes, other.bytes);

  static bool _bytesEqual(Uint8List a, Uint8List b) {
    if (identical(a, b)) return true;
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  @override
  int get hashCode => Object.hash(ref, bytes.length);
}

class BlobStoreUnavailableException implements Exception {
  final String message;
  const BlobStoreUnavailableException([this.message = 'Blob store is unavailable']);

  @override
  String toString() => 'BlobStoreUnavailableException: $message';
}

class BlobRejectedException implements Exception {
  final BlobVerdict verdict;
  const BlobRejectedException(this.verdict);

  @override
  String toString() => 'BlobRejectedException: $verdict';
}

class BlobNotFoundException implements Exception {
  final String sha256Hex;
  const BlobNotFoundException(this.sha256Hex);

  @override
  String toString() => 'BlobNotFoundException: $sha256Hex';
}

class BlobCorruptException implements Exception {
  final String sha256Hex;
  /// The verification verdict, or null if the record could not be read.
  final BlobVerdict? verdict;
  const BlobCorruptException(this.sha256Hex, [this.verdict]);

  @override
  String toString() => 'BlobCorruptException($sha256Hex, $verdict)';
}

abstract interface class BlobStorePort {
  Future<bool> has(String sha256Hex);

  /// Adds [campaignId] as an owner if the blob is stored. Returns false if it isn't.
  /// If the stored entry fails verifyBlob or is unreadable, deletes it and returns false.
  Future<bool> addOwner(String sha256Hex, String campaignId);

  /// Verifies with verifyBlob first. On anything but ok: throws BlobRejectedException(verdict)
  /// and writes nothing. If the hash is already stored, only adds the owner.
  /// If the existing entry fails verifyBlob or is unreadable, replaces it with a fresh
  /// record whose owners are just this campaign.
  Future<void> put(BlobRef ref, Uint8List bytes, {required String campaignId});

  /// Returns the stored ref and bytes after re-checking them with verifyBlob.
  /// Missing: throws BlobNotFoundException. Fails the check: deletes the entry,
  /// then throws BlobCorruptException.
  Future<StoredBlob> get(String sha256Hex);

  /// Removes [campaignId] from every entry's owners and deletes entries left with none.
  Future<void> releaseCampaign(String campaignId);
}
