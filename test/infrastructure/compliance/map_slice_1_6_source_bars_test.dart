import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Map Slice 1.6 Source Bars Compliance', () {
    ({List<({String name, String content})> files, List<String> problems}) readFolders(List<String> folderPaths) {
      final files = <({String name, String content})>[];
      final problems = <String>[];
      for (final dirPath in folderPaths) {
        final dir = Directory(dirPath);
        if (!dir.existsSync()) {
          problems.add('Folder does not exist: $dirPath');
          continue;
        }
        final dartFiles = dir
            .listSync(recursive: true)
            .whereType<File>()
            .where((f) => f.path.endsWith('.dart'))
            .toList();
        if (dartFiles.isEmpty) {
          problems.add('Folder contains no .dart files: $dirPath');
          continue;
        }
        for (final f in dartFiles) {
          files.add((name: f.path.replaceAll(r'\', '/'), content: f.readAsStringSync()));
        }
      }
      return (files: files, problems: problems);
    }

    test('SB29: .moveToken( appears only in map_token_mover.dart; .placeToken( only in map_token_picker.dart; .removeToken( and .setMinionOwner( only in map_token_panel.dart', () {
      const moveTokenToken = '.move' 'Token(';
      const placeTokenToken = '.place' 'Token(';
      const removeTokenToken = '.remove' 'Token(';
      const setMinionOwnerToken = '.set' 'MinionOwner(';

      List<String> scanFor(List<({String name, String content})> files, String token, List<String> allowedFiles) {
        final violations = <String>[];
        for (final f in files) {
          if (f.content.contains(token)) {
            final isAllowed = allowedFiles.any((allowed) => f.name.endsWith(allowed));
            if (!isAllowed) {
              violations.add('${f.name} contains $token but is not in $allowedFiles');
            }
          }
        }
        return violations;
      }

      final readResult = readFolders(['lib']);
      expect(readResult.problems, isEmpty);

      final moveViolations = scanFor(readResult.files, moveTokenToken, ['map_token_mover.dart']);
      expect(moveViolations, isEmpty, reason: 'SB29 moveToken violations: $moveViolations');

      // Also verify it actually appears in map_token_mover.dart
      final moverFiles = readResult.files.where((f) => f.name.endsWith('map_token_mover.dart')).toList();
      expect(moverFiles, isNotEmpty);
      expect(moverFiles.first.content.contains(moveTokenToken), isTrue);

      final presentationFiles = readResult.files.where((f) => f.name.contains('/presentation/')).toList();

      final placeViolations = scanFor(presentationFiles, placeTokenToken, ['map_token_picker.dart']);
      expect(placeViolations, isEmpty, reason: 'SB29 placeToken violations: $placeViolations');
      final pickerFiles = presentationFiles.where((f) => f.name.endsWith('map_token_picker.dart')).toList();
      expect(pickerFiles, isNotEmpty);
      expect(pickerFiles.first.content.contains(placeTokenToken), isTrue);

      final removeViolations = scanFor(presentationFiles, removeTokenToken, ['map_token_panel.dart']);
      expect(removeViolations, isEmpty, reason: 'SB29 removeToken violations: $removeViolations');

      final setOwnerViolations = scanFor(presentationFiles, setMinionOwnerToken, ['map_token_panel.dart']);
      expect(setOwnerViolations, isEmpty, reason: 'SB29 setMinionOwner violations: $setOwnerViolations');

      final panelFiles = presentationFiles.where((f) => f.name.endsWith('map_token_panel.dart')).toList();
      expect(panelFiles, isNotEmpty);
      expect(panelFiles.first.content.contains(removeTokenToken), isTrue);
      expect(panelFiles.first.content.contains(setMinionOwnerToken), isTrue);

      // Controls
      final badFiles = [
        (name: 'lib/bad_file.dart', content: 'service' '$moveTokenToken);'),
      ];
      expect(scanFor(badFiles, moveTokenToken, ['map_token_mover.dart']), hasLength(1));
    });

    test('SB30: map_token_mover.dart and map_token_candidates.dart import nothing from package:flutter', () {
      const flutterPkg = 'package:' 'flutter';

      List<String> scanForFlutter(List<({String name, String content})> files) {
        final violations = <String>[];
        for (final f in files) {
          if (f.content.contains(flutterPkg)) {
            violations.add('${f.name} imports $flutterPkg');
          }
        }
        return violations;
      }

      final readResult = readFolders(['lib/application/map']);
      expect(readResult.problems, isEmpty);

      final targetFiles = readResult.files.where((f) =>
          f.name.endsWith('map_token_mover.dart') ||
          f.name.endsWith('map_token_candidates.dart')).toList();
      expect(targetFiles, hasLength(2));

      final violations = scanForFlutter(targetFiles);
      expect(violations, isEmpty, reason: 'SB30 violations: $violations');

      // Control
      final badFiles = [(name: 'lib/application/map/bad.dart', content: "import '$flutterPkg/material.dart';")];
      expect(scanForFlutter(badFiles), hasLength(1));
    });

    test('SB31: Under lib/presentation/widgets/map/, activeProfile appears only in map_token_picker.dart', () {
      const activeProfileToken = 'active' 'Profile';

      List<String> scanForActiveProfile(List<({String name, String content})> files) {
        final violations = <String>[];
        for (final f in files) {
          if (f.content.contains(activeProfileToken) && !f.name.endsWith('map_token_picker.dart')) {
            violations.add('${f.name} contains $activeProfileToken');
          }
        }
        return violations;
      }

      final readResult = readFolders(['lib/presentation/widgets/map']);
      expect(readResult.problems, isEmpty);

      final violations = scanForActiveProfile(readResult.files);
      expect(violations, isEmpty, reason: 'SB31 violations: $violations');

      // Verify it appears in map_token_picker.dart
      final pickerFiles = readResult.files.where((f) => f.name.endsWith('map_token_picker.dart')).toList();
      expect(pickerFiles, isNotEmpty);
      expect(pickerFiles.first.content.contains(activeProfileToken), isTrue);

      // Control
      final badFiles = [(name: 'lib/presentation/widgets/map/bad.dart', content: 'final p = s.$activeProfileToken;')];
      expect(scanForActiveProfile(badFiles), hasLength(1));
    });

    test('SB32: Under lib/presentation/, none of canMoveToken(, .minionOwner(, .partyRoster, or .activeMinions appears; in map_token_rules.dart, canMoveToken calls canMoveTokenWith( and contains no MapTokenKind.', () {
      const canMoveTokenToken = 'canMove' 'Token(';
      const minionOwnerToken = '.minion' 'Owner(';
      const partyRosterToken = '.' 'party' 'Roster';
      const activeMinionsToken = '.' 'active' 'Minions';
      final forbiddenPresentationTokens = [
        canMoveTokenToken,
        minionOwnerToken,
        partyRosterToken,
        activeMinionsToken,
      ];

      List<String> scanForForbidden(List<({String name, String content})> files, List<String> tokens) {
        final violations = <String>[];
        for (final f in files) {
          for (final token in tokens) {
            if (f.content.contains(token)) {
              violations.add('${f.name} contains $token');
            }
          }
        }
        return violations;
      }

      final readResult = readFolders([
        'lib/presentation/widgets/map',
        'lib/presentation/screens/map',
      ]);
      expect(readResult.problems, isEmpty);

      // Also check full lib/presentation
      final fullPresentationRead = readFolders(['lib/presentation']);
      expect(fullPresentationRead.problems, isEmpty);

      final violations = scanForForbidden(fullPresentationRead.files, forbiddenPresentationTokens);
      expect(violations, isEmpty, reason: 'SB32 presentation violations: $violations');

      // Check map_token_rules.dart
      final rulesFile = File('lib/application/map/map_token_rules.dart');
      expect(rulesFile.existsSync(), isTrue);
      final rulesContent = rulesFile.readAsStringSync();

      const canMoveTokenWithToken = 'canMove' 'TokenWith(';
      const mapTokenKindToken = 'MapToken' 'Kind.';

      // Extract canMoveToken function body: find matching closing brace
      final startIdx = rulesContent.indexOf('bool canMoveToken(');
      expect(startIdx, isNot(-1));
      final openBrace = rulesContent.indexOf('{', startIdx);
      int depth = 0;
      int closeBrace = openBrace;
      for (int i = openBrace; i < rulesContent.length; i++) {
        if (rulesContent[i] == '{') depth++;
        if (rulesContent[i] == '}') {
          depth--;
          if (depth == 0) {
            closeBrace = i;
            break;
          }
        }
      }
      final canMoveTokenBody = rulesContent.substring(openBrace, closeBrace + 1);

      expect(canMoveTokenBody.contains(canMoveTokenWithToken), isTrue,
          reason: 'canMoveToken must call canMoveTokenWith(');
      expect(canMoveTokenBody.contains(mapTokenKindToken), isFalse,
          reason: 'canMoveToken body must contain no MapTokenKind.');

      // Controls
      final badFiles = [(name: 'lib/presentation/bad.dart', content: 'if ($canMoveTokenToken) {}')];
      expect(scanForForbidden(badFiles, forbiddenPresentationTokens), hasLength(1));
    });

    test('SB33: Files under lib/presentation/widgets/map/ contain none of MaterialPageRoute, .push(, .pushNamed(, or .pushReplacement(', () {
      const materialPageRouteToken = 'Material' 'PageRoute';
      const pushToken = '.' 'push(';
      const pushNamedToken = '.' 'pushNamed(';
      const pushReplacementToken = '.' 'pushReplacement(';

      final forbiddenTokens = [
        materialPageRouteToken,
        pushToken,
        pushNamedToken,
        pushReplacementToken,
      ];

      List<String> scanForNavigation(List<({String name, String content})> files) {
        final violations = <String>[];
        for (final f in files) {
          for (final token in forbiddenTokens) {
            if (f.content.contains(token)) {
              violations.add('${f.name} contains $token');
            }
          }
        }
        return violations;
      }

      final readResult = readFolders(['lib/presentation/widgets/map']);
      expect(readResult.problems, isEmpty);

      final violations = scanForNavigation(readResult.files);
      expect(violations, isEmpty, reason: 'SB33 violations: $violations');

      // Control
      final badFiles = [(name: 'lib/presentation/widgets/map/bad.dart', content: 'Navigator$pushToken route);')];
      expect(scanForNavigation(badFiles), hasLength(1));
    });
  });
}
