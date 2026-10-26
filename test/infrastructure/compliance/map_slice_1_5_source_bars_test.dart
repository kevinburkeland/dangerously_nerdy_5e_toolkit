import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Map Slice 1.5 Source Bars Compliance', () {
    List<({String name, String content})> readLibDartFiles() {
      final dir = Directory('lib');
      final files = <({String name, String content})>[];
      for (final f in dir.listSync(recursive: true).whereType<File>()) {
        if (f.path.endsWith('.dart')) {
          files.add((name: f.path.replaceAll(r'\', '/'), content: f.readAsStringSync()));
        }
      }
      return files;
    }

    test('SB24: Under lib/, calls .withTokenPlaced(, .withTokenMoved(, .withTokenRemoved( and .withMinionOwner( appear only in map_token_service.dart', () {
      const tokens = [
        '.withToken' 'Placed(',
        '.withToken' 'Moved(',
        '.withToken' 'Removed(',
        '.withMinion' 'Owner(',
      ];

      List<String> scanSb24(List<({String name, String content})> files) {
        final violations = <String>[];
        for (final f in files) {
          final isAllowed = f.name.endsWith('map_token_service.dart');
          if (isAllowed) continue;
          final lines = f.content.split('\n');
          for (var i = 0; i < lines.length; i++) {
            for (final token in tokens) {
              if (lines[i].contains(token)) {
                violations.add('${f.name}:${i + 1}: contains $token');
              }
            }
          }
        }
        return violations;
      }

      final libFiles = readLibDartFiles();
      final violations = scanSb24(libFiles);
      expect(violations, isEmpty, reason: 'Found SB24 violations:\n${violations.join('\n')}');

      // Verify they do appear in map_token_service.dart
      final serviceFile = libFiles.firstWhere((f) => f.name.endsWith('map_token_service.dart'));
      for (final token in tokens) {
        expect(serviceFile.content.contains(token), isTrue, reason: 'Expected $token in map_token_service.dart');
      }

      // Control: in-memory bad file
      const badContent = 'profile' '.withToken' 'Placed(token, cell, ts);';
      final controlHits = scanSb24([(name: 'lib/bad_file.dart', content: badContent)]);
      expect(controlHits.length, equals(1));
      expect(controlHits.first, contains('lib/bad_file.dart'));
    });

    test('SB25: Under lib/, none of .mapTokens.add(, .mapTokens.remove(, .mapTokenCells.add(, .minionOwners.add( or .minionOwners.remove( appears', () {
      const banned = [
        '.mapTokens' '.add(',
        '.mapTokens' '.remove(',
        '.mapTokenCells' '.add(',
        '.minionOwners' '.add(',
        '.minionOwners' '.remove(',
      ];

      List<String> scanSb25(List<({String name, String content})> files) {
        final violations = <String>[];
        for (final f in files) {
          final lines = f.content.split('\n');
          for (var i = 0; i < lines.length; i++) {
            for (final token in banned) {
              if (lines[i].contains(token)) {
                violations.add('${f.name}:${i + 1}: contains $token');
              }
            }
          }
        }
        return violations;
      }

      final libFiles = readLibDartFiles();
      final violations = scanSb25(libFiles);
      expect(violations, isEmpty, reason: 'Found SB25 violations:\n${violations.join('\n')}');

      // Control: in-memory bad file
      const badContent = 'profile' '.mapTokens' '.add(token);';
      final controlHits = scanSb25([(name: 'lib/bad_file.dart', content: badContent)]);
      expect(controlHits.length, equals(1));
      expect(controlHits.first, contains('lib/bad_file.dart'));
    });

    test('SB26: map_token_rules.dart and map_token_service.dart import nothing from package:flutter', () {
      const flutterImport = 'package:flutter' '/';

      List<String> scanSb26(List<({String name, String content})> files) {
        final violations = <String>[];
        for (final f in files) {
          if (f.name.endsWith('map_token_rules.dart') || f.name.endsWith('map_token_service.dart')) {
            final lines = f.content.split('\n');
            for (var i = 0; i < lines.length; i++) {
              if (lines[i].contains(flutterImport)) {
                violations.add('${f.name}:${i + 1}: imports flutter');
              }
            }
          }
        }
        return violations;
      }

      final libFiles = readLibDartFiles();
      final violations = scanSb26(libFiles);
      expect(violations, isEmpty, reason: 'Found SB26 violations:\n${violations.join('\n')}');

      // Control: in-memory bad file
      const badContent = 'import "' 'package:flutter' '/material.dart";';
      final controlHits = scanSb26([(name: 'lib/application/map/map_token_rules.dart', content: badContent)]);
      expect(controlHits.length, equals(1));
      expect(controlHits.first, contains('map_token_rules.dart'));
    });

    test('SB27: map_token_service.dart contains updateProfile( and does not contain activeProfile', () {
      const updateProf = 'update' 'Profile(';
      const actProf = 'active' 'Profile';

      List<String> scanSb27(List<({String name, String content})> files) {
        final violations = <String>[];
        for (final f in files) {
          if (f.name.endsWith('map_token_service.dart')) {
            if (!f.content.contains(updateProf)) {
              violations.add('${f.name}: missing $updateProf');
            }
            final lines = f.content.split('\n');
            for (var i = 0; i < lines.length; i++) {
              if (lines[i].contains(actProf)) {
                violations.add('${f.name}:${i + 1}: contains $actProf');
              }
            }
          }
        }
        return violations;
      }

      final libFiles = readLibDartFiles();
      final violations = scanSb27(libFiles);
      expect(violations, isEmpty, reason: 'Found SB27 violations:\n${violations.join('\n')}');

      // Control: in-memory bad file
      const badContent = 'void foo() {\n  repo.' 'active' 'Profile;\n}';
      final controlHits = scanSb27([(name: 'lib/application/map/map_token_service.dart', content: badContent)]);
      expect(controlHits.length, equals(2)); // missing updateProfile and contains activeProfile
      expect(controlHits.any((h) => h.contains('missing updateProfile(')), isTrue);
      expect(controlHits.any((h) => h.contains('contains activeProfile')), isTrue);
    });

    test('SB28: Under lib/, newTokenId: appears only in map_token_service.dart and injection_container.dart', () {
      const newTokenIdParam = 'newTokenId' ':';

      List<String> scanSb28(List<({String name, String content})> files) {
        final violations = <String>[];
        for (final f in files) {
          final isAllowed = f.name.endsWith('map_token_service.dart') || f.name.endsWith('injection_container.dart');
          if (isAllowed) continue;
          final lines = f.content.split('\n');
          for (var i = 0; i < lines.length; i++) {
            if (lines[i].contains(newTokenIdParam)) {
              violations.add('${f.name}:${i + 1}: contains $newTokenIdParam');
            }
          }
        }
        return violations;
      }

      final libFiles = readLibDartFiles();
      final violations = scanSb28(libFiles);
      expect(violations, isEmpty, reason: 'Found SB28 violations:\n${violations.join('\n')}');

      // Verify they do appear in the allowed files
      final serviceFile = libFiles.firstWhere((f) => f.name.endsWith('map_token_service.dart'));
      expect(serviceFile.content.contains(newTokenIdParam), isTrue);
      final diFile = libFiles.firstWhere((f) => f.name.endsWith('injection_container.dart'));
      expect(diFile.content.contains(newTokenIdParam), isTrue);

      // Control: in-memory bad file
      const badContent = 'MapTokenService(' 'newTokenId' ': () => "foo");';
      final controlHits = scanSb28([(name: 'lib/bad_file.dart', content: badContent)]);
      expect(controlHits.length, equals(1));
      expect(controlHits.first, contains('lib/bad_file.dart'));
    });
  });
}
