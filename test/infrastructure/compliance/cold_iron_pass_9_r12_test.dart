import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

/// Scans the given content for any occurrence of banned phrases.
List<String> scanForBannedPhrases(String content, {required String filePath}) {
  final bannedPhrases = [
    'event-sourced',
    'encrypted',
    'cryptographic validity',
    'animate objects tracker',
    'LAN multicast',
    'Writer authority is partitioned',
    '_nodeSequenceVectors',
    'UDP health probing',
    'Strict Content Security Policy',
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
    test('asserts absence of banned phrases across lib/, docs/, pubspec.yaml, web assets, README.md, AGENTS.md, and .agents/rules/*.md', () {
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

      // 5. Scan README.md and AGENTS.md
      final readme = File('README.md');
      if (readme.existsSync()) {
        filesToScan.add(readme);
      }
      final agents = File('AGENTS.md');
      if (agents.existsSync()) {
        filesToScan.add(agents);
      }

      // 6. Scan .agents/rules/*.md
      final rulesDir = Directory('.agents/rules');
      if (rulesDir.existsSync()) {
        filesToScan.addAll(
          rulesDir
              .listSync(recursive: true)
              .whereType<File>()
              .where((f) => f.path.endsWith('.md')),
        );
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
Line 6: Discovered via LAN multicast in network.
Line 7: Writer authority is partitioned across nodes.
Line 8: Vectors stored in _nodeSequenceVectors field.
Line 9: Using UDP health probing on sockets.
Line 10: Strict Content Security Policy configured.
''';

      final violations = scanForBannedPhrases(sample, filePath: 'sample.txt');
      expect(violations.length, 9);
      expect(violations[0], contains('event-sourced'));
      expect(violations[1], contains('encrypted'));
      expect(violations[2], contains('cryptographic validity'));
      expect(violations[3], contains('animate objects tracker'));
      expect(violations[4], contains('LAN multicast'));
      expect(violations[5], contains('Writer authority is partitioned'));
      expect(violations[6], contains('_nodeSequenceVectors'));
      expect(violations[7], contains('UDP health probing'));
      expect(violations[8], contains('Strict Content Security Policy'));
    });

    test('storage durability coordinator comment references checksum integrity', () {
      final file = File('lib/application/storage/storage_durability_coordinator.dart');
      expect(file.existsSync(), isTrue);
      final content = file.readAsStringSync();
      expect(content, contains('checksum integrity is already verified'));
      expect(content, isNot(contains('cryptographic validity')));
    });

    test('docs/ARCHITECTURE.md contains Trust model as built section and required keywords', () {
      final file = File('docs/ARCHITECTURE.md');
      expect(file.existsSync(), isTrue);
      final content = file.readAsStringSync();
      expect(content, contains('## Trust model as built'));

      final trustSection = content.split('## Trust model as built').last;
      expect(trustSection, contains('room code'));
      expect(trustSection, contains('SHA-256'));
      expect(trustSection, contains('not authorised'));
      expect(trustSection, contains('App Check'));
    });
  });
}
