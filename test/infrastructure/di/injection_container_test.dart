import 'package:flutter_test/flutter_test.dart';
import 'package:dangerously_nerdy_5e_toolkit/application/services/combat_encounter_service.dart';
import 'package:dangerously_nerdy_5e_toolkit/domain/ports/i_campaign_repository.dart';
import 'package:dangerously_nerdy_5e_toolkit/domain/ports/i_character_repository.dart';
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

      final charRepo = sl<ICharacterRepository>();
      expect(charRepo, isA<LocalCharacterRepository>());

      final campRepo = sl<ICampaignRepository>();
      expect(campRepo, isA<LocalCampaignRepository>());

      final combatService = sl<CombatEncounterService>();
      expect(combatService.characterRepo, equals(charRepo));
      expect(combatService.campaignRepo, equals(campRepo));
    });

    test('throws StateError when resolving an unregistered dependency', () {
      expect(() => sl<DateTime>(), throwsStateError);
    });
  });
}
