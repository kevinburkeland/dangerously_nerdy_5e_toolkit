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
    test('SB19: grid_geometry.dart and map_grid_service.dart import nothing from package:flutter', () {
      final files = [
        File('lib/application/map/grid_geometry.dart'),
        File('lib/application/map/map_grid_service.dart'),
      ];

      for (final file in files) {
        expect(file.existsSync(), isTrue, reason: '${file.path} must exist');
        final content = file.readAsStringSync();
        expect(
          content.contains('package:flutter'),
          isFalse,
          reason: '${file.path} must not import package:flutter',
        );
      }

      // Control: in-memory bad string
      const badContent = "import 'package:flutter/material.dart';";
      expect(badContent.contains('package:flutter'), isTrue);
    });

    test('SB20: Under lib/, withMapGrid( appears only in map_grid_service.dart, and MapGrid( only in map_grid_service.dart, grid_geometry.dart, and map_grid_controls.dart', () {
      final dir = Directory('lib');
      final dartFiles = dir
          .listSync(recursive: true)
          .whereType<File>()
          .where((f) => f.path.endsWith('.dart'))
          .toList();

      const withMapGridToken = 'withMapGrid(';
      final mapGridConstructorPattern = RegExp(r'(?<![a-zA-Z0-9_])MapGrid\(');

      final withMapGridHits = <String>[];
      final mapGridConstructorHits = <String>[];

      for (final file in dartFiles) {
        final content = file.readAsStringSync();
        final normalizedPath = file.path.replaceAll(r'\', '/');

        if (content.contains(withMapGridToken)) {
          withMapGridHits.add(normalizedPath);
        }
        if (mapGridConstructorPattern.hasMatch(content)) {
          mapGridConstructorHits.add(normalizedPath);
        }
      }

      expect(
        withMapGridHits,
        hasLength(1),
        reason: 'withMapGrid( must appear only in map_grid_service.dart. Found in: $withMapGridHits',
      );
      expect(withMapGridHits.first, endsWith('map_grid_service.dart'));

      for (final hit in mapGridConstructorHits) {
        final matchesAllowed = hit.endsWith('map_grid_service.dart') ||
            hit.endsWith('grid_geometry.dart') ||
            hit.endsWith('map_grid_controls.dart');
        expect(
          matchesAllowed,
          isTrue,
          reason: 'MapGrid( constructor appears in unallowed file: $hit',
        );
      }
      expect(mapGridConstructorHits.length, equals(3));

      // Controls: in-memory bad strings
      const badWithMapGrid = 'profile.withMapGrid(null, clock);';
      expect(badWithMapGrid.contains(withMapGridToken), isTrue);

      const badMapGrid = 'final g = MapGrid(mapSha256Hex: "x");';
      expect(mapGridConstructorPattern.hasMatch(badMapGrid), isTrue);
      // Ensure toggleMapGrid does not trigger constructor regex
      const goodToggle = 'toggleMapGrid(gridService: s);';
      expect(mapGridConstructorPattern.hasMatch(goodToggle), isFalse);
    });

    test('SB21: No file under lib/presentation/widgets/map/ contains updateProfile, SharedPreferences, or Hive', () {
      final dir = Directory('lib/presentation/widgets/map');
      expect(dir.existsSync(), isTrue);

      final dartFiles = dir
          .listSync(recursive: true)
          .whereType<File>()
          .where((f) => f.path.endsWith('.dart'))
          .toList();

      final forbidden = [
        'update' 'Profile',
        'Shared' 'Preferences',
        'Hi' 've',
      ];

      final violations = <String>[];
      for (final file in dartFiles) {
        final content = file.readAsStringSync();
        for (final token in forbidden) {
          if (content.contains(token)) {
            violations.add('${file.path} contains forbidden token: $token');
          }
        }
      }

      expect(violations, isEmpty, reason: 'SB21 violations: $violations');

      // Controls: in-memory bad strings
      for (final token in forbidden) {
        final badContent = 'call($token);';
        expect(badContent.contains(token), isTrue);
      }
    });
  });
}
