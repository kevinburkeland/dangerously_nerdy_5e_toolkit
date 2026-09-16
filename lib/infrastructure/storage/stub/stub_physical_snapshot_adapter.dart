import '../../../domain/storage/models/storage_snapshot_bundle.dart';
import '../../../domain/storage/ports/i_physical_snapshot_port.dart';

/// Non-web fallback stub adapter for cold-storage snapshot export and import.
class PhysicalSnapshotAdapter implements IPhysicalSnapshotPort {
  const PhysicalSnapshotAdapter();

  @override
  Future<void> exportAtomicSnapshot({
    required String fileName,
    required StorageSnapshotBundle bundle,
  }) async {
    // No-op fallback in headless or non-web environments
  }

  @override
  Future<StorageSnapshotBundle?> importAtomicSnapshot() async {
    return null;
  }
}
