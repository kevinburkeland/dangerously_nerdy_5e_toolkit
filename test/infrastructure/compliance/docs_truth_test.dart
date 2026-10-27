import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

import '../../../tool/codebase_map_generator.dart';

/// Allowlist of at most 15 Dart and Flutter SDK types only.
const kSdkTypeAllowlist = <String>{
  'UnsupportedError', // dart:core
  'TextScaler', // package:flutter
  'Map', // dart:core
  'String', // dart:core
};

String _normalizeRelPath(String repoRoot, String fullPath) {
  var p = fullPath.replaceAll('\\', '/');
  if (p.startsWith('./')) p = p.substring(2);
  final rootPrefix = repoRoot.replaceAll('\\', '/');
  if (rootPrefix != '.' && rootPrefix.isNotEmpty && p.startsWith('$rootPrefix/')) {
    p = p.substring(rootPrefix.length + 1);
  }
  if (p.startsWith('./')) p = p.substring(2);
  while (p.endsWith('/')) {
    p = p.substring(0, p.length - 1);
  }
  return p;
}

List<String> requiredArchitectureFolders(String repoRoot) {
  final libDir = Directory('$repoRoot/lib');
  if (!libDir.existsSync()) return [];

  final folders = <String>{};

  // Directly under lib/
  for (final entity in libDir.listSync(followLinks: false)) {
    if (entity is Directory) {
      folders.add(_normalizeRelPath(repoRoot, entity.path));
    }
  }

  // One or two levels below lib/application, lib/domain, lib/infrastructure, lib/presentation
  final layered = [
    '$repoRoot/lib/application',
    '$repoRoot/lib/domain',
    '$repoRoot/lib/infrastructure',
    '$repoRoot/lib/presentation',
  ];

  for (final base in layered) {
    final baseDir = Directory(base);
    if (!baseDir.existsSync()) continue;
    for (final child in baseDir.listSync(followLinks: false)) {
      if (child is Directory) {
        folders.add(_normalizeRelPath(repoRoot, child.path));
        for (final grandchild in child.listSync(followLinks: false)) {
          if (grandchild is Directory) {
            folders.add(_normalizeRelPath(repoRoot, grandchild.path));
          }
        }
      }
    }
  }

  final list = folders.toList()..sort();
  return list;
}

List<String> missingFolderNames(String doc, List<String> folders) {
  final missing = <String>[];
  for (final f in folders) {
    final hasWithoutSlash = doc.contains('`$f`');
    final hasWithSlash = doc.contains('`$f/`');
    if (!hasWithoutSlash && !hasWithSlash) {
      missing.add(f);
    }
  }
  return missing;
}

List<String> missingPathProblems(String doc, String repoRoot) {
  final problems = <String>[];
  final pattern = RegExp(
    r'(?<![a-zA-Z0-9_./-])(?:lib|test|docs|scripts|tool|web|\.agents|\.github)/[a-zA-Z0-9_./\-*]*',
  );

  for (final m in pattern.allMatches(doc)) {
    var token = m.group(0)!;
    while (token.endsWith('.') || token.endsWith('/')) {
      token = token.substring(0, token.length - 1);
    }
    if (token.isEmpty) continue;

    if (token.contains('*')) {
      final parts = token.split('/');
      final dirPart = parts.sublist(0, parts.length - 1).join('/');
      final filePattern = parts.last;
      final targetDir = Directory('$repoRoot/$dirPart');
      bool matched = false;
      if (targetDir.existsSync()) {
        final regexStr = '^${RegExp.escape(filePattern).replaceAll(r'\*', '.*')}\$';
        final fileRegex = RegExp(regexStr);
        for (final entity in targetDir.listSync(followLinks: false)) {
          final segs = entity.uri.pathSegments;
          final name = segs.isNotEmpty
              ? segs[segs.length - (entity is Directory ? 2 : 1)]
              : '';
          if (fileRegex.hasMatch(name)) {
            matched = true;
            break;
          }
        }
      }
      if (!matched) {
        problems.add('Glob does not match any file: $token');
      }
    } else {
      final fullPath = '$repoRoot/$token';
      if (!File(fullPath).existsSync() && !Directory(fullPath).existsSync()) {
        problems.add('Path does not exist: $token');
      }
    }
  }

  return problems;
}

List<String> unknownClassNames(String doc, Set<String> declared, Set<String> allowlist) {
  final problems = <String>[];
  final tokenPattern = RegExp(r'`([^`\n]+)`');
  final fileExtensions = {'.md', '.dart', '.yaml', '.yml', '.json', '.sh', '.html', '.txt'};
  final capIdentPattern = RegExp(r'^[A-Z][A-Za-z0-9_]*$');

  for (final m in tokenPattern.allMatches(doc)) {
    final raw = m.group(1)!.trim();
    if (fileExtensions.any((ext) => raw.endsWith(ext))) {
      continue;
    }
    final parts = raw.split(RegExp(r'[^a-zA-Z0-9_]+'));
    for (final ident in parts) {
      if (capIdentPattern.hasMatch(ident)) {
        if (!declared.contains(ident) && !allowlist.contains(ident)) {
          problems.add('Unknown class name: `$raw` (identifier: $ident)');
        }
      }
    }
  }
  return problems;
}

List<String> checkDocFiles(List<String> targetFiles, Set<String> declared, Set<String> allowlist) {
  final allProblems = <String>[];
  for (final filePath in targetFiles) {
    final file = File(filePath);
    if (!file.existsSync()) {
      allProblems.add('Missing target file: $filePath');
      continue;
    }
    final content = file.readAsStringSync();
    final problems = unknownClassNames(content, declared, allowlist);
    if (problems.isNotEmpty) {
      allProblems.add('$filePath:\n  ${problems.join('\n  ')}');
    }
  }
  return allProblems;
}

List<Directory> resolveScannedLibDirectories(String repoRoot) {
  final configFile = File('$repoRoot/.dart_tool/package_config.json');
  if (!configFile.existsSync()) {
    throw StateError('.dart_tool/package_config.json not found in $repoRoot');
  }
  final jsonMap = jsonDecode(configFile.readAsStringSync()) as Map<String, dynamic>;
  final packages = jsonMap['packages'] as List<dynamic>? ?? [];

  Directory? coreLib;
  Directory? rulesetLib;

  for (final pkg in packages) {
    if (pkg is Map<String, dynamic>) {
      final name = pkg['name'];
      if (name == 'vtt_engine_core' || name == 'vtt_ruleset_dnd5e') {
        final rootUriStr = pkg['rootUri'] as String;
        final packageUriStr = (pkg['packageUri'] as String?) ?? 'lib/';
        final configUri = configFile.uri;
        final rootUri = configUri.resolve(rootUriStr);
        final libUri = rootUri.resolve(packageUriStr);
        final dir = Directory(libUri.toFilePath());
        if (name == 'vtt_engine_core') {
          coreLib = dir;
        } else {
          rulesetLib = dir;
        }
      }
    }
  }

  if (coreLib == null || !coreLib.existsSync()) {
    throw StateError('Could not find package vtt_engine_core via .dart_tool/package_config.json');
  }
  if (rulesetLib == null || !rulesetLib.existsSync()) {
    throw StateError('Could not find package vtt_ruleset_dnd5e via .dart_tool/package_config.json');
  }

  return [
    Directory('$repoRoot/lib'),
    coreLib,
    rulesetLib,
  ];
}

List<String> findMarkdownAndRulesFiles(String repoRoot) {
  final rootDir = Directory(repoRoot);
  final skipNames = {'.git', '.dart_tool', 'build', 'ephemeral', 'node_modules'};
  final results = <String>[];

  void walk(Directory dir) {
    for (final entity in dir.listSync(followLinks: false)) {
      final p = entity.path.replaceAll('\\', '/');
      final segs = p.split('/');
      if (segs.any((s) => skipNames.contains(s))) continue;
      if (p.contains('test/fixtures')) continue;
      if (entity is Directory) {
        walk(entity);
      } else if (entity is File) {
        var rel = p.startsWith('./') ? p.substring(2) : p;
        if (repoRoot != '.' && repoRoot.isNotEmpty && rel.startsWith('$repoRoot/')) {
          rel = rel.substring(repoRoot.length + 1);
        }
        if (rel.startsWith('./')) rel = rel.substring(2);
        if (rel.endsWith('.md') || rel.endsWith('.antigravityrules')) {
          results.add(rel);
        }
      }
    }
  }

  walk(rootDir);
  results.sort();
  return results;
}

void main() {
  group('Documentation Truth & Coverage Invariants', () {
    test('DT1c (control): required architecture folder calculation behaves as specified', () {
      final folders = requiredArchitectureFolders('.');
      expect(folders.length, greaterThanOrEqualTo(50),
          reason: 'Expected at least 50 required architecture folders');
      expect(folders, contains('lib/application/blob'));
      expect(folders, contains('lib/application/map'));
      expect(folders, contains('lib/infrastructure/map/web'));
      expect(folders, contains('lib/presentation/widgets/map'));
      expect(folders, contains('lib/models'));
      expect(folders, isNot(contains('lib/infrastructure/modules/dnd5e/ingestion')),
          reason: 'Must not contain 3-levels deep folder');

      // Sample doc naming all but one folder gives exactly that one folder
      final sampleDoc = folders.skip(1).map((f) => '`$f`').join('\n');
      final missing = missingFolderNames(sampleDoc, folders);
      expect(missing, equals([folders.first]));
    });

    test('DT1: ARCHITECTURE.md names every required architecture folder', () {
      final archDoc = File('docs/ARCHITECTURE.md').readAsStringSync();
      final required = requiredArchitectureFolders('.');
      final missing = missingFolderNames(archDoc, required);
      expect(missing, isEmpty,
          reason: 'ARCHITECTURE.md is missing required folders:\n${missing.join('\n')}');
    });

    test('DT2c (control): path extraction and existence checking', () {
      expect(missingPathProblems('`lib/main.dart`', '.'), isEmpty);
      expect(missingPathProblems('`lib/no_such.dart`', '.'), hasLength(1));
      expect(missingPathProblems('`lib/screens/*_codex_screen.dart`', '.'), isEmpty);
      expect(missingPathProblems('`lib/screens/*_no_such.dart`', '.'), hasLength(1));
      expect(missingPathProblems('vtt-engine-core/test/compliance/', '.'), isEmpty);
      expect(missingPathProblems('https://github.com/x/blob/main/lib/no_such.dart', '.'), isEmpty);
      expect(missingPathProblems('`lib/main.dart`.', '.'), isEmpty);
    });

    test('DT2: all repo paths mentioned across docs exist', () {
      final files = findMarkdownAndRulesFiles('.')
          .where((f) => !f.endsWith('CHANGELOG.md'))
          .toList();

      final allProblems = <String>[];
      for (final filePath in files) {
        final content = File(filePath).readAsStringSync();
        final problems = missingPathProblems(content, '.');
        if (problems.isNotEmpty) {
          allProblems.add('$filePath problems:\n  ${problems.join('\n  ')}');
        }
      }

      expect(allProblems, isEmpty,
          reason: 'Found missing path references in docs:\n${allProblems.join('\n')}');
    });

    test('DT3c (control): declared types scanning and class validation', () {
      expect(kSdkTypeAllowlist.length, lessThanOrEqualTo(15));

      final libs = resolveScannedLibDirectories('.');
      final declared = declaredTypeNames(libs);

      // Print size of declared set as required by prompt
      // ignore: avoid_print
      print('DT3c declared type names set size: ${declared.length}');

      // Assert allowlist does not shadow any real declared class
      final collision = kSdkTypeAllowlist.intersection(declared);
      expect(collision, isEmpty,
          reason: 'Allowlist names should not collide with declared classes: $collision');

      expect(unknownClassNames('`ZzNoSuchClass`', declared, kSdkTypeAllowlist), hasLength(1));
      expect(unknownClassNames('`AGENTS.md`', declared, kSdkTypeAllowlist), isEmpty);
      expect(unknownClassNames('`CampaignProfile`', declared, kSdkTypeAllowlist), isEmpty);
      expect(unknownClassNames('`CampaignProfile.join`', declared, kSdkTypeAllowlist), isEmpty);
      expect(unknownClassNames('`Dnd5eCombatResolver`', declared, kSdkTypeAllowlist), isEmpty);
      expect(unknownClassNames('`MapView`', declared, kSdkTypeAllowlist), isEmpty);
    });

    test('DT3: navigation docs contain no unknown class names', () {
      final libs = resolveScannedLibDirectories('.');
      final declared = declaredTypeNames(libs);

      final targetFiles = <String>[
        'docs/ARCHITECTURE.md',
        '.agents/rules/codebase_map.md',
        '.agents/rules/architecture.md',
        'AGENTS.md',
        'GEMINI.md',
      ];

      final decisionsDir = Directory('docs/decisions');
      if (decisionsDir.existsSync()) {
        for (final f in decisionsDir.listSync().whereType<File>()) {
          if (f.path.endsWith('.md')) {
            targetFiles.add(f.path.replaceAll('\\', '/'));
          }
        }
      }

      final allProblems = checkDocFiles(targetFiles, declared, kSdkTypeAllowlist);

      expect(allProblems, isEmpty,
          reason: 'Found unknown class names in navigation docs:\n${allProblems.join('\n')}');
    });

    test('DT3d (control): calling the DT3 check with a target list that includes docs/no_such_file.md gives exactly one problem naming it', () {
      final libs = resolveScannedLibDirectories('.');
      final declared = declaredTypeNames(libs);
      final problems = checkDocFiles(['docs/no_such_file.md'], declared, kSdkTypeAllowlist);
      expect(problems, hasLength(1));
      expect(problems.first, contains('docs/no_such_file.md'));
    });

    test('DT3e (control): generic types and multi-token backticked spans validation', () {
      final libs = resolveScannedLibDirectories('.');
      final declared = declaredTypeNames(libs);

      final p1 = unknownClassNames('`CrdtLwwRegister<ZzFake?>`', declared, kSdkTypeAllowlist);
      expect(p1, hasLength(1));
      expect(p1.first, contains('ZzFake'));

      final p2 = unknownClassNames('`CrdtLwwRegister<BlobRef?>`', declared, kSdkTypeAllowlist);
      expect(p2, isEmpty);

      final p3 = unknownClassNames('`Map<String, ZzOther>`', declared, kSdkTypeAllowlist);
      expect(p3, hasLength(1));
      expect(p3.first, contains('ZzOther'));
    });

    test('DT4c (control): renderFolderIndex generates deterministic table', () {
      final tempDir = Directory.systemTemp.createTempSync('dt4c_control_');
      try {
        final libDir = Directory('${tempDir.path}/lib')..createSync(recursive: true);
        final aDir = Directory('${libDir.path}/a')..createSync(recursive: true);
        final bDir = Directory('${aDir.path}/b')..createSync(recursive: true);

        File('${aDir.path}/x.dart').writeAsStringSync('''
abstract interface class Alpha {}
sealed class Beta {}
final class Gamma {}
enum Delta { one }
typedef Eps = int;
extension type Zeta(int v) {}
mixin Eta {}
class _Hidden {}
// class NotReal {}
''');

        File('${bDir.path}/y.dart').writeAsStringSync('''
class Theta {}
''');

        const expected =
            '| Folder | Files | Declared Types |\n'
            '|---|---|---|\n'
            '| `lib` | 0 | |\n'
            '| `lib/a` | 1 | Alpha, Beta, Delta, Eps, Eta, Gamma, Zeta |\n'
            '| `lib/a/b` | 1 | Theta |\n';

        final actual = renderFolderIndex(tempDir.path);
        expect(actual, equals(expected));

        // 10 classes in one file
        File('${bDir.path}/y.dart').writeAsStringSync('''
class C01 {}
class C02 {}
class C03 {}
class C04 {}
class C05 {}
class C06 {}
class C07 {}
class C08 {}
class C09 {}
class C10 {}
''');

        final actual10 = renderFolderIndex(tempDir.path);
        expect(actual10, contains('| `lib/a/b` | 1 | C01, C02, C03, C04, C05, C06, C07, C08, +2 more |'));
      } finally {
        tempDir.deleteSync(recursive: true);
      }
    });

    test('DT4d (marker control): updateCodebaseMapContent marker validation', () {
      expect(
        () => updateCodebaseMapContent('no markers here', 'index'),
        throwsA(isA<StateError>()),
      );
      expect(
        () => updateCodebaseMapContent('$startMarker\nno end marker', 'index'),
        throwsA(isA<StateError>()),
      );

      const original = 'Header\n$startMarker\nold index\n$endMarker\nFooter';
      final updated = updateCodebaseMapContent(original, 'new index\n');
      expect(updated, equals('Header\n$startMarker\nnew index\n$endMarker\nFooter'));
    });

    test('DT4: .agents/rules/codebase_map.md generated folder index is fresh', () {
      final file = File('.agents/rules/codebase_map.md');
      expect(file.existsSync(), isTrue);
      final content = file.readAsStringSync();

      final startIdx = content.indexOf(startMarker);
      final endIdx = content.indexOf(endMarker);
      expect(startIdx, isNot(-1), reason: 'Missing start marker in codebase_map.md');
      expect(endIdx, isNot(-1), reason: 'Missing end marker in codebase_map.md');

      final currentSlice = content.substring(startIdx + startMarker.length, endIdx).trim();
      final freshIndex = renderFolderIndex('.').trim();

      expect(currentSlice, equals(freshIndex),
          reason: 'codebase_map.md folder index is stale. Run `dart run tool/generate_codebase_map.dart` to refresh.');
    });

    test('DT5: Architecture Decision Records (ADRs) shape and index validation', () {
      final decisionsDir = Directory('docs/decisions');
      expect(decisionsDir.existsSync(), isTrue);

      final entities = decisionsDir.listSync(followLinks: false);
      final readme = File('docs/decisions/README.md');
      expect(readme.existsSync(), isTrue, reason: 'docs/decisions/README.md must exist');
      final readmeContent = readme.readAsStringSync();

      final adrFiles = entities
          .whereType<File>()
          .where((f) => !f.path.endsWith('README.md') && f.path.endsWith('.md'))
          .toList();

      adrFiles.sort((a, b) => a.path.compareTo(b.path));

      final adrPattern = RegExp(r'^(\d{4})-[a-z0-9-]+\.md$');
      final linkedFiles = <String>{};

      for (var i = 0; i < adrFiles.length; i++) {
        final file = adrFiles[i];
        final filename = file.uri.pathSegments.last;
        final match = adrPattern.firstMatch(filename);
        expect(match, isNotNull,
            reason: '$filename does not match NNNN-lowercase-words.md');

        final expectedNum = (i + 1).toString().padLeft(4, '0');
        final actualNum = match!.group(1);
        expect(actualNum, equals(expectedNum),
            reason: 'ADR numbers must run sequentially without gaps from 0001');

        final lines = file.readAsLinesSync();
        expect(lines, isNotEmpty);
        final firstLine = lines.first;
        expect(firstLine, startsWith('# $actualNum. '),
            reason: '$filename first line must start with "# $actualNum. "');

        final content = file.readAsStringSync();
        expect(content, contains('## Context'),
            reason: '$filename must contain "## Context"');
        expect(content, contains('## Decision'),
            reason: '$filename must contain "## Decision"');
        expect(content, contains('## Rejected Options'),
            reason: '$filename must contain "## Rejected Options"');

        linkedFiles.add(filename);
      }

      // README.md links every ADR file and nothing else in the folder
      for (final filename in linkedFiles) {
        expect(readmeContent, contains(filename),
            reason: 'docs/decisions/README.md must link $filename');
      }

      final readmeLinks = RegExp(r'\[.*?\]\((.*?)\)').allMatches(readmeContent);
      for (final m in readmeLinks) {
        final target = m.group(1)!;
        if (!target.startsWith('http') && !target.startsWith('#')) {
          expect(linkedFiles, contains(target),
              reason: 'docs/decisions/README.md links unexpected target: $target');
        }
      }
    });

    test('DT6: Pure Dart folders line in ARCHITECTURE.md contains lib/domain/, lib/application/ and lib/infrastructure/dtos/', () {
      final archDoc = File('docs/ARCHITECTURE.md').readAsStringSync();
      final match = RegExp(
        r'^Pure Dart folders \(checked by test/domain/domain_purity_test\.dart\):\s*(.+)$',
        multiLine: true,
      ).firstMatch(archDoc);

      expect(match, isNotNull,
          reason: 'ARCHITECTURE.md must contain "Pure Dart folders (checked by test/domain/domain_purity_test.dart): ..."');

      final folders = match!.group(1)!.split(RegExp(r'[\s,]+')).where((s) => s.isNotEmpty).toList();
      expect(folders, contains('lib/domain/'));
      expect(folders, contains('lib/application/'));
      expect(folders, contains('lib/infrastructure/dtos/'));
    });
  });
}
