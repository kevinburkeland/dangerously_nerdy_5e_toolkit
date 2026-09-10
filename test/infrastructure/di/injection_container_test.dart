import 'package:flutter_test/flutter_test.dart';
import 'package:dangerously_nerdy_5e_toolkit/application/services/cascading_transport_router.dart';
import 'package:dangerously_nerdy_5e_toolkit/application/services/clock_sync_service.dart';
import 'package:dangerously_nerdy_5e_toolkit/application/services/combat_encounter_service.dart';
import 'package:dangerously_nerdy_5e_toolkit/application/services/room_sync_orchestrator.dart';
import 'package:dangerously_nerdy_5e_toolkit/domain/ports/i_campaign_repository.dart';
import 'package:dangerously_nerdy_5e_toolkit/domain/ports/i_character_repository.dart';
import 'package:dangerously_nerdy_5e_toolkit/domain/ports/i_network_time_port.dart';
import 'package:dangerously_nerdy_5e_toolkit/domain/ports/i_p2p_transport_port.dart';
import 'package:dangerously_nerdy_5e_toolkit/infrastructure/di/injection_container.dart';
import 'package:dangerously_nerdy_5e_toolkit/infrastructure/repositories/local_campaign_repository.dart';
import 'package:dangerously_nerdy_5e_toolkit/infrastructure/repositories/local_character_repository.dart';
import 'package:dangerously_nerdy_5e_toolkit/services/persistence/app_database_service.dart';

void main() {
  setUp(() {
    sl.reset();
  });

  tearDown(() {
    sl.reset();
  });

  group('InjectionContainer Unit Tests', () {
    test('registers and resolves singletons and lazy singletons', () {
      sl.registerSingleton<String>('hello_world');
      expect(sl<String>(), equals('hello_world'));

      int factoryCallCount = 0;
      sl.registerLazySingleton<int>(() {
        factoryCallCount++;
        return 42;
      });

      expect(factoryCallCount, equals(0));
      expect(sl<int>(), equals(42));
      expect(factoryCallCount, equals(1));
      expect(sl<int>(), equals(42));
      expect(factoryCallCount, equals(1)); // Cached as singleton
    });

    test('initServiceLocator registers repositories and application services without singletons', () async {
      await initServiceLocator();

      expect(sl.isRegistered<AppDatabaseService>(), isTrue);
      expect(sl.isRegistered<ICharacterRepository>(), isTrue);
      expect(sl.isRegistered<ICampaignRepository>(), isTrue);
      expect(sl.isRegistered<CombatEncounterService>(), isTrue);
      expect(sl.isRegistered<INetworkTimePort>(), isTrue);
      expect(sl.isRegistered<ClockSyncService>(), isTrue);
      expect(sl.isRegistered<CascadingTransportRouter>(), isTrue);
      expect(sl.isRegistered<IP2pTransportPort>(), isTrue);
      expect(sl.isRegistered<RoomSyncOrchestrator>(), isTrue);

      final charRepo = sl<ICharacterRepository>();
      expect(charRepo, isA<LocalCharacterRepository>());

      final campRepo = sl<ICampaignRepository>();
      expect(campRepo, isA<LocalCampaignRepository>());

      final combatService = sl<CombatEncounterService>();
      expect(combatService.characterRepo, equals(charRepo));
      expect(combatService.campaignRepo, equals(campRepo));

      final router = sl<CascadingTransportRouter>();
      expect(router, isA<CascadingTransportRouter>());
      expect(sl<IP2pTransportPort>(), equals(router));

      final orchestrator = sl<RoomSyncOrchestrator>();
      expect(orchestrator, isA<RoomSyncOrchestrator>());
    });

    test('throws StateError when resolving an unregistered dependency', () {
      expect(() => sl<DateTime>(), throwsStateError);
    });
  });
}
