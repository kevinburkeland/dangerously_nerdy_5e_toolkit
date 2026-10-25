import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Sibling Repo Reference Source Bar (Pass 5.1.3)', () {
    final testDir = Directory('test');

    List<String> checkFileViolations(String relativePath, String content) {
      final normalizedPath = relativePath.replaceAll('\\', '/');
      if (normalizedPath.endsWith('sibling_repo_reference_source_bar_test.dart')) {
        return [];
      }

      final lines = content.split('\n');
      final violations = <String>[];

      for (var i = 0; i < lines.length; i++) {
        final line = lines[i];
        if (line.contains('../vtt-')) {
          violations.add('$normalizedPath:${i + 1}: ${line.trim()}');
        }
      }

      return violations;
    }

    test('Source Bar: No file under test/ may contain sibling repo references (../vtt-)', () {
      expect(testDir.existsSync(), isTrue, reason: 'test/ directory must exist');

      final violations = <String>[];
      for (final entity in testDir.listSync(recursive: true)) {
        if (entity is File) {
          final content = entity.readAsStringSync(encoding: latin1);
          violations.addAll(checkFileViolations(entity.path, content));
        }
      }

      expect(
        violations,
        isEmpty,
        reason: 'Forbidden sibling repository references (../vtt-) found under test/:\n'
            '${violations.join('\n')}\n'
            'Tests in CI run in an isolated clone with no sibling repositories. '
            'All test fixtures must be local to this repository.',
      );
    });

    group('Source Bar Self-Tests', () {
      test('detects ../vtt- references in content', () {
        const dummyCode = "final fallback = File('../vtt-engine-core/fixtures/foo.json');";
        final violations = checkFileViolations('test/dummy_test.dart', dummyCode);
        expect(violations, isNotEmpty);
        expect(violations.first, contains('test/dummy_test.dart:1'));
      });

      test('allows clean content without sibling repo references', () {
        const cleanCode = "final local = File('test/fixtures/legacy_entity_links/foo.json');";
        final violations = checkFileViolations('test/dummy_test.dart', cleanCode);
        expect(violations, isEmpty);
      });
    });
  });
}
