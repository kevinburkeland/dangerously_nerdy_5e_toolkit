import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Infrastructure DTO Architecture Purity Tests', () {
    test('Ensures no files in lib/infrastructure/dtos/ import package:flutter/...', () {
      final dtosDir = Directory('lib/infrastructure/dtos');
      expect(dtosDir.existsSync(), isTrue, reason: 'lib/infrastructure/dtos directory must exist');

      final dartFiles = dtosDir
          .listSync(recursive: true)
          .whereType<File>()
          .where((file) => file.path.endsWith('.dart'))
          .toList();

      expect(dartFiles, isNotEmpty, reason: 'There should be DTO files to test');

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

      expect(
        violations,
        isEmpty,
        reason:
            'DTO layer files must NOT import package:flutter/... (Infrastructure Purity Directive). Violations:\n${violations.join('\n')}',
      );
    });
  });
}
