import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:dangerously_nerdy_5e_toolkit/services/dice_room_service.dart';
import 'package:dangerously_nerdy_5e_toolkit/services/persistence/homebrew_persistence_service.dart';
import 'package:dangerously_nerdy_5e_toolkit/main.dart';

class _FakeHomebrewPersistenceService implements HomebrewPersistenceService {
  int syncCalls = 0;

  @override
  Future<void> syncToLibraries() async {
    syncCalls++;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _TrackingDiceRoomService extends DiceRoomService {
  int restoreCalls = 0;

  _TrackingDiceRoomService() : super.newInstance();

  @override
  Future<void> restorePersistedSession() async {
    restoreCalls++;
    await super.restorePersistedSession();
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Pass 9 R9: DiceRoomService asynchronous construction and startup restore', () {
    testWidgets('Constructing service does no disk work; activeSessionNotifier is null until restorePersistedSession is called',
        (tester) async {
      SharedPreferences.setMockInitialValues({
        'dice_room_persisted_remember': true,
        'dice_room_persisted_code': 'REMOTE99',
        'dice_room_persisted_player_name': 'Alyn',
      });

      // Construct service instance
      final service = DiceRoomService.newInstance();

      // Pump frames - constructing service must start NO asynchronous work
      await tester.pump(const Duration(milliseconds: 100));
      expect(service.activeSessionNotifier.value, isNull,
          reason: 'Constructing DiceRoomService must not start asynchronous restore work');

      // Now explicitly call restorePersistedSession()
      await service.restorePersistedSession();
      expect(service.activeSessionNotifier.value, isNotNull);
      expect(service.activeSessionNotifier.value!.roomCode, equals('REMOTE99'));
      expect(service.activeSessionNotifier.value!.playerName, equals('Alyn'));
      expect(service.activeSessionNotifier.value!.isRemembered, isTrue);
    });

    test('Startup calls restorePersistedSession() exactly once', () async {
      final fakeHomebrew = _FakeHomebrewPersistenceService();
      final trackingDiceRoom = _TrackingDiceRoomService();

      expect(trackingDiceRoom.restoreCalls, equals(0));
      expect(fakeHomebrew.syncCalls, equals(0));

      await restoreApplicationStartupState(
        homebrewService: fakeHomebrew,
        diceRoomService: trackingDiceRoom,
      );

      expect(trackingDiceRoom.restoreCalls, equals(1),
          reason: 'Startup must call restorePersistedSession() exactly once');
      expect(fakeHomebrew.syncCalls, equals(1),
          reason: 'Startup must call syncToLibraries() exactly once');
    });
  });
}
