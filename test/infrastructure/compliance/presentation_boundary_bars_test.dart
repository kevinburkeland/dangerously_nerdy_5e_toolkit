import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import '../../support/dart_directive_reader.dart';

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

final _modernFuncTypedefRegex = RegExp(
  r'\btypedef\s+([A-Za-z0-9_]+)\s*(?:<[^>]*>)?\s*=\s*([^;]*\bFunction\b[^;]*);',
);
final _oldFuncTypedefRegex = RegExp(
  r'\btypedef\s+(?:(?:void|[A-Za-z0-9_<>?]+)\s+)?([A-Za-z0-9_]+)\s*\([^;]*\)\s*;',
);

/// Extracts top-level and class-member statements terminated by `;` (at brace
/// depth 0 or 1), collapsing internal newlines/whitespace to single spaces and
/// recording the 1-based line where each statement starts.
List<({int startLine, String text})> _extractTopAndMemberStatements(
  String stripped,
) {
  final statements = <({int startLine, String text})>[];
  var depth = 0;
  var line = 1;
  var stmtStartLine = -1;
  final buf = StringBuffer();

  void flushStmt() {
    final normalized = buf.toString().replaceAll(RegExp(r'\s+'), ' ').trim();
    if (normalized.isNotEmpty && stmtStartLine > 0) {
      statements.add((startLine: stmtStartLine, text: normalized));
    }
    buf.clear();
    stmtStartLine = -1;
  }

  for (var i = 0; i < stripped.length; i++) {
    final c = stripped[i];
    if (c == '\n') {
      if (stmtStartLine > 0 && depth <= 1) {
        buf.write(' ');
      }
      line++;
      continue;
    }

    if (c == '{') {
      if (depth == 0) {
        // Opening a class/mixin/extension/function body: discard header
        buf.clear();
        stmtStartLine = -1;
      } else if (depth == 1) {
        // Opening a method/getter body inside a class: discard header
        buf.clear();
        stmtStartLine = -1;
      }
      depth++;
      continue;
    }

    if (c == '}') {
      if (depth > 0) depth--;
      if (depth <= 1) {
        buf.clear();
        stmtStartLine = -1;
      }
      continue;
    }

    if (depth > 1) continue;

    if (c == ';') {
      if (stmtStartLine > 0) {
        buf.write(';');
        flushStmt();
      }
      continue;
    }

    if (stmtStartLine == -1) {
      if (c.trim().isEmpty) continue;
      stmtStartLine = line;
    }
    buf.write(c);
  }

  return statements;
}

Set<String> collectFunctionTypedefs(String source) {
  final stripped = stripCommentsAndStringsPreservingNewlines(source);
  final stmts = _extractTopAndMemberStatements(stripped);
  final names = <String>{};
  for (final stmt in stmts) {
    final t = stmt.text;
    if (!t.startsWith('typedef ')) continue;
    final m1 = _modernFuncTypedefRegex.firstMatch(t);
    if (m1 != null) {
      names.add(m1.group(1)!);
      continue;
    }
    final m2 = _oldFuncTypedefRegex.firstMatch(t);
    if (m2 != null) {
      names.add(m2.group(1)!);
    }
  }
  return names;
}

Set<String> collectAllProjectFunctionTypedefs() {
  final names = <String>{};
  void scanDir(Directory dir) {
    if (!dir.existsSync()) {
      throw StateError('Required Dart library directory missing: ${dir.path}');
    }
    for (final entity in dir.listSync(recursive: true)) {
      if (entity is File && entity.path.endsWith('.dart')) {
        names.addAll(collectFunctionTypedefs(entity.readAsStringSync()));
      }
    }
  }

  // 1. App lib/
  scanDir(Directory('lib'));

  // 2. External packages vtt_engine_core and vtt_ruleset_dnd5e via package_config.json
  final pkgConfigFile = File('.dart_tool/package_config.json');
  if (!pkgConfigFile.existsSync()) {
    throw StateError('Missing .dart_tool/package_config.json (fail-closed)');
  }
  final decoded = jsonDecode(pkgConfigFile.readAsStringSync());
  if (decoded is! Map<String, dynamic> || decoded['packages'] is! List) {
    throw StateError('Malformed .dart_tool/package_config.json');
  }
  final pkgConfigDir = pkgConfigFile.parent.absolute.uri;
  final packages = (decoded['packages'] as List).cast<Map<String, dynamic>>();

  for (final reqPkg in const ['vtt_engine_core', 'vtt_ruleset_dnd5e']) {
    final entry = packages.cast<Map<String, dynamic>?>().firstWhere(
          (p) => p?['name'] == reqPkg,
          orElse: () => null,
        );
    if (entry == null) {
      throw StateError('Package $reqPkg not found in package_config.json');
    }
    final rootUriStr = entry['rootUri'] as String?;
    final pkgUriStr = (entry['packageUri'] as String?) ?? 'lib/';
    if (rootUriStr == null) {
      throw StateError('Package $reqPkg missing rootUri in package_config.json');
    }
    final rootUri = pkgConfigDir.resolve(rootUriStr);
    final libUri = rootUri.resolve(pkgUriStr);
    scanDir(Directory.fromUri(libUri));
  }

  return names;
}

List<String> checkRuleP2(
  String filePath,
  String source, {
  Set<String> extraTypedefs = const {},
}) {
  final stripped = stripCommentsAndStringsPreservingNewlines(source);
  final stmts = _extractTopAndMemberStatements(stripped);
  final violations = <String>[];

  final typedefNames = <String>{
    ...extraTypedefs,
    ...collectFunctionTypedefs(source),
  };

  // Direct Function field (including nested in generics such as List<void Function()>)
  final directFunctionFieldRegex = RegExp(
    r'\bFunction\b',
  );

  // Match any typedef name appearing as a type identifier in a field declaration
  final typedefWordRegexes = typedefNames
      .map((name) => RegExp('\\b${RegExp.escape(name)}\\b'))
      .toList();

  for (final stmt in stmts) {
    final t = stmt.text;

    if (t.startsWith('typedef ')) {
      final modernMatch = _modernFuncTypedefRegex.firstMatch(t);
      if (modernMatch != null) {
        violations.add(
            '$filePath:${stmt.startLine}: function typedef in models (${modernMatch.group(1)})');
        continue;
      }
      final oldMatch = _oldFuncTypedefRegex.firstMatch(t);
      if (oldMatch != null) {
        violations.add(
            '$filePath:${stmt.startLine}: function typedef in models (${oldMatch.group(1)})');
        continue;
      }
      continue;
    }

    // Ignore non-field directives/constructors/methods/getters/returns
    if (t.startsWith('import ') ||
        t.startsWith('export ') ||
        t.startsWith('part ') ||
        t.startsWith('library ') ||
        t.startsWith('return ') ||
        t.startsWith('const ') && !t.contains('=')) {
      continue;
    }

    // Extract the declaration portion before any `=` or `=>`
    final eqIdx = t.indexOf('=');
    final declPart = eqIdx == -1 ? t : t.substring(0, eqIdx).trim();
    // Skip abstract methods / getters / setters with `=>` or method parameter lists
    // unless `Function(` is part of the type!
    final isGetterOrMethodWithoutFunc =
        declPart.contains(' get ') || declPart.contains(' set ');
    if (isGetterOrMethodWithoutFunc) continue;

    // Check if declPart is a field declaration with a Function type or typedef
    if (directFunctionFieldRegex.hasMatch(declPart)) {
      // Ensure it is a field (ends with an identifier before `;` or `=`), not a method
      if (!declPart.endsWith(')')) {
        violations.add('$filePath:${stmt.startLine}: $t');
        continue;
      }
    }

    var matchedTypedef = false;
    for (final tr in typedefWordRegexes) {
      if (tr.hasMatch(declPart) && !declPart.contains('(')) {
        matchedTypedef = true;
        break;
      }
    }
    if (matchedTypedef) {
      violations.add('$filePath:${stmt.startLine}: $t');
    }
  }
  return violations;
}

List<String> checkRuleP2AcrossFiles({
  required String targetPath,
  required String targetSource,
  Map<String, String> extraSources = const {},
}) {
  final allTypedefs = <String>{};
  for (final src in extraSources.values) {
    allTypedefs.addAll(collectFunctionTypedefs(src));
  }
  return checkRuleP2(targetPath, targetSource, extraTypedefs: allTypedefs);
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

    test('Rule P2 controls: flags class field with function type, typedef function type, and initializers', () {
      const bad = 'class Foo { final void Function(Object? c)? onTap; }';
      const badWithInit = 'class Foo { final void Function(Object? c)? onTap = null; }';
      const badTypedef = '''
typedef ActionCallback = void Function(Object? sheet);
class CharacterCombatAction {
  final ActionCallback? onExecute;
}
''';
      const badTypedefWithInit = '''
typedef ActionCallback = void Function(Object? sheet);
class CharacterCombatAction {
  final ActionCallback? onExecute = null;
}
''';
      const good = 'class Foo { void run(int Function(int sides) roller) {} }';

      expect(checkRuleP2('in_memory.dart', bad), hasLength(1));
      expect(checkRuleP2('in_memory.dart', badWithInit), hasLength(1));
      expect(checkRuleP2('in_memory.dart', badTypedef), hasLength(2));
      expect(checkRuleP2('in_memory.dart', badTypedefWithInit), hasLength(2));
      expect(checkRuleP2('in_memory.dart', good), isEmpty);

      // Fix 5.1 controls:
      const c1 = 'typedef ZzCb = void Function(Object? sheet);';
      final v1 = checkRuleP2('in_memory.dart', c1);
      expect(v1, hasLength(1));
      expect(v1.first, contains('function typedef in models (ZzCb)'));

      const c2 = 'typedef int ZzOld(int x);';
      final v2 = checkRuleP2('in_memory.dart', c2);
      expect(v2, hasLength(1));
      expect(v2.first, contains('function typedef in models (ZzOld)'));

      const c3 = 'typedef ZzMap = Map<String, int>;';
      expect(checkRuleP2('in_memory.dart', c3), isEmpty);

      const c4 = '''
class SummonPreset {
  static void Function(Object? sheet)? zzOnExecute;
}
''';
      final v4 = checkRuleP2('lib/models/srd_summons/summon_preset.dart', c4);
      expect(v4, hasLength(1));
      expect(v4.first, contains('zzOnExecute'));
    });

    test('Fix 4.2 Rule P2 controls: multi-line typedefs and cross-file typedef references', () {
      const multiLineTypedef = '''
typedef ZzMultiCb =
    void Function(Object? sheet);
''';
      expect(
        checkRuleP2('lib/models/zz_multi.dart', multiLineTypedef),
        hasLength(1),
        reason: 'Multi-line function typedef in models must be flagged',
      );

      const genericMultiLineTypedef = '''
typedef ZzGen<T> =
  T Function(T);
''';
      expect(
        checkRuleP2('lib/models/zz_gen.dart', genericMultiLineTypedef),
        hasLength(1),
        reason: 'Generic multi-line function typedef in models must be flagged',
      );

      const nonFuncMultiLineTypedef = '''
typedef ZzMap =
    Map<String, int>;
''';
      expect(
        checkRuleP2('lib/models/zz_map.dart', nonFuncMultiLineTypedef),
        isEmpty,
        reason: 'Non-function multi-line typedef must NOT be flagged',
      );

      const utilFile = 'typedef ZzUtilCb = void Function();\n';
      const modelWithUtilCb = '''
class ZzModel {
  final ZzUtilCb? cb;
}
''';
      const modelWithMapUtilCb = '''
class ZzModel2 {
  final Map<String, ZzUtilCb> zz;
}
''';
      final crossViolations1 = checkRuleP2AcrossFiles(
        targetPath: 'lib/models/zz_model.dart',
        targetSource: modelWithUtilCb,
        extraSources: {'lib/utils/zz_util.dart': utilFile},
      );
      expect(crossViolations1, hasLength(1),
          reason: 'Nullable field using cross-file function typedef must be flagged');

      final crossViolations2 = checkRuleP2AcrossFiles(
        targetPath: 'lib/models/zz_model2.dart',
        targetSource: modelWithMapUtilCb,
        extraSources: {'lib/utils/zz_util.dart': utilFile},
      );
      expect(crossViolations2, hasLength(1),
          reason: 'Map field mentioning cross-file function typedef must be flagged');
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
      final allTypedefs = collectAllProjectFunctionTypedefs();
      final violations = <String>[];
      final modelsDir = Directory('lib/models');

      for (final entity in modelsDir.listSync(recursive: true)) {
        if (entity is File && entity.path.endsWith('.dart')) {
          final normPath = entity.path.replaceAll(r'\', '/');
          final content = entity.readAsStringSync();
          final fileViolations = checkRuleP2(
            normPath,
            content,
            extraTypedefs: allTypedefs,
          );
          violations.addAll(fileViolations);
        }
      }

      expect(violations, isEmpty,
          reason:
              'Rule P2: No function typedef or class field with function type allowed in lib/models/:\n${violations.join('\n')}');
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
