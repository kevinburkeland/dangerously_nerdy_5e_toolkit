import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Cold Iron Birdcage — Pass 3.3 Source Bars & Architectural Invariants', () {
    final libDir = Directory('lib');

    List<File> getDartFiles() {
      expect(libDir.existsSync(), isTrue, reason: 'lib directory must exist');
      return libDir
          .listSync(recursive: true)
          .whereType<File>()
          .where((file) =>
              file.path.endsWith('.dart') && !file.path.endsWith('.g.dart'))
          .toList();
    }

    test(
        'Source Bar C: StatefulHlcClock constructor is forbidden under lib/ EXCEPT lib/infrastructure/di/',
        () {
      final dartFiles = getDartFiles();
      expect(dartFiles, isNotEmpty);

      final clockPattern = RegExp(r'\bStatefulHlcClock\s*\(');
      final violations = <String>[];

      for (final file in dartFiles) {
        final normalizedPath = file.path.replaceAll('\\', '/');
        // Exact approved DI path
        if (normalizedPath.contains('lib/infrastructure/di/')) {
          continue;
        }

        final lines = file.readAsLinesSync();
        bool inBlockComment = false;

        for (var i = 0; i < lines.length; i++) {
          var line = lines[i].trim();

          // Block comment tracking
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

          // Single-line comment removal
          if (line.startsWith('//') || line.startsWith('*')) {
            continue;
          }
          final commentIdx = line.indexOf('//');
          if (commentIdx != -1) {
            line = line.substring(0, commentIdx).trim();
          }

          if (clockPattern.hasMatch(line)) {
            violations.add('$normalizedPath:${i + 1} -> ${lines[i].trim()}');
          }
        }
      }

      expect(
        violations,
        isEmpty,
        reason:
            'StatefulHlcClock construction is forbidden outside lib/infrastructure/di/ (Source Bar C). Violations:\n'
            '${violations.join('\n')}',
      );
    });

    test(
        'Source Bar D: Literal ReplicaId construction ReplicaId(\'...\') is forbidden anywhere in lib/',
        () {
      final dartFiles = getDartFiles();
      expect(dartFiles, isNotEmpty);

      // Matches ReplicaId('...') and ReplicaId("...")
      final literalReplicaPattern =
          RegExp(r'''\bReplicaId\s*\(\s*['"][^'"]*['"]\s*\)''');
      final violations = <String>[];

      for (final file in dartFiles) {
        final normalizedPath = file.path.replaceAll('\\', '/');
        final lines = file.readAsLinesSync();
        bool inBlockComment = false;

        for (var i = 0; i < lines.length; i++) {
          var line = lines[i].trim();

          // Block comment tracking
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

          // Single-line comment removal
          if (line.startsWith('//') || line.startsWith('*')) {
            continue;
          }
          final commentIdx = line.indexOf('//');
          if (commentIdx != -1) {
            line = line.substring(0, commentIdx).trim();
          }

          if (literalReplicaPattern.hasMatch(line)) {
            violations.add('$normalizedPath:${i + 1} -> ${lines[i].trim()}');
          }
        }
      }

      expect(
        violations,
        isEmpty,
        reason:
            'Literal ReplicaId construction is forbidden in production lib/ (Source Bar D). Violations:\n'
            '${violations.join('\n')}',
      );
    });

    test(
        'Source Bar E: Known local mutation and load services must NOT call observeRemote',
        () {
      final forbiddenFiles = [
        'lib/application/services/combat_encounter_service.dart',
        'lib/providers/dm_dashboard_controller.dart',
      ];
      final observeRemotePattern = RegExp(r'\b_?clock\.observeRemote\s*\(');
      final violations = <String>[];

      for (final relPath in forbiddenFiles) {
        final file = File(relPath);
        if (!file.existsSync()) continue;
        final lines = file.readAsLinesSync();
        for (var i = 0; i < lines.length; i++) {
          final line = lines[i];
          if (line.trim().startsWith('//')) continue;
          if (observeRemotePattern.hasMatch(line)) {
            violations.add('$relPath:${i + 1} -> ${line.trim()}');
          }
        }
      }

      expect(
        violations,
        isEmpty,
        reason:
            'Known local mutation services must not call observeRemote (Source Bar E). Violations:\n'
            '${violations.join('\n')}',
      );
    });

    test(
        'Source Bar F: Active production code in lib/ must not call CampaignProfile.copyWith(pinnedRuleIds: ...)',
        () {
      final dartFiles = getDartFiles();
      expect(dartFiles, isNotEmpty);

      final copyWithPattern = RegExp(r'\.copyWith\s*\([^)]*\bpinnedRuleIds\s*:', dotAll: true);
      final violations = <String>[];

      for (final file in dartFiles) {
        final content = file.readAsStringSync();
        for (final match in copyWithPattern.allMatches(content)) {
          final matchedText = match.group(0)!;
          if (file.path.contains('settings_provider.dart')) {
            continue;
          }
          final lineNumber = content.substring(0, match.start).split('\n').length;
          violations.add('${file.path}:$lineNumber -> $matchedText');
        }
      }

      expect(
        violations,
        isEmpty,
        reason:
            'Active production code must not call CampaignProfile.copyWith(pinnedRuleIds: ...) (Source Bar F). Violations:\n'
            '${violations.join('\n')}',
      );
    });

    test(
        'Source Bar G: Active production code in lib/ must not call CampaignProfile.copyWith(partyCharacterIds: ...)',
        () {
      final dartFiles = getDartFiles();
      expect(dartFiles, isNotEmpty);

      final copyWithPattern = RegExp(r'\.copyWith\s*\([^)]*\bpartyCharacterIds\s*:', dotAll: true);
      final violations = <String>[];

      for (final file in dartFiles) {
        final content = file.readAsStringSync();
        for (final match in copyWithPattern.allMatches(content)) {
          final matchedText = match.group(0)!;
          final lineNumber = content.substring(0, match.start).split('\n').length;
          violations.add('${file.path}:$lineNumber -> $matchedText');
        }
      }

      expect(
        violations,
        isEmpty,
        reason:
            'Active production code must not call CampaignProfile.copyWith(partyCharacterIds: ...) (Source Bar G). Violations:\n'
            '${violations.join('\n')}',
      );
    });
  });
}

