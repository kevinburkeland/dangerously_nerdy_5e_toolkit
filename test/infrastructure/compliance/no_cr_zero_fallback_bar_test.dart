import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Strips `//` line comments, `/* ... */` block comments, and string literals
/// while preserving line numbers so pattern matches report exact 1-based lines.
String _stripCommentsAndStrings(String source) {
  final buf = StringBuffer();
  var i = 0;
  final n = source.length;
  while (i < n) {
    final c = source[i];
    if (c == '/' && i + 1 < n && source[i + 1] == '/') {
      while (i < n && source[i] != '\n') {
        buf.write(' ');
        i++;
      }
      continue;
    }
    if (c == '/' && i + 1 < n && source[i + 1] == '*') {
      buf.write('  ');
      i += 2;
      while (i < n) {
        if (source[i] == '*' && i + 1 < n && source[i + 1] == '/') {
          buf.write('  ');
          i += 2;
          break;
        }
        buf.write(source[i] == '\n' ? '\n' : ' ');
        i++;
      }
      continue;
    }
    if (c == '\'' || c == '"') {
      final quote = c;
      final triple = i + 2 < n && source[i + 1] == quote && source[i + 2] == quote;
      final delimLen = triple ? 3 : 1;
      for (var k = 0; k < delimLen; k++) {
        buf.write(' ');
        i++;
      }
      while (i < n) {
        if (!triple && source[i] == '\\' && i + 1 < n) {
          buf.write('  ');
          i += 2;
          continue;
        }
        if (triple &&
            i + 2 < n &&
            source[i] == quote &&
            source[i + 1] == quote &&
            source[i + 2] == quote) {
          buf.write('   ');
          i += 3;
          break;
        }
        if (!triple && source[i] == quote) {
          buf.write(' ');
          i++;
          break;
        }
        buf.write(source[i] == '\n' ? '\n' : ' ');
        i++;
      }
      continue;
    }
    buf.write(c);
    i++;
  }
  return buf.toString();
}

final _kCrZeroFallbackPattern = RegExp(
  r'parseChallengeRating\s*\([^)]*\)\s*\?\?\s*-?\d+(?:\.\d+)?',
  multiLine: true,
);

List<String> scanCrFallbackViolations(Map<String, String> files) {
  final violations = <String>[];
  for (final entry in files.entries) {
    final cleaned = _stripCommentsAndStrings(entry.value);
    for (final match in _kCrZeroFallbackPattern.allMatches(cleaned)) {
      final line = '\n'.allMatches(cleaned.substring(0, match.start)).length + 1;
      violations.add('${entry.key}:$line: ${match.group(0)}');
    }
  }
  return violations;
}

void main() {
  group('Fix 7.2 source bar: no parseChallengeRating(...) ?? <number> in lib/', () {
    test('controls: flags parseChallengeRating(x) ?? 0 with file and line; comment passes', () {
      final bad = scanCrFallbackViolations({
        'lib/sample_bad.dart': 'final a = 1;\nfinal cr = parseChallengeRating(x) ?? 0;\n',
      });
      expect(bad, hasLength(1));
      expect(bad.single, contains('lib/sample_bad.dart:2'));

      final commented = scanCrFallbackViolations({
        'lib/sample_comment.dart': '// final cr = parseChallengeRating(x) ?? 0;\n/* parseChallengeRating(y) ?? 1.5 */\n',
      });
      expect(commented, isEmpty);
    });

    test('real bar: lib/ contains zero parseChallengeRating(...) ?? <number> fallbacks', () {
      final libDir = Directory('lib');
      final files = <String, String>{};
      for (final entity in libDir.listSync(recursive: true)) {
        if (entity is File && entity.path.endsWith('.dart')) {
          files[entity.path] = entity.readAsStringSync();
        }
      }
      final violations = scanCrFallbackViolations(files);
      expect(
        violations,
        isEmpty,
        reason: 'Forbidden parseChallengeRating numeric fallback(s) found:\n${violations.join('\n')}',
      );
    });
  });
}
