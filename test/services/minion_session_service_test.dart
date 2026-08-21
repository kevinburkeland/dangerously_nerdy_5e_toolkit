import 'package:flutter_test/flutter_test.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/srd_summons/srd_summons_library.dart';
import 'package:dangerously_nerdy_5e_toolkit/services/minion_session_service.dart';

void main() {
  late MinionSessionService service;

  setUp(() {
    service = MinionSessionService();
    service.clearCacheForTesting();
  });

  tearDown(() {
    service.clearCacheForTesting();
  });

  group('MinionSessionService Unit Tests', () {
    test('getOrCreateSession creates and initializes default minions for Animate Objects', () {
      const preset = AnimateObjectsSummon.preset;
      expect(service.hasSession(preset.id), isFalse);

      final session = service.getOrCreateSession(preset, defaultSpellLevel: 5);

      expect(service.hasSession(preset.id), isTrue);
      expect(session.spellLevel, 5);
      expect(session.activeObjects.length, 10);
      expect(session.activeObjects.first.name, 'Silver Coin #1');
    });

    test('getOrCreateSession returns existing session without overwriting modifications', () {
      const preset = BeastSummons.conjureAnimalsPreset;
      final session1 = service.getOrCreateSession(preset, defaultSpellLevel: 3);

      expect(session1.spellLevel, 3);
      expect(session1.activeObjects.length, 8); // 8 wolves

      // Upcast to 5th level and add 8 more wolves (16 total)
      session1.spellLevel = 5;
      for (int i = 0; i < 8; i++) {
        session1.addMinionFromStatBlock(BeastSummons.wolf);
      }
      expect(session1.activeObjects.length, 16);

      // Re-querying session returns the same persisted state
      final session2 = service.getOrCreateSession(preset, defaultSpellLevel: 3);
      expect(identical(session1, session2), isTrue);
      expect(session2.spellLevel, 5);
      expect(session2.activeObjects.length, 16);
    });

    test('Multiple presets maintain distinct and independent session states', () {
      const animalsPreset = BeastSummons.conjureAnimalsPreset;
      const undeadPreset = UndeadSummons.animateDeadPreset;

      final animalsSession = service.getOrCreateSession(animalsPreset, defaultSpellLevel: 3);
      final undeadSession = service.getOrCreateSession(undeadPreset, defaultSpellLevel: 3);

      animalsSession.spellLevel = 7;
      undeadSession.spellLevel = 4;

      expect(service.getOrCreateSession(animalsPreset).spellLevel, 7);
      expect(service.getOrCreateSession(undeadPreset).spellLevel, 4);
    });

    test('resetSession restores default spell level and default minions', () {
      const preset = BeastSummons.conjureAnimalsPreset;
      final session = service.getOrCreateSession(preset, defaultSpellLevel: 3);

      session.spellLevel = 9;
      session.clearAll();
      expect(session.activeObjects, isEmpty);

      service.resetSession(preset, defaultSpellLevel: 3);

      final resetSession = service.getSession(preset.id);
      expect(resetSession, isNotNull);
      expect(resetSession!.spellLevel, 3);
      expect(resetSession.activeObjects.length, 8);
    });

    test('clearCacheForTesting removes all active sessions', () {
      service.getOrCreateSession(AnimateObjectsSummon.preset);
      service.getOrCreateSession(BeastSummons.conjureAnimalsPreset);

      expect(service.hasSession(AnimateObjectsSummon.preset.id), isTrue);
      expect(service.hasSession(BeastSummons.conjureAnimalsPreset.id), isTrue);

      service.clearCacheForTesting();

      expect(service.hasSession(AnimateObjectsSummon.preset.id), isFalse);
      expect(service.hasSession(BeastSummons.conjureAnimalsPreset.id), isFalse);
    });

    test('Bag of Tricks variants auto-roll upon initial session creation and persist across visits', () {
      final graySession = service.getOrCreateSession(BagOfTricksSummons.grayBagPreset);
      expect(graySession.activeObjects.length, equals(1));
      final firstCreatureName = graySession.activeObjects.first.name;

      // Re-fetching session keeps the same rolled creature
      final graySession2 = service.getOrCreateSession(BagOfTricksSummons.grayBagPreset);
      expect(identical(graySession, graySession2), isTrue);
      expect(graySession2.activeObjects.first.name, equals(firstCreatureName));

      final rustSession = service.getOrCreateSession(BagOfTricksSummons.rustBagPreset);
      expect(rustSession.activeObjects.length, equals(1));

      final tanSession = service.getOrCreateSession(BagOfTricksSummons.tanBagPreset);
      expect(tanSession.activeObjects.length, equals(1));
    });

    test('Each Horn of Valhalla variant rolls appropriate Berserker squad and persists through session', () {
      final silverSession = service.getOrCreateSession(ValhallaSummons.silverHornPreset);
      // Silver: 2d4 + 2 -> between 4 and 10 berserkers
      expect(silverSession.activeObjects.length, inInclusiveRange(4, 10));
      final silverCount = silverSession.activeObjects.length;

      // Persists on re-query
      final silverSession2 = service.getOrCreateSession(ValhallaSummons.silverHornPreset);
      expect(silverSession2.activeObjects.length, equals(silverCount));

      final brassSession = service.getOrCreateSession(ValhallaSummons.brassHornPreset);
      // Brass: 3d4 + 3 -> between 6 and 15 berserkers
      expect(brassSession.activeObjects.length, inInclusiveRange(6, 15));

      final bronzeSession = service.getOrCreateSession(ValhallaSummons.bronzeHornPreset);
      // Bronze: 4d4 + 4 -> between 8 and 20 berserkers
      expect(bronzeSession.activeObjects.length, inInclusiveRange(8, 20));

      final ironSession = service.getOrCreateSession(ValhallaSummons.ironHornPreset);
      // Iron: 5d4 + 5 -> between 10 and 25 berserkers
      expect(ironSession.activeObjects.length, inInclusiveRange(10, 25));
    });
  });
}
