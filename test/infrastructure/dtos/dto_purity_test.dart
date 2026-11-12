import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

import '../../support/flutter_free_packages.dart';

List<String> scanFolderForDtoViolations(String folderPath) {
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
      final line = lines[i];
      for (final uri in extractImportExportUris(line)) {
        if (isFlutterBoundUri(uri)) {
          violations.add('${file.path}:${i + 1} -> $line');
        }
      }
    }
  }
  return violations;
}

void main() {
  group('Infrastructure DTO Architecture Purity Tests', () {
    test(
        'Ensures no files in lib/infrastructure/dtos/ import package:flutter/...',
        () {
      final dtosDir = Directory('lib/infrastructure/dtos');
      expect(dtosDir.existsSync(), isTrue,
          reason: 'lib/infrastructure/dtos directory must exist');

      final violations = scanFolderForDtoViolations('lib/infrastructure/dtos');

      expect(
        violations,
        isEmpty,
        reason:
            'DTO layer files must NOT import Flutter-bound packages (Infrastructure Purity Directive). Violations:\n${violations.join('\n')}',
      );
    });

    test('negative case: DTO file importing package:flutter/material.dart is reported', () {
      final tempDir = Directory.systemTemp.createTempSync('dto_flutter_negative_test_');
      addTearDown(() {
        if (tempDir.existsSync()) {
          tempDir.deleteSync(recursive: true);
        }
      });
      final violatingFile = File('${tempDir.path}/violating_dto.dart');
      violatingFile.writeAsStringSync("import 'package:flutter/material.dart';\nclass A {}\n");

      final violations = scanFolderForDtoViolations(tempDir.path);
      expect(violations, isNotEmpty);
      expect(violations.first, contains('package:flutter/material.dart'));
    });

    test('negative case: DTO file importing package:material_ui/material_ui.dart is reported', () {
      final tempDir = Directory.systemTemp.createTempSync('dto_material_ui_negative_test_');
      addTearDown(() {
        if (tempDir.existsSync()) {
          tempDir.deleteSync(recursive: true);
        }
      });
      final violatingFile = File('${tempDir.path}/violating_dto.dart');
      violatingFile.writeAsStringSync("import 'package:material_ui/material_ui.dart';\nclass B {}\n");

      final violations = scanFolderForDtoViolations(tempDir.path);
      expect(violations, isNotEmpty);
      expect(violations.first, contains('material_ui'));
    });
  });
}
