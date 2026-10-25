import 'package:crypto/crypto.dart';
import 'package:vtt_engine_core/vtt_engine_core.dart';
import '../blob/blob_store_port.dart';
import '../blob/blob_verifier.dart';
import 'map_image_header.dart';
import 'map_image_intake_port.dart';

final class MapSetResult {
  final BlobRef ref;
  final int originalWidth;
  final int originalHeight;
  final bool scaledDown;

  const MapSetResult(
    this.ref,
    this.originalWidth,
    this.originalHeight, {
    required this.scaledDown,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MapSetResult &&
          ref == other.ref &&
          originalWidth == other.originalWidth &&
          originalHeight == other.originalHeight &&
          scaledDown == other.scaledDown;

  @override
  int get hashCode => Object.hash(ref, originalWidth, originalHeight, scaledDown);

  @override
  String toString() =>
      'MapSetResult(${ref.sha256Hex}, ${originalWidth}x$originalHeight, scaled: $scaledDown)';
}

class MapIntakeService {
  final MapImageIntakePort intake;
  final BlobStorePort store;
  final ICampaignRepository campaignRepo;
  final StatefulHlcClock clock;

  const MapIntakeService({
    required this.intake,
    required this.store,
    required this.campaignRepo,
    required this.clock,
  });

  Future<MapSetResult> setMapFromSource(
    MapImageSource source, {
    required String campaignId,
  }) async {
    // 1. Read header
    final header = await readMapImageHeader(source.readRange, source.byteSize);

    // 2. Target size
    final target = mapTargetSize(header.width, header.height);

    // 3. Normalize image
    final out = await intake.normalize(
      source,
      targetWidth: target.width,
      targetHeight: target.height,
    );

    // 4. Build BlobRef (SB12: only place under lib/ that constructs a BlobRef)
    final hash = sha256.convert(out.bytes).toString().toLowerCase();
    final BlobRef ref;
    try {
      ref = BlobRef(
        sha256Hex: hash,
        byteSize: out.bytes.length,
        width: out.width,
        height: out.height,
        format: out.format,
      );
    } catch (_) {
      throw MapIntakeRejected(
        MapRejectReason.outputTooLarge,
        byteSize: out.bytes.length,
      );
    }

    // 5. verifyBlob must be ok
    final verdict = verifyBlob(ref, out.bytes);
    if (verdict != BlobVerdict.ok) {
      throw const MapIntakeRejected(MapRejectReason.encoderMismatch);
    }

    // 6. Put in store
    await store.put(ref, out.bytes, campaignId: campaignId);

    // 7. Only after put succeeded: update profile activeMapRegister
    await campaignRepo.updateProfile(
      campaignId,
      (current) => current.copyWith(
        activeMapRegister: CrdtLwwRegister<BlobRef?>(
          value: ref,
          timestamp: clock.nextTimestamp(),
        ),
      ),
    );

    // 8. Return result
    final scaledDown =
        target.width != header.width || target.height != header.height;
    return MapSetResult(
      ref,
      header.width,
      header.height,
      scaledDown: scaledDown,
    );
  }

  Future<void> clearMap({required String campaignId}) async {
    await campaignRepo.updateProfile(
      campaignId,
      (current) => current.copyWith(
        activeMapRegister: CrdtLwwRegister<BlobRef?>(
          value: null,
          timestamp: clock.nextTimestamp(),
        ),
      ),
    );
  }
}
