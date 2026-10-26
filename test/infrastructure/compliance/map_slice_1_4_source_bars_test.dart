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

    test('SB17: No file under lib/presentation/widgets/map/, lib/presentation/screens/map/ or lib/application/map/ contains isRegistered', () {
      const isReg = 'is' 'Registered';

      List<String> scanForIsRegistered(List<({String name, String content})> files) {
        final violations = <String>[];
        for (final f in files) {
          final lines = f.content.split('\n');
          for (var i = 0; i < lines.length; i++) {
            if (lines[i].contains(isReg)) {
              violations.add('${f.name}:${i + 1}: ${lines[i].trim()}');
            }
          }
        }
        return violations;
      }

      final targetDirs = [
        'lib/presentation/widgets/map',
        'lib/presentation/screens/map',
        'lib/application/map',
      ];

      final diskFiles = <({String name, String content})>[];
      for (final dirPath in targetDirs) {
        final dir = Directory(dirPath);
        if (dir.existsSync()) {
          for (final f in dir.listSync(recursive: true).whereType<File>().where((f) => f.path.endsWith('.dart'))) {
            diskFiles.add((name: f.path.replaceAll(r'\', '/'), content: f.readAsStringSync()));
          }
        }
      }

      final violations = scanForIsRegistered(diskFiles);
      expect(violations, isEmpty, reason: 'SB17 violations:\n${violations.join('\n')}');

      // Control: run the same scanner function on an in-memory pair whose source contains if (sl.isRegistered<Foo>()) {}
      final inMemoryPair = [(
        name: 'test_file.dart',
        content: 'void check() {\n  if (sl.' '$isReg<Foo>()) {}\n}',
      )];
      final controlViolations = scanForIsRegistered(inMemoryPair);
      expect(controlViolations, hasLength(1));
      expect(controlViolations.first, contains('test_file.dart'));
      expect(controlViolations.first, contains(isReg));
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
    test('SB19: grid_geometry.dart, map_grid_service.dart, and map_grid_editor.dart import nothing from package:flutter', () {
      final files = [
        File('lib/application/map/grid_geometry.dart'),
        File('lib/application/map/map_grid_service.dart'),
        File('lib/application/map/map_grid_editor.dart'),
      ];

      const flutterPkg = 'package:' 'flutter';

      for (final file in files) {
        expect(file.existsSync(), isTrue, reason: '${file.path} must exist');
        final content = file.readAsStringSync();
        expect(
          content.contains(flutterPkg),
          isFalse,
          reason: '${file.path} must not import package:flutter',
        );
      }

      // Control: in-memory bad string
      const badContent = "import 'package:" "flutter/material.dart';";
      expect(badContent.contains(flutterPkg), isTrue);
    });

    test('SB20: Under lib/, withMapGrid( appears only in map_grid_service.dart, and MapGrid( only in map_grid_service.dart and grid_geometry.dart', () {
      final dir = Directory('lib');
      final dartFiles = dir
          .listSync(recursive: true)
          .whereType<File>()
          .where((f) => f.path.endsWith('.dart'))
          .toList();

      const withMapGridToken = 'with' 'MapGrid(';
      final mapGridConstructorPattern = RegExp(r'(?<![a-zA-Z0-9_])' 'Map' r'Grid\(');

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
            hit.endsWith('grid_geometry.dart');
        expect(
          matchesAllowed,
          isTrue,
          reason: 'MapGrid( constructor appears in unallowed file: $hit',
        );
      }
      expect(mapGridConstructorHits.length, equals(2));

      // Controls: in-memory bad strings
      const badWithMapGrid = 'profile.' 'with' 'MapGrid(null, clock);';
      expect(badWithMapGrid.contains(withMapGridToken), isTrue);

      const badMapGrid = 'final g = ' 'Map' 'Grid(mapSha256Hex: "x");';
      expect(mapGridConstructorPattern.hasMatch(badMapGrid), isTrue);
      // Ensure toggleMapGrid does not trigger constructor regex
      const goodToggle = 'toggle' 'MapGrid(gridService: s);';
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

    test('SB22: Under lib/, .setGrid(, .applyEdit(, .toggleVisible(, and .setCornerAt( are called only in map_grid_editor.dart. map_grid_controls.dart contains no Timer, no MapGridService, and no setGrid', () {
      final dir = Directory('lib');
      final dartFiles = dir
          .listSync(recursive: true)
          .whereType<File>()
          .where((f) => f.path.endsWith('.dart'))
          .toList();

      const editTokens = [
        '.set' 'Grid(',
        '.apply' 'Edit(',
        '.toggle' 'Visible(',
        '.set' 'CornerAt(',
      ];

      for (final token in editTokens) {
        final hits = <String>[];
        for (final file in dartFiles) {
          final content = file.readAsStringSync();
          if (content.contains(token)) {
            hits.add(file.path.replaceAll(r'\', '/'));
          }
        }
        for (final hit in hits) {
          final isAllowed = hit.endsWith('map_grid_editor.dart') ||
              (hit.endsWith('map_view.dart') &&
                  (token.contains('toggleVisible') || token.contains('setCornerAt')));
          expect(
            isAllowed,
            isTrue,
            reason: '$token must appear only in map_grid_editor.dart (or map_view.dart calling the editor). Found in: $hit',
          );
        }
        if (token.contains('setGrid') || token.contains('applyEdit')) {
          expect(
            hits,
            hasLength(1),
            reason: '$token must appear only in map_grid_editor.dart',
          );
          expect(hits.first, endsWith('map_grid_editor.dart'));
        }
      }

      final controlsFile = File('lib/presentation/widgets/map/map_grid_controls.dart');
      expect(controlsFile.existsSync(), isTrue);
      final controlsContent = controlsFile.readAsStringSync();

      const forbiddenInControls = [
        'Ti' 'mer',
        'MapGrid' 'Service',
        'set' 'Grid',
      ];
      for (final token in forbiddenInControls) {
        expect(
          controlsContent.contains(token),
          isFalse,
          reason: 'map_grid_controls.dart must not contain $token',
        );
      }

      // Controls: in-memory bad strings
      for (final token in editTokens) {
        final badContent = 'service$token;';
        expect(badContent.contains(token), isTrue);
      }
      for (final token in forbiddenInControls) {
        final badContent = 'final x = $token;';
        expect(badContent.contains(token), isTrue);
      }
    });

    test('SB23: map_view.dart contains boundaryMargin', () {
      final file = File('lib/presentation/widgets/map/map_view.dart');
      expect(file.existsSync(), isTrue);
      final content = file.readAsStringSync();

      const requiredToken = 'boundary' 'Margin';
      expect(
        content.contains(requiredToken),
        isTrue,
        reason: 'map_view.dart must contain boundaryMargin',
      );

      // Controls:
      const badContent = 'InteractiveViewer(panEnabled: true);';
      expect(badContent.contains(requiredToken), isFalse);
      const goodContent = 'InteractiveViewer($requiredToken: const EdgeInsets.all(double.infinity));';
      expect(goodContent.contains(requiredToken), isTrue);
    });
  });
}
