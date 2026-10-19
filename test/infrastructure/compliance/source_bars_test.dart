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
        'Source Bar G: Active production code in lib/ must not use partyCharacterIds as CampaignProfile authority input (partyRoster is authoritative)',
        () {
      final dartFiles = getDartFiles();
      expect(dartFiles, isNotEmpty);

      // Whitelisted explicit migration/compatibility boundaries
      final allowedMigrationPaths = <String>[
        'lib/infrastructure/dtos/campaign_profile_dto.dart',
        'lib/infrastructure/dtos/migrations/',
      ];

      final violations = <String>[];
      final targets = [
        'CampaignProfile(',
        'CampaignProfile.raw(',
        'CampaignProfile.initial(',
        '.copyWith(',
      ];

      for (final file in dartFiles) {
        final normalizedPath = file.path.replaceAll(r'\\', '/');
        if (allowedMigrationPaths.any((p) => normalizedPath.endsWith(p) || normalizedPath.contains(p))) {
          continue;
        }

        final content = file.readAsStringSync();
        for (final target in targets) {
          var pos = 0;
          while (true) {
            final idx = content.indexOf(target, pos);
            if (idx == -1) break;

            final parenStart = idx + target.length - 1;
            var depth = 1;
            var cur = parenStart + 1;
            while (cur < content.length && depth > 0) {
              if (content[cur] == '(') {
                depth++;
              } else if (content[cur] == ')') {
                depth--;
              }
              cur++;
            }

            final callBody = content.substring(parenStart, cur);
            if (callBody.contains('partyCharacterIds:')) {
              final lineNumber = content.substring(0, idx).split('\n').length;
              final snippet = content.substring(idx, cur.clamp(0, idx + 120)).replaceAll('\n', ' ');
              violations.add('$normalizedPath:$lineNumber -> $snippet');
            }

            pos = idx + target.length;
          }
        }
      }

      expect(
        violations,
        isEmpty,
        reason:
            'Active production code must not use partyCharacterIds as CampaignProfile authority input (Source Bar G).\n'
            'Party membership authority is partyRoster (CrdtOrSet<String>), not legacy partyCharacterIds.\n'
            'Violations:\n${violations.join("\n")}',
      );
    });

    test(
        'Source Bar G unit validation: rejects copyWith(partyCharacterIds:) and CampaignProfile(partyCharacterIds:) while allowing migration boundary',
        () {
      bool hasPartyCharacterIdsViolation(String content) {
        final targets = [
          'CampaignProfile(',
          'CampaignProfile.raw(',
          'CampaignProfile.initial(',
          '.copyWith(',
        ];
        for (final target in targets) {
          var pos = 0;
          while (true) {
            final idx = content.indexOf(target, pos);
            if (idx == -1) break;
            final parenStart = idx + target.length - 1;
            var depth = 1;
            var cur = parenStart + 1;
            while (cur < content.length && depth > 0) {
              if (content[cur] == '(') depth++;
              if (content[cur] == ')') depth--;
              cur++;
            }
            final callBody = content.substring(parenStart, cur);
            if (callBody.contains('partyCharacterIds:')) return true;
            pos = idx + target.length;
          }
        }
        return false;
      }

      const badCopyWith = '''
        final updated = profile.copyWith(
          partyCharacterIds: ['char1', 'char2'],
        );
      ''';
      const badConstructor = '''
        final prof = CampaignProfile(
          id: 'camp_1',
          name: 'Camp 1',
          nodeId: 'node_1',
          createdAt: DateTime.now().toUtc(),
          lastPlayedAt: DateTime.now().toUtc(),
          partyCharacterIds: ['char1'],
          roomState: roomState,
        );
      ''';
      const goodConstructor = '''
        final prof = CampaignProfile(
          id: 'camp_1',
          name: 'Camp 1',
          nodeId: 'node_1',
          createdAt: DateTime.now().toUtc(),
          lastPlayedAt: DateTime.now().toUtc(),
          partyRoster: roster,
          roomState: roomState,
        );
      ''';
      const allowedMigrationPath = 'lib/infrastructure/dtos/campaign_profile_dto.dart';
      final allowedPaths = [
        'lib/infrastructure/dtos/campaign_profile_dto.dart',
        'lib/infrastructure/dtos/migrations/',
      ];

      expect(hasPartyCharacterIdsViolation(badCopyWith), isTrue);
      expect(hasPartyCharacterIdsViolation(badConstructor), isTrue);
      expect(hasPartyCharacterIdsViolation(goodConstructor), isFalse);
      expect(allowedPaths.any((p) => allowedMigrationPath.endsWith(p)), isTrue);
    });

    test(
        'Source Bar H: Active production code under lib/ must not use CrdtOrSet<RoomEntityLink> authority',
        () {
      final dartFiles = getDartFiles();
      expect(dartFiles, isNotEmpty);

      // Matches CrdtOrSet<RoomEntityLink> with flexible whitespace
      final legacyEntityLinkCrdtPattern =
          RegExp(r'\bCrdtOrSet\s*<\s*RoomEntityLink\s*>');
      final violations = <String>[];

      // Whitelisted explicit migration/compatibility boundaries
      final allowedMigrationPaths = <String>[
        'lib/infrastructure/dtos/migrations/',
      ];

      for (final file in dartFiles) {
        final normalizedPath = file.path.replaceAll('\\', '/');
        if (allowedMigrationPaths.any((p) => normalizedPath.contains(p))) {
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

          if (legacyEntityLinkCrdtPattern.hasMatch(line)) {
            violations.add('$normalizedPath:${i + 1} -> ${lines[i].trim()}');
          }
        }
      }

      expect(
        violations,
        isEmpty,
        reason:
            'CrdtOrSet<RoomEntityLink> as authoritative entity link representation is forbidden in lib/ (Source Bar H). '
            'Use EntityLinkCrdtSet instead. Violations:\n'
            '${violations.join('\n')}',
      );
    });

    test(
        'Source Bar H unit validation: rejects representative production pattern and allows migration boundary',
        () {
      final legacyPattern = RegExp(r'\bCrdtOrSet\s*<\s*RoomEntityLink\s*>');
      const badSnippet = 'final CrdtOrSet<RoomEntityLink> entityLinksCrdt;';
      const goodSnippet = 'final EntityLinkCrdtSet entityLinksCrdt;';
      const allowedMigrationPath =
          'lib/infrastructure/dtos/migrations/legacy_entity_link_migration.dart';

      expect(legacyPattern.hasMatch(badSnippet), isTrue);
      expect(legacyPattern.hasMatch(goodSnippet), isFalse);

      final allowedPaths = ['lib/infrastructure/dtos/migrations/'];
      expect(allowedPaths.any((p) => allowedMigrationPath.contains(p)), isTrue);
    });

    List<String> findImmutableConfigViolations(String content, [String filePath = '']) {
      final violations = <String>[];
      var pos = 0;
      while (true) {
        final idx = content.indexOf('.copyWith(', pos);
        if (idx == -1) break;

        var receiverEnd = idx;
        var receiverStart = receiverEnd - 1;
        while (receiverStart >= 0 &&
            (content[receiverStart] == ' ' || content[receiverStart] == '\n' || content[receiverStart] == '\r')) {
          receiverStart--;
          receiverEnd--;
        }
        while (receiverStart >= 0 &&
            (RegExp(r'[a-zA-Z0-9_\.]').hasMatch(content[receiverStart]) ||
                content[receiverStart] == ')' ||
                content[receiverStart] == '?')) {
          receiverStart--;
        }
        receiverStart++;
        final receiver = content.substring(receiverStart, receiverEnd).trim().replaceAll('?', '');

        final parenStart = idx + '.copyWith'.length;
        var depth = 1;
        var cur = parenStart + 1;
        while (cur < content.length && depth > 0) {
          if (content[cur] == '(') {
            depth++;
          } else if (content[cur] == ')') {
            depth--;
          }
          cur++;
        }

        final callBody = content.substring(parenStart, cur);

        final hasPosition = RegExp(r'\bposition\s*:').hasMatch(callBody);
        final hasIsVisible = RegExp(r'\bisVisible\s*:').hasMatch(callBody);
        final hasRuntimeData = RegExp(r'\bruntimeData\s*:').hasMatch(callBody);
        final hasCustomProperties = RegExp(r'\bcustomProperties\s*:').hasMatch(callBody);

        final isEntityInstanceOrLink = RegExp(
                r'(instance|entityinstance|link|entitylink|roomentitylink)',
                caseSensitive: false)
            .hasMatch(receiver);
        final isRoomNodeState = RegExp(
                r'(room|roomstate|roomnode|roomnodestate|node)',
                caseSensitive: false)
            .hasMatch(receiver);

        bool isViolation = false;
        if (hasPosition || hasIsVisible || hasRuntimeData) {
          if (isEntityInstanceOrLink || isRoomNodeState || receiver.isEmpty) {
            isViolation = true;
          }
        }
        if (hasCustomProperties) {
          if (isRoomNodeState || isEntityInstanceOrLink) {
            isViolation = true;
          }
        }

        if (isViolation) {
          final lineNumber = content.substring(0, idx).split('\n').length;
          final snippet = content.substring(receiverStart, cur.clamp(receiverStart, idx + 120)).replaceAll('\n', ' ');
          violations.add('$filePath:$lineNumber -> $snippet');
        }

        pos = idx + '.copyWith('.length;
      }
      return violations;
    }

    test(
        'Source Bar I: Active production code under lib/ must not mutate immutable configuration fields via copyWith on EntityInstance, RoomEntityLink, or RoomNodeState',
        () {
      final dartFiles = getDartFiles();
      expect(dartFiles, isNotEmpty);

      final violations = <String>[];

      for (final file in dartFiles) {
        final content = file.readAsStringSync();
        final fileViolations = findImmutableConfigViolations(content, file.path);
        violations.addAll(fileViolations);
      }

      expect(
        violations,
        isEmpty,
        reason:
            'Immutable configuration fields (position, isVisible, runtimeData, customProperties on EntityInstance/RoomEntityLink, '
            'and customProperties on RoomNodeState) must not be mutated via copyWith in lib/ (Source Bar I).\n'
            'Violations:\n${violations.join('\n')}',
      );
    });

    test(
        'Source Bar I unit validation: rejects representative immutable configuration mutations and allows character/compendium/homebrew customProperties',
        () {
      const badRoomCustomProps = '''
        final updatedRoom = roomState.copyWith(
          customProperties: {'theme': 'dungeon'},
        );
      ''';
      const badLinkPosition = '''
        final updatedLink = link.copyWith(
          position: {'x': 10, 'y': 20},
        );
      ''';
      const badInstanceVisibility = '''
        final updatedInst = entityInstance.copyWith(
          isVisible: false,
        );
      ''';
      const badInstanceRuntimeData = '''
        final updatedInst = instance.copyWith(
          runtimeData: {'hp': 10},
        );
      ''';
      const badLinkCustomProps = '''
        final updatedLink = entityLink.copyWith(
          customProperties: {'secret': true},
        );
      ''';

      const goodCharacterCustomProps = '''
        final updatedChar = character.copyWith(
          customProperties: {'favoriteFood': 'lembas'},
        );
      ''';
      const goodCompendiumCustomProps = '''
        final updatedCompendium = entry.copyWith(
          customProperties: {'sourceBook': 'PHB'},
        );
      ''';
      const goodRoomTitle = '''
        final updatedRoom = roomState.copyWith(
          title: 'Dragon Lair',
        );
      ''';

      expect(findImmutableConfigViolations(badRoomCustomProps), isNotEmpty);
      expect(findImmutableConfigViolations(badLinkPosition), isNotEmpty);
      expect(findImmutableConfigViolations(badInstanceVisibility), isNotEmpty);
      expect(findImmutableConfigViolations(badInstanceRuntimeData), isNotEmpty);
      expect(findImmutableConfigViolations(badLinkCustomProps), isNotEmpty);

      expect(findImmutableConfigViolations(goodCharacterCustomProps), isEmpty);
      expect(findImmutableConfigViolations(goodCompendiumCustomProps), isEmpty);
      expect(findImmutableConfigViolations(goodRoomTitle), isEmpty);
    });

    test(
        'Source Bar J: No string literal \'partyPurse\', \'memberPurses\', or \'characterRoster\' in lib/ files that import cloud_firestore, except party_ledger_legacy_import.dart',
        () {
      final dartFiles = getDartFiles();
      expect(dartFiles, isNotEmpty);

      final forbiddenLiterals = [
        'partyPurse',
        'memberPurses',
        'characterRoster',
      ];
      final violations = <String>[];

      for (final file in dartFiles) {
        final normalizedPath = file.path.replaceAll('\\', '/');
        if (normalizedPath.endsWith('party_ledger_legacy_import.dart')) {
          continue; // P5 legacy import exemption
        }

        final content = file.readAsStringSync();
        if (!content.contains('cloud_firestore')) {
          continue;
        }

        final lines = file.readAsLinesSync();
        for (var i = 0; i < lines.length; i++) {
          final line = lines[i];
          final trimmed = line.trim();
          if (trimmed.startsWith('//') ||
              trimmed.startsWith('/*') ||
              trimmed.startsWith('*')) {
            continue;
          }
          for (final literal in forbiddenLiterals) {
            if (line.contains("'$literal'") || line.contains('"$literal"')) {
              violations.add(
                  '$normalizedPath:${i + 1}: $trimmed (contains "$literal")');
            }
          }
        }
      }

      expect(
        violations,
        isEmpty,
        reason:
            'Files importing cloud_firestore must not contain legacy ledger literals (\'partyPurse\', \'memberPurses\', \'characterRoster\') (Source Bar J).\n'
            'Violations:\n${violations.join('\n')}',
      );
    });
  });
}

