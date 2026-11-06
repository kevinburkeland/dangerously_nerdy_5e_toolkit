import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

const String kAppPackagePrefix = 'package:dangerously_nerdy_5e_toolkit/';
const String kInjectionContainerTarget =
    'lib/infrastructure/di/injection_container.dart';
const String kServiceContainerTarget =
    'lib/infrastructure/di/service_container.dart';
const String kCampaignStorageMigrationTarget =
    'lib/infrastructure/repositories/campaign_storage_migration.dart';

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
const int kCollaboratorDefaultsCeiling = 45;

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

/// Checks whether [source] in file [filePath] imports the service container.
bool importsServiceContainer(String filePath, String source) {
  final uris = extractDirectiveUris(source);
  for (final uri in uris) {
    final resolved = resolveUri(filePath, uri);
    if (resolved == kServiceContainerTarget) {
      return true;
    }
  }
  return false;
}

/// Strips block comments and line comments from [source], preserving line count.
String stripCommentsPreservingLines(String source) {
  final lines = source.split('\n');
  final out = <String>[];
  bool inBlock = false;
  for (final rawLine in lines) {
    var line = rawLine;
    final sb = StringBuffer();
    int i = 0;
    while (i < line.length) {
      if (inBlock) {
        final endIdx = line.indexOf('*/', i);
        if (endIdx == -1) {
          i = line.length;
        } else {
          inBlock = false;
          i = endIdx + 2;
        }
      } else {
        if (line.startsWith('//', i)) {
          break;
        } else if (line.startsWith('/*', i)) {
          inBlock = true;
          i += 2;
        } else {
          sb.write(line[i]);
          i++;
        }
      }
    }
    out.add(sb.toString());
  }
  return out.join('\n');
}

/// Strips block comments, line comments, and string literal contents (preserving `${...}` interpolation code) from [source], preserving line count.
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
      if (source[i] == '\n') {
        buf.write('\n');
      }
      i++;
    }
  }
  return buf.toString();
}

/// Evaluates Rule 4 against in-memory [source] of `service_container.dart`.
List<String> findServiceContainerViolations(String filePath, String source) {
  final violations = <String>[];
  final uris = extractDirectiveUris(source);
  for (final uri in uris) {
    if (!uri.startsWith('dart:')) {
      violations.add('$filePath:1: non-dart directive URI: $uri');
    }
  }

  final stripped = stripCommentsAndStringsPreservingLines(source);
  final lines = stripped.split('\n');
  for (int i = 0; i < lines.length; i++) {
    final line = lines[i];
    if (line.contains('ForTesting')) {
      violations.add('$filePath:${i + 1}: contains ForTesting: ${line.trim()}');
    }
    const forbiddenReset = 'reset' 'TestingState';
    if (line.contains(forbiddenReset)) {
      violations.add('$filePath:${i + 1}: contains $forbiddenReset: ${line.trim()}');
    }
    if (line.contains('configure(')) {
      violations.add('$filePath:${i + 1}: contains configure(: ${line.trim()}');
    }
    if (line.contains('runtimeType')) {
      violations.add('$filePath:${i + 1}: contains runtimeType: ${line.trim()}');
    }
    if (RegExp(r' is ').hasMatch(line)) {
      violations.add('$filePath:${i + 1}: contains ` is ` type test: ${line.trim()}');
    }
  }
  return violations;
}

/// Evaluates Rule 5 against in-memory [source] of [filePath].
/// In `lib/`, a call to a member whose name ends in `ForTesting`
/// (pattern: `\b\w*ForTesting\s*\(` that is not its declaration) is allowed
/// only inside the file that declares that member.
List<String> findForTestingCallViolations(String filePath, String source) {
  final stripped = stripCommentsPreservingLines(source);
  final lines = stripped.split('\n');
  final callRegex = RegExp(r'\b(\w*ForTesting)\s*\(');
  final declaredInFile = <String>{};

  for (final line in lines) {
    for (final match in callRegex.allMatches(line)) {
      final name = match.group(1)!;
      final prefix = line.substring(0, match.start);
      if (_isDeclarationPrefix(prefix)) {
        declaredInFile.add(name);
      }
    }
  }

  final violations = <String>[];
  final rawLines = source.split('\n');
  for (int i = 0; i < lines.length; i++) {
    final line = lines[i];
    for (final match in callRegex.allMatches(line)) {
      final name = match.group(1)!;
      final prefix = line.substring(0, match.start);
      if (_isDeclarationPrefix(prefix)) {
        continue;
      }
      if (!declaredInFile.contains(name)) {
        violations.add('$filePath:${i + 1}: ${rawLines[i].trim()}');
      }
    }
  }
  return violations;
}

bool _isDeclarationPrefix(String prefix) {
  final trimmed = prefix.trimRight();
  if (trimmed.isEmpty) return false;
  if (trimmed.endsWith('.') || trimmed.endsWith('?.') || trimmed.endsWith('..')) {
    return false;
  }
  // A declaration precedes the method/setter name with a return type or `static`/`void`/`set`/`get`/`Future<...>`/etc.
  return RegExp(
    r'(?:\b(?:void|static|set|get|Future|Stream|bool|int|double|String|dynamic|Object|T|[A-Z]\w*)\s*[>?]?)$',
  ).hasMatch(trimmed);
}

const Map<String, Set<String>> kCollaboratorFieldsByServiceFile = {
  'lib/services/persistence/campaign_profile_service.dart': {
    '_repository',
    '_replicaId',
    '_clock',
    '_blobStoreProvider',
    '_registryService',
  },
  'lib/services/persistence/dm_backup_service.dart': {
    '_clock',
  },
  'lib/services/dice_room_service.dart': {
    '_transport',
    '_orchestrator',
    '_sessionStarter',
  },
};

/// Evaluates Rule 6 against in-memory [source] of [filePath].
/// A mention of a collaborator field in [fieldNames] outside:
/// (a) its declaration,
/// (b) `configure`/`bind`/`newInstance` assignments (or constructor initializer list for DmBackupService),
/// (c) its `...ForTesting` reset, and
/// (d) its own `_require...()` getter
/// fails, printed as `path:line: text`.
List<String> findCollaboratorFieldAccessViolations(
  String filePath,
  String source,
  Set<String> fieldNames,
) {
  final stripped = stripCommentsAndStringsPreservingLines(source);
  final rawLines = source.split('\n');

  // Identify allowed line ranges (1-based) by scanning top-level class members.
  final allowedLines = <int>{};

  // Line index lookup from character offset in `stripped`.
  final lineStarts = <int>[0];
  for (int i = 0; i < stripped.length; i++) {
    if (stripped[i] == '\n') {
      lineStarts.add(i + 1);
    }
  }
  int lineForOffset(int offset) {
    int lo = 0;
    int hi = lineStarts.length - 1;
    while (lo <= hi) {
      final mid = (lo + hi) >> 1;
      if (lineStarts[mid] <= offset) {
        lo = mid + 1;
      } else {
        hi = mid - 1;
      }
    }
    return hi + 1; // 1-based line number
  }
  void allowSpan(int startOffset, int endOffset) {
    final startLine = lineForOffset(startOffset);
    final endLine = lineForOffset(endOffset);
    for (int l = startLine; l <= endLine; l++) {
      allowedLines.add(l);
    }
  }

  final classMatch = RegExp(r'\bclass\s+([A-Za-z_]\w*)\b').allMatches(stripped);
  for (final cm in classMatch) {
    final className = cm.group(1)!;
    final openBrace = stripped.indexOf('{', cm.end);
    if (openBrace == -1) continue;
    int depth = 1;
    int p = openBrace + 1;
    while (p < stripped.length && depth > 0) {
      if (stripped[p] == '{') depth++;
      if (stripped[p] == '}') depth--;
      p++;
    }
    final bodyStart = openBrace + 1;
    final bodyEnd = p - 1;

    int i = bodyStart;
    int braceDepth = 0;
    int parenDepth = 0;
    int stmtStart = bodyStart;

    while (i < bodyEnd) {
      final ch = stripped[i];
      if (ch == '(' && braceDepth == 0) {
        parenDepth++;
        i++;
        continue;
      }
      if (ch == ')' && braceDepth == 0) {
        if (parenDepth > 0) parenDepth--;
        i++;
        continue;
      }
      if (ch == ';' && braceDepth == 0 && parenDepth == 0) {
        final stmt = stripped.substring(stmtStart, i + 1);
        if (_isAllowedCollaboratorMemberHeader(stmt, className, fieldNames)) {
          allowSpan(stmtStart, i);
        }
        stmtStart = i + 1;
        i++;
        continue;
      }
      if (ch == '{' && parenDepth == 0 && braceDepth == 0) {
        final header = stripped.substring(stmtStart, i);
        braceDepth = 1;
        i++;
        while (i < bodyEnd && braceDepth > 0) {
          if (stripped[i] == '{') braceDepth++;
          if (stripped[i] == '}') braceDepth--;
          i++;
        }
        if (_isAllowedCollaboratorMemberHeader(header, className, fieldNames)) {
          allowSpan(stmtStart, i - 1);
        }
        stmtStart = i;
        continue;
      }
      i++;
    }
  }

  final violations = <String>[];
  final strippedLines = stripped.split('\n');
  for (int idx = 0; idx < strippedLines.length; idx++) {
    final lineNo = idx + 1;
    if (allowedLines.contains(lineNo)) continue;
    final line = strippedLines[idx];
    for (final field in fieldNames) {
      if (RegExp('\\b${RegExp.escape(field)}\\b').hasMatch(line)) {
        violations.add('$filePath:$lineNo: ${rawLines[idx].trim()}');
        break;
      }
    }
  }
  return violations;
}

bool _isAllowedCollaboratorMemberHeader(
  String header,
  String className,
  Set<String> fieldNames,
) {
  final clean = header.trim();
  if (clean.isEmpty) return false;

  // (a) Field declaration: e.g. `ICampaignRepository? _repository;`
  if (clean.endsWith(';') && !clean.contains('(') && !clean.contains('=>')) {
    for (final field in fieldNames) {
      if (RegExp('\\b${RegExp.escape(field)}\\s*;\\s*\$').hasMatch(clean)) {
        return true;
      }
    }
    return false;
  }

  // (b) configure / bind / newInstance / private constructor initializer
  if (RegExp(r'\b(?:configure|bind|newInstance)\s*\(').hasMatch(clean)) {
    return true;
  }
  if (RegExp('\\b${RegExp.escape(className)}\\._internal\\s*\\(').hasMatch(clean)) {
    return true;
  }

  // (c) ...ForTesting reset method
  if (RegExp(r'\b\w*reset\w*ForTesting\s*\(', caseSensitive: false)
      .hasMatch(clean)) {
    return true;
  }

  // (d) _require...() getter/method
  if (RegExp(r'\b_require[A-Z]\w*\s*(?:\(|$)').hasMatch(clean)) {
    return true;
  }

  return false;
}

/// Evaluates Rule 7 against in-memory [source] of `campaign_storage_migration.dart`.
/// `lib/infrastructure/repositories/campaign_storage_migration.dart` has no `static`
/// field other than `const`, and no public static function in it has a nullable
/// parameter (no `?` after a parameter type) or an optional positional parameter (`[`).
List<String> findCampaignStorageMigrationViolations(
  String filePath,
  String source,
) {
  final stripped = stripCommentsAndStringsPreservingLines(source);
  final rawLines = source.split('\n');
  final violations = <String>[];

  final lineStarts = <int>[0];
  for (int i = 0; i < stripped.length; i++) {
    if (stripped[i] == '\n') {
      lineStarts.add(i + 1);
    }
  }
  int lineForOffset(int offset) {
    int lo = 0;
    int hi = lineStarts.length - 1;
    while (lo <= hi) {
      final mid = (lo + hi) >> 1;
      if (lineStarts[mid] <= offset) {
        lo = mid + 1;
      } else {
        hi = mid - 1;
      }
    }
    return hi + 1;
  }

  final classMatch = RegExp(r'\bclass\s+([A-Za-z_]\w*)\b').allMatches(stripped);
  for (final cm in classMatch) {
    final openBrace = stripped.indexOf('{', cm.end);
    if (openBrace == -1) continue;
    int depth = 1;
    int p = openBrace + 1;
    while (p < stripped.length && depth > 0) {
      if (stripped[p] == '{') depth++;
      if (stripped[p] == '}') depth--;
      p++;
    }
    final bodyStart = openBrace + 1;
    final bodyEnd = p - 1;

    int i = bodyStart;
    int braceDepth = 0;
    int parenDepth = 0;
    int stmtStart = bodyStart;

    while (i < bodyEnd) {
      final ch = stripped[i];
      if (ch == '(' && braceDepth == 0) {
        parenDepth++;
        i++;
        continue;
      }
      if (ch == ')' && braceDepth == 0) {
        if (parenDepth > 0) parenDepth--;
        i++;
        continue;
      }
      if (ch == ';' && braceDepth == 0 && parenDepth == 0) {
        final stmt = stripped.substring(stmtStart, i + 1);
        _checkStaticMemberHeader(
          filePath,
          rawLines,
          stripped,
          stmtStart,
          stmt,
          isFieldOrAbstract: true,
          lineForOffset: lineForOffset,
          violations: violations,
        );
        stmtStart = i + 1;
        i++;
        continue;
      }
      if (ch == '{' && parenDepth == 0 && braceDepth == 0) {
        final header = stripped.substring(stmtStart, i);
        _checkStaticMemberHeader(
          filePath,
          rawLines,
          stripped,
          stmtStart,
          header,
          isFieldOrAbstract: false,
          lineForOffset: lineForOffset,
          violations: violations,
        );
        braceDepth = 1;
        i++;
        while (i < bodyEnd && braceDepth > 0) {
          if (stripped[i] == '{') braceDepth++;
          if (stripped[i] == '}') braceDepth--;
          i++;
        }
        stmtStart = i;
        continue;
      }
      i++;
    }
  }
  return violations;
}

void _checkStaticMemberHeader(
  String filePath,
  List<String> rawLines,
  String stripped,
  int stmtStart,
  String header, {
  required bool isFieldOrAbstract,
  required int Function(int) lineForOffset,
  required List<String> violations,
}) {
  final staticMatch = RegExp(r'\bstatic\b').firstMatch(header);
  if (staticMatch == null) return;

  final headerLine = lineForOffset(stmtStart + staticMatch.start);

  // Check if it is a static field (no `(` before `=` or `;` and not `get`/`set`)
  final beforeEqOrSemi = header.split(RegExp(r'[=;]')).first;
  final hasParenInDecl = beforeEqOrSemi.contains('(');
  final isGetterOrSetter = RegExp(r'\bstatic\s+(?:[A-Za-z0-9_<>,?\s]+\s+)?(?:get|set)\b')
      .hasMatch(beforeEqOrSemi);

  if (isFieldOrAbstract && !hasParenInDecl && !isGetterOrSetter) {
    if (!RegExp(r'\bstatic\s+const\b').hasMatch(beforeEqOrSemi)) {
      violations.add(
        '$filePath:$headerLine: non-const static field: ${rawLines[headerLine - 1].trim()}',
      );
    }
    return;
  }

  // Otherwise check if it's a public static function/method
  final openParenRel = header.indexOf('(');
  if (openParenRel == -1) return;
  final beforeParen = header.substring(0, openParenRel).trim();
  final fnNameMatch = RegExp(r'([A-Za-z_]\w*)$').firstMatch(beforeParen);
  if (fnNameMatch == null) return;
  final fnName = fnNameMatch.group(1)!;
  if (fnName.startsWith('_')) return; // private static function

  // Extract parameter list between `(` and matching `)`
  int depth = 1;
  int p = openParenRel + 1;
  while (p < header.length && depth > 0) {
    if (header[p] == '(') depth++;
    if (header[p] == ')') depth--;
    p++;
  }
  final paramsText = header.substring(openParenRel + 1, p - 1);
  final paramsOffsetInFile = stmtStart + openParenRel + 1;

  // Check for optional positional parameter `[`
  final bracketIdx = paramsText.indexOf('[');
  if (bracketIdx != -1) {
    final lineNo = lineForOffset(paramsOffsetInFile + bracketIdx);
    violations.add(
      '$filePath:$lineNo: optional positional parameter in $fnName: ${rawLines[lineNo - 1].trim()}',
    );
  }

  // Check for nullable parameter (`?`)
  for (final qMatch in RegExp(r'\?').allMatches(paramsText)) {
    final lineNo = lineForOffset(paramsOffsetInFile + qMatch.start);
    violations.add(
      '$filePath:$lineNo: nullable parameter in $fnName: ${rawLines[lineNo - 1].trim()}',
    );
  }
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

        if (importsServiceContainer(path, content) &&
            !path.startsWith('lib/infrastructure/di/')) {
          violations.add('$path:1: service container imported outside di');
        }

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

  group('Service Locator Bars (Rule 4: The container knows no services)', () {
    test('In-memory controls flag service import and is type test, allow clean container', () {
      const containerWithServiceImport = '''
import '../../services/dice_room_service.dart';
class InjectionContainer {}
''';
      const containerWithTypeTest = '''
class InjectionContainer {
  void registerSingleton<T>(T instance) {
    if (instance is Foo) {}
  }
}
''';
      const cleanContainer = '''
class InjectionContainer {
  final Map<Type, dynamic> _singletons = {};
  void registerSingleton<T>(T instance) {
    _singletons[T] = instance;
  }
  void reset() {
    _singletons.clear();
  }
}
''';

      expect(
        findServiceContainerViolations(
          kServiceContainerTarget,
          containerWithServiceImport,
        ),
        isNotEmpty,
        reason: 'Control: service import in container must be flagged',
      );
      expect(
        findServiceContainerViolations(
          kServiceContainerTarget,
          containerWithTypeTest,
        ),
        isNotEmpty,
        reason: 'Control: ` is ` type test in container must be flagged',
      );
      expect(
        findServiceContainerViolations(
          kServiceContainerTarget,
          cleanContainer,
        ),
        isEmpty,
        reason: 'Control: clean container must pass',
      );
    });

    test('lib/infrastructure/di/service_container.dart exists and knows no services', () {
      final file = File(kServiceContainerTarget);
      if (!file.existsSync()) {
        final fallbackFile = File(kInjectionContainerTarget);
        final fallbackViolations = fallbackFile.existsSync()
            ? findServiceContainerViolations(
                kInjectionContainerTarget,
                fallbackFile.readAsStringSync(),
              )
            : <String>[];
        fail(
          'Missing $kServiceContainerTarget (container is still in $kInjectionContainerTarget with ${fallbackViolations.length} violations:\n${fallbackViolations.take(10).join('\n')})',
        );
      }

      final content = file.readAsStringSync();
      final violations = findServiceContainerViolations(
        kServiceContainerTarget,
        content,
      );

      if (violations.isNotEmpty) {
        fail('Rule 4 violations in $kServiceContainerTarget:\n${violations.join('\n')}');
      }
      expect(violations, isEmpty);
    });
  });

  group('Service Locator Bars (Rule 5: Test hooks are called only by tests)', () {
    test('In-memory controls flag external ForTesting call and allow call in declaring file', () {
      const externalCaller = '''
void cleanup() {
  Foo.resetForTesting();
}
''';
      const declaringCaller = '''
class Foo {
  static void resetForTesting() {}
  static void fullResetForTesting() {
    resetForTesting();
  }
}
''';

      expect(
        findForTestingCallViolations('lib/other.dart', externalCaller),
        equals(['lib/other.dart:2: Foo.resetForTesting();']),
      );
      expect(
        findForTestingCallViolations('lib/foo.dart', declaringCaller),
        isEmpty,
      );
    });

    test('No calls to *ForTesting( in lib/ outside the file that declares that member', () {
      final libDir = Directory('lib');
      final dartFiles = libDir
          .listSync(recursive: true)
          .whereType<File>()
          .where((f) => f.path.endsWith('.dart'))
          .toList();

      final violations = <String>[];
      for (final file in dartFiles) {
        final path = normalizePath(file.path);
        final content = file.readAsStringSync();
        violations.addAll(findForTestingCallViolations(path, content));
      }

      if (violations.isNotEmpty) {
        fail('Rule 5 (*ForTesting call) violations:\n${violations.join('\n')}');
      }
      expect(violations, isEmpty);
    });
  });

  group('Service Locator Bars (Rule 6: Collaborator fields read only in _require...())', () {
    test('In-memory controls flag direct collaborator field read in broadcast() and allow _requireTransport()', () {
      const badClass = '''
class DiceRoomService {
  IP2pTransportPort? _transport;
  void bind({required IP2pTransportPort transport}) {
    _transport = transport;
  }
  static void resetForTesting() {
    _instance._transport = null;
  }
  IP2pTransportPort _requireTransport() {
    final t = _transport;
    if (t != null) return t;
    throw StateError('unbound');
  }
  Future<void> broadcast() async {
    final t = _transport;
    if (t == null) return;
    await t.broadcastPayload('{}');
  }
}
''';
      const goodClass = '''
class DiceRoomService {
  IP2pTransportPort? _transport;
  void bind({required IP2pTransportPort transport}) {
    _transport = transport;
  }
  static void resetForTesting() {
    _instance._transport = null;
  }
  IP2pTransportPort _requireTransport() {
    final t = _transport;
    if (t != null) return t;
    throw StateError('unbound');
  }
  Future<void> broadcast() async {
    final t = _requireTransport();
    await t.broadcastPayload('{}');
  }
}
''';

      final badViolations = findCollaboratorFieldAccessViolations(
        'lib/services/dice_room_service.dart',
        badClass,
        {'_transport'},
      );
      expect(
        badViolations,
        equals(['lib/services/dice_room_service.dart:15: final t = _transport;']),
      );

      final goodViolations = findCollaboratorFieldAccessViolations(
        'lib/services/dice_room_service.dart',
        goodClass,
        {'_transport'},
      );
      expect(goodViolations, isEmpty);
    });

    test('Collaborator fields in the three service files are accessed only in allowed places', () {
      final violations = <String>[];
      for (final entry in kCollaboratorFieldsByServiceFile.entries) {
        final file = File(entry.key);
        expect(file.existsSync(), isTrue, reason: 'Missing ${entry.key}');
        final content = file.readAsStringSync();
        violations.addAll(
          findCollaboratorFieldAccessViolations(
            entry.key,
            content,
            entry.value,
          ),
        );
      }

      if (violations.isNotEmpty) {
        fail('Rule 6 (collaborator field access) violations:\n${violations.join('\n')}');
      }
      expect(violations, isEmpty);
    });
  });

  group('Service Locator Bars (Rule 7: CampaignStorageMigration stateless and required non-null params)', () {
    test('In-memory controls flag nullable parameter and non-const static field, allow required non-null parameters', () {
      const withNullableParam = '''
class CampaignStorageMigration {
  static Future<void> run({StatefulHlcClock? clock}) async {}
}
''';
      const withStaticField = '''
class CampaignStorageMigration {
  static ICampaignRepository? _repo;
  static Future<void> run({required StatefulHlcClock clock}) async {}
}
''';
      const cleanMigration = '''
class CampaignStorageMigration {
  static const int kVersion = 1;
  static Future<void> run({
    required ICampaignRepository repository,
    required StatefulHlcClock clock,
  }) async {}
}
''';

      expect(
        findCampaignStorageMigrationViolations(
          kCampaignStorageMigrationTarget,
          withNullableParam,
        ),
        isNotEmpty,
        reason: 'Control: nullable parameter in public static function must be flagged',
      );
      expect(
        findCampaignStorageMigrationViolations(
          kCampaignStorageMigrationTarget,
          withStaticField,
        ),
        isNotEmpty,
        reason: 'Control: non-const static field must be flagged',
      );
      expect(
        findCampaignStorageMigrationViolations(
          kCampaignStorageMigrationTarget,
          cleanMigration,
        ),
        isEmpty,
        reason: 'Control: clean stateless migration with required non-null params must pass',
      );
    });

    test('lib/infrastructure/repositories/campaign_storage_migration.dart has no non-const static fields and only non-null required parameters', () {
      final file = File(kCampaignStorageMigrationTarget);
      expect(
        file.existsSync(),
        isTrue,
        reason: 'Missing $kCampaignStorageMigrationTarget',
      );
      final content = file.readAsStringSync();
      final violations = findCampaignStorageMigrationViolations(
        kCampaignStorageMigrationTarget,
        content,
      );

      if (violations.isNotEmpty) {
        fail(
          'Rule 7 ($kCampaignStorageMigrationTarget) violations:\n${violations.join('\n')}',
        );
      }
      expect(violations, isEmpty);
    });
  });
}
