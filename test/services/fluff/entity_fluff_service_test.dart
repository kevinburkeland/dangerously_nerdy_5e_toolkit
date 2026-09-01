import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:dangerously_nerdy_5e_toolkit/services/fluff/entity_fluff_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('EntityFluffService Tests', () {
    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      final service = EntityFluffService();
      service.clearAll();
      await service.init();
    });

    test('saves, retrieves, and updates imported lore/fluff correctly', () {
      final service = EntityFluffService();

      expect(service.getFluff('monster', 'aboleth'), isNull);

      service.setFluff(
        'monster',
        'aboleth',
        'Ancient telepathic amphibians that dwell in primeval sunken ruins.',
        images: ['https://example.com/aboleth.png'],
        source: 'SRD 5.1',
      );

      final fluff = service.getFluff('monster', 'aboleth');
      expect(fluff, isNotNull);
      expect(fluff!.slug, equals('aboleth'));
      expect(fluff.entityType, equals('monster'));
      expect(fluff.loreMarkdown, contains('Ancient telepathic amphibians'));
      expect(fluff.images, contains('https://example.com/aboleth.png'));
      expect(fluff.source, equals('SRD 5.1'));

      // Additive update
      service.setFluff(
        'monster',
        'aboleth',
        'They remember everything dating back to the dawn of creation.',
      );

      final updatedFluff = service.getFluff('monster', 'aboleth');
      expect(updatedFluff!.loreMarkdown, contains('Ancient telepathic amphibians'));
      expect(updatedFluff.loreMarkdown, contains('They remember everything'));
    });

    test('saves, retrieves, and updates user-authored notes', () {
      final service = EntityFluffService();

      expect(service.getUserNotes('spell', 'fireball'), isNull);

      service.setUserNotes('spell', 'fireball', 'Always check radius for friendly fire in narrow dungeons.');
      expect(service.getUserNotes('spell', 'fireball'), equals('Always check radius for friendly fire in narrow dungeons.'));

      // Empty string clears note
      service.setUserNotes('spell', 'fireball', '   ');
      expect(service.getUserNotes('spell', 'fireball'), isNull);
    });

    test('exports and imports backup payloads faithfully', () {
      final service = EntityFluffService();

      service.setFluff('race', 'elf', 'Graceful fey heritage.', source: 'SRD 5.1');
      service.setUserNotes('class', 'fighter', 'Focus on Action Surge combos.');

      final exportedFluff = service.exportFluffMap();
      final exportedNotes = service.exportUserNotesMap();

      expect(exportedFluff, isNotEmpty);
      expect(exportedNotes, isNotEmpty);

      service.clearAll();
      expect(service.getFluff('race', 'elf'), isNull);
      expect(service.getUserNotes('class', 'fighter'), isNull);

      service.importFromBackup(
        fluffData: exportedFluff,
        userNotesData: exportedNotes,
      );

      expect(service.getFluff('race', 'elf')?.loreMarkdown, contains('Graceful fey heritage.'));
      expect(service.getUserNotes('class', 'fighter'), equals('Focus on Action Surge combos.'));
    });
  });
}
