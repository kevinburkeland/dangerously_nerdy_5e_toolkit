import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Dice Reading Compliance Bar (Law D16)', () {
    // Law D16: All dice reading and extraction in the app must route through
    // DiceExpression (from package:vtt_ruleset_dnd5e). Hand-written regex literals,
    // .split('d') calls, and ad-hoc dice parsing helpers in lib/ are forbidden.
    const allowedFiles = <String>{};

    final diceRegexPatterns = [
      RegExp(r'\\d\*d\\d\+', caseSensitive: false),
      RegExp(r'\\d\+d\\d\+', caseSensitive: false),
      RegExp(r'\(\\d\+\)d\(\\d\+\)', caseSensitive: false),
      RegExp(r'\^\\d\*d\\d\+', caseSensitive: false),
      RegExp(r'\^d\\d\+', caseSensitive: false),
      RegExp(r'\[dD\]\\d\+', caseSensitive: false),
      RegExp(r'd\(\\d\+\)', caseSensitive: false),
      RegExp(r'\\b\(\?:d\\d\+|d%\|roll\|die\|dice\|result\)\\b', caseSensitive: false),
      RegExp(r'\|d\\d\+', caseSensitive: false),
    ];

    final splitDicePattern = RegExp(r"\.split\('[dD]'\)|\.split\(\x22[dD]\x22\)");
    final diceHelperPattern = RegExp(
        r'(?:String\??|List<int>|\(int,\s*int\))\s+(?:_?parseDice|_?readDice|_?extractDice|extractHigherLevelsDice)\s*\(');

    List<String> checkFileViolations(String relativePath, String content) {
      final normalizedPath = relativePath.replaceAll('\\', '/');
      if (allowedFiles.contains(normalizedPath)) {
        return [];
      }

      final violations = <String>[];
      final lines = content.split('\n');

      for (var i = 0; i < lines.length; i++) {
        final line = lines[i];
        final trimmed = line.trim();

        // Skip comments
        if (trimmed.startsWith('//') ||
            trimmed.startsWith('/*') ||
            trimmed.startsWith('*')) {
          continue;
        }

        if (line.contains('RegExp')) {
          for (final pattern in diceRegexPatterns) {
            if (pattern.hasMatch(line)) {
              violations.add(
                '$normalizedPath:${i + 1}: Hand-written dice regex literal forbidden: "$trimmed"',
              );
              break;
            }
          }
        }

        if (splitDicePattern.hasMatch(line)) {
          violations.add(
            '$normalizedPath:${i + 1}: Direct .split("d") dice parsing forbidden: "$trimmed"',
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

      for (final file in dartFiles) {
        final relativePath = file.path.replaceAll('\\', '/');
        final content = file.readAsStringSync();
        allViolations.addAll(checkFileViolations(relativePath, content));
      }

      expect(
        allViolations,
        isEmpty,
        reason: 'Hand-written dice reading sites found in lib/ (must use DiceExpression):\n'
            '${allViolations.join('\n')}',
      );
    });

    group('Source Bar Self-Tests', () {
      test('Flags hand-written dice regex literal', () {
        const fakePath = 'lib/services/fake_service.dart';
        const fakeContent = '''
class FakeService {
  void parse(String text) {
    final m = RegExp(r'(\\d+)d(\\d+)').firstMatch(text);
  }
}
''';
        final v = checkFileViolations(fakePath, fakeContent);
        expect(v, isNotEmpty);
        expect(v.first, contains('Hand-written dice regex'));
      });

      test('Flags .split("d") call', () {
        const fakePath = 'lib/services/fake_service.dart';
        const fakeContent = '''
class FakeService {
  void parse(String text) {
    final parts = text.split('d');
  }
}
''';
        final v = checkFileViolations(fakePath, fakeContent);
        expect(v, isNotEmpty);
        expect(v.first, contains('Direct .split("d")'));
      });

      test('Flags ad-hoc dice helper method', () {
        const fakePath = 'lib/services/fake_service.dart';
        const fakeContent = '''
class FakeService {
  static String? extractHigherLevelsDice(String? text) {
    return null;
  }
}
''';
        final v = checkFileViolations(fakePath, fakeContent);
        expect(v, isNotEmpty);
        expect(v.first, contains('Ad-hoc dice parsing helper'));
      });
    });
  });
}
