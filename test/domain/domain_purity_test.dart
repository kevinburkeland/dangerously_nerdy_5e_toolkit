import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

List<String> parsePureFoldersFromDocs(String docContent) {
  final match = RegExp(
    r'^Pure Dart folders \(checked by test/domain/domain_purity_test\.dart\):\s*(.+)$',
    multiLine: true,
  ).firstMatch(docContent);
  if (match == null) {
    throw StateError(
      'docs/ARCHITECTURE.md must contain "Pure Dart folders (checked by test/domain/domain_purity_test.dart): <folders>"',
    );
  }
  final foldersStr = match.group(1)!.trim();
  return foldersStr.split(RegExp(r'[\s,]+')).where((s) => s.isNotEmpty).toList();
}

List<String> scanFolderForFlutterImports(String folderPath) {
  final dir = Directory(folderPath);
  if (!dir.existsSync()) {
    return ['Folder does not exist: $folderPath'];
  }
  final dartFiles = dir
      .listSync(recursive: true)
      .whereType<File>()
      .where((file) => file.path.endsWith('.dart'))
      .toList();
  final violations = <String>[];
  for (final file in dartFiles) {
    final lines = file.readAsLinesSync();
    for (var i = 0; i < lines.length; i++) {
      final line = lines[i].trim();
      if (line.startsWith('import') && line.contains('package:flutter/')) {
        violations.add('${file.path}:${i + 1} -> $line');
      }
    }
  }
  return violations;
}

void main() {
  group('Domain Architecture Purity Tests', () {
    test('Reads pure Dart folders from docs/ARCHITECTURE.md and ensures zero Flutter imports', () {
      final docFile = File('docs/ARCHITECTURE.md');
      expect(docFile.existsSync(), isTrue, reason: 'docs/ARCHITECTURE.md must exist');
      final content = docFile.readAsStringSync();

      final folders = parsePureFoldersFromDocs(content);
      expect(folders, isNotEmpty, reason: 'Must declare at least one pure Dart folder');

      final allViolations = <String>[];
      for (final folder in folders) {
        final violations = scanFolderForFlutterImports(folder);
        allViolations.addAll(violations);
      }

      expect(
        allViolations,
        isEmpty,
        reason:
            'Declared pure Dart folders must NOT import package:flutter/... (Domain Purity Directive). Violations:\n${allViolations.join('\n')}',
      );
    });

    test('negative case: temp folder with a Flutter import listed in sample doc line is reported', () {
      final tempDir = Directory.systemTemp.createTempSync('pure_dart_negative_test_');
      addTearDown(() {
        if (tempDir.existsSync()) {
          tempDir.deleteSync(recursive: true);
        }
      });

      final violatingFile = File('${tempDir.path}/violating_domain.dart');
      violatingFile.writeAsStringSync("import 'package:flutter/material.dart';\nclass A {}\n");

      final sampleDoc = 'Pure Dart folders (checked by test/domain/domain_purity_test.dart): ${tempDir.path}';
      final folders = parsePureFoldersFromDocs(sampleDoc);
      expect(folders, contains(tempDir.path));

      final violations = scanFolderForFlutterImports(tempDir.path);
      expect(violations, isNotEmpty);
      expect(violations.first, contains('package:flutter/material.dart'));
      expect(violations.first, contains('violating_domain.dart'));
    });
  });
}
