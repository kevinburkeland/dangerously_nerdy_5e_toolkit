import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

const String kAppPackagePrefix = 'package:dangerously_nerdy_5e_toolkit/';
const String kInjectionContainerTarget =
    'lib/infrastructure/di/injection_container.dart';

/// Allowlist of files outside `lib/infrastructure/di/` and `lib/main.dart`
/// permitted to import `injection_container.dart`.
///
/// Every entry includes a one-line reason. A listed file that ceases importing
/// the locator fails as a stale allowlist entry.
const Map<String, String> kAllowedLocatorImporters = {
  'lib/presentation/screens/homebrew/homebrew_expert_options_view.dart':
      'Resolves StatefulHlcClock during expert homebrew import setup',
  'lib/presentation/screens/map/map_screen.dart':
      'Resolves map controllers and reactive state management',
  'lib/presentation/widgets/map/map_token_panel.dart':
      'Resolves token panel actions and map repositories',
  'lib/presentation/widgets/map/map_token_picker.dart':
      'Resolves token picker asset repositories',
  'lib/presentation/widgets/map/map_view.dart':
      'Resolves map view interactive sync and controllers',
  'lib/providers/dm_dashboard_controller.dart':
      'Resolves repository and encounter services for DM dashboard',
  'lib/screens/character_builder_screen.dart':
      'Resolves character builder state and draft persistence',
  'lib/screens/character_sheet_view.dart':
      'Resolves character sheet telemetry and rules services',
  'lib/screens/dm_dashboard_screen.dart':
      'Resolves DM dashboard replica identity and clock services',
  'lib/screens/landing_screen.dart':
      'Resolves PartyRoomService to sync campaigns on landing screen open',
  'lib/screens/party_room_screen.dart':
      'Resolves transport, sync orchestrator, and room session starter',
  'lib/services/party/party_room_service.dart':
      'Resolves singleton instance and test unregistration hooks',
  'lib/widgets/room_banner_widget.dart':
      'Resolves P2P transport and sync orchestrator for banner status',
};

/// Exact counts of `.isRegistered` calls permitted in exempted files.
const Map<String, int> kExpectedIsRegisteredCounts = {
  'lib/providers/dm_dashboard_controller.dart': 9,
  'lib/screens/dm_dashboard_screen.dart': 3,
};

/// Ceilings for service locator usages and collaborator `??` defaults.
const int kSlUsesCeiling = 56;
const int kCollaboratorDefaultsCeiling = 50;

String normalizePath(String path) {
  final parts = path.split('/');
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

String? resolveUri(String fromPath, String uri) {
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

/// Extracts all import, export, and part directive URIs from [source],
/// including configuration branches in conditional imports.
List<String> extractDirectiveUris(String source) {
  final uris = <String>[];
  final directiveRegex = RegExp(
    r'''^\s*(?:import|export|part)\s+['"]([^'"]+)['"](?:\s+if\s*\([^)]+\)\s*['"]([^'"]+)['"])*''',
    multiLine: true,
  );
  final uriStringRegex = RegExp(r'''['"]([^'"]+)['"]''');

  for (final match in directiveRegex.allMatches(source)) {
    final matchedText = match.group(0)!;
    for (final strMatch in uriStringRegex.allMatches(matchedText)) {
      final uri = strMatch.group(1);
      if (uri != null && uri.isNotEmpty) {
        uris.add(uri);
      }
    }
  }
  return uris;
}

/// Checks whether [source] in file [filePath] imports the injection container.
bool importsInjectionContainer(String filePath, String source) {
  final uris = extractDirectiveUris(source);
  for (final uri in uris) {
    final resolved = resolveUri(filePath, uri);
    if (resolved == kInjectionContainerTarget) {
      return true;
    }
  }
  return false;
}

/// Finds line violations of `\.isRegistered\b` in [source].
List<String> findIsRegisteredViolations(String filePath, String source) {
  final isRegisteredRegex = RegExp(r'\.isRegistered\b');
  final lines = source.split('\n');
  final violations = <String>[];
  for (int i = 0; i < lines.length; i++) {
    final line = lines[i];
    if (isRegisteredRegex.hasMatch(line)) {
      violations.add('$filePath:${i + 1}: ${line.trim()}');
    }
  }
  return violations;
}

final RegExp kSlPattern = RegExp(r'(?<![a-zA-Z0-9_\$.])sl\s*([<.(])');

final RegExp kDefaultsPattern = RegExp(
  r'\?\?\s*(?://[^\n]*\n\s*)*(?:const\s+|new\s+)?[A-Z][A-Za-z0-9_]*(?:Service|Repository|Adapter|Controller|Engine|Store|Manager|Orchestrator|Router|Port|Resolver|Coordinator|Importer|Pipeline|Starter)(?:\.[A-Za-z_][A-Za-z0-9_]*)?\s*\(',
);

int countSlUses(String source) {
  return kSlPattern.allMatches(source).length;
}

int countCollaboratorDefaults(String source) {
  return kDefaultsPattern.allMatches(source).length;
}

void main() {
  group('Service Locator Bars (Rule 1: Locator Importers)', () {
    test('In-memory controls flag disallowed imports (relative and package:)', () {
      const relativeImportFile = '''
import '../infrastructure/di/injection_container.dart';
void run() {}
''';
      const packageImportFile = '''
import 'package:dangerously_nerdy_5e_toolkit/infrastructure/di/injection_container.dart';
void run() {}
''';
      const unrelatedImportFile = '''
import '../application/services/room_sync_orchestrator.dart';
void run() {}
''';

      expect(
        importsInjectionContainer(
          'lib/services/my_service.dart',
          relativeImportFile,
        ),
        isTrue,
        reason: 'Control: relative import to locator must be detected',
      );
      expect(
        importsInjectionContainer(
          'lib/services/my_service.dart',
          packageImportFile,
        ),
        isTrue,
        reason: 'Control: package: import to locator must be detected',
      );
      expect(
        importsInjectionContainer(
          'lib/services/my_service.dart',
          unrelatedImportFile,
        ),
        isFalse,
      );
    });

    test('Only allowed files import lib/infrastructure/di/injection_container.dart', () {
      final libDir = Directory('lib');
      expect(libDir.existsSync(), isTrue, reason: 'lib directory must exist');

      final dartFiles = libDir
          .listSync(recursive: true)
          .whereType<File>()
          .where((f) => f.path.endsWith('.dart'))
          .toList();

      expect(
        dartFiles,
        isNotEmpty,
        reason: 'lib must contain Dart files to scan',
      );

      final violations = <String>[];
      final actualImporters = <String>{};

      for (final file in dartFiles) {
        final path = normalizePath(file.path);
        final content = file.readAsStringSync();

        if (importsInjectionContainer(path, content)) {
          actualImporters.add(path);

          final isAllowed = path == 'lib/main.dart' ||
              path.startsWith('lib/infrastructure/di/') ||
              kAllowedLocatorImporters.containsKey(path);

          if (!isAllowed) {
            // Find line number
            final lines = content.split('\n');
            int lineNo = 1;
            String matchingLine = '';
            for (int i = 0; i < lines.length; i++) {
              if (lines[i].contains('injection_container.dart')) {
                lineNo = i + 1;
                matchingLine = lines[i].trim();
                break;
              }
            }
            violations.add('$path:$lineNo: $matchingLine');
          }
        }
      }

      // Check for stale allowlist entries
      for (final allowed in kAllowedLocatorImporters.keys) {
        if (!actualImporters.contains(allowed)) {
          violations.add('$allowed:1: stale allowlist entry (file no longer imports locator)');
        }
      }

      if (violations.isNotEmpty) {
        fail('Locator import rule violations:\n${violations.join('\n')}');
      }

      expect(violations, isEmpty);
    });
  });

  group('Service Locator Bars (Rule 2: No isRegistered calls)', () {
    test('In-memory controls flag .isRegistered without false-positives', () {
      const flaggedSnippet = 'if (sl.isRegistered<Foo>()) {}';
      const cleanSnippet = 'SrdClassesLibrary.isRegisteredSubclassFeature(x)';

      final flaggedMatches =
          findIsRegisteredViolations('test/control.dart', flaggedSnippet);
      final cleanMatches =
          findIsRegisteredViolations('test/control.dart', cleanSnippet);

      expect(
        flaggedMatches,
        isNotEmpty,
        reason: 'Control: sl.isRegistered must be flagged',
      );
      expect(
        cleanMatches,
        isEmpty,
        reason: 'Control: isRegisteredSubclassFeature must not be flagged',
      );
    });

    test('No .isRegistered calls in lib/ except exact counts in DM dashboard', () {
      final libDir = Directory('lib');
      final dartFiles = libDir
          .listSync(recursive: true)
          .whereType<File>()
          .where((f) => f.path.endsWith('.dart'))
          .toList();

      final violations = <String>[];
      final recordedCounts = <String, int>{};

      for (final file in dartFiles) {
        final path = normalizePath(file.path);
        final content = file.readAsStringSync();
        final matches = findIsRegisteredViolations(path, content);

        if (matches.isNotEmpty) {
          recordedCounts[path] = matches.length;
          final expectedCount = kExpectedIsRegisteredCounts[path];

          if (expectedCount == null) {
            violations.addAll(matches);
          } else if (matches.length != expectedCount) {
            violations.add(
              '$path:0: expected exactly $expectedCount .isRegistered calls, found ${matches.length}',
            );
          }
        }
      }

      for (final entry in kExpectedIsRegisteredCounts.entries) {
        final actual = recordedCounts[entry.key] ?? 0;
        if (actual < entry.value) {
          violations.add(
            '${entry.key}:0: .isRegistered count dropped from ${entry.value} to $actual; lower test expectation',
          );
        }
      }

      if (violations.isNotEmpty) {
        fail('.isRegistered rule violations:\n${violations.join('\n')}');
      }

      expect(violations, isEmpty);
    });
  });

  group('Service Locator Bars (Rule 3: Ceilings on sl and ?? defaults)', () {
    test('In-memory controls count sl and ?? defaults correctly', () {
      const sampleSnippet = '''
void test() {
  sl<Foo>();
  sl.get<Bar>();
  final x = val ??
      FooService();
  isl<Foo>();
  x.sl<Foo>();
}
''';
      expect(
        countSlUses(sampleSnippet),
        equals(2),
        reason: 'Control: sl<Foo>() and sl.get<Bar>() count as 2, isl and x.sl count as 0',
      );
      expect(
        countCollaboratorDefaults(sampleSnippet),
        equals(1),
        reason: 'Control: ?? FooService() across lines counts as 1',
      );
    });

    test('Actual sl uses and collaborator defaults do not exceed ceilings', () {
      final libDir = Directory('lib');
      final dartFiles = libDir
          .listSync(recursive: true)
          .whereType<File>()
          .where((f) => f.path.endsWith('.dart'))
          .toList();

      int actualSlUses = 0;
      int actualDefaults = 0;

      for (final file in dartFiles) {
        final path = normalizePath(file.path);
        if (path.startsWith('lib/infrastructure/di/')) {
          continue;
        }

        final content = file.readAsStringSync();

        if (path != 'lib/main.dart') {
          actualSlUses += countSlUses(content);
        }

        actualDefaults += countCollaboratorDefaults(content);
      }

      // Output real counts for transparency
      stdout.writeln('Service locator bars: sl uses = $actualSlUses (ceiling: $kSlUsesCeiling)');
      stdout.writeln('Service locator bars: defaults = $actualDefaults (ceiling: $kCollaboratorDefaultsCeiling)');

      expect(
        actualSlUses,
        lessThanOrEqualTo(kSlUsesCeiling),
        reason: 'sl uses outside lib/infrastructure/di/ and lib/main.dart ($actualSlUses) exceeded ceiling ($kSlUsesCeiling)',
      );

      expect(
        actualDefaults,
        lessThanOrEqualTo(kCollaboratorDefaultsCeiling),
        reason: 'Collaborator ?? defaults outside lib/infrastructure/di/ ($actualDefaults) exceeded ceiling ($kCollaboratorDefaultsCeiling)',
      );
    });
  });
}
