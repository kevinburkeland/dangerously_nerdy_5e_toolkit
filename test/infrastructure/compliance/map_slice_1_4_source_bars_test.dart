import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Map Slice 1.4 Source Bars Compliance', () {
    test('SB16: Under lib/, .startSynchronization( appears only in room_session_starter.dart, exactly once', () {
      const token = '.start' 'Synchronization(';
      final dir = Directory('lib');
      final dartFiles = dir
          .listSync(recursive: true)
          .whereType<File>()
          .where((f) => f.path.endsWith('.dart'))
          .toList();

      final hits = <String, int>{};
      for (final file in dartFiles) {
        final content = file.readAsStringSync();
        final count = token.allMatches(content).length;
        if (count > 0) {
          hits[file.path] = count;
        }
      }

      expect(
        hits.keys.length,
        equals(1),
        reason: '.startSynchronization( must appear only in room_session_starter.dart. Found in: $hits',
      );
      final entry = hits.entries.first;
      expect(entry.key.replaceAll(r'\', '/'), endsWith('room_session_starter.dart'));
      expect(entry.value, equals(1));

      // Control: in-memory bad string
      const badContent = 'orchestrator' '.start' 'Synchronization();';
      expect(token.allMatches(badContent).length, equals(1));
    });

    test('SB17: Under lib/, none of isRegistered for ActiveMapController, MapIntakeService, MapImageIntakePort, RoomSessionStarter appears', () {
      final forbiddenTokens = [
        'isRegistered<' 'ActiveMapController>',
        'isRegistered<' 'MapIntakeService>',
        'isRegistered<' 'MapImageIntakePort>',
        'isRegistered<' 'RoomSessionStarter>',
      ];

      final dir = Directory('lib');
      final dartFiles = dir
          .listSync(recursive: true)
          .whereType<File>()
          .where((f) => f.path.endsWith('.dart'))
          .toList();

      final violations = <String>[];
      for (final file in dartFiles) {
        final content = file.readAsStringSync();
        for (final token in forbiddenTokens) {
          if (content.contains(token)) {
            violations.add('${file.path} contains forbidden token: $token');
          }
        }
      }

      expect(violations, isEmpty, reason: 'SB17 violations: $violations');

      // Control: in-memory bad string for each token
      for (final token in forbiddenTokens) {
        final badContent = 'if (sl.$token) {}';
        expect(badContent.contains(token), isTrue);
      }
    });

    test('SB18: In web_map_image_intake_adapter.dart, resizeHeight does not appear, and orientationMismatch appears at least once', () {
      final file = File('lib/infrastructure/map/web/web_map_image_intake_adapter.dart');
      expect(file.existsSync(), isTrue);
      final content = file.readAsStringSync();

      const forbiddenResizeHeight = 'resize' 'Height';
      const requiredOrientationMismatch = 'orientation' 'Mismatch';

      expect(
        content.contains(forbiddenResizeHeight),
        isFalse,
        reason: 'web_map_image_intake_adapter.dart must not contain resizeHeight',
      );

      final matchCount = requiredOrientationMismatch.allMatches(content).length;
      expect(
        matchCount,
        greaterThanOrEqualTo(1),
        reason: 'web_map_image_intake_adapter.dart must contain orientationMismatch at least once',
      );

      // Controls:
      const badResize = 'opts = { $forbiddenResizeHeight: 100 };';
      expect(badResize.contains(forbiddenResizeHeight), isTrue);

      const goodOrientation = 'throw MapIntakeRejected(MapRejectReason.$requiredOrientationMismatch);';
      expect(requiredOrientationMismatch.allMatches(goodOrientation).length, equals(1));
    });
  });
}
