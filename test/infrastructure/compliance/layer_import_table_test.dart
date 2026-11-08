import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

const String kAppPackagePrefix = 'package:dangerously_nerdy_5e_toolkit/';
const String kLayerTableStartMarker = '<!-- layer-table:start -->';
const String kLayerTableEndMarker = '<!-- layer-table:end -->';

const Set<String> kExemptTopLevelLibFiles = {
  'lib/main.dart',
  'lib/firebase_options.dart',
};

const List<String> kFlutterUriPrefixes = [
  'package:flutter/',
  'package:flutter_webrtc/',
  'package:hive_flutter/',
  'dart:ui',
];

class LayerRule {
  final Set<String> allowedAppFolders;
  final bool flutterAllowed;

  const LayerRule({
    required this.allowedAppFolders,
    required this.flutterAllowed,
  });
}

/// Canonical table rows as rendered in `docs/ARCHITECTURE.md` between
/// `<!-- layer-table:start -->` and `<!-- layer-table:end -->`.
const List<List<String>> kExpectedDocLayerTableRows = [
  ['Folder', 'May import these app folders', 'Flutter allowed?'],
  ['`domain`', '`domain`', 'no'],
  ['`utils`', '`domain`, `utils`', 'no'],
  ['`models`', '`domain`, `models`, `utils`', 'no'],
  ['`application`', '`domain`, `models`, `utils`, `application`', 'no'],
  [
    '`services`',
    '`domain`, `models`, `utils`, `application`, `services`, `infrastructure`',
    'yes',
  ],
  [
    '`infrastructure`',
    '`domain`, `models`, `utils`, `application`, `services`, `infrastructure`',
    'yes',
  ],
  ['`providers`', 'everything above, and `providers`', 'yes'],
  [
    '`presentation`, `screens`, `widgets`, `theme`',
    'everything above, and `presentation`, `screens`, `widgets`, `theme`',
    'yes',
  ],
];

const Map<String, LayerRule> kLayerRules = {
  'domain': LayerRule(
    allowedAppFolders: {'domain'},
    flutterAllowed: false,
  ),
  'utils': LayerRule(
    allowedAppFolders: {'domain', 'utils'},
    flutterAllowed: false,
  ),
  'models': LayerRule(
    allowedAppFolders: {'domain', 'models', 'utils'},
    flutterAllowed: false,
  ),
  'application': LayerRule(
    allowedAppFolders: {'domain', 'models', 'utils', 'application'},
    flutterAllowed: false,
  ),
  'services': LayerRule(
    allowedAppFolders: {
      'domain',
      'models',
      'utils',
      'application',
      'services',
      'infrastructure',
    },
    flutterAllowed: true,
  ),
  'infrastructure': LayerRule(
    allowedAppFolders: {
      'domain',
      'models',
      'utils',
      'application',
      'services',
      'infrastructure',
    },
    flutterAllowed: true,
  ),
  'providers': LayerRule(
    allowedAppFolders: {
      'domain',
      'models',
      'utils',
      'application',
      'services',
      'infrastructure',
      'providers',
    },
    flutterAllowed: true,
  ),
  'presentation': LayerRule(
    allowedAppFolders: {
      'domain',
      'models',
      'utils',
      'application',
      'services',
      'infrastructure',
      'providers',
      'presentation',
      'screens',
      'widgets',
      'theme',
    },
    flutterAllowed: true,
  ),
  'screens': LayerRule(
    allowedAppFolders: {
      'domain',
      'models',
      'utils',
      'application',
      'services',
      'infrastructure',
      'providers',
      'presentation',
      'screens',
      'widgets',
      'theme',
    },
    flutterAllowed: true,
  ),
  'widgets': LayerRule(
    allowedAppFolders: {
      'domain',
      'models',
      'utils',
      'application',
      'services',
      'infrastructure',
      'providers',
      'presentation',
      'screens',
      'widgets',
      'theme',
    },
    flutterAllowed: true,
  ),
  'theme': LayerRule(
    allowedAppFolders: {
      'domain',
      'models',
      'utils',
      'application',
      'services',
      'infrastructure',
      'providers',
      'presentation',
      'screens',
      'widgets',
      'theme',
    },
    flutterAllowed: true,
  ),
};

class AllowlistEntry {
  final Set<String> kinds;
  final String reason;

  const AllowlistEntry({
    required this.kinds,
    required this.reason,
  });
}

/// Allowlist from file path to the exact set of violation kinds it may have today,
/// each with a one-line reason.
const Map<String, AllowlistEntry> kLayerViolationAllowlist = {
  'lib/application/services/cascading_transport_router.dart': AllowlistEntry(
    kinds: {'application -> services'},
    reason: 'application uses old services (later locator/folder slice)',
  ),
  'lib/application/services/combat_encounter_service.dart': AllowlistEntry(
    kinds: {'application -> services'},
    reason: 'application uses old services (later locator/folder slice)',
  ),
  'lib/application/services/homebrew_import_orchestrator.dart': AllowlistEntry(
    kinds: {'application -> services'},
    reason: 'application uses old services (later locator/folder slice)',
  ),
  'lib/application/services/room_state_reconciliation_service.dart': AllowlistEntry(
    kinds: {'application -> infrastructure'},
    reason: 'compatibility re-export (folder-layout slice)',
  ),
  'lib/application/services/room_sync_orchestrator.dart': AllowlistEntry(
    kinds: {'application -> services'},
    reason: 'application uses old services (later locator/folder slice)',
  ),
  'lib/application/storage/storage_durability_coordinator.dart': AllowlistEntry(
    kinds: {'application -> services'},
    reason: 'application uses old services (later locator/folder slice)',
  ),
  'lib/models/animated_object.dart': AllowlistEntry(
    kinds: {'models -> infrastructure'},
    reason: 'compatibility re-export (folder-layout slice)',
  ),
  'lib/models/app_settings.dart': AllowlistEntry(
    kinds: {'flutter'},
    reason: 'UI data in models (Cleanup slice 10.1)',
  ),
  'lib/models/arena/arena_simulation_models.dart': AllowlistEntry(
    kinds: {'flutter'},
    reason: 'UI data in models (Cleanup slice 10.1)',
  ),
  'lib/models/arena/monster_combat_profile.dart': AllowlistEntry(
    kinds: {'models -> services'},
    reason: 'ACL stat block boundary parsing in factory constructor',
  ),
  'lib/models/campaign_profile.dart': AllowlistEntry(
    kinds: {'models -> infrastructure'},
    reason: 'compatibility re-export (folder-layout slice)',
  ),
  'lib/models/characters/srd_classes_library.dart': AllowlistEntry(
    kinds: {'models -> services'},
    reason: 'AST entry node transformation for subclass feature markdown',
  ),
  'lib/models/characters/srd_equipment_library.dart': AllowlistEntry(
    kinds: {'flutter'},
    reason: 'UI data in models (Cleanup slice 10.1)',
  ),
  'lib/models/dm_screen_data.dart': AllowlistEntry(
    kinds: {'models -> infrastructure'},
    reason: 'compatibility re-export (folder-layout slice)',
  ),
  'lib/models/glyph_gallery_data.dart': AllowlistEntry(
    kinds: {'flutter'},
    reason: 'UI data in models (Cleanup slice 10.1)',
  ),
  'lib/models/magic_items/magic_item_data.dart': AllowlistEntry(
    kinds: {'flutter', 'models -> widgets'},
    reason: 'UI data in models (Cleanup slice 10.1)',
  ),
  'lib/models/monster_codex_data.dart': AllowlistEntry(
    kinds: {'models -> services'},
    reason: 'baseline DPR calculation method on Monster domain model and UI data',
  ),
  'lib/models/party/party_purse.dart': AllowlistEntry(
    kinds: {'models -> infrastructure'},
    reason: 'compatibility re-export (folder-layout slice)',
  ),
  'lib/models/party/party_room_lobby.dart': AllowlistEntry(
    kinds: {'models -> infrastructure'},
    reason: 'compatibility re-export (folder-layout slice)',
  ),
  'lib/models/party/party_session_state.dart': AllowlistEntry(
    kinds: {'models -> infrastructure'},
    reason: 'compatibility re-export (folder-layout slice)',
  ),
  'lib/models/spellbook_data.dart': AllowlistEntry(
    kinds: {'flutter', 'models -> widgets'},
    reason: 'UI data in models (Cleanup slice 10.1)',
  ),
  'lib/models/srd_summons/minion_stat_block.dart': AllowlistEntry(
    kinds: {'models -> widgets'},
    reason: 'UI data in models (Cleanup slice 10.1)',
  ),
  'lib/models/tables/rollable_table.dart': AllowlistEntry(
    kinds: {'flutter'},
    reason: 'UI data in models (Cleanup slice 10.1)',
  ),
  'lib/services/haptic_service.dart': AllowlistEntry(
    kinds: {'services -> providers'},
    reason: 'services reads UI state (later)',
  ),
  'lib/services/persistence/app_backup_service.dart': AllowlistEntry(
    kinds: {'services -> providers'},
    reason: 'services reads UI state (later)',
  ),
  'lib/services/rules/character_actions_resolver.dart': AllowlistEntry(
    kinds: {'services -> providers'},
    reason: 'services reads UI state (later)',
  ),
  'lib/utils/pwa_helper_web.dart': AllowlistEntry(
    kinds: {'utils -> services'},
    reason: 'web PWA helper logs non-fatal error via LoggingService (later locator/folder slice)',
  ),
};

String normalizePath(String path) {
  final parts = path.replaceAll('\\', '/').split('/');
  final normalized = <String>[];
  for (final part in parts) {
    if (part.isEmpty || part == '.') continue;
    if (part == '..') {
      if (normalized.isNotEmpty) normalized.removeLast();
    } else {
      normalized.add(part);
    }
  }
  return normalized.join('/');
}

String? resolveAppUri(String fromPath, String uri) {
  if (uri.startsWith('dart:')) return null;
  if (uri.startsWith(kAppPackagePrefix)) {
    return normalizePath('lib/${uri.substring(kAppPackagePrefix.length)}');
  }
  if (uri.startsWith('package:')) return null;
  final dir = fromPath.contains('/')
      ? fromPath.substring(0, fromPath.lastIndexOf('/'))
      : '';
  final combined = dir.isEmpty ? uri : '$dir/$uri';
  return normalizePath(combined);
}

bool isFlutterUri(String uri) {
  for (final prefix in kFlutterUriPrefixes) {
    if (uri == prefix || uri.startsWith(prefix)) {
      return true;
    }
  }
  return false;
}

String stripCommentsPreservingNewlines(String source) {
  final sb = StringBuffer();
  int i = 0;
  final n = source.length;
  bool inBlock = false;
  String? inStr;

  while (i < n) {
    if (inBlock) {
      if (source.startsWith('*/', i)) {
        inBlock = false;
        i += 2;
      } else {
        if (source[i] == '\n') sb.write('\n');
        i++;
      }
    } else if (inStr != null) {
      if (source[i] == r'\' && i + 1 < n) {
        if (source[i + 1] == '\n') sb.write('\n');
        i += 2;
      } else if (source.startsWith(inStr, i)) {
        sb.write(inStr);
        i += inStr.length;
        inStr = null;
      } else {
        sb.write(source[i]);
        i++;
      }
    } else {
      if (source.startsWith('//', i)) {
        while (i < n && source[i] != '\n') {
          i++;
        }
      } else if (source.startsWith('/*', i)) {
        inBlock = true;
        i += 2;
      } else if (source.startsWith("'''", i) || source.startsWith('"""', i)) {
        inStr = source.substring(i, i + 3);
        sb.write(inStr);
        i += 3;
      } else if (source[i] == "'" || source[i] == '"') {
        inStr = source[i];
        sb.write(inStr);
        i++;
      } else {
        sb.write(source[i]);
        i++;
      }
    }
  }
  return sb.toString();
}

class LayerViolation {
  final String filePath;
  final int line;
  final String kind;
  final String formatted;

  const LayerViolation({
    required this.filePath,
    required this.line,
    required this.kind,
    required this.formatted,
  });
}

/// Scans a single file's [source] at [filePath] against [layerRules].
List<LayerViolation> evaluateFileLayerImports(
  String filePath,
  String source, {
  Map<String, LayerRule> layerRules = kLayerRules,
}) {
  final normPath = normalizePath(filePath);
  if (kExemptTopLevelLibFiles.contains(normPath)) {
    return const [];
  }

  final parts = normPath.split('/');
  if (parts.length < 3 || parts.first != 'lib') {
    return [
      LayerViolation(
        filePath: normPath,
        line: 1,
        kind: 'folder not in layer table',
        formatted: '$normPath:1: folder not in layer table',
      ),
    ];
  }

  final fromFolder = parts[1];
  final rule = layerRules[fromFolder];
  if (rule == null) {
    return [
      LayerViolation(
        filePath: normPath,
        line: 1,
        kind: 'folder not in layer table',
        formatted: '$normPath:1: folder not in layer table ($fromFolder)',
      ),
    ];
  }

  final stripped = stripCommentsPreservingNewlines(source);
  final directiveRegex = RegExp(
    r'^\s*(?:import|export|part)\s+(?!of\b)[^;]+;',
    multiLine: true,
    dotAll: true,
  );
  final uriRegex = RegExp(r'''['"]([^'"]+)['"]''');

  final violations = <LayerViolation>[];

  for (final match in directiveRegex.allMatches(stripped)) {
    final stmt = match.group(0)!;
    final lineNo = '\n'.allMatches(stripped.substring(0, match.start)).length + 1;

    for (final uriMatch in uriRegex.allMatches(stmt)) {
      final uri = uriMatch.group(1)!;
      if (uri.isEmpty) continue;

      if (!rule.flutterAllowed && isFlutterUri(uri)) {
        violations.add(
          LayerViolation(
            filePath: normPath,
            line: lineNo,
            kind: 'flutter',
            formatted: '$normPath:$lineNo: flutter ($uri)',
          ),
        );
      }

      final resolved = resolveAppUri(normPath, uri);
      if (resolved != null && resolved.startsWith('lib/')) {
        final rParts = resolved.split('/');
        if (rParts.length >= 3) {
          final toFolder = rParts[1];
          if (!rule.allowedAppFolders.contains(toFolder)) {
            final kind = '$fromFolder -> $toFolder';
            violations.add(
              LayerViolation(
                filePath: normPath,
                line: lineNo,
                kind: kind,
                formatted: '$normPath:$lineNo: $kind',
              ),
            );
          }
        }
      }
    }
  }

  return violations;
}

/// Evaluates a map of `{filePath: source}` against [allowlist] and returns
/// any unallowlisted violations or stale allowlist entries.
List<String> checkFilesAgainstAllowlist(
  Map<String, String> filesByPath,
  Map<String, AllowlistEntry> allowlist, {
  Map<String, LayerRule> layerRules = kLayerRules,
}) {
  final problems = <String>[];
  final observedKindsByFile = <String, Set<String>>{};

  for (final entry in filesByPath.entries) {
    final path = normalizePath(entry.key);
    final violations = evaluateFileLayerImports(
      path,
      entry.value,
      layerRules: layerRules,
    );
    if (violations.isEmpty) continue;

    final kinds = observedKindsByFile.putIfAbsent(path, () => <String>{});
    final allowEntry = allowlist[path];

    for (final v in violations) {
      kinds.add(v.kind);
      if (allowEntry == null || !allowEntry.kinds.contains(v.kind)) {
        problems.add(v.formatted);
      }
    }
  }

  // Check for stale allowlist entries or stale kinds within an entry
  for (final entry in allowlist.entries) {
    final path = normalizePath(entry.key);
    if (entry.value.reason.trim().isEmpty) {
      problems.add('$path:1: allowlist entry missing reason');
    }
    final observed = observedKindsByFile[path];
    if (observed == null || observed.isEmpty) {
      problems.add('$path:1: stale allowlist entry (no violations remaining)');
      continue;
    }
    for (final allowedKind in entry.value.kinds) {
      if (!observed.contains(allowedKind)) {
        problems.add(
          '$path:1: stale allowlist entry (kind "$allowedKind" no longer occurs)',
        );
      }
    }
  }

  return problems;
}

/// Parses the Markdown table between `<!-- layer-table:start -->` and
/// `<!-- layer-table:end -->` in [docContent] and compares every cell with
/// [expectedRows].
List<String> checkDocLayerTable(
  String docContent, {
  List<List<String>> expectedRows = kExpectedDocLayerTableRows,
}) {
  final startIdx = docContent.indexOf(kLayerTableStartMarker);
  final endIdx = docContent.indexOf(kLayerTableEndMarker);
  if (startIdx == -1 || endIdx == -1 || endIdx <= startIdx) {
    return ['Missing or malformed layer-table markers in docs/ARCHITECTURE.md'];
  }

  final section = docContent
      .substring(startIdx + kLayerTableStartMarker.length, endIdx)
      .trim();
  final rawLines = section
      .split('\n')
      .map((l) => l.trim())
      .where((l) => l.isNotEmpty)
      .toList();

  final parsedRows = <List<String>>[];
  for (int i = 0; i < rawLines.length; i++) {
    final line = rawLines[i];
    if (!line.startsWith('|') || !line.endsWith('|')) {
      return ['Malformed markdown table line in docs/ARCHITECTURE.md: $line'];
    }
    final cells = line
        .substring(1, line.length - 1)
        .split('|')
        .map((c) => c.trim())
        .toList();
    // Skip separator row `|---|---|---|`
    if (cells.every((c) => RegExp(r'^:?-{3,}:?$').hasMatch(c))) {
      continue;
    }
    parsedRows.add(cells);
  }

  final problems = <String>[];
  if (parsedRows.length != expectedRows.length) {
    problems.add(
      'Doc layer table row count mismatch: expected ${expectedRows.length} rows, found ${parsedRows.length}',
    );
    return problems;
  }

  for (int r = 0; r < expectedRows.length; r++) {
    final expectedRow = expectedRows[r];
    final actualRow = parsedRows[r];
    if (actualRow.length != expectedRow.length) {
      problems.add(
        'Doc layer table row $r column count mismatch: expected ${expectedRow.length}, found ${actualRow.length}',
      );
      continue;
    }
    for (int c = 0; c < expectedRow.length; c++) {
      if (actualRow[c] != expectedRow[c]) {
        problems.add(
          'Doc/test layer table mismatch at row $r, col $c: expected "${expectedRow[c]}", found "${actualRow[c]}"',
        );
      }
    }
  }

  return problems;
}

void main() {
  group('Layer Import Table Controls', () {
    test('In-memory controls verify edge rules, Flutter rules, conditional imports, staleness, and doc table sync', () {
      // 1. lib/models/x.dart importing ../screens/y.dart -> models -> screens
      final v1 = evaluateFileLayerImports(
        'lib/models/x.dart',
        "import '../screens/y.dart';\n",
      );
      expect(v1.map((v) => v.formatted), equals(['lib/models/x.dart:1: models -> screens']));

      // 2. lib/models/x.dart importing package:.../widgets/z.dart -> models -> widgets
      final v2 = evaluateFileLayerImports(
        'lib/models/x.dart',
        "import 'package:dangerously_nerdy_5e_toolkit/widgets/z.dart';\n",
      );
      expect(v2.map((v) => v.formatted), equals(['lib/models/x.dart:1: models -> widgets']));

      // 3. lib/models/x.dart importing package:flutter/foundation.dart -> flutter
      final v3 = evaluateFileLayerImports(
        'lib/models/x.dart',
        "import 'package:flutter/foundation.dart';\n",
      );
      expect(
        v3.map((v) => v.formatted),
        equals(['lib/models/x.dart:1: flutter (package:flutter/foundation.dart)']),
      );

      // 4. Conditional import whose second branch reaches screens -> flagged
      final v4 = evaluateFileLayerImports(
        'lib/models/x.dart',
        "import 'a_stub.dart' if (dart.library.html) '../screens/web_screen.dart';\n",
      );
      expect(v4.map((v) => v.formatted), equals(['lib/models/x.dart:1: models -> screens']));

      // 5. lib/screens/a.dart importing ../models/b.dart -> not flagged
      final v5 = evaluateFileLayerImports(
        'lib/screens/a.dart',
        "import '../models/b.dart';\n",
      );
      expect(v5, isEmpty);

      // 6. Allowlist entry for a file with no violation fails as stale
      final staleProblems = checkFilesAgainstAllowlist(
        {'lib/models/clean.dart': "import 'other_model.dart';\n"},
        {
          'lib/models/clean.dart': const AllowlistEntry(
            kinds: {'models -> widgets'},
            reason: 'UI data in models (Cleanup slice 10.1)',
          ),
        },
      );
      expect(
        staleProblems,
        contains(contains('stale allowlist entry')),
      );

      // 7. Doc table with one changed cell fails
      final realDoc = File('docs/ARCHITECTURE.md').readAsStringSync();
      final mutatedDoc = realDoc.replaceFirst(
        '| `models` | `domain`, `models`, `utils` | no |',
        '| `models` | `domain`, `models`, `utils`, `providers` | no |',
      );
      final docProblems = checkDocLayerTable(mutatedDoc);
      expect(
        docProblems,
        isNotEmpty,
        reason: 'Control: doc table with one changed cell must fail',
      );
      expect(docProblems.first, contains('Doc/test layer table mismatch'));
    });
  });

  group('Layer Import Table Verification', () {
    test('docs/ARCHITECTURE.md layer table matches test table cell-for-cell', () {
      final docFile = File('docs/ARCHITECTURE.md');
      expect(docFile.existsSync(), isTrue, reason: 'docs/ARCHITECTURE.md must exist');
      final problems = checkDocLayerTable(docFile.readAsStringSync());
      if (problems.isNotEmpty) {
        fail('docs/ARCHITECTURE.md layer table mismatch:\n${problems.join('\n')}');
      }
      expect(problems, isEmpty);
    });

    test('Every .dart file under lib/ obeys the layer import table and exact allowlist', () {
      final libDir = Directory('lib');
      expect(libDir.existsSync(), isTrue, reason: 'lib directory must exist');

      // Check top-level folders under lib/
      for (final entity in libDir.listSync(followLinks: false)) {
        if (entity is Directory) {
          final folderName = normalizePath(entity.path).split('/').last;
          if (!kLayerRules.containsKey(folderName)) {
            fail('folder not in layer table: lib/$folderName');
          }
        }
      }

      final dartFiles = libDir
          .listSync(recursive: true, followLinks: false)
          .whereType<File>()
          .where((f) => f.path.endsWith('.dart'))
          .toList()
        ..sort((a, b) => a.path.compareTo(b.path));

      expect(dartFiles, isNotEmpty, reason: 'No .dart files found under lib/');

      final filesByPath = <String, String>{};
      int totalViolationsFound = 0;
      final countPerKind = <String, int>{};

      for (final file in dartFiles) {
        final path = normalizePath(file.path);
        final content = file.readAsStringSync();
        filesByPath[path] = content;

        final violations = evaluateFileLayerImports(path, content);
        totalViolationsFound += violations.length;
        final kindsInFile = <String>{};
        for (final v in violations) {
          kindsInFile.add(v.kind);
        }
        for (final kind in kindsInFile) {
          countPerKind[kind] = (countPerKind[kind] ?? 0) + 1;
        }
      }

      int allowlistKindCount = 0;
      for (final entry in kLayerViolationAllowlist.values) {
        allowlistKindCount += entry.kinds.length;
      }

      stdout.writeln(
        'Layer import table: files scanned = ${dartFiles.length}, '
        'directive violations found = $totalViolationsFound, '
        'allowlist files = ${kLayerViolationAllowlist.length} '
        '(total allowlist file-kind entries = $allowlistKindCount)',
      );
      final sortedKinds = countPerKind.keys.toList()..sort();
      for (final kind in sortedKinds) {
        stdout.writeln('  kind "$kind": ${countPerKind[kind]} file(s)');
      }

      final problems = checkFilesAgainstAllowlist(
        filesByPath,
        kLayerViolationAllowlist,
      );

      if (problems.isNotEmpty) {
        fail('Layer import table violations:\n${problems.join('\n')}');
      }
      expect(problems, isEmpty);
    });
  });
}
