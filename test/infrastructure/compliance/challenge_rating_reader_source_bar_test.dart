import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../../support/dart_directive_reader.dart';

final _crTextParserDeclRe = RegExp(
  r'\b\w*ChallengeRating\w*\s*\(\s*String\b',
);

final _stripNonDigitSlashRe = RegExp(
  r"""RegExp\s*\(\s*r?['"]\[\^0-9\/\]['"]\s*\)""",
);

/// Strips `//` line comments and `/* ... */` block comments while preserving
/// string literals and newlines (so regex literal patterns remain inspectable).
String _stripCommentsOnlyPreservingNewlines(String source) {
  final out = StringBuffer();
  var i = 0;
  final n = source.length;
  while (i < n) {
    final c = source.codeUnitAt(i);
    // Single-line comment
    if (c == 0x2F && i + 1 < n && source.codeUnitAt(i + 1) == 0x2F) {
      i += 2;
      while (i < n && source.codeUnitAt(i) != 0x0A) {
        i++;
      }
      continue;
    }
    // Block comment
    if (c == 0x2F && i + 1 < n && source.codeUnitAt(i + 1) == 0x2A) {
      i += 2;
      while (i + 1 < n &&
          !(source.codeUnitAt(i) == 0x2A && source.codeUnitAt(i + 1) == 0x2F)) {
        if (source.codeUnitAt(i) == 0x0A) out.write('\n');
        i++;
      }
      i += 2;
      continue;
    }
    // Preserve string literals verbatim (don't treat // or /* inside strings as comments)
    if (c == 0x27 || c == 0x22) {
      final quote = c;
      final isRaw = i > 0 && source.codeUnitAt(i - 1) == 0x72;
      final isTriple = i + 2 < n &&
          source.codeUnitAt(i + 1) == quote &&
          source.codeUnitAt(i + 2) == quote;
      if (isTriple) {
        out.write(source.substring(i, i + 3));
        i += 3;
        while (i < n) {
          if (!isRaw && source.codeUnitAt(i) == 0x5C && i + 1 < n) {
            out.write(source.substring(i, i + 2));
            i += 2;
            continue;
          }
          if (i + 2 < n &&
              source.codeUnitAt(i) == quote &&
              source.codeUnitAt(i + 1) == quote &&
              source.codeUnitAt(i + 2) == quote) {
            out.write(source.substring(i, i + 3));
            i += 3;
            break;
          }
          out.writeCharCode(source.codeUnitAt(i));
          i++;
        }
      } else {
        out.writeCharCode(quote);
        i++;
        while (i < n) {
          if (!isRaw && source.codeUnitAt(i) == 0x5C && i + 1 < n) {
            out.write(source.substring(i, i + 2));
            i += 2;
            continue;
          }
          final ch = source.codeUnitAt(i);
          out.writeCharCode(ch);
          i++;
          if (ch == quote || ch == 0x0A) break;
        }
      }
      continue;
    }
    out.writeCharCode(c);
    i++;
  }
  return out.toString();
}

/// Scans every `.dart` file under [dir] for:
/// 1. Any function/method declaration whose name contains `ChallengeRating`
///    and takes a `String` parameter (comments and strings stripped).
/// 2. Any occurrence of `RegExp(r'[^0-9/]')` (comments stripped).
List<String> scanChallengeRatingReaders(Directory dir) {
  if (!dir.existsSync()) {
    throw StateError('Directory does not exist: ${dir.path}');
  }
  final violations = <String>[];
  final files = dir
      .listSync(recursive: true)
      .whereType<File>()
      .where((f) => f.path.endsWith('.dart'))
      .toList()
    ..sort((a, b) => a.path.compareTo(b.path));

  for (final file in files) {
    final source = file.readAsStringSync();
    final strippedCode = stripCommentsAndStringsPreservingNewlines(source);
    final codeLines = strippedCode.split('\n');
    for (var i = 0; i < codeLines.length; i++) {
      final match = _crTextParserDeclRe.firstMatch(codeLines[i]);
      if (match != null) {
        violations.add(
          '${file.path}:${i + 1}: declares ChallengeRating text parser '
          '"${match.group(0)}" (use parseChallengeRating from vtt_ruleset_dnd5e)',
        );
      }
    }

    final noComments = _stripCommentsOnlyPreservingNewlines(source);
    final rawLines = noComments.split('\n');
    for (var i = 0; i < rawLines.length; i++) {
      final match = _stripNonDigitSlashRe.firstMatch(rawLines[i]);
      if (match != null) {
        violations.add(
          '${file.path}:${i + 1}: uses destructive CR regex "${match.group(0)}" '
          '(use parseChallengeRating from vtt_ruleset_dnd5e)',
        );
      }
    }
  }
  return violations;
}

void main() {
  group('Fix 2.2 source bar: no local ChallengeRating text parsers under lib/', () {
    test('controls: private _parseChallengeRating(String) and RegExp fail; commented versions pass', () {
      final tmp = Directory.systemTemp.createTempSync('cr_bar_ctrl_');
      addTearDown(() => tmp.deleteSync(recursive: true));

      final badFile = File('${tmp.path}/bad_cr.dart')
        ..writeAsStringSync('''
class Foo {
  static double _parseChallengeRating(String crDisplay) {
    final cleaned = crDisplay.replaceAll(RegExp(r'[^0-9/]'), '');
    return double.tryParse(cleaned) ?? 0;
  }
}
''');
      final badHits = scanChallengeRatingReaders(tmp);
      expect(badHits, hasLength(2));
      expect(badHits[0], contains('bad_cr.dart:2'));
      expect(badHits[1], contains('bad_cr.dart:3'));

      badFile.writeAsStringSync('''
class Foo {
  // static double _parseChallengeRating(String crDisplay) => 0;
  /* RegExp(r'[^0-9/]') */
  String _parseChallengeRating(dynamic raw) => raw.toString();
}
''');
      final okHits = scanChallengeRatingReaders(tmp);
      expect(okHits, isEmpty);
    });

    test('real bar: lib/ delegates all numeric CR parsing to vtt_ruleset_dnd5e', () {
      final hits = scanChallengeRatingReaders(Directory('lib'));
      expect(hits, isEmpty, reason: hits.join('\n'));
    });
  });
}
