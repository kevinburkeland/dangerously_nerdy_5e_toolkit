import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dangerously_nerdy_5e_toolkit/application/storage/storage_durability_coordinator.dart';
import 'package:vtt_engine_core/models/campaign_profile.dart';
import 'package:vtt_engine_core/ports/i_campaign_repository.dart';
import 'package:vtt_engine_core/storage/models/engine_profile.dart';
import 'package:vtt_engine_core/storage/models/storage_snapshot_bundle.dart';
import 'package:vtt_engine_core/storage/models/storage_telemetry_report.dart';
import 'package:vtt_engine_core/storage/ports/i_physical_snapshot_port.dart';
import 'package:vtt_engine_core/storage/ports/i_storage_durability_port.dart';
import 'package:dangerously_nerdy_5e_toolkit/presentation/storage/storage_durability_banner.dart';

class MockStorageDurabilityPort implements IStorageDurabilityPort {
  EngineProfile profile;
  bool isPersisted;
  int bytesUsed;
  int byteQuota;
  int requestPersistenceCalls = 0;

  MockStorageDurabilityPort({
    required this.profile,
    this.isPersisted = false,
    this.bytesUsed = 100,
    this.byteQuota = 1000,
  });

  @override
  EngineProfile detectProfile() => profile;

  @override
  Future<StorageTelemetryReport> inspectStorage() async {
    return StorageTelemetryReport.safe(
      isPersisted: isPersisted,
      bytesUsed: bytesUsed,
      byteQuota: byteQuota,
      profile: profile,
    );
  }

  @override
  Future<bool> requestPersistence() async {
    requestPersistenceCalls++;
    isPersisted = true;
    return true;
  }
}

class MockPhysicalSnapshotPort implements IPhysicalSnapshotPort {
  @override
  Future<void> exportAtomicSnapshot({
    required String fileName,
    required StorageSnapshotBundle bundle,
  }) async {}

  @override
  Future<StorageSnapshotBundle?> importAtomicSnapshot() async => null;
}

class MockCampaignRepository implements ICampaignRepository {
  @override
  String? get activeProfileId => null;
  @override
  CampaignProfile? get activeProfile => null;
  @override
  List<CampaignProfile> get allProfiles => [];
  @override
  Future<void> deleteProfile(String id) async {}
  @override
  Future<CampaignProfile?> getActiveProfile() async => null;
  @override
  Future<CampaignProfile?> getProfile(String id) async => null;
  @override
  Future<List<CampaignProfile>> loadAllProfiles() async => [];
  @override
  Future<void> saveProfile(CampaignProfile profile) async {}
  @override
  Future<void> saveProfileImmediate(CampaignProfile profile) async {}
  @override
  Future<void> setActiveProfileId(String id) async {}
  @override
  Stream<CampaignProfile?> watchActiveProfile() => const Stream.empty();
  @override
  Stream<List<CampaignProfile>> watchAllProfiles() => const Stream.empty();
}

void main() {
  group('StorageDurabilityBanner & StorageLockOfflineAction Widget Tests', () {
    testWidgets(
        'Zero-Friction Invariant: completely hidden if isPersisted is true',
        (tester) async {
      final port = MockStorageDurabilityPort(
        profile: const EngineProfile(
          engine: BrowserEngine.webkit,
          os: PlatformOs.ios,
          isStandalonePwa: false,
        ),
        isPersisted: true,
      );
      final coordinator = StorageDurabilityCoordinator(
        storagePort: port,
        snapshotPort: MockPhysicalSnapshotPort(),
        campaignRepo: MockCampaignRepository(),
      );
      await coordinator.executeSilentPreflight();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StorageDurabilityBanner(coordinator: coordinator),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(StorageDurabilityBanner), findsOneWidget);
      expect(find.textContaining('Running in temporary browser mode'),
          findsNothing);
      expect(
          find.textContaining('Storage capacity is reaching critical limits'),
          findsNothing);

      coordinator.dispose();
    });

    testWidgets('Zero-Friction Invariant: completely hidden if standalone PWA',
        (tester) async {
      final port = MockStorageDurabilityPort(
        profile: const EngineProfile(
          engine: BrowserEngine.webkit,
          os: PlatformOs.ios,
          isStandalonePwa: true,
        ),
        isPersisted: false,
      );
      final coordinator = StorageDurabilityCoordinator(
        storagePort: port,
        snapshotPort: MockPhysicalSnapshotPort(),
        campaignRepo: MockCampaignRepository(),
      );
      await coordinator.executeSilentPreflight();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StorageDurabilityBanner(coordinator: coordinator),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('Running in temporary browser mode'),
          findsNothing);

      coordinator.dispose();
    });

    testWidgets(
        'Condition 1 (Safari Tab Risk): renders dismissible banner and dismisses cleanly',
        (tester) async {
      final port = MockStorageDurabilityPort(
        profile: const EngineProfile(
          engine: BrowserEngine.webkit,
          os: PlatformOs.ios,
          isStandalonePwa: false,
        ),
        isPersisted: false,
        bytesUsed: 100,
        byteQuota: 1000,
      );
      final coordinator = StorageDurabilityCoordinator(
        storagePort: port,
        snapshotPort: MockPhysicalSnapshotPort(),
        campaignRepo: MockCampaignRepository(),
      );
      await coordinator.executeSilentPreflight();

      bool dismissed = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StorageDurabilityBanner(
              coordinator: coordinator,
              onDismiss: () => dismissed = true,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Assert warning banner renders
      expect(
        find.text(
            'Running in temporary browser mode. Add to Home Screen to ensure campaign data is never cleared by iOS.'),
        findsOneWidget,
      );

      // Verify touch target constraint >= 48x48 on dismiss button
      final dismissFinder = find.byTooltip('Dismiss storage warning');
      expect(dismissFinder, findsOneWidget);
      final Size buttonSize = tester.getSize(dismissFinder);
      expect(buttonSize.width, greaterThanOrEqualTo(48.0));
      expect(buttonSize.height, greaterThanOrEqualTo(48.0));

      // Tap dismiss
      await tester.tap(dismissFinder);
      await tester.pumpAndSettle();

      expect(dismissed, isTrue);
      expect(
        find.text(
            'Running in temporary browser mode. Add to Home Screen to ensure campaign data is never cleared by iOS.'),
        findsNothing,
      );

      coordinator.dispose();
    });

    testWidgets(
        'Condition 3 (Storage Pressure >= 80%): renders critical alert with export action',
        (tester) async {
      final port = MockStorageDurabilityPort(
        profile: const EngineProfile(
          engine: BrowserEngine.chromium,
          os: PlatformOs.linux,
          isStandalonePwa: false,
        ),
        isPersisted: false,
        bytesUsed: 850,
        byteQuota: 1000, // 85% full
      );
      final coordinator = StorageDurabilityCoordinator(
        storagePort: port,
        snapshotPort: MockPhysicalSnapshotPort(),
        campaignRepo: MockCampaignRepository(),
      );
      await coordinator.executeSilentPreflight();

      bool exportTapped = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StorageDurabilityBanner(
              coordinator: coordinator,
              onExportColdStorage: () => exportTapped = true,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(
          find.textContaining(
              'Storage capacity is reaching critical limits (85% used)'),
          findsOneWidget);

      final exportButtonFinder = find.text('Export Backup');
      expect(exportButtonFinder, findsOneWidget);

      final Size buttonSize = tester.getSize(find.byType(ElevatedButton));
      expect(buttonSize.width, greaterThanOrEqualTo(48.0));
      expect(buttonSize.height, greaterThanOrEqualTo(48.0));

      await tester.tap(exportButtonFinder);
      expect(exportTapped, isTrue);

      coordinator.dispose();
    });

    testWidgets(
        'Condition 2 (Firefox Pending): StorageLockOfflineAction renders and triggers requestPersistence',
        (tester) async {
      final port = MockStorageDurabilityPort(
        profile: const EngineProfile(
          engine: BrowserEngine.gecko,
          os: PlatformOs.windows,
          isStandalonePwa: false,
        ),
        isPersisted: false,
      );
      final coordinator = StorageDurabilityCoordinator(
        storagePort: port,
        snapshotPort: MockPhysicalSnapshotPort(),
        campaignRepo: MockCampaignRepository(),
      );
      await coordinator.executeSilentPreflight();
      expect(coordinator.requiresContextualPrompt, isTrue);

      bool successCalled = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StorageLockOfflineAction(
              coordinator: coordinator,
              onSuccess: () => successCalled = true,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final lockButtonFinder = find.text('Lock Data Offline');
      expect(lockButtonFinder, findsOneWidget);

      final Size buttonSize = tester.getSize(find.byType(OutlinedButton));
      expect(buttonSize.width, greaterThanOrEqualTo(48.0));
      expect(buttonSize.height, greaterThanOrEqualTo(48.0));

      await tester.tap(lockButtonFinder);
      await tester.pumpAndSettle();

      expect(port.requestPersistenceCalls, equals(1));
      expect(successCalled, isTrue);

      coordinator.dispose();
    });

    testWidgets(
        'Accessibility: supports 2.0x dynamic type scaling without RenderFlex overflow',
        (tester) async {
      tester.view.physicalSize = const Size(360 * 3, 640 * 3);
      tester.view.devicePixelRatio = 3.0;

      final port = MockStorageDurabilityPort(
        profile: const EngineProfile(
          engine: BrowserEngine.webkit,
          os: PlatformOs.ios,
          isStandalonePwa: false,
        ),
        isPersisted: false,
        bytesUsed: 900,
        byteQuota: 1000,
      );
      final coordinator = StorageDurabilityCoordinator(
        storagePort: port,
        snapshotPort: MockPhysicalSnapshotPort(),
        campaignRepo: MockCampaignRepository(),
      );
      await coordinator.executeSilentPreflight();

      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(
              textScaler: TextScaler.linear(2.0),
            ),
            child: Scaffold(
              body: StorageDurabilityBanner(coordinator: coordinator),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Ensure no Flutter layout overflow errors were thrown
      expect(tester.takeException(), isNull);
      expect(find.byType(StorageDurabilityBanner), findsOneWidget);

      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
        coordinator.dispose();
      });
    });
  });
}
