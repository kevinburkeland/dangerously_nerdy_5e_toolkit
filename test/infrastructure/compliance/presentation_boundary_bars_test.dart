import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Strips block comments, line comments, and string literal contents
/// (preserving `${...}` interpolation code) from [source], preserving line count.
String stripCommentsAndStringsPreservingLines(String source) {
  final n = source.length;
  int i = 0;
  final buf = StringBuffer();
  final stack = <Map<String, dynamic>>[{'type': 'code', 'braceDepth': 0}];

  while (i < n) {
    final ctx = stack.last;
    final type = ctx['type'] as String;

    if (type == 'code') {
      if (source.startsWith('//', i)) {
        while (i < n && source[i] != '\n') {
          i++;
        }
        continue;
      }
      if (source.startsWith('/*', i)) {
        i += 2;
        while (i < n && !source.startsWith('*/', i)) {
          if (source[i] == '\n') buf.write('\n');
          i++;
        }
        if (i < n) i += 2;
        continue;
      }
      if (source[i] == 'r' &&
          i + 1 < n &&
          (source[i + 1] == "'" || source[i + 1] == '"')) {
        final q = source[i + 1];
        final isTriple =
            i + 3 < n && source[i + 2] == q && source[i + 3] == q;
        final delim = isTriple ? q * 3 : q;
        buf.write("''");
        i += 1 + delim.length;
        while (i < n) {
          if (source.startsWith(delim, i)) {
            i += delim.length;
            break;
          } else {
            if (source[i] == '\n') buf.write('\n');
            i++;
          }
        }
        continue;
      }
      if (source[i] == "'" || source[i] == '"') {
        final q = source[i];
        final isTriple =
            i + 2 < n && source[i + 1] == q && source[i + 2] == q;
        final delim = isTriple ? q * 3 : q;
        buf.write(q);
        i += delim.length;
        stack.add({'type': 'string', 'delim': delim, 'quote': q});
        continue;
      }
      if (source[i] == '{') {
        ctx['braceDepth'] = (ctx['braceDepth'] as int) + 1;
        buf.write('{');
        i++;
        continue;
      }
      if (source[i] == '}') {
        final bd = ctx['braceDepth'] as int;
        if (bd > 0) {
          ctx['braceDepth'] = bd - 1;
          buf.write('}');
          i++;
        } else if (stack.length > 1) {
          stack.removeLast();
          buf.write('}');
          i++;
        } else {
          buf.write('}');
          i++;
        }
        continue;
      }
      buf.write(source[i]);
      i++;
    } else if (type == 'string') {
      final delim = ctx['delim'] as String;
      final q = ctx['quote'] as String;
      if (source.startsWith(delim, i)) {
        buf.write(q);
        i += delim.length;
        stack.removeLast();
        continue;
      }
      if (source[i] == r'\' && i + 1 < n) {
        if (source[i + 1] == '\n') buf.write('\n');
        i += 2;
        continue;
      }
      if (source.startsWith(r'${', i)) {
        buf.write(r'${');
        i += 2;
        stack.add({'type': 'code', 'braceDepth': 0});
        continue;
      }
      if (source[i] == '\n') buf.write('\n');
      i++;
    }
  }
  return buf.toString();
}

List<String> checkRuleP1(String filePath, String source) {
  final stripped = stripCommentsAndStringsPreservingLines(source);
  final lines = stripped.split('\n');
  final violations = <String>[];
  final regex = RegExp(r'\bas\s+BuildContext\b');

  for (int idx = 0; idx < lines.length; idx++) {
    final line = lines[idx];
    if (regex.hasMatch(line)) {
      violations.add('$filePath:${idx + 1}: ${line.trim()}');
    }
  }
  return violations;
}

List<String> checkRuleP2(String filePath, String source) {
  final stripped = stripCommentsAndStringsPreservingLines(source);
  final lines = stripped.split('\n');
  final violations = <String>[];
  final regex = RegExp(
      r'\bfinal\s+(?:(?:void|[A-Za-z0-9_<>?]+)\s+)?Function\s*\([^)]*\)\s*[?]?\s*[A-Za-z0-9_]+\s*;');

  for (int idx = 0; idx < lines.length; idx++) {
    final line = lines[idx];
    if (regex.hasMatch(line)) {
      violations.add('$filePath:${idx + 1}: ${line.trim()}');
    }
  }
  return violations;
}

List<String> checkRuleP3(String filePath, String source) {
  final stripped = stripCommentsAndStringsPreservingLines(source);
  final lines = stripped.split('\n');
  final violations = <String>[];
  final regex = RegExp(
      r'\b(?:Object\?|Object|dynamic)\s+(?:context|ctx|buildContext|raw[A-Za-z0-9_]*(?:Ctx|Context))\b');

  for (int idx = 0; idx < lines.length; idx++) {
    final line = lines[idx];
    if (regex.hasMatch(line)) {
      violations.add('$filePath:${idx + 1}: ${line.trim()}');
    }
  }
  return violations;
}

void main() {
  group('Presentation Boundary Bars Controls', () {
    test('Rule P1 controls: flags as BuildContext, allows typed parameter', () {
      const bad = 'final c = x as BuildContext;';
      const good = 'void f(BuildContext c) {}';

      expect(checkRuleP1('in_memory.dart', bad), hasLength(1));
      expect(checkRuleP1('in_memory.dart', good), isEmpty);
    });

    test('Rule P2 controls: flags class field with function type, allows method parameter', () {
      const bad = 'class Foo { final void Function(Object? c)? onTap; }';
      const good = 'class Foo { void run(int Function(int sides) roller) {} }';

      expect(checkRuleP2('in_memory.dart', bad), hasLength(1));
      expect(checkRuleP2('in_memory.dart', good), isEmpty);
    });

    test('Rule P3 controls: flags Object? context and dynamic rawCtx, allows BuildContext context', () {
      const bad1 = 'void f(Object? context) {}';
      const bad2 = 'void g(dynamic rawCtx) {}';
      const good = 'void h(BuildContext context) {}';

      expect(checkRuleP3('in_memory.dart', bad1), hasLength(1));
      expect(checkRuleP3('in_memory.dart', bad2), hasLength(1));
      expect(checkRuleP3('in_memory.dart', good), isEmpty);
    });
  });

  group('Presentation Boundary Bars Invariants', () {
    test('Rule P1: no as BuildContext anywhere in lib/', () {
      final violations = <String>[];
      final libDir = Directory('lib');
      for (final entity in libDir.listSync(recursive: true)) {
        if (entity is File && entity.path.endsWith('.dart')) {
          final content = entity.readAsStringSync();
          violations.addAll(checkRuleP1(entity.path, content));
        }
      }

      expect(violations, isEmpty,
          reason: 'Rule P1: No "as BuildContext" allowed in lib/');
    });

    test('Rule P2: no class field with function type in lib/models/', () {
      final violations = <String>[];
      final modelsDir = Directory('lib/models');
      for (final entity in modelsDir.listSync(recursive: true)) {
        if (entity is File && entity.path.endsWith('.dart')) {
          final content = entity.readAsStringSync();
          violations.addAll(checkRuleP2(entity.path, content));
        }
      }

      expect(violations, isEmpty,
          reason:
              'Rule P2: No class field with Function(...) type allowed in lib/models/');
    });

    test('Rule P3: no Object?/Object/dynamic context variable or parameter in lib/', () {
      final violations = <String>[];
      final libDir = Directory('lib');
      for (final entity in libDir.listSync(recursive: true)) {
        if (entity is File && entity.path.endsWith('.dart')) {
          final content = entity.readAsStringSync();
          violations.addAll(checkRuleP3(entity.path, content));
        }
      }

      expect(violations, isEmpty,
          reason:
              'Rule P3: No Object?/Object/dynamic context variables or parameters allowed in lib/');
    });
  });
}
