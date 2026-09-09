import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Domain Architecture Purity Tests', () {
    test('Ensures no files in lib/domain/ import package:flutter/...', () {
      final domainDir = Directory('lib/domain');
      expect(domainDir.existsSync(), isTrue, reason: 'lib/domain directory must exist');

      final dartFiles = domainDir
          .listSync(recursive: true)
          .whereType<File>()
          .where((file) => file.path.endsWith('.dart'))
          .toList();

      expect(dartFiles, isNotEmpty, reason: 'There should be domain files to test');

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
            'Domain layer files must NOT import package:flutter/... (Directive 1: Domain-Driven Design). Violations:\n${violations.join('\n')}',
      );
    });
  });
}
