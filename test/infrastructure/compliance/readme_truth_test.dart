import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

/// Finds hand-typed test count strings or badges.
/// Finds a number (not directly after a letter, so d20 is not a number)
/// followed by test, tests or passing (any case, allowing commas in the number,
/// an optional word like automated in between, and %20 or spaces as separators).
List<String> handTypedCountProblems(String text) {
  final pattern = RegExp(
    r'(?<![a-zA-Z0-9])(\d{1,3}(?:,\d{3})+|\d+)(?:%20|\s)+(?:[a-zA-Z]+(?:%20|\s)+)?(tests?|passing)\b',
    caseSensitive: false,
  );
  return pattern.allMatches(text).map((m) => m.group(0)!).toList();
}

void main() {
  group('README Truth & Test Count Invariants', () {
    test('RT1: README.md has at most 100 lines', () {
      final readmeFile = File('README.md');
      expect(readmeFile.existsSync(), isTrue);

      final lines = readmeFile.readAsLinesSync();
      expect(lines.length, lessThanOrEqualTo(100),
          reason: 'README.md must be at most 100 lines, found: ${lines.length}');
    });

    test('RT2: handTypedCountProblems finds nothing in README.md or any .md under docs/', () {
      final readmeFile = File('README.md');
      expect(readmeFile.existsSync(), isTrue);
      final readmeContent = readmeFile.readAsStringSync();
      final readmeProblems = handTypedCountProblems(readmeContent);
      expect(readmeProblems, isEmpty,
          reason: 'README.md contains hand-typed test counts: $readmeProblems');

      final docsDir = Directory('docs');
      expect(docsDir.existsSync(), isTrue);
      final docFiles = docsDir
          .listSync(recursive: true)
          .whereType<File>()
          .where((f) => f.path.endsWith('.md'))
          .toList();

      expect(docFiles.length, greaterThanOrEqualTo(4));

      for (final doc in docFiles) {
        final content = doc.readAsStringSync();
        final problems = handTypedCountProblems(content);
        expect(problems, isEmpty,
            reason: '${doc.path} contains hand-typed test counts: $problems');
      }
    });

    test('RT3 (control): finds the badge and both counts in old README and sample strings', () {
      final fixtureFile = File('test/fixtures/docs/old_readme.md');
      expect(fixtureFile.existsSync(), isTrue);

      final oldContent = fixtureFile.readAsStringSync();
      final oldProblems = handTypedCountProblems(oldContent);

      expect(oldProblems, isNotEmpty);
      expect(oldProblems.any((p) => p.contains('1946%20Passing')), isTrue,
          reason: 'Expected badge 1946%20Passing to be found');
      expect(oldProblems.any((p) => p.contains('1,946 tests')), isTrue,
          reason: 'Expected 1,946 tests to be found');
      expect(oldProblems.any((p) => p.contains('1,946 automated tests')), isTrue,
          reason: 'Expected 1,946 automated tests to be found');

      // Four positive example strings
      expect(handTypedCountProblems('1,946 tests'), isNotEmpty);
      expect(handTypedCountProblems('Tests-1946%20Passing'), isNotEmpty);
      expect(handTypedCountProblems('2680 automated tests'), isNotEmpty);
      expect(handTypedCountProblems('1946 Passing'), isNotEmpty);

      // Three negative example strings
      expect(handTypedCountProblems('Run the tests with flutter test'), isEmpty);
      expect(handTypedCountProblems('Section 3'), isEmpty);
      expect(handTypedCountProblems('d20 tests of skill'), isEmpty);
    });

    test('RT4: README.md contains generated Actions badge URL and no shields Tests badge', () {
      final readmeFile = File('README.md');
      expect(readmeFile.existsSync(), isTrue);
      final content = readmeFile.readAsStringSync();

      const actionsBadgeUrl =
          'https://github.com/kevinburkeland/dangerously_nerdy_5e_toolkit/actions/workflows/release.yml/badge.svg?branch=main';
      expect(content, contains(actionsBadgeUrl),
          reason: 'README.md must contain the GitHub Actions status badge URL for release.yml on main');

      expect(content, isNot(contains('img.shields.io/badge/Tests')),
          reason: 'README.md must not contain the hand-typed shields Tests badge');
    });

    test('RT5: README.md links each of the three repositories', () {
      final readmeFile = File('README.md');
      expect(readmeFile.existsSync(), isTrue);
      final content = readmeFile.readAsStringSync();

      expect(content, contains('github.com/kevinburkeland/vtt-engine-core'),
          reason: 'README.md must link vtt-engine-core repo');
      expect(content, contains('github.com/kevinburkeland/vtt-ruleset-dnd5e'),
          reason: 'README.md must link vtt-ruleset-dnd5e repo');
      expect(content, contains('github.com/kevinburkeland/dangerously_nerdy_5e_toolkit'),
          reason: 'README.md must link dangerously_nerdy_5e_toolkit repo');
    });
  });
}
