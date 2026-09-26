import 'dart:async';
import 'package:vtt_engine_core/models/campaign_profile.dart';
import 'package:vtt_engine_core/ports/i_campaign_repository.dart';
import 'package:vtt_engine_core/storage/models/engine_profile.dart';
import 'package:vtt_engine_core/storage/models/storage_snapshot_bundle.dart';
import 'package:vtt_engine_core/storage/models/storage_telemetry_report.dart';
import 'package:vtt_engine_core/storage/ports/i_campaign_snapshot_serializer_port.dart';
import 'package:vtt_engine_core/storage/ports/i_physical_snapshot_port.dart';
import 'package:vtt_engine_core/storage/ports/i_storage_durability_port.dart';

/// Application coordinator governing browser storage persistence negotiation,
/// ambient telemetry reporting, and tamper-evident cold storage backups.
class StorageDurabilityCoordinator {
  final IStorageDurabilityPort storagePort;
  final IPhysicalSnapshotPort snapshotPort;
  final ICampaignRepository campaignRepo;
  final ICampaignSnapshotSerializerPort? serializer;

  final StreamController<StorageTelemetryReport> _telemetryController =
      StreamController<StorageTelemetryReport>.broadcast(sync: false);

  StorageTelemetryReport? _currentTelemetry;
  bool _requiresContextualPrompt = false;

  StorageDurabilityCoordinator({
    required this.storagePort,
    required this.snapshotPort,
    required this.campaignRepo,
    ICampaignSnapshotSerializerPort? serializer,
  }) : serializer = serializer ??
            ICampaignSnapshotSerializerPort.defaultProvider?.call();

  /// Reactive stream broadcasting storage persistence, quota, and risk diagnostics.
  Stream<StorageTelemetryReport> get telemetryStream =>
      _telemetryController.stream;

  /// Latest captured storage telemetry snapshot.
  StorageTelemetryReport? get currentTelemetry => _currentTelemetry;

  /// Whether host browser policies (e.g. Firefox) require explicit user gestures before requesting persistence.
  bool get requiresContextualPrompt => _requiresContextualPrompt;

  /// Executes pre-storage initialization persistence checks before IndexedDB / Hive connection pools open.
  /// Prevents host browsers from locking the backing database into an ephemeral/evictable tier.
  Future<void> executeSilentPreflight() async {
    final profile = storagePort.detectProfile();

    if (profile.engine == BrowserEngine.chromium ||
        ((profile.engine == BrowserEngine.webkit ||
                profile.os == PlatformOs.ios) &&
            profile.isStandalonePwa)) {
      // Chromium or WebKit Standalone PWA: silently request persistence without user prompt
      try {
        await storagePort.requestPersistence();
      } catch (_) {}
    } else if (profile.requiresExplicitGesture) {
      // Firefox Desktop: suppress automatic prompt during boot to avoid browser notification blockage
      _requiresContextualPrompt = true;
    } else if (profile.isWebKitEvictionRisk) {
      // Safari Browser Tab: log eviction risk internally without blocking the user
      // Warning state is broadcast in the telemetry report below
    }

    final report = await storagePort.inspectStorage();
    _currentTelemetry = report;
    _telemetryController.add(report);
  }

  /// Contextual persistence request triggered strictly during user-initiated mutation gestures
  /// (e.g. character save, homebrew import, campaign export).
  Future<bool> requestContextualPersistence() async {
    final success = await storagePort.requestPersistence();
    final profile = storagePort.detectProfile();

    if (success) {
      _requiresContextualPrompt = false;
    } else {
      _requiresContextualPrompt = profile.requiresExplicitGesture;
    }

    final report = await storagePort.inspectStorage();
    _currentTelemetry = report;
    _telemetryController.add(report);
    return success;
  }

  /// Exports local campaign CRDT state into an atomic, SHA-256 sealed cold storage file.
  Future<void> generateColdStorageExport(String vaultId) async {
    CampaignProfile? profile = await campaignRepo.getProfile(vaultId);
    if (profile == null && campaignRepo.activeProfile?.id == vaultId) {
      profile = campaignRepo.activeProfile;
    }
    if (profile == null && campaignRepo.activeProfile != null) {
      profile = campaignRepo.activeProfile;
    }

    if (profile == null) {
      throw StateError(
          'Cannot export cold storage: vault "$vaultId" not found.');
    }

    if (serializer == null) {
      throw StateError(
          'Cannot export cold storage: serializer port not provided.');
    }

    final payloadBytes = await serializer!.serializeToBytes(profile);

    final bundle = StorageSnapshotBundle.create(
      vaultId: vaultId,
      payloadBytes: payloadBytes,
    );
    bundle.validateOrThrow();

    final fileName =
        'vault_${vaultId}_${bundle.exportedAt.millisecondsSinceEpoch}.dndvault';
    await snapshotPort.exportAtomicSnapshot(
      fileName: fileName,
      bundle: bundle,
    );
  }

  /// Hydrates campaign state from an atomic cold-storage bundle.
  /// Acts as an authoritative, user-directed import based solely on constant-time SHA-256
  /// bundle integrity and schema validation, independent of real-time packet sliding windows.
  Future<bool> hydrateFromColdStorage() async {
    final bundle = await snapshotPort.importAtomicSnapshot();
    if (bundle == null) return false;

    // 1. Verify constant-time SHA-256 integrity
    if (!bundle.isValid) {
      return false;
    }

    if (serializer == null) {
      return false;
    }

    // 2. Deserialize inbound campaign state via snapshot serializer port
    CampaignProfile inboundProfile;
    try {
      inboundProfile =
          await serializer!.deserializeFromBytes(bundle.payloadBytes);
    } catch (_) {
      return false;
    }

    // User-initiated cold-storage snapshot restoration allows rollbacks;
    // cryptographic validity is already verified via bundle.isValid above.

    // Reconcile / save state
    await campaignRepo.saveProfileImmediate(inboundProfile);
    if (campaignRepo.activeProfileId == null ||
        campaignRepo.activeProfileId == inboundProfile.id) {
      await campaignRepo.setActiveProfileId(inboundProfile.id);
    }

    return true;
  }

  /// Disposes internal broadcast stream controller.
  void dispose() {
    _telemetryController.close();
  }
}
