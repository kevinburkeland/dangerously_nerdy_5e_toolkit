import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/characters/srd_classes_library.dart';

/// Strips `//` line comments and `/* ... */` block comments from Dart source
/// while preserving string literals and newlines for line-number reporting.
String _stripCommentsPreservingStrings(String source) {
  final out = StringBuffer();
  var i = 0;
  final n = source.length;
  while (i < n) {
    final c = source[i];
    final next = i + 1 < n ? source[i + 1] : '';
    if (c == '/' && next == '/') {
      i += 2;
      while (i < n && source[i] != '\n') {
        i++;
      }
      continue;
    }
    if (c == '/' && next == '*') {
      i += 2;
      while (i + 1 < n && !(source[i] == '*' && source[i + 1] == '/')) {
        if (source[i] == '\n') out.write('\n');
        i++;
      }
      i += 2;
      continue;
    }
    if (c == "'" || c == '"') {
      final quote = c;
      final isTriple =
          i + 2 < n && source[i + 1] == quote && source[i + 2] == quote;
      final delim = isTriple ? '$quote$quote$quote' : quote;
      out.write(delim);
      i += delim.length;
      while (i < n) {
        if (source[i] == r'\' && i + 1 < n) {
          out.write(source[i]);
          out.write(source[i + 1]);
          i += 2;
          continue;
        }
        if (source.startsWith(delim, i)) {
          out.write(delim);
          i += delim.length;
          break;
        }
        out.write(source[i]);
        i++;
      }
      continue;
    }
    out.write(c);
    i++;
  }
  return out.toString();
}

final _stringLiteralPattern = RegExp(r'''(?:'([^'\\]*)'|"([^"\\]*)")''');

Set<String> _extractDistinctSlugs(String block, Set<String> srdSlugs) {
  final found = <String>{};
  for (final m in _stringLiteralPattern.allMatches(block)) {
    final raw = (m.group(1) ?? m.group(2) ?? '').toLowerCase().trim();
    if (srdSlugs.contains(raw)) {
      found.add(raw);
    }
  }
  return found;
}

int _lineNumberAt(String source, int offset) {
  var line = 1;
  for (var i = 0; i < offset && i < source.length; i++) {
    if (source[i] == '\n') line++;
  }
  return line;
}

/// Finds collection literals (`[...]`, `{...}`) and `switch` blocks that hold
/// 3 or more distinct SRD class slugs as string literals.
List<String> findHardcodedClassSlugViolations(
  String source,
  Set<String> srdSlugs,
) {
  final stripped = _stripCommentsPreservingStrings(source);
  final violations = <String>[];
  final n = stripped.length;

  final openStack = <({String ch, int pos, bool isSwitch})>[];
  var inQuote = '';

  for (var i = 0; i < n; i++) {
    final c = stripped[i];
    if (inQuote.isNotEmpty) {
      if (c == r'\' && i + 1 < n) {
        i++;
        continue;
      }
      if (c == inQuote) inQuote = '';
      continue;
    }
    if (c == "'" || c == '"') {
      inQuote = c;
      continue;
    }
    if (c == '[' || c == '{') {
      var isSwitch = false;
      if (c == '{') {
        final lookbackStart = i > 80 ? i - 80 : 0;
        final before = stripped.substring(lookbackStart, i);
        if (RegExp(r'\bswitch\s*\([^;{]*\)\s*$').hasMatch(before)) {
          isSwitch = true;
        }
      }
      openStack.add((ch: c, pos: i, isSwitch: isSwitch));
    } else if ((c == ']' || c == '}') && openStack.isNotEmpty) {
      final top = openStack.removeLast();
      final matches = (top.ch == '[' && c == ']') || (top.ch == '{' && c == '}');
      if (!matches) continue;

      final block = stripped.substring(top.pos, i + 1);
      final isCollectionOrSwitch = top.ch == '[' ||
          top.isSwitch ||
          RegExp(r'(?:[=(,:>]|=>|\breturn|\bconst)\s*$').hasMatch(
              stripped.substring(top.pos > 30 ? top.pos - 30 : 0, top.pos));
      if (!isCollectionOrSwitch) continue;

      final slugs = _extractDistinctSlugs(block, srdSlugs);
      if (slugs.length >= 3) {
        final kind = top.isSwitch
            ? 'switch'
            : (top.ch == '[' ? 'list literal' : 'set/map literal');
        final line = _lineNumberAt(stripped, top.pos);
        final sorted = slugs.toList()..sort();
        violations.add('line $line ($kind): ${sorted.join(', ')}');
      }
    }
  }
  return violations;
}

void main() {
  final srdSlugs = SrdClassesLibrary.baseClasses
      .map((c) => c.id.slug.toLowerCase())
      .toSet();

  group('Fix 7.4 compliance bar: no hardcoded 3+ SRD class slug lists or switches in builder/level-up',
      () {
    test('controls: 3-slug list fails; comment passes; 2-slug list passes', () {
      expect(srdSlugs.length, greaterThanOrEqualTo(12));

      const badList = "final casters = ['wizard', 'cleric', 'druid'];";
      const badSwitch = '''
String foo(String s) {
  return switch (s) {
    'wizard' => 'int',
    'cleric' => 'wis',
    'druid' => 'wis',
    _ => 'cha',
  };
}
''';
      const commentOnly = "// final casters = ['wizard', 'cleric', 'druid'];";
      const twoSlugs = "final pair = ['wizard', 'cleric'];";

      expect(findHardcodedClassSlugViolations(badList, srdSlugs), isNotEmpty);
      expect(findHardcodedClassSlugViolations(badSwitch, srdSlugs), isNotEmpty);
      expect(findHardcodedClassSlugViolations(commentOnly, srdSlugs), isEmpty);
      expect(findHardcodedClassSlugViolations(twoSlugs, srdSlugs), isEmpty);
    });

    test('real bar: lib/screens/character_builder_screen.dart and lib/widgets/character_builder/** hold no 3+ SRD class slug literals',
        () {
      final targets = <File>[
        File('lib/screens/character_builder_screen.dart'),
      ];
      final builderDir = Directory('lib/widgets/character_builder');
      if (builderDir.existsSync()) {
        targets.addAll(
          builderDir
              .listSync(recursive: true)
              .whereType<File>()
              .where((f) => f.path.endsWith('.dart')),
        );
      }
      targets.sort((a, b) => a.path.compareTo(b.path));

      final failures = <String>[];
      for (final file in targets) {
        final v = findHardcodedClassSlugViolations(
          file.readAsStringSync(),
          srdSlugs,
        );
        for (final hit in v) {
          failures.add('${file.path}:$hit');
        }
      }

      expect(
        failures,
        isEmpty,
        reason:
            'Hardcoded 3+ SRD class slug lists/switches found:\n${failures.join('\n')}',
      );
    });
  });
}
