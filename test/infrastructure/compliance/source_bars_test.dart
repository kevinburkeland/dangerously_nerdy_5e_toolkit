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
        final hasRoomCode = RegExp(r'\broomCode\s*:').hasMatch(callBody);
        final hasRoomId = RegExp(r'\broomId\s*:').hasMatch(callBody);

        final isEntityInstanceOrLink = RegExp(
                r'(instance|entityinstance|link|entitylink|roomentitylink)',
                caseSensitive: false)
            .hasMatch(receiver);
        final isRoomNodeState = RegExp(
                r'(room|roomstate|roomnode|roomnodestate|node)',
                caseSensitive: false)
            .hasMatch(receiver);

        final isRelinkFile = filePath.replaceAll('\\', '/').endsWith('lib/services/party/room_code_relink.dart');

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
        if ((hasRoomCode || hasRoomId) && !isRelinkFile) {
          if (isRoomNodeState || receiver.isEmpty) {
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
            'Immutable configuration fields (position, isVisible, runtimeData, customProperties, roomCode, roomId on RoomNodeState/EntityInstance/RoomEntityLink) '
            'must not be mutated via copyWith in lib/ except in room_code_relink.dart (Source Bar I).\n'
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
      const badRoomCode = '''
        final updatedRoom = roomState.copyWith(
          roomCode: 'NEW_CODE',
        );
      ''';
      const badRoomId = '''
        final updatedRoom = roomState.copyWith(
          roomId: 'room_NEW_CODE',
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
      expect(findImmutableConfigViolations(badRoomCode), isNotEmpty);
      expect(findImmutableConfigViolations(badRoomId), isNotEmpty);

      expect(
        findImmutableConfigViolations(
          badRoomCode,
          'lib/services/party/room_code_relink.dart',
        ),
        isEmpty,
      );
      expect(
        findImmutableConfigViolations(
          badRoomId,
          'lib/services/party/room_code_relink.dart',
        ),
        isEmpty,
      );

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

    test(
        'Pass 7.1 Source Bar 1: Member purses writes and arguments in lib/ are restricted to allowlist',
        () {
      final dartFiles = getDartFiles();
      expect(dartFiles, isNotEmpty);

      final allowlist = [
        'party_ledger_operations.dart',
        'party_ledger_legacy_import.dart',
        'room_state_reconciliation_service.dart',
        'campaign_profile_dto.dart',
        'lib/models/party/party_session_state.dart',
      ];

      final violations = <String>[];

      for (final file in dartFiles) {
        final normalizedPath = file.path.replaceAll('\\', '/');
        if (allowlist.any((allowed) => normalizedPath.endsWith(allowed))) {
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
          if (line.startsWith('//') || line.startsWith('*')) {
            continue;
          }
          final commentIdx = line.indexOf('//');
          if (commentIdx != -1) {
            line = line.substring(0, commentIdx).trim();
          }

          // Check memberPurses[...] = assignment
          if (RegExp(r'\bmemberPurses\s*\[.*\]\s*=').hasMatch(line)) {
            violations.add('$normalizedPath:${i + 1} -> ${lines[i].trim()}');
            continue;
          }

          // Check memberPurses: argument
          if (RegExp(r'\bmemberPurses\s*:').hasMatch(line)) {
            // Allowed: memberPurses: const {}
            if (RegExp(r'\bmemberPurses\s*:\s*const\s*\{\s*\}').hasMatch(line)) {
              continue;
            }
            // Allowed: inside PartySessionState constructor
            bool isPartySessionState = false;
            for (var back = i; back >= 0 && back >= i - 30; back--) {
              if (lines[back].contains('PartySessionState(') ||
                  lines[back].contains('PartySessionState (')) {
                isPartySessionState = true;
                break;
              }
              if (back < i &&
                  (lines[back].endsWith(';') ||
                      lines[back].contains('CampaignProfile(') ||
                      lines[back].contains('.copyWith('))) {
                break;
              }
            }
            if (isPartySessionState) {
              continue;
            }

            violations.add('$normalizedPath:${i + 1} -> ${lines[i].trim()}');
          }
        }
      }

      expect(
        violations,
        isEmpty,
        reason:
            'Member purses arguments and writes outside allowlist are forbidden (Pass 7.1 Source Bar 1).\n'
            'Violations:\n${violations.join('\n')}',
      );
    });

    test(
        'Pass 7.1 Source Bar 2: Lobby campaignId writes and arguments are restricted to createCampaign, PartyRoomLobby, and ensureRoomExists',
        () {
      final dartFiles = getDartFiles();
      expect(dartFiles, isNotEmpty);

      // The sync payload\'s campaignId: in room_sync_payload_mapper.dart and room_sync_orchestrator.dart is a different type; allow those two files by name with a comment.
      // The blob store\'s campaignId: parameter in blob_transfer_service.dart represents blob ownership; allow by name.
      final allowedFilesByName = [
        'party_room_lobby.dart',
        'room_sync_payload_mapper.dart',
        'room_sync_orchestrator.dart',
        'blob_transfer_service.dart',
      ];

      final violations = <String>[];

      for (final file in dartFiles) {
        final normalizedPath = file.path.replaceAll('\\', '/');
        if (allowedFilesByName.any((name) => normalizedPath.endsWith(name))) {
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
          if (line.startsWith('//') || line.startsWith('*')) {
            continue;
          }
          final commentIdx = line.indexOf('//');
          if (commentIdx != -1) {
            line = line.substring(0, commentIdx).trim();
          }

          // Strip string literals to avoid matching messages like 'without lobby campaignId: ...'
          final nonStringLine = line.replaceAll(RegExp(r'''('[^']*'|"[^"]*")'''), '');

          // Check campaignId: argument
          if (RegExp(r'\bcampaignId\s*:').hasMatch(nonStringLine)) {
            // Find enclosing function by scanning backwards
            bool inCreateCampaign = false;
            for (var back = i; back >= 0 && back >= i - 60; back--) {
              if (lines[back].contains('Future<void> createCampaign(') ||
                  lines[back].contains('createCampaign(')) {
                inCreateCampaign = true;
                break;
              }
            }
            if (!inCreateCampaign) {
              violations.add('$normalizedPath:${i + 1} -> ${lines[i].trim()}');
            }
          }

          // Check 'campaignId': map key
          if (RegExp(r'''['"]campaignId['"]\s*:''').hasMatch(line)) {
            // Only allowed in ensureRoomExists
            bool inEnsureRoomExists = false;
            for (var back = i; back >= 0 && back >= i - 60; back--) {
              if (lines[back].contains('Future<void> ensureRoomExists(') ||
                  lines[back].contains('ensureRoomExists(')) {
                inEnsureRoomExists = true;
                break;
              }
            }
            if (!inEnsureRoomExists) {
              violations.add('$normalizedPath:${i + 1} -> ${lines[i].trim()}');
            }
          }
        }
      }

      expect(
        violations,
        isEmpty,
        reason:
            'PartyRoomLobby campaignId writes/arguments outside createCampaign and ensureRoomExists are forbidden (Pass 7.1 Source Bar 2).\n'
            'Violations:\n${violations.join('\n')}',
      );
    });

    test(
        'Pass 7.1 Source Bar 3: No RoomNodeState creation in lib/ with title/description without timestamps',
        () {
      final dartFiles = getDartFiles();
      expect(dartFiles, isNotEmpty);

      final violations = <String>[];

      for (final file in dartFiles) {
        final normalizedPath = file.path.replaceAll('\\', '/');
        final content = file.readAsStringSync();

        // Strip single-line and multi-line comments from content while preserving line breaks
        final stripped = StringBuffer();
        var idx = 0;
        bool inBlock = false;
        while (idx < content.length) {
          if (inBlock) {
            if (idx + 1 < content.length &&
                content[idx] == '*' &&
                content[idx + 1] == '/') {
              inBlock = false;
              idx += 2;
            } else {
              if (content[idx] == '\n') stripped.write('\n');
              idx++;
            }
          } else if (idx + 1 < content.length &&
              content[idx] == '/' &&
              content[idx + 1] == '*') {
            inBlock = true;
            idx += 2;
          } else if (idx + 1 < content.length &&
              content[idx] == '/' &&
              content[idx + 1] == '/') {
            while (idx < content.length && content[idx] != '\n') {
              idx++;
            }
          } else {
            stripped.write(content[idx]);
            idx++;
          }
        }

        final cleanContent = stripped.toString();
        final patterns = [
          'RoomNodeState(',
          'RoomNodeState.fromLegacyCrdtOrSet(',
        ];

        for (final pat in patterns) {
          var searchPos = 0;
          while (true) {
            final matchPos = cleanContent.indexOf(pat, searchPos);
            if (matchPos == -1) break;

            final parenStart = matchPos + pat.length - 1;
            var depth = 1;
            var cur = parenStart + 1;
            while (cur < cleanContent.length && depth > 0) {
              if (cleanContent[cur] == '(') {
                depth++;
              } else if (cleanContent[cur] == ')') {
                depth--;
              }
              cur++;
            }

            final callBody = cleanContent.substring(parenStart, cur);
            final hasTitle = RegExp(r'\btitle\s*:').hasMatch(callBody);
            final hasTitleTs = RegExp(r'\btitleTimestamp\s*:').hasMatch(callBody);
            final hasDesc = RegExp(r'\bdescription\s*:').hasMatch(callBody);
            final hasDescTs = RegExp(r'\bdescriptionTimestamp\s*:').hasMatch(callBody);

            if ((hasTitle && !hasTitleTs) || (hasDesc && !hasDescTs)) {
              final lineNum = cleanContent.substring(0, matchPos).split('\n').length;
              final snippet = cleanContent
                  .substring(matchPos, cur.clamp(matchPos, matchPos + 120))
                  .replaceAll('\n', ' ');
              violations.add('$normalizedPath:$lineNum -> $snippet');
            }

            searchPos = matchPos + pat.length;
          }
        }
      }

      expect(
        violations,
        isEmpty,
        reason:
            'RoomNodeState constructor calls passing title or description without timestamps are forbidden (Pass 7.1 Source Bar 3).\n'
            'Violations:\n${violations.join('\n')}',
      );
    });

    test(
        'Source Bar K: No empty or unintentional catches across all of lib/',
        () {
      final filesToCheck = getDartFiles();
      expect(filesToCheck, isNotEmpty);

      final violations = <String>[];
      for (final file in filesToCheck) {
        final content = file.readAsStringSync();
        final fileViolations = _findEmptyCatchViolations(content);
        for (final v in fileViolations) {
          violations.add('${file.path}:$v');
        }
      }

      expect(
        violations,
        isEmpty,
        reason:
            'Empty or unintentional catches forbidden across lib/ (Source Bar K).\n'
            'Violations:\n${violations.join('\n')}',
      );
    });

    test(
        'Source Bar L: No (<expr> - 10) ~/ 2 ability modifier calculations under lib/ (must use Dnd5eScoreMath.scoreToModifier)',
        () {
      final dartFiles = getDartFiles();
      expect(dartFiles, isNotEmpty);

      // Matches (expr - 10) ~/ 2 with flexible whitespace
      final modifierPattern = RegExp(r'-\s*10\s*\)\s*~/\s*2');
      final violations = <String>[];

      for (final file in dartFiles) {
        final lines = file.readAsLinesSync();
        for (var i = 0; i < lines.length; i++) {
          final line = lines[i];
          final trimmed = line.trim();
          if (trimmed.startsWith('//') ||
              trimmed.startsWith('*') ||
              trimmed.startsWith('/*')) {
            continue;
          }
          if (modifierPattern.hasMatch(line)) {
            violations.add('${file.path}:${i + 1} -> $trimmed');
          }
        }
      }

      expect(
        violations,
        isEmpty,
        reason:
            'Active production code under lib/ must not calculate ability modifiers using (<expr> - 10) ~/ 2; '
            'use Dnd5eScoreMath.scoreToModifier (Source Bar L).\n'
            'Violations:\n${violations.join('\n')}',
      );
    });

    test('Source Bar L unit validation: rejects (<expr> - 10) ~/ 2 patterns', () {
      final modifierPattern = RegExp(r'-\s*10\s*\)\s*~/\s*2');
      expect(modifierPattern.hasMatch('(score - 10) ~/ 2'), isTrue);
      expect(
          modifierPattern.hasMatch('(finalScores.dexterity - 10) ~/ 2'), isTrue);
      expect(modifierPattern.hasMatch('(total - 10)~/2'), isTrue);
      expect(
          modifierPattern.hasMatch('Dnd5eScoreMath.scoreToModifier(total)'),
          isFalse);
    });

    test(
        'Source Bar K unit validation: catches empty/unintentional blocks and allows // intentional:',
        () {
      // Negative case 1: catch (_) {}
      expect(
        _findEmptyCatchViolations('void f() { try { a(); } catch (_) {} }'),
        isNotEmpty,
      );

      // Negative case 2: catch (e) {}
      expect(
        _findEmptyCatchViolations('void f() { try { a(); } catch (e) {} }'),
        isNotEmpty,
      );

      // Negative case 3: catch (e, st) { across lines }
      expect(
        _findEmptyCatchViolations(
            'void f() { try { a(); } catch (e, st) {\n  \n} }'),
        isNotEmpty,
      );

      // Negative case 4: catch with non-intentional comment
      expect(
        _findEmptyCatchViolations(
            'void f() { try { a(); } catch (e) {\n  // non-fatal comment\n} }'),
        isNotEmpty,
      );

      // Positive case 1: catch with // intentional:
      expect(
        _findEmptyCatchViolations(
            'void f() { try { a(); } catch (_) {\n  // intentional: error reported by write queue\n} }'),
        isEmpty,
      );

      // Positive case 2: catch with logNonFatal
      expect(
        _findEmptyCatchViolations(
            'void f() { try { a(); } catch (e, st) {\n  LoggingService().logNonFatal(e, st);\n} }'),
        isEmpty,
      );
    });

    test(
        'Source Bar M: CampaignProfile.raw( may appear only in approved sites with count 1',
        () {
      final dartFiles = getDartFiles();
      expect(dartFiles, isNotEmpty);

      const approvedCounts = {
        'lib/infrastructure/dtos/campaign_profile_dto.dart': 1,
        'lib/application/services/room_state_reconciliation_service.dart': 1,
        'lib/infrastructure/repositories/campaign_storage_migration.dart': 1,
      };

      final occurrencesByFile = <String, List<int>>{};
      final violations = <String>[];

      for (final file in dartFiles) {
        final normalizedPath = file.path.replaceAll('\\', '/');
        final content = file.readAsStringSync();

        final stripped = StringBuffer();
        var idx = 0;
        bool inBlock = false;
        while (idx < content.length) {
          if (inBlock) {
            if (idx + 1 < content.length &&
                content[idx] == '*' &&
                content[idx + 1] == '/') {
              inBlock = false;
              idx += 2;
            } else {
              if (content[idx] == '\n') stripped.write('\n');
              idx++;
            }
          } else if (idx + 1 < content.length &&
              content[idx] == '/' &&
              content[idx + 1] == '*') {
            inBlock = true;
            idx += 2;
          } else if (idx + 1 < content.length &&
              content[idx] == '/' &&
              content[idx + 1] == '/') {
            while (idx < content.length && content[idx] != '\n') {
              idx++;
            }
          } else {
            stripped.write(content[idx]);
            idx++;
          }
        }

        final cleanContent = stripped.toString();
        const target = 'CampaignProfile.raw(';
        final lines = cleanContent.split('\n');

        for (var i = 0; i < lines.length; i++) {
          final line = lines[i];
          var pos = 0;
          while (true) {
            final matchPos = line.indexOf(target, pos);
            if (matchPos == -1) break;
            final lineNum = i + 1;
            occurrencesByFile.putIfAbsent(normalizedPath, () => []).add(lineNum);
            pos = matchPos + target.length;
          }
        }
      }

      for (final entry in occurrencesByFile.entries) {
        final path = entry.key;
        final lines = entry.value;
        final expected = approvedCounts.entries
            .where((e) => path.endsWith(e.key))
            .map((e) => e.value)
            .firstOrNull;

        if (expected == null) {
          for (final line in lines) {
            violations.add('Disallowed site $path:$line -> CampaignProfile.raw(');
          }
        } else if (lines.length != expected) {
          violations.add(
              'Wrong count for $path: expected $expected, found ${lines.length} at lines $lines');
        }
      }

      for (final approved in approvedCounts.entries) {
        final matchingPath = occurrencesByFile.keys
            .where((k) => k.endsWith(approved.key))
            .firstOrNull;
        if (matchingPath == null) {
          violations.add(
              'Missing expected site: ${approved.key} (expected count ${approved.value}, got 0)');
        }
      }

      expect(
        violations,
        isEmpty,
        reason:
            'CampaignProfile.raw( may only appear in the 3 approved sites with count 1 (Source Bar M):\n'
            '${violations.join('\n')}',
      );
    });
  });
}

List<String> _findEmptyCatchViolations(String content) {
  final violations = <String>[];
  final catchPattern = RegExp(r'\bcatch\s*(\([^\)]*\))?\s*\{');
  for (final match in catchPattern.allMatches(content)) {
    final startBrace = match.end - 1;
    var depth = 1;
    var cur = startBrace + 1;
    while (cur < content.length && depth > 0) {
      if (content[cur] == '{') {
        depth++;
      } else if (content[cur] == '}') {
        depth--;
      }
      cur++;
    }
    final body = content.substring(startBrace + 1, cur - 1);
    final lineNum = content.substring(0, match.start).split('\n').length;

    final lines = body.split('\n');
    final nonCommentLines = <String>[];
    final intentionalComments = <String>[];
    for (final line in lines) {
      final trimmed = line.trim();
      if (trimmed.isEmpty) continue;
      if (trimmed.startsWith('// intentional:')) {
        intentionalComments.add(trimmed);
      } else if (trimmed.startsWith('//') ||
          trimmed.startsWith('/*') ||
          trimmed.startsWith('*')) {
        // regular comment
      } else {
        nonCommentLines.add(trimmed);
      }
    }

    if (nonCommentLines.isEmpty && intentionalComments.isEmpty) {
      violations.add('$lineNum -> ${match.group(0)}$body}');
    }
  }
  return violations;
}

