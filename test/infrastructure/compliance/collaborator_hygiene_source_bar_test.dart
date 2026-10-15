import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Pass 6 Source Bar: Collaborator Hygiene & Hook Elimination', () {
    late final List<File> allDartFiles;

    setUpAll(() {
      final packageConfigFile = File('.dart_tool/package_config.json');
      expect(packageConfigFile.existsSync(), isTrue, reason: '.dart_tool/package_config.json must exist');

      final packageConfig = jsonDecode(packageConfigFile.readAsStringSync()) as Map<String, dynamic>;
      final packages = packageConfig['packages'] as List<dynamic>;

      final corePkg = packages.firstWhere(
        (p) => p['name'] == 'vtt_engine_core',
        orElse: () => null,
      );
      final rulesetPkg = packages.firstWhere(
        (p) => p['name'] == 'vtt_ruleset_dnd5e',
        orElse: () => null,
      );

      expect(corePkg, isNotNull, reason: 'vtt_engine_core package must be configured');
      expect(rulesetPkg, isNotNull, reason: 'vtt_ruleset_dnd5e package must be configured');

      final coreLibDir = Directory('${Uri.parse(corePkg['rootUri'] as String).toFilePath()}/lib');
      final rulesetLibDir = Directory('${Uri.parse(rulesetPkg['rootUri'] as String).toFilePath()}/lib');
      final appLibDir = Directory('lib');

      expect(coreLibDir.existsSync(), isTrue, reason: 'vtt_engine_core lib directory must exist: ${coreLibDir.path}');
      expect(rulesetLibDir.existsSync(), isTrue, reason: 'vtt_ruleset_dnd5e lib directory must exist: ${rulesetLibDir.path}');
      expect(appLibDir.existsSync(), isTrue, reason: 'app lib directory must exist: ${appLibDir.path}');

      final files = <File>[];
      for (final dir in [coreLibDir, rulesetLibDir, appLibDir]) {
        files.addAll(
          dir
              .listSync(recursive: true)
              .whereType<File>()
              .where((f) => f.path.endsWith('.dart') && !f.path.endsWith('.g.dart')),
        );
      }

      allDartFiles = files;
    });

    test('Rule 1: No static fields (neither const nor final) with nullable or function-typedef types', () {
      final violations = <String>[];

      // Collect all typedef names across allDartFiles
      final typedefPattern = RegExp(r'\btypedef\s+(\w+)\s*=');
      final allTypedefs = <String>{};
      for (final file in allDartFiles) {
        final content = file.readAsStringSync();
        for (final match in typedefPattern.allMatches(content)) {
          allTypedefs.add(match.group(1)!);
        }
      }

      // Pattern for static field (neither const nor final) with nullable type:
      // static [late] Type? name [= ...];
      final nullableStaticFieldPattern = RegExp(
        r'\bstatic\s+(?!const\b|final\b)(?:late\s+)?(?:[\w<>,?\s]+?)\?\s+([a-zA-Z0-9_]+)\s*(?:=|;)',
      );

      // Pattern for static field with inline Function type:
      // static [late] ... Function(...) name [= ...];
      final inlineFunctionFieldPattern = RegExp(
        r'\bstatic\s+(?!const\b|final\b)[^;=\(\)]*\bFunction\s*[\(<]',
      );

      for (final file in allDartFiles) {
        final lines = file.readAsLinesSync();
        bool inBlockComment = false;

        for (int i = 0; i < lines.length; i++) {
          var line = lines[i].trim();

          // Strip block comments
          if (inBlockComment) {
            if (line.contains('*/')) {
              line = line.substring(line.indexOf('*/') + 2).trim();
              inBlockComment = false;
            } else {
              continue;
            }
          }
          if (line.startsWith('/*')) {
            if (!line.contains('*/')) {
              inBlockComment = true;
              continue;
            } else {
              line = line.substring(line.indexOf('*/') + 2).trim();
            }
          }

          // Strip single-line comments
          final codeOnly = line.split('//').first.trim();
          if (codeOnly.isEmpty) continue;

          // Exclude getters, setters, and static methods
          if (RegExp(r'\bstatic\s+(?!const\b|final\b).*\b(get|set)\b').hasMatch(codeOnly)) {
            continue;
          }

          bool isViolation = nullableStaticFieldPattern.hasMatch(codeOnly);

          if (!isViolation && inlineFunctionFieldPattern.hasMatch(codeOnly)) {
            isViolation = true;
          }

          if (!isViolation && codeOnly.startsWith('static ') && !codeOnly.contains('(')) {
            for (final td in allTypedefs) {
              if (RegExp('\\bstatic\\s+(?!const\\b|final\\b)(?:late\\s+)?$td\\s+[a-zA-Z0-9_]+\\s*(?:=|;)').hasMatch(codeOnly)) {
                isViolation = true;
                break;
              }
            }
          }

          if (isViolation) {
            final normalized = file.path.replaceAll('\\', '/');

            // Allowlist 1: Dnd5eRuleset._catalog in dnd5e_catalog.dart (ruleset)
            // Required SPI gateway for standalone ruleset module to access host catalog.
            if (normalized.endsWith('dnd5e_catalog.dart') && codeOnly.contains('_catalog')) {
              continue;
            }

            // Allowlist 2: MinionStats.defaultProvider in minion_instance.dart (app)
            // Pass 6 known debt: allowlisted defaultProvider fallback; to be replaced in a later pass.
            if (normalized.endsWith('minion_instance.dart') && codeOnly.contains('defaultProvider')) {
              continue;
            }

            violations.add('${file.path}:${i + 1} - $codeOnly');
          }
        }
      }

      expect(
        violations,
        isEmpty,
        reason: 'Forbidden mutable static fields with nullable or function-typedef types found:\n${violations.join('\n')}',
      );
    });

    test('Rule 2: No top-level final initialized with immediately invoked closure (= () { ... }();)', () {
      final violations = <String>[];
      final topLevelFinalClosurePattern = RegExp(r'^final\s+[\w<>,?\s]+=\s*\(\s*\)\s*(async\s*)?\{[\s\S]*?\}\s*\(\s*\)\s*;', multiLine: true);

      for (final file in allDartFiles) {
        final content = file.readAsStringSync();
        // Remove block comments and line comments for clean matching
        final cleanedContent = content
            .replaceAll(RegExp(r'/\*[\s\S]*?\*/'), '')
            .split('\n')
            .map((line) => line.split('//').first)
            .join('\n');

        final matches = topLevelFinalClosurePattern.allMatches(cleanedContent);
        for (final match in matches) {
          violations.add('${file.path}: ${match.group(0)?.split('\n').first}...');
        }
      }

      expect(
        violations,
        isEmpty,
        reason: 'Forbidden top-level lazy finals with immediately-invoked closures found:\n${violations.join('\n')}',
      );
    });

    test('Rule 3: No ??= assignment to a field on a ruleset or core class', () {
      final violations = <String>[];
      final classFieldNullAssignPattern = RegExp(r'\b([A-Z]\w+)\.([a-zA-Z0-9_]+)\s*\?\?=');

      for (final file in allDartFiles) {
        final lines = file.readAsLinesSync();
        bool inBlockComment = false;

        for (int i = 0; i < lines.length; i++) {
          var line = lines[i].trim();

          if (inBlockComment) {
            if (line.contains('*/')) {
              line = line.substring(line.indexOf('*/') + 2).trim();
              inBlockComment = false;
            } else {
              continue;
            }
          }
          if (line.startsWith('/*')) {
            if (!line.contains('*/')) {
              inBlockComment = true;
              continue;
            } else {
              line = line.substring(line.indexOf('*/') + 2).trim();
            }
          }

          final codeOnly = line.split('//').first.trim();
          if (codeOnly.isEmpty) continue;

          final match = classFieldNullAssignPattern.firstMatch(codeOnly);
          if (match != null) {
            violations.add('${file.path}:${i + 1} - $codeOnly');
          }
        }
      }

      expect(
        violations,
        isEmpty,
        reason: 'Forbidden ??= assignment to class field found:\n${violations.join('\n')}',
      );
    });
  });
}
