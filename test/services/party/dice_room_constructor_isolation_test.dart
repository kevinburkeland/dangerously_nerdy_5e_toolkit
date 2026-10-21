import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:dangerously_nerdy_5e_toolkit/services/dice_room_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
      'Cold production factory DiceRoomService() starts no asynchronous restore; activeSessionNotifier is null until restorePersistedSession is called',
      (tester) async {
    // Set mock preferences with remembered session first before any touch of DiceRoomService()
    SharedPreferences.setMockInitialValues({
      'dice_room_persisted_remember': true,
      'dice_room_persisted_code': 'REMOTE99',
      'dice_room_persisted_player_name': 'Alyn',
    });

    // Call production factory DiceRoomService() for the first time
    final service = DiceRoomService();

    // Pump frames for 100 ms - constructor must start NO asynchronous work
    await tester.pump(const Duration(milliseconds: 100));
    expect(service.activeSessionNotifier.value, isNull,
        reason: 'DiceRoomService() constructor must not start asynchronous restore work');

    // Explicitly await restorePersistedSession() and verify session is restored
    await service.restorePersistedSession();
    expect(service.activeSessionNotifier.value, isNotNull);
    expect(service.activeSessionNotifier.value!.roomCode, equals('REMOTE99'));
    expect(service.activeSessionNotifier.value!.playerName, equals('Alyn'));
    expect(service.activeSessionNotifier.value!.isRemembered, isTrue);
  });
}
