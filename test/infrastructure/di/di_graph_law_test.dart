import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:vtt_engine_core/vtt_engine_core.dart';
import 'package:dangerously_nerdy_5e_toolkit/infrastructure/di/injection_container.dart';
import 'package:dangerously_nerdy_5e_toolkit/application/map/active_map_controller.dart';
import 'package:dangerously_nerdy_5e_toolkit/services/persistence/app_database_service.dart';
import 'package:dangerously_nerdy_5e_toolkit/application/blob/blob_channel_port.dart';
import 'package:dangerously_nerdy_5e_toolkit/application/blob/blob_store_port.dart';
import 'package:dangerously_nerdy_5e_toolkit/application/blob/blob_transfer_service.dart';
import 'package:dangerously_nerdy_5e_toolkit/application/services/cascading_transport_router.dart';
import 'package:dangerously_nerdy_5e_toolkit/application/services/clock_sync_service.dart';
import 'package:dangerously_nerdy_5e_toolkit/application/services/combat_encounter_service.dart';
import 'package:dangerously_nerdy_5e_toolkit/application/services/homebrew_import_orchestrator.dart';
import 'package:dangerously_nerdy_5e_toolkit/application/services/room_document_port.dart';
import 'package:dangerously_nerdy_5e_toolkit/application/map/map_grid_service.dart';
import 'package:dangerously_nerdy_5e_toolkit/application/map/map_image_intake_port.dart';
import 'package:dangerously_nerdy_5e_toolkit/application/map/map_intake_service.dart';
import 'package:dangerously_nerdy_5e_toolkit/application/map/map_token_service.dart';
import 'package:dangerously_nerdy_5e_toolkit/services/party/party_room_service.dart';
import 'package:dangerously_nerdy_5e_toolkit/application/services/room_session_starter.dart';
import 'package:dangerously_nerdy_5e_toolkit/application/services/room_state_reconciliation_service.dart';
import 'package:dangerously_nerdy_5e_toolkit/application/services/room_sync_orchestrator.dart';
import 'package:dangerously_nerdy_5e_toolkit/application/storage/storage_durability_coordinator.dart';
import 'package:dangerously_nerdy_5e_toolkit/infrastructure/adapters/p2p/webrtc_mesh_adapter.dart';
import 'package:dangerously_nerdy_5e_toolkit/application/services/party_room_service.dart'
    as app_party;

import '../../test_doubles/hive_test_harness.dart';

Set<String> parseRegisteredTypes(String source) {
  final initIndex = source.indexOf('Future<void> initServiceLocator');
  final body = initIndex >= 0 ? source.substring(initIndex) : source;
  final regex =
      RegExp(r'sl\.register(?:Singleton|LazySingleton|Factory)<([^>]+)>');
  return regex.allMatches(body).map((m) => m.group(1)!.trim()).toSet();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final harness = HiveTestHarness();

  setUp(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
    sl.reset();
    await harness.setUp('di_graph_law_test_');
  });

  tearDown(() async {
    sl.reset();
    await harness.tearDown();
  });

  group('DI Graph Law', () {
    test(
        'resolves every type registered by initServiceLocator matching source registrations exactly',
        () async {
      await initServiceLocator();

      const sourcePath = 'lib/infrastructure/di/injection_container.dart';
      final source = File(sourcePath).readAsStringSync();
      final expectedTypes = parseRegisteredTypes(source);

      final Map<String, Object Function()> typeResolvers = {
        'ActiveMapController': () => sl<ActiveMapController>(),
        'AppDatabaseService': () => sl<AppDatabaseService>(),
        'BlobChannelPort': () => sl<BlobChannelPort>(),
        'BlobStorePort': () => sl<BlobStorePort>(),
        'BlobTransferService': () => sl<BlobTransferService>(),
        'CascadingTransportRouter': () => sl<CascadingTransportRouter>(),
        'ClockSyncService': () => sl<ClockSyncService>(),
        'CombatEncounterService': () => sl<CombatEncounterService>(),
        'HomebrewImportOrchestrator': () => sl<HomebrewImportOrchestrator>(),
        'ICampaignRepository': () => sl<ICampaignRepository>(),
        'ICampaignSnapshotSerializerPort': () =>
            sl<ICampaignSnapshotSerializerPort>(),
        'ICharacterRepository': () => sl<ICharacterRepository>(),
        'ICombatResolver': () => sl<ICombatResolver>(),
        'IGithubIngestorPort': () => sl<IGithubIngestorPort>(),
        'INetworkTimePort': () => sl<INetworkTimePort>(),
        'IP2pTransportPort': () => sl<IP2pTransportPort>(),
        'IPhysicalSnapshotPort': () => sl<IPhysicalSnapshotPort>(),
        'IRoomDocumentPort': () => sl<IRoomDocumentPort>(),
        'IRoomSyncPayloadPort': () => sl<IRoomSyncPayloadPort>(),
        'IStorageDurabilityPort': () => sl<IStorageDurabilityPort>(),
        'MapGridService': () => sl<MapGridService>(),
        'MapImageIntakePort': () => sl<MapImageIntakePort>(),
        'MapIntakeService': () => sl<MapIntakeService>(),
        'MapTokenService': () => sl<MapTokenService>(),
        'PartyRoomService': () => sl<PartyRoomService>(),
        'ReplicaId': () => sl<ReplicaId>(),
        'RoomSessionStarter': () => sl<RoomSessionStarter>(),
        'RoomStateReconciliationService': () =>
            sl<RoomStateReconciliationService>(),
        'RoomSyncOrchestrator': () => sl<RoomSyncOrchestrator>(),
        'StatefulHlcClock': () => sl<StatefulHlcClock>(),
        'StorageDurabilityCoordinator': () =>
            sl<StorageDurabilityCoordinator>(),
        'WebRtcMeshAdapter': () => sl<WebRtcMeshAdapter>(),
        'app_party.PartyRoomService': () => sl<app_party.PartyRoomService>(),
      };

      final actualTypes = typeResolvers.keys.toSet();

      if (!setEquals(actualTypes, expectedTypes)) {
        stdout.writeln('DI Graph Law Mismatch:');
        stdout.writeln('Source types (${expectedTypes.length}): $expectedTypes');
        stdout.writeln('Test types (${actualTypes.length}): $actualTypes');
        stdout.writeln('Missing in test: ${expectedTypes.difference(actualTypes)}');
        stdout.writeln('Extra in test: ${actualTypes.difference(expectedTypes)}');
      }
      expect(actualTypes, equals(expectedTypes),
          reason: 'Resolver types must exactly match source registrations');

      int resolvedCount = 0;
      for (final entry in typeResolvers.entries) {
        final instance = entry.value();
        expect(instance, isNotNull,
            reason: 'Type ${entry.key} must resolve to a non-null instance');
        resolvedCount++;
      }

      stdout.writeln(
          'DI graph law: resolved $resolvedCount types successfully without throwing.');
      expect(resolvedCount, equals(expectedTypes.length));
    });

    test(
        'Control: comparison on in-memory string fails and names the missing type',
        () {
      const inMemorySource = '''
        sl.registerSingleton<AlphaService>(alpha);
        sl.registerLazySingleton<BetaPort>(() => beta);
        sl.registerFactory<GammaCoordinator>(() => gamma);
      ''';
      final parsed = parseRegisteredTypes(inMemorySource);
      expect(parsed, equals({'AlphaService', 'BetaPort', 'GammaCoordinator'}));

      final incompleteList = {'AlphaService', 'BetaPort'};
      final missing = parsed.difference(incompleteList);

      expect(missing, contains('GammaCoordinator'));
      expect(incompleteList.containsAll(parsed), isFalse);
    });
  });
}
