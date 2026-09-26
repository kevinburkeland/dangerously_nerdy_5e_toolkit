import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:dangerously_nerdy_5e_toolkit/application/storage/storage_durability_coordinator.dart';
import 'package:vtt_engine_core/models/campaign_profile.dart';
import 'package:vtt_engine_core/ports/i_campaign_repository.dart';
import 'package:vtt_engine_core/storage/models/engine_profile.dart';
import 'package:vtt_engine_core/storage/models/storage_snapshot_bundle.dart';
import 'package:vtt_engine_core/storage/models/storage_telemetry_report.dart';
import 'package:vtt_engine_core/storage/ports/i_physical_snapshot_port.dart';
import 'package:vtt_engine_core/storage/ports/i_storage_durability_port.dart';
import 'package:dangerously_nerdy_5e_toolkit/infrastructure/adapters/storage/campaign_snapshot_serializer_adapter.dart';
import 'package:dangerously_nerdy_5e_toolkit/infrastructure/dtos/campaign_profile_dto.dart';

class FakeStorageDurabilityPort implements IStorageDurabilityPort {
  EngineProfile currentProfile;
  bool isPersisted;
  int bytesUsed;
  int byteQuota;
  int requestPersistenceCallCount = 0;

  FakeStorageDurabilityPort({
    required this.currentProfile,
    this.isPersisted = false,
    this.bytesUsed = 1000,
    this.byteQuota = 10000,
  });

  @override
  EngineProfile detectProfile() => currentProfile;

  @override
  Future<StorageTelemetryReport> inspectStorage() async {
    return StorageTelemetryReport.safe(
      isPersisted: isPersisted,
      bytesUsed: bytesUsed,
      byteQuota: byteQuota,
      profile: currentProfile,
    );
  }

  @override
  Future<bool> requestPersistence() async {
    requestPersistenceCallCount++;
    isPersisted = true;
    return true;
  }
}

class FakePhysicalSnapshotPort implements IPhysicalSnapshotPort {
  StorageSnapshotBundle? storedBundle;
  String? exportedFileName;
  int exportCallCount = 0;
  int importCallCount = 0;

  @override
  Future<void> exportAtomicSnapshot({
    required String fileName,
    required StorageSnapshotBundle bundle,
  }) async {
    exportCallCount++;
    exportedFileName = fileName;
    storedBundle = bundle;
  }

  @override
  Future<StorageSnapshotBundle?> importAtomicSnapshot() async {
    importCallCount++;
    return storedBundle;
  }
}

class FakeCampaignRepository implements ICampaignRepository {
  final Map<String, CampaignProfile> profiles = {};
  String? _activeId;

  @override
  String? get activeProfileId => _activeId;

  @override
  CampaignProfile? get activeProfile =>
      _activeId != null ? profiles[_activeId] : null;

  @override
  List<CampaignProfile> get allProfiles => profiles.values.toList();

  @override
  Future<void> deleteProfile(String id) async {
    profiles.remove(id);
    if (_activeId == id) _activeId = null;
  }

  @override
  Future<CampaignProfile?> getActiveProfile() async => activeProfile;

  @override
  Future<CampaignProfile?> getProfile(String id) async => profiles[id];

  @override
  Future<List<CampaignProfile>> loadAllProfiles() async => allProfiles;

  @override
  Future<void> saveProfile(CampaignProfile profile) async {
    profiles[profile.id] = profile;
  }

  @override
  Future<void> saveProfileImmediate(CampaignProfile profile) async {
    profiles[profile.id] = profile;
  }

  @override
  Future<void> setActiveProfileId(String id) async {
    _activeId = id;
  }

  @override
  Stream<CampaignProfile?> watchActiveProfile() => const Stream.empty();

  @override
  Stream<List<CampaignProfile>> watchAllProfiles() => const Stream.empty();
}

void main() {
  setUpAll(() {
    CampaignSnapshotSerializerAdapter.registerDefault();
  });

  group('StorageDurabilityCoordinator Lifecycle & Preflight', () {
    test('Silent preflight triggers requestPersistence on Chromium', () async {
      final storagePort = FakeStorageDurabilityPort(
        currentProfile: const EngineProfile(
          engine: BrowserEngine.chromium,
          os: PlatformOs.linux,
          isStandalonePwa: false,
        ),
      );
      final snapshotPort = FakePhysicalSnapshotPort();
      final campaignRepo = FakeCampaignRepository();

      final coordinator = StorageDurabilityCoordinator(
        storagePort: storagePort,
        snapshotPort: snapshotPort,
        campaignRepo: campaignRepo,
      );

      expect(storagePort.requestPersistenceCallCount, equals(0));
      await coordinator.executeSilentPreflight();

      expect(storagePort.requestPersistenceCallCount, equals(1));
      expect(coordinator.requiresContextualPrompt, isFalse);
      expect(coordinator.currentTelemetry?.isPersisted, isTrue);

      coordinator.dispose();
    });

    test(
        'Silent preflight triggers requestPersistence on WebKit Standalone PWA',
        () async {
      final storagePort = FakeStorageDurabilityPort(
        currentProfile: const EngineProfile(
          engine: BrowserEngine.webkit,
          os: PlatformOs.ios,
          isStandalonePwa: true,
        ),
      );
      final snapshotPort = FakePhysicalSnapshotPort();
      final campaignRepo = FakeCampaignRepository();

      final coordinator = StorageDurabilityCoordinator(
        storagePort: storagePort,
        snapshotPort: snapshotPort,
        campaignRepo: campaignRepo,
      );

      await coordinator.executeSilentPreflight();

      expect(storagePort.requestPersistenceCallCount, equals(1));
      expect(coordinator.requiresContextualPrompt, isFalse);

      coordinator.dispose();
    });

    test(
        'Silent preflight suppresses prompt on Firefox Desktop and sets requiresContextualPrompt',
        () async {
      final storagePort = FakeStorageDurabilityPort(
        currentProfile: const EngineProfile(
          engine: BrowserEngine.gecko,
          os: PlatformOs.windows,
          isStandalonePwa: false,
        ),
      );
      final snapshotPort = FakePhysicalSnapshotPort();
      final campaignRepo = FakeCampaignRepository();

      final coordinator = StorageDurabilityCoordinator(
        storagePort: storagePort,
        snapshotPort: snapshotPort,
        campaignRepo: campaignRepo,
      );

      await coordinator.executeSilentPreflight();

      // Must NOT prompt automatically on boot in Firefox
      expect(storagePort.requestPersistenceCallCount, equals(0));
      expect(coordinator.requiresContextualPrompt, isTrue);

      // Subsequent contextual mutation gesture triggers permission
      final success = await coordinator.requestContextualPersistence();
      expect(success, isTrue);
      expect(storagePort.requestPersistenceCallCount, equals(1));
      expect(coordinator.requiresContextualPrompt, isFalse);

      coordinator.dispose();
    });
  });

  group('StorageDurabilityCoordinator Cold Storage Export & Hydration', () {
    test('Exports campaign profile into verified cold storage snapshot',
        () async {
      final storagePort = FakeStorageDurabilityPort(
        currentProfile: const EngineProfile(
          engine: BrowserEngine.chromium,
          os: PlatformOs.macos,
          isStandalonePwa: true,
        ),
      );
      final snapshotPort = FakePhysicalSnapshotPort();
      final campaignRepo = FakeCampaignRepository();

      final profile = CampaignProfile.defaultProfile(
        id: 'camp_frost_haven',
        name: 'Frost Haven Campaign',
        nodeId: 'test_node',
      );
      await campaignRepo.saveProfileImmediate(profile);
      await campaignRepo.setActiveProfileId(profile.id);

      final coordinator = StorageDurabilityCoordinator(
        storagePort: storagePort,
        snapshotPort: snapshotPort,
        campaignRepo: campaignRepo,
      );

      await coordinator.generateColdStorageExport('camp_frost_haven');

      expect(snapshotPort.exportCallCount, equals(1));
      expect(
          snapshotPort.exportedFileName, contains('vault_camp_frost_haven_'));
      expect(snapshotPort.storedBundle, isNotNull);
      expect(snapshotPort.storedBundle!.isValid, isTrue);

      coordinator.dispose();
    });

    test(
        'Hydrates snapshot allowing user-initiated rollbacks to older snapshots',
        () async {
      final storagePort = FakeStorageDurabilityPort(
        currentProfile: const EngineProfile(
          engine: BrowserEngine.chromium,
          os: PlatformOs.linux,
          isStandalonePwa: true,
        ),
      );
      final snapshotPort = FakePhysicalSnapshotPort();
      final campaignRepo = FakeCampaignRepository();

      final now = DateTime.now();

      // Local profile modified 10 seconds ago
      final localProfile = CampaignProfile.defaultProfile(
        id: 'vault_sync_1',
        name: 'Local Fresh State',
        nodeId: 'test_node',
      ).copyWith(
        lastPlayedAt: now.subtract(const Duration(seconds: 10)),
      );
      await campaignRepo.saveProfileImmediate(localProfile);

      final coordinator = StorageDurabilityCoordinator(
        storagePort: storagePort,
        snapshotPort: snapshotPort,
        campaignRepo: campaignRepo,
      );

      // 1. Inbound older snapshot (e.g. 60 seconds ago) for an intentional user rollback
      final rollbackProfile = localProfile.copyWith(name: 'Rolled Back State');
      final rollbackPayload = Uint8List.fromList(
        utf8.encode(CampaignProfileDto.fromDomain(rollbackProfile).toJson()),
      );
      final rollbackBundle = StorageSnapshotBundle.create(
        vaultId: 'vault_sync_1',
        payloadBytes: rollbackPayload,
        exportedAt: now.subtract(const Duration(seconds: 60)),
      );
      snapshotPort.storedBundle = rollbackBundle;

      final rollbackResult = await coordinator.hydrateFromColdStorage();
      expect(rollbackResult, isTrue,
          reason:
              'User-initiated rollback should succeed when bundle is valid');
      final currentAfterRollback =
          await campaignRepo.getProfile('vault_sync_1');
      expect(currentAfterRollback!.name, equals('Rolled Back State'));

      // 2. Fresh inbound snapshot
      final freshProfile =
          localProfile.copyWith(name: 'Authorized Fresh State');
      final freshPayload = Uint8List.fromList(
        utf8.encode(CampaignProfileDto.fromDomain(freshProfile).toJson()),
      );
      final freshBundle = StorageSnapshotBundle.create(
        vaultId: 'vault_sync_1',
        payloadBytes: freshPayload,
        exportedAt: now.add(const Duration(seconds: 5)),
      );
      snapshotPort.storedBundle = freshBundle;

      final freshResult = await coordinator.hydrateFromColdStorage();
      expect(freshResult, isTrue);
      final currentAfterFresh = await campaignRepo.getProfile('vault_sync_1');
      expect(currentAfterFresh!.name, equals('Authorized Fresh State'));

      coordinator.dispose();
    });

    test('Rejects corrupted or tampered bundle during hydration', () async {
      final storagePort = FakeStorageDurabilityPort(
        currentProfile: const EngineProfile(
          engine: BrowserEngine.chromium,
          os: PlatformOs.linux,
          isStandalonePwa: true,
        ),
      );
      final snapshotPort = FakePhysicalSnapshotPort();
      final campaignRepo = FakeCampaignRepository();

      final coordinator = StorageDurabilityCoordinator(
        storagePort: storagePort,
        snapshotPort: snapshotPort,
        campaignRepo: campaignRepo,
      );

      // Bundle with forged payload
      final authenticBundle = StorageSnapshotBundle.create(
        vaultId: 'vault_tamper',
        payloadBytes: Uint8List.fromList(utf8.encode('{}')),
      );
      final tamperedBundle = authenticBundle.copyWith(
        payloadBytes: Uint8List.fromList(utf8.encode('{"hacked": true}')),
      );
      snapshotPort.storedBundle = tamperedBundle;

      final result = await coordinator.hydrateFromColdStorage();
      expect(result, isFalse);

      coordinator.dispose();
    });
  });
}
