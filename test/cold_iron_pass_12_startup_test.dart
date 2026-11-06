import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vtt_engine_core/crdt/replica_id.dart';
import 'package:vtt_engine_core/crdt/stateful_hlc_clock.dart';
import 'package:vtt_engine_core/ports/i_campaign_repository.dart';
import 'package:vtt_engine_core/ports/i_character_repository.dart';
import 'package:dangerously_nerdy_5e_toolkit/infrastructure/di/injection_container.dart';
import 'package:dangerously_nerdy_5e_toolkit/infrastructure/repositories/local_campaign_repository.dart';
import 'package:dangerously_nerdy_5e_toolkit/infrastructure/repositories/local_character_repository.dart';
import 'package:dangerously_nerdy_5e_toolkit/main.dart';
import 'package:dangerously_nerdy_5e_toolkit/services/app_services.dart';
import 'package:dangerously_nerdy_5e_toolkit/services/logging_service.dart';
import 'package:dangerously_nerdy_5e_toolkit/services/party/party_room_service.dart';

import 'test_doubles/fake_room_document_port.dart';
import 'test_doubles/hive_test_harness.dart';
import 'test_doubles/service_test_configurator.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final harness = HiveTestHarness();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await harness.setUpInMemory();
    sl.reset();

    final replica = ReplicaId('startup_test_replica');
    final clock = StatefulHlcClock(replicaId: replica);
    final charRepo = LocalCharacterRepository();
    final campRepo = LocalCampaignRepository(
      replicaId: replica,
      clock: clock,
      characterRepo: charRepo,
    );

    sl.registerSingleton<ReplicaId>(replica);
    sl.registerSingleton<StatefulHlcClock>(clock);
    sl.registerSingleton<ICampaignRepository>(campRepo);
    sl.registerSingleton<ICharacterRepository>(charRepo);
    sl.registerSingleton<PartyRoomService>(
      PartyRoomService(
        replicaId: replica,
        clock: clock,
        roomDocumentPort: RecordingRoomDocumentPort(),
      ),
    );
    configureTestServices(
      repository: campRepo,
      replicaId: replica,
      clock: clock,
    );
  });

  tearDown(() async {
    resetTestServices();
    sl.reset();
    await harness.tearDown();
  });

  testWidgets("B1a: initServices throws StateError('boom') -> StartupFailedPage shows 'The app couldn't start' and 'boom'", (tester) async {
    final rootWidget = await completeNormalStartup(
      AppServices.instance,
      LoggingService(),
      initServices: () async {
        throw StateError('boom');
      },
      setupFirebase: () async {},
    );

    expect(rootWidget, isA<StartupFailedPage>());

    await tester.pumpWidget(rootWidget);
    await tester.pumpAndSettle();

    expect(find.text("The app couldn't start"), findsOneWidget);
    expect(find.text('boom'), findsOneWidget);
  });

  testWidgets("B1b: runMigration throws StateError('migration boom') -> StartupFailedPage shows 'The app couldn't start' and 'migration boom'", (tester) async {
    final rootWidget = await completeNormalStartup(
      AppServices.instance,
      LoggingService(),
      initServices: () async {},
      runMigration: () async {
        throw StateError('migration boom');
      },
      setupFirebase: () async {},
    );

    expect(rootWidget, isA<StartupFailedPage>());

    await tester.pumpWidget(rootWidget);
    await tester.pumpAndSettle();

    expect(find.text("The app couldn't start"), findsOneWidget);
    expect(find.text('migration boom'), findsOneWidget);
  });

  testWidgets('B1c (control): both steps succeed -> returned root is not StartupFailedPage and contains DangerouslyNerdy5eToolkitApp', (tester) async {
    final rootWidget = await completeNormalStartup(
      AppServices.instance,
      LoggingService(),
      initServices: () async {},
      runMigration: () async {},
      setupFirebase: () async {},
    );

    expect(rootWidget is StartupFailedPage, isFalse);

    await tester.pumpWidget(rootWidget);
    await tester.pumpAndSettle();

    expect(find.byType(DangerouslyNerdy5eToolkitApp), findsOneWidget);
  });
}
