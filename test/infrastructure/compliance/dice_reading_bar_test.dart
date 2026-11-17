import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import '../../support/dart_string_literal_reader.dart';

bool isDicePattern(String s) {
  // Condition 1: Contains at least one regex escape or group construct:
  // \d, \s, \w, \b (or \D, \S, \W, \B) or (?:, (?=, (?!, (?<
  final c1 = RegExp(r'\\[dswbDSWB]|\(\?(?:[:=!]|<)').hasMatch(s);
  if (!c1) return false;

  // Condition 2: Has a standalone letter d or D (or d%) adjacent to a regex digit token
  // (e.g. \d, \d+, [0-9], [0-9]+, or an explicit digit), separated by at most optional
  // whitespace or grouping parens, OR a class of dice faces d(?:4|6|8|10|12|20|100).
  // The die letter d or D must NOT be preceded by backslash \ (which would make it \d).
  const dieLetter = r'(?<![a-zA-Z_\\])[dD](?![a-zA-Z_])';
  const faceClass = r'd\(\?:\s*(?:4|6|8|10|12|20|100)(?:\s*\|\s*(?:4|6|8|10|12|20|100))*\)';
  const digitToken = r'(?:\\[dD]|\[0-9\]|\d+)(?:\+)?';
  const sep = r'(?:\s*|\\s\*|\(|\)|\[|\/)*';

  final c2 = RegExp(
    '(?:'
    '(?:$digitToken$sep$dieLetter)'
    '|'
    '(?:$dieLetter$sep$digitToken)'
    '|'
    '(?:$dieLetter%)'
    '|'
    '(?:$faceClass)'
    ')',
    caseSensitive: false,
  ).hasMatch(s);

  return c2;
}

void main() {
  group('Dice Reading Compliance Bar (Law D16)', () {
    // Law D16: All dice reading and extraction in the app must route through
    // DiceExpression (from package:vtt_ruleset_dnd5e). Hand-written regex literals,
    // string slicing on die letter (.split('d'), indexOf('d')), and ad-hoc dice parsing
    // helpers in lib/ are forbidden.
    const allowedFiles = <String>{};

    final splitDicePattern = RegExp(r"\.split\('[dD]'\)|\.split\(\x22[dD]\x22\)");
    final indexOfDicePattern = RegExp(r"\.indexOf\('[dD]'\)|\.indexOf\(\x22[dD]\x22\)");
    final diceHelperPattern = RegExp(
        r'(?:String\??|List<int>|\(int,\s*int\))\s+(?:_?parseDice|_?readDice|_?extractDice|extractHigherLevelsDice)\s*\(');

    List<String> checkFileViolations(String relativePath, String content) {
      final normalizedPath = relativePath.replaceAll('\\', '/');

      final violations = <String>[];

      // 1. Check all string literals via extractDartStringLiterals
      final literals = extractDartStringLiterals(content, filePath: normalizedPath);
      for (final lit in literals) {
        if (isDicePattern(lit.value)) {
          violations.add(
            '$normalizedPath:${lit.lineNumber}: Hand-written dice regex pattern forbidden: "${lit.value.trim()}"',
          );
        }
      }

      // 2. Check for string slicing or ad-hoc helper patterns in code lines
      final lines = content.split('\n');
      for (var i = 0; i < lines.length; i++) {
        final line = lines[i];
        final trimmed = line.trim();

        if (trimmed.startsWith('//') ||
            trimmed.startsWith('/*') ||
            trimmed.startsWith('*')) {
          continue;
        }

        if (splitDicePattern.hasMatch(line)) {
          violations.add(
            '$normalizedPath:${i + 1}: Direct .split("d") dice parsing forbidden: "$trimmed"',
          );
        }

        if (indexOfDicePattern.hasMatch(line)) {
          violations.add(
            '$normalizedPath:${i + 1}: Direct .indexOf("d") dice parsing forbidden: "$trimmed"',
          );
        }

        if (diceHelperPattern.hasMatch(line)) {
          violations.add(
            '$normalizedPath:${i + 1}: Ad-hoc dice parsing helper forbidden: "$trimmed"',
          );
        }
      }

      return violations;
    }

    test('All dice parsing in lib/ uses DiceExpression (no hand-written parsers)', () {
      final libDir = Directory('lib');
      final dartFiles = libDir
          .listSync(recursive: true)
          .whereType<File>()
          .where((f) => f.path.endsWith('.dart'))
          .where((f) => !f.path.replaceAll('\\', '/').contains('/generated/'))
          .toList()
        ..sort((a, b) => a.path.compareTo(b.path));

      final allViolations = <String>[];
      final matchedAllowlist = <String>{};

      for (final file in dartFiles) {
        final relativePath = file.path.replaceAll('\\', '/');
        final content = file.readAsStringSync();
        final fileViolations = checkFileViolations(relativePath, content);
        if (allowedFiles.contains(relativePath)) {
          if (fileViolations.isNotEmpty) {
            matchedAllowlist.add(relativePath);
          }
        } else {
          allViolations.addAll(fileViolations);
        }
      }

      // Stale check for allowedFiles
      final staleAllowlist = allowedFiles.difference(matchedAllowlist);
      expect(
        staleAllowlist,
        isEmpty,
        reason: 'Stale entries in allowedFiles that have no violations: $staleAllowlist',
      );

      expect(
        allViolations,
        isEmpty,
        reason: 'Hand-written dice reading sites found in lib/ (must use DiceExpression):\n'
            '${allViolations.join('\n')}',
      );
    });

    group('Source Bar Self-Tests & Controls', () {
      test('16 flagged positive controls pass isDicePattern', () {
        const posControls = [
          r'(\d+)d(\d+)',
          r'(\d+)d(\d+)(?:\s*([+-])\s*(\d+))?',
          r'\bHit\s+Di(?:e|ce)\s*[:]?\s*(?:1)?(d\d+)\b',
          r'(?:\{@damage\s+)?(\d+d\d+)(?:\|([a-zA-Z]+))?\}?|\b(\d+d\d+)\s*(acid|bludgeoning|cold|fire|force|lightning|necrotic|piercing|poison|psychic|radiant|slashing|thunder)?\b',
          r'(\d+d\d+)[^\w\n]*(acid|bludgeoning|cold|fire|force|lightning|necrotic|piercing|poison|psychic|radiant|slashing|thunder)\s+damage',
          r'^Hit\s+Die\s*[:]?\s*(?:1)?(d(?:6|8|10|12))\b',
          r'^(?:1)?d(?:6|8|10|12)$',
          r'(?:plus|and(?:\s+the\s+target)?\s+takes?|extra)\s*(?:\d+\s*)?\(?(\d+)\s*d\s*(\d+)\)?(?:\s*([+-]\s*\d+))?\s*(\w+)?\s*damage',
          r"target's\s*(Strength|Constitution|Dexterity|Intelligence|Wisdom|Charisma)\s*score is reduced by\s*(\d+d\d+|\d+)(?:.*?(target dies if this reduces (?:its\s+)?.*?to 0))?",
          r"target's hit point maximum is reduced by (?:an amount equal to the (?:necrotic )?damage|(\d+d\d+|\d+))",
          r'takes (?:(\d+)\s*\()?(\d+)d(\d+)(?:\s*\+\s*(\d+))?\)?\s*(\w+)?\s*damage at the (start|end) of (?:each of )?its turns?',
          r'\d*d\d+',
          r'\d+d\d+',
          r'(\d+)d(\d+)',
          r'^d\d+',
          r'd(\d+)',
        ];

        for (final control in posControls) {
          expect(
            isDicePattern(control),
            isTrue,
            reason: 'Expected positive control to be flagged: $control',
          );
        }
      });

      test('14 unflagged negative controls do not pass isDicePattern', () {
        const negControls = [
          'ordinary text with d in it',
          'https://example.com/api/data',
          '2026-11-17T12:00:00Z',
          r'\b[a-z]+\b',
          r'^\d{4}-\d{2}-\d{2}$',
          'SELECT id, name FROM users WHERE id = ?',
          '# Header\n\nSome markdown text with words.',
          r'^[A-Z][a-z0-9_]*$',
          r'\s+',
          r'\b(?:cat|dog|fish)\b',
          r'width:\s*\d+px',
          r'border-radius:\s*\d+rem',
          r'(?:hello|world)',
          r'\b[0-9a-fA-F]{32}\b',
        ];

        for (final control in negControls) {
          expect(
            isDicePattern(control),
            isFalse,
            reason: 'Expected negative control to NOT be flagged: $control',
          );
        }
      });

      test('Flags string split across adjacent lines', () {
        const fakePath = 'lib/services/fake_service.dart';
        const fakeContent = r'''
final r = RegExp(
  r'(\d+)'
  r'd(\d+)'
);
''';
        final v = checkFileViolations(fakePath, fakeContent);
        expect(v, isNotEmpty);
        expect(v.first, contains('Hand-written dice regex pattern forbidden'));
      });

      test('Flags .split("d") and indexOf("d") calls', () {
        const fakePath = 'lib/services/fake_service.dart';
        const fakeContent = '''
void parse(String text) {
  final idx = text.indexOf('d');
  final parts = text.split('d');
}
''';
        final v = checkFileViolations(fakePath, fakeContent);
        expect(v.length, 2);
        expect(v[0], contains('Direct .indexOf("d")'));
        expect(v[1], contains('Direct .split("d")'));
      });
    });
  });
}
