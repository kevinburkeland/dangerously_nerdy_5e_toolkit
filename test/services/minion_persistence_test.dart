import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/animated_object.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/spell_session.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/srd_summons/srd_summons_library.dart';
import 'package:dangerously_nerdy_5e_toolkit/services/minion_session_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Minion Session Persistence Tests', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
      MinionSessionService().clearCacheForTesting();
    });

    test('SpellSession serialization round-trip retains minion state and damage', () {
      final preset = SrdSummonsLibrary.allPresets.first;
      final session = SpellSession(
        activePreset: preset,
        spellLevel: 6,
      );

      final minion = AnimatedObjectInstance(
        id: 'minion_1',
        name: 'Coin Sentinel',
        size: ObjectSize.tiny,
        currentHp: 12,
        maxHp: 20,
        tempHp: 5,
        isSilvered: true,
      );
      session.activeObjects.add(minion);

      final map = session.toMap();
      final restored = SpellSession.fromMap(map);

      expect(restored.activePreset.id, preset.id);
      expect(restored.spellLevel, 6);
      expect(restored.activeObjects.length, 1);
      expect(restored.activeObjects.first.name, 'Coin Sentinel');
      expect(restored.activeObjects.first.currentHp, 12);
      expect(restored.activeObjects.first.maxHp, 20);
      expect(restored.activeObjects.first.tempHp, 5);
      expect(restored.activeObjects.first.isSilvered, isTrue);
    });

    test('MinionSessionService persists and restores session state', () async {
      final service = MinionSessionService();
      final preset = SrdSummonsLibrary.allPresets.first;

      final session = service.getOrCreateSession(preset);
      session.activeObjects.first.takeDamage(5);
      expect(session.activeObjects.first.currentHp < session.activeObjects.first.maxHp, isTrue);

      await service.persistAllSessions();

      // Clear in-memory cache to simulate fresh app restart
      service.clearCacheForTesting();

      // Create new instance and load from persisted SharedPreferences
      final freshService = MinionSessionService();
      await freshService.reloadFromDisk();
      final reloadedSession = freshService.getOrCreateSession(preset);

      expect(reloadedSession.activeObjects.first.currentHp, session.activeObjects.first.currentHp);
    });
  });
}
