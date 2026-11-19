import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

String _stripCommentsAndStrings(String source) {
  final out = StringBuffer();
  final len = source.length;
  var i = 0;

  while (i < len) {
    final c = source[i];
    final next = i + 1 < len ? source[i + 1] : '';

    if (c == '/' && next == '/') {
      while (i < len && source[i] != '\n') {
        i++;
      }
      continue;
    }

    if (c == '/' && next == '*') {
      var depth = 1;
      i += 2;
      while (i < len && depth > 0) {
        if (source[i] == '/' && i + 1 < len && source[i + 1] == '*') {
          depth++;
          i += 2;
        } else if (source[i] == '*' && i + 1 < len && source[i + 1] == '/') {
          depth--;
          i += 2;
        } else {
          if (source[i] == '\n') out.write('\n');
          i++;
        }
      }
      continue;
    }

    if (c == 'r' && (next == "'" || next == '"')) {
      final quote = next;
      final isTriple = i + 3 < len &&
          source[i + 2] == quote &&
          source[i + 3] == quote;
      i += isTriple ? 4 : 2;
      while (i < len) {
        if (isTriple) {
          if (i + 2 < len &&
              source[i] == quote &&
              source[i + 1] == quote &&
              source[i + 2] == quote) {
            i += 3;
            break;
          }
        } else if (source[i] == quote) {
          i++;
          break;
        }
        if (source[i] == '\n') out.write('\n');
        i++;
      }
      out.write(' ');
      continue;
    }

    if (c == "'" || c == '"') {
      final quote = c;
      final isTriple = i + 2 < len &&
          source[i + 1] == quote &&
          source[i + 2] == quote;
      i += isTriple ? 3 : 1;
      while (i < len) {
        if (source[i] == r'\') {
          i += 2;
          continue;
        }
        if (isTriple) {
          if (i + 2 < len &&
              source[i] == quote &&
              source[i + 1] == quote &&
              source[i + 2] == quote) {
            i += 3;
            break;
          }
        } else if (source[i] == quote) {
          i++;
          break;
        }
        if (source[i] == '\n') out.write('\n');
        i++;
      }
      out.write(' ');
      continue;
    }

    out.write(c);
    i++;
  }

  return out.toString();
}

Set<String> extractTopLevelDeclaredTypeNames(String source) {
  final cleaned = _stripCommentsAndStrings(source);
  final names = <String>{};

  final topLevel = StringBuffer();
  var depth = 0;
  for (var i = 0; i < cleaned.length; i++) {
    final ch = cleaned[i];
    if (ch == '{') {
      if (depth == 0) topLevel.write(' ');
      depth++;
    } else if (ch == '}') {
      if (depth > 0) depth--;
    } else if (depth == 0) {
      topLevel.write(ch);
    }
  }

  final declRegex = RegExp(
    r'(?:^|[\n;])\s*'
    r'(?:(?:abstract|base|interface|final|sealed|mixin)\s+)*'
    r'(?:(class|mixin|enum|typedef)\s+([A-Za-z_][A-Za-z0-9_]*)'
    r'|extension\s+type\s+(?:const\s+)?([A-Za-z_][A-Za-z0-9_]*)'
    r'|extension\s+([A-Za-z_][A-Za-z0-9_]*)\s*(?:<[^>]*>)?\s+on\b)',
  );

  for (final m in declRegex.allMatches(topLevel.toString())) {
    final name = m.group(2) ?? m.group(3) ?? m.group(4);
    if (name == null || name.startsWith('_')) continue;
    names.add(name);
  }

  return names;
}

Map<String, String> _collectPackageTypes(Directory libDir) {
  final map = <String, String>{};
  final files = libDir
      .listSync(recursive: true)
      .whereType<File>()
      .where((f) => f.path.endsWith('.dart'))
      .toList()
    ..sort((a, b) => a.path.compareTo(b.path));

  final rootNorm = libDir.path.replaceAll('\\', '/');
  for (final file in files) {
    final rel = file.path
        .replaceAll('\\', '/')
        .substring(rootNorm.length)
        .replaceFirst(RegExp(r'^/+'), 'lib/');
    for (final name in extractTopLevelDeclaredTypeNames(file.readAsStringSync())) {
      map.putIfAbsent(name, () => rel);
    }
  }
  return map;
}

Directory _resolvePackageLibDir(String packageName) {
  final configFile = File('.dart_tool/package_config.json');
  if (!configFile.existsSync()) {
    throw StateError(
      'Fail-closed: .dart_tool/package_config.json not found; cannot locate $packageName.',
    );
  }
  final decoded = jsonDecode(configFile.readAsStringSync());
  if (decoded is! Map<String, dynamic> || decoded['packages'] is! List) {
    throw StateError('Fail-closed: malformed .dart_tool/package_config.json.');
  }
  final configDir = configFile.parent.uri;
  for (final entry in decoded['packages'] as List<dynamic>) {
    if (entry is Map<String, dynamic> && entry['name'] == packageName) {
      final rootUriStr = entry['rootUri'] as String?;
      final pkgUriStr = (entry['packageUri'] as String?) ?? 'lib/';
      if (rootUriStr == null) break;
      final rootUri = configDir.resolve(rootUriStr.endsWith('/') ? rootUriStr : '$rootUriStr/');
      final dir = Directory.fromUri(rootUri.resolve(pkgUriStr));
      if (!dir.existsSync()) {
        throw StateError('Fail-closed: resolved $packageName lib dir missing: ${dir.path}');
      }
      return dir;
    }
  }
  throw StateError('Fail-closed: package $packageName not found in package_config.json.');
}

List<String> findThreePackageCollisions({
  required Map<String, String> coreTypes,
  required Map<String, String> rulesetTypes,
  required Map<String, String> appTypes,
}) {
  final violations = <String>[];
  final pairs = [
    ('core', coreTypes, 'ruleset', rulesetTypes),
    ('core', coreTypes, 'app', appTypes),
    ('ruleset', rulesetTypes, 'app', appTypes),
  ];
  for (final (aName, aMap, bName, bMap) in pairs) {
    final shared = aMap.keys.toSet().intersection(bMap.keys.toSet()).toList()
      ..sort();
    for (final name in shared) {
      violations.add(
        '$name: declared in $aName ${aMap[name]} and $bName ${bMap[name]}',
      );
    }
  }
  return violations;
}

void main() {
  group('Fix 7.1: One name, one type across core, ruleset, and app', () {
    test('Controls: flags duplicate class/typedef/enum, ignores private and comments/strings', () {
      expect(
        findThreePackageCollisions(
          coreTypes: {for (final n in extractTopLevelDeclaredTypeNames('class ZzSame {}')) n: 'lib/a.dart'},
          rulesetTypes: {for (final n in extractTopLevelDeclaredTypeNames('class ZzSame {}')) n: 'lib/b.dart'},
          appTypes: const {},
        ),
        ['ZzSame: declared in core lib/a.dart and ruleset lib/b.dart'],
      );

      expect(
        findThreePackageCollisions(
          coreTypes: const {},
          rulesetTypes: {for (final n in extractTopLevelDeclaredTypeNames('typedef ZzSame = int;')) n: 'lib/b.dart'},
          appTypes: {for (final n in extractTopLevelDeclaredTypeNames('enum ZzSame { a }')) n: 'lib/c.dart'},
        ),
        ['ZzSame: declared in ruleset lib/b.dart and app lib/c.dart'],
      );

      expect(
        findThreePackageCollisions(
          coreTypes: {for (final n in extractTopLevelDeclaredTypeNames('class _ZzPrivate {}')) n: 'lib/a.dart'},
          rulesetTypes: {for (final n in extractTopLevelDeclaredTypeNames('class _ZzPrivate {}')) n: 'lib/b.dart'},
          appTypes: {for (final n in extractTopLevelDeclaredTypeNames('class _ZzPrivate {}')) n: 'lib/c.dart'},
        ),
        isEmpty,
      );

      expect(
        extractTopLevelDeclaredTypeNames(
          '// class ZzGhost {}\n/* enum ZzGhost2 { a } */\nconst s = "class ZzGhost3 {}";\n',
        ),
        isEmpty,
      );
    });

    test('No public top-level type name is declared in two of core, ruleset, and app', () {
      final coreTypes = _collectPackageTypes(_resolvePackageLibDir('vtt_engine_core'));
      final rulesetTypes = _collectPackageTypes(_resolvePackageLibDir('vtt_ruleset_dnd5e'));
      final appTypes = _collectPackageTypes(Directory('lib'));
      expect(coreTypes, isNotEmpty);
      expect(rulesetTypes, isNotEmpty);
      expect(appTypes, isNotEmpty);

      final violations = findThreePackageCollisions(
        coreTypes: coreTypes,
        rulesetTypes: rulesetTypes,
        appTypes: appTypes,
      );
      expect(
        violations,
        isEmpty,
        reason: 'Shared top-level type names across packages:\n${violations.join('\n')}',
      );
    });
  });
}
