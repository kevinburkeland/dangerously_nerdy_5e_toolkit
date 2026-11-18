import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import '../../support/dart_directive_reader.dart';

/// Empty allowlist for pure ruleset tests in the app.
/// Any entry here must exist and would otherwise trigger the bar;
/// this list starts empty and must remain empty.
const Set<String> kPureRulesetTestAllowlist = {};

const String _kAppPackagePrefix = 'package:dangerously_nerdy_5e_toolkit/';

/// Checks whether a Dart source string is a pure barrel that only re-exports `package:` URIs
/// with no imports, parts, or declarations.
bool isPurePackageReexportBarrel(String source) {
  final directives = parseDartDirectives(source);
  if (directives.isEmpty) return false;

  for (final d in directives) {
    if (!d.isExport) return false;
    if (d.uris.any((u) => !u.startsWith('package:'))) return false;
  }

  // Strip comments and strings preserving newlines, then remove all directives
  // and library declarations to verify no top-level declarations remain.
  var stripped = stripCommentsAndStringsPreservingNewlines(source);
  stripped = stripped.replaceAll(RegExp(r'\bexport\b[^;]*;'), '');
  stripped = stripped.replaceAll(RegExp(r'\blibrary\b[^;]*;'), '');

  return stripped.trim().isEmpty;
}

/// Resolves an app package URI (`package:dangerously_nerdy_5e_toolkit/...`)
/// or relative URI from a file under `test/` or `lib/` to a repo-relative path under `lib/`.
String? resolveAppLibPath(String uri, String fromFilePath) {
  if (uri.startsWith(_kAppPackagePrefix)) {
    return 'lib/${uri.substring(_kAppPackagePrefix.length)}';
  }
  if (!uri.contains(':')) {
    final parentDir = File(fromFilePath).parent.path.replaceAll('\\', '/');
    final combined = '$parentDir/$uri';
    final normalized = Uri.parse(combined).normalizePath().path;
    if (normalized.startsWith('lib/')) {
      return normalized;
    }
  }
  return null;
}

/// Expands any pure package re-export barrels in [imports] using files under [repoRoot].
Set<String> expandImportsThroughBarrels(
  List<String> imports,
  String fromFilePath, {
  String repoRoot = '.',
  Set<String>? visitedBarrels,
}) {
  final visited = visitedBarrels ?? <String>{};
  final resolved = <String>{};

  for (final uri in imports) {
    final libPath = resolveAppLibPath(uri, fromFilePath);
    if (libPath != null && !visited.contains(libPath)) {
      final file = File('$repoRoot/$libPath');
      if (file.existsSync()) {
        final source = file.readAsStringSync();
        if (isPurePackageReexportBarrel(source)) {
          visited.add(libPath);
          final directives = parseDartDirectives(source);
          final exportedUris = directives.expand((d) => d.uris).toList();
          resolved.addAll(
            expandImportsThroughBarrels(
              exportedUris,
              libPath,
              repoRoot: repoRoot,
              visitedBarrels: visited,
            ),
          );
          continue;
        }
      }
    }
    resolved.add(uri);
  }

  return resolved;
}

bool _isAllowedPureRulesetUri(String uri) {
  return uri.startsWith('dart:') ||
      uri == 'package:flutter_test/flutter_test.dart' ||
      uri.startsWith('package:flutter_test/') ||
      uri == 'package:test/test.dart' ||
      uri.startsWith('package:test/') ||
      uri.startsWith('package:vtt_engine_core/') ||
      uri.startsWith('package:vtt_ruleset_dnd5e/');
}

/// Returns a violation string if [source] in [testPath] is a pure ruleset test.
String? checkTestSourceForPureRulesetImports(
  String testPath,
  String source, {
  String repoRoot = '.',
}) {
  final directives = parseDartDirectives(source);
  final importUris = directives
      .where((d) => d.isImport)
      .expand((d) => d.uris)
      .toList();

  if (importUris.isEmpty) return null;

  final expanded = expandImportsThroughBarrels(
    importUris,
    testPath,
    repoRoot: repoRoot,
  );

  // Must actually reference vtt_ruleset_dnd5e (or core+ruleset) and have ONLY ruleset/core/test/dart URIs.
  final usesRuleset = expanded.any((u) => u.startsWith('package:vtt_ruleset_dnd5e/'));
  if (!usesRuleset) return null;

  final allAllowed = expanded.every(_isAllowedPureRulesetUri);
  if (allAllowed) {
    return '$testPath: pure ruleset test, move it to vtt-ruleset-dnd5e';
  }
  return null;
}

List<String> scanForPureRulesetTests({String repoRoot = '.'}) {
  final testDir = Directory('$repoRoot/test');
  if (!testDir.existsSync()) return const [];

  final testFiles = testDir
      .listSync(recursive: true)
      .whereType<File>()
      .where((f) => f.path.replaceAll('\\', '/').endsWith('_test.dart'))
      .toList()
    ..sort((a, b) => a.path.compareTo(b.path));

  final violations = <String>[];
  for (final file in testFiles) {
    var relPath = file.path.replaceAll('\\', '/');
    if (relPath.startsWith('$repoRoot/')) {
      relPath = relPath.substring('$repoRoot/'.length);
    }
    if (kPureRulesetTestAllowlist.contains(relPath)) continue;

    final source = file.readAsStringSync();
    final violation = checkTestSourceForPureRulesetImports(
      relPath,
      source,
      repoRoot: repoRoot,
    );
    if (violation != null) {
      violations.add(violation);
    }
  }
  return violations;
}

void main() {
  group('Fix 6.3: No pure ruleset tests in the app', () {
    test('control: in-memory test importing only flutter_test and ruleset is flagged', () {
      const source = '''
import 'package:flutter_test/flutter_test.dart';
import 'package:vtt_ruleset_dnd5e/vtt_ruleset_dnd5e.dart';
void main() {}
''';
      final result = checkTestSourceForPureRulesetImports(
        'test/scratch_pure_test.dart',
        source,
      );
      expect(
        result,
        equals('test/scratch_pure_test.dart: pure ruleset test, move it to vtt-ruleset-dnd5e'),
      );
    });

    test('control: in-memory test importing core_types.dart barrel and ruleset is flagged', () {
      const source = '''
import 'package:flutter_test/flutter_test.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/domain/core_types.dart';
import 'package:vtt_ruleset_dnd5e/vtt_ruleset_dnd5e.dart';
void main() {}
''';
      final result = checkTestSourceForPureRulesetImports(
        'test/scratch_barrel_test.dart',
        source,
      );
      expect(
        result,
        equals('test/scratch_barrel_test.dart: pure ruleset test, move it to vtt-ruleset-dnd5e'),
      );
    });

    test('control: in-memory test importing an app widget is not flagged', () {
      const source = '''
import 'package:flutter_test/flutter_test.dart';
import 'package:dangerously_nerdy_5e_toolkit/widgets/room_banner_widget.dart';
import 'package:vtt_ruleset_dnd5e/vtt_ruleset_dnd5e.dart';
void main() {}
''';
      final result = checkTestSourceForPureRulesetImports(
        'test/scratch_widget_test.dart',
        source,
      );
      expect(result, isNull);
    });

    test('allowlist stale check: kPureRulesetTestAllowlist must be empty and valid', () {
      expect(kPureRulesetTestAllowlist, isEmpty);
      for (final path in kPureRulesetTestAllowlist) {
        expect(File(path).existsSync(), isTrue, reason: 'Stale allowlist entry: $path');
      }
    });

    test('no pure ruleset tests remain in app test/ directory', () {
      final violations = scanForPureRulesetTests();
      expect(
        violations,
        isEmpty,
        reason: 'Pure ruleset tests found in app:\n${violations.join('\n')}',
      );
    });
  });
}
