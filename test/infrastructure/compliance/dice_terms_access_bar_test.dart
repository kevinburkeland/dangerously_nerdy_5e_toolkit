import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import '../../support/dart_directive_reader.dart';

/// Allowed member suffixes immediately after `.diceTerms` (ignoring whitespace/newlines).
final _allowedAfterDiceTerms = RegExp(
  r'^\s*(?:\.(?:map|fold|expand|where|every|any)\s*\(|\.(?:length|isEmpty|isNotEmpty)\b)',
);

/// Checks whether `.diceTerms` at [matchStart] is the iterable of a `for (... in ...)` header.
bool _isForInIterable(String stripped, int matchStart, int matchEnd) {
  // Look ahead after `.diceTerms` for closing `)` of the for-in header.
  final after = stripped.substring(matchEnd);
  if (!RegExp(r'^\s*\)').hasMatch(after)) return false;

  // Walk backward to the enclosing `(` of the `for (...)` header.
  int depth = 0;
  int openParen = -1;
  for (int i = matchStart - 1; i >= 0; i--) {
    final c = stripped[i];
    if (c == ')') {
      depth++;
    } else if (c == '(') {
      if (depth == 0) {
        openParen = i;
        break;
      }
      depth--;
    } else if (c == ';' || c == '{' || c == '}') {
      return false;
    }
  }
  if (openParen == -1) return false;

  // Check that `for` immediately precedes `(` (ignoring whitespace)
  final beforeParen = stripped.substring(0, openParen);
  if (!RegExp(r'\bfor\s*$').hasMatch(beforeParen)) return false;

  // Check that ` in ` appears between `(` and `.diceTerms`
  final headerInside = stripped.substring(openParen + 1, matchStart);
  return RegExp(r'\bin\b').hasMatch(headerInside);
}

List<String> scanDiceTermsAccessViolations(String source, String filePath) {
  final stripped = stripCommentsAndStringsPreservingNewlines(source);
  final violations = <String>[];
  final pattern = RegExp(r'\.\s*diceTerms\b');

  for (final m in pattern.allMatches(stripped)) {
    final after = stripped.substring(m.end);
    if (_allowedAfterDiceTerms.hasMatch(after)) continue;
    if (_isForInIterable(stripped, m.start, m.end)) continue;

    final line = '\n'.allMatches(stripped.substring(0, m.start)).length + 1;
    violations.add("$filePath:$line: takes part of an expression's dice");
  }

  return violations;
}

void main() {
  group('Fix 3.3 Source Bar: no partial extraction from .diceTerms', () {
    test('Controls: flags partial access and variable capture, allows full iteration and safe checks', () {
      // Must flag
      expect(
        scanDiceTermsAccessViolations('final x = expr.diceTerms.first;', 'a.dart'),
        equals(["a.dart:1: takes part of an expression's dice"]),
      );
      expect(
        scanDiceTermsAccessViolations(
          'final x = expr\n    .diceTerms\n    .firstOrNull;',
          'b.dart',
        ),
        equals(["b.dart:2: takes part of an expression's dice"]),
      );
      expect(
        scanDiceTermsAccessViolations('final t = expr.diceTerms;', 'c.dart'),
        equals(["c.dart:1: takes part of an expression's dice"]),
      );
      expect(
        scanDiceTermsAccessViolations('final x = expr.diceTerms[0];', 'd.dart'),
        equals(["d.dart:1: takes part of an expression's dice"]),
      );
      expect(
        scanDiceTermsAccessViolations('final x = expr.diceTerms.elementAt(0);', 'e.dart'),
        equals(["e.dart:1: takes part of an expression's dice"]),
      );

      // Must NOT flag
      expect(
        scanDiceTermsAccessViolations('for (final t in expr.diceTerms) {}', 'ok1.dart'),
        isEmpty,
      );
      expect(
        scanDiceTermsAccessViolations('final x = expr.diceTerms.map(f);', 'ok2.dart'),
        isEmpty,
      );
      expect(
        scanDiceTermsAccessViolations('if (expr.diceTerms.isEmpty) {}', 'ok3.dart'),
        isEmpty,
      );
      expect(
        scanDiceTermsAccessViolations(
          '// expr.diceTerms.first\nconst s = "expr.diceTerms.firstOrNull";\n',
          'ok4.dart',
        ),
        isEmpty,
      );
    });

    test('Production lib/ contains zero partial .diceTerms accesses', () {
      final libDir = Directory('lib');
      expect(libDir.existsSync(), isTrue);

      final violations = <String>[];
      final files = libDir
          .listSync(recursive: true)
          .whereType<File>()
          .where((f) => f.path.endsWith('.dart'))
          .toList()
        ..sort((a, b) => a.path.compareTo(b.path));

      for (final file in files) {
        final content = file.readAsStringSync();
        violations.addAll(scanDiceTermsAccessViolations(content, file.path));
      }

      expect(
        violations,
        isEmpty,
        reason: 'Partial .diceTerms accesses found:\n${violations.join('\n')}',
      );
    });
  });
}
