import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

/// Scans the given content for any occurrence of banned phrases.
List<String> scanForBannedPhrases(String content, {required String filePath}) {
  final bannedPhrases = [
    'event-sourced',
    'encrypted',
    'cryptographic validity',
    'animate objects tracker',
  ];

  final violations = <String>[];
  final lines = content.split('\n');

  for (int i = 0; i < lines.length; i++) {
    final line = lines[i];
    final lowerLine = line.toLowerCase();
    for (final phrase in bannedPhrases) {
      if (lowerLine.contains(phrase.toLowerCase())) {
        violations.add('$filePath:${i + 1} contains banned phrase "$phrase": "$line"');
      }
    }
  }

  return violations;
}

void main() {
  group('Cold Iron Pass 9 - R12 Documentation & Invariant Closure Tests', () {
    test('asserts absence of banned phrases across lib/, docs/, pubspec.yaml, and web assets', () {
      final filesToScan = <File>[];

      // 1. Scan all Dart files in lib/
      final libDir = Directory('lib');
      if (libDir.existsSync()) {
        filesToScan.addAll(
          libDir
              .listSync(recursive: true)
              .whereType<File>()
              .where((f) => f.path.endsWith('.dart')),
        );
      }

      // 2. Scan all Markdown files in docs/
      final docsDir = Directory('docs');
      if (docsDir.existsSync()) {
        filesToScan.addAll(
          docsDir
              .listSync(recursive: true)
              .whereType<File>()
              .where((f) => f.path.endsWith('.md')),
        );
      }

      // 3. Scan pubspec.yaml
      final pubspec = File('pubspec.yaml');
      if (pubspec.existsSync()) {
        filesToScan.add(pubspec);
      }

      // 4. Scan web manifest and index.html
      final webIndex = File('web/index.html');
      if (webIndex.existsSync()) {
        filesToScan.add(webIndex);
      }
      final webManifest = File('web/manifest.json');
      if (webManifest.existsSync()) {
        filesToScan.add(webManifest);
      }

      expect(filesToScan, isNotEmpty, reason: 'Expected to find files to scan');

      final allViolations = <String>[];
      for (final file in filesToScan) {
        final content = file.readAsStringSync();
        final violations = scanForBannedPhrases(content, filePath: file.path);
        allViolations.addAll(violations);
      }

      expect(
        allViolations,
        isEmpty,
        reason: 'Found banned phrase violations:\n${allViolations.join('\n')}',
      );
    });

    test('negative case: scanForBannedPhrases detects each banned phrase', () {
      const sample = '''
Line 1: Normal system architecture.
Line 2: Network state is event-sourced and replicated.
Line 3: Payload is encrypted using AES.
Line 4: Verified cryptographic validity.
Line 5: Launch Animate Objects tracker app.
''';

      final violations = scanForBannedPhrases(sample, filePath: 'sample.txt');
      expect(violations.length, 4);
      expect(violations[0], contains('event-sourced'));
      expect(violations[1], contains('encrypted'));
      expect(violations[2], contains('cryptographic validity'));
      expect(violations[3], contains('animate objects tracker'));
    });

    test('storage durability coordinator comment references checksum integrity', () {
      final file = File('lib/application/storage/storage_durability_coordinator.dart');
      expect(file.existsSync(), isTrue);
      final content = file.readAsStringSync();
      expect(content, contains('checksum integrity is already verified'));
      expect(content, isNot(contains('cryptographic validity')));
    });

    test('vtt-engine-core AGENTS.md does not claim encrypted frame contracts', () {
      final coreAgentsFile = File('../vtt-engine-core/AGENTS.md');
      if (coreAgentsFile.existsSync()) {
        final content = coreAgentsFile.readAsStringSync();
        expect(content, isNot(contains('Encrypted frame & payload contracts')));
        expect(content, contains('Replicated frame & payload contracts'));
      }
    });
  });
}
