import 'dart:typed_data';
import 'package:vtt_engine_core/vtt_engine_core.dart';
import '../../../application/blob/blob_store_port.dart';

class BlobStoreAdapter implements BlobStorePort {
  const BlobStoreAdapter({
    String? databaseName,
    dynamic opener,
  });

  @override
  Future<bool> has(String sha256Hex) async {
    throw const BlobStoreUnavailableException('blob store is only available on web');
  }

  @override
  Future<bool> addOwner(String sha256Hex, String campaignId) async {
    throw const BlobStoreUnavailableException('blob store is only available on web');
  }

  @override
  Future<void> put(BlobRef ref, Uint8List bytes, {required String campaignId}) async {
    throw const BlobStoreUnavailableException('blob store is only available on web');
  }

  @override
  Future<StoredBlob> get(String sha256Hex) async {
    throw const BlobStoreUnavailableException('blob store is only available on web');
  }

  @override
  Future<void> releaseCampaign(String campaignId) async {
    throw const BlobStoreUnavailableException('blob store is only available on web');
  }

  Future<void> close() async {}
}
