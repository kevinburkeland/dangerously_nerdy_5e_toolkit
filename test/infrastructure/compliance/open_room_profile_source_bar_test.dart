import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Exact allowlist of `lib/` files permitted to call `openRoomProfile(`.
///
/// Why a source bar is used instead of a type boundary: `openRoomProfile` must
/// remain public on `PartyRoomService` for `PartyRoomScreen` in `lib/screens/`,
/// and Dart has no friend/package-private visibility to hide it from `lib/widgets/`.
const Set<String> kOpenRoomProfileCallerAllowlist = {
  'lib/services/party/party_room_service.dart',
  'lib/screens/party_room_screen.dart',
  'lib/services/party/shared_room_campaign_opener.dart',
};

String normalizeSourceBarPath(String path) {
  return path.replaceAll('\\', '/').replaceFirst(RegExp(r'^\./'), '');
}

/// Strips `//` line comments (including `///` doc comments) and `/* ... */`
/// block comments while preserving line numbers.
String stripCommentsPreservingLines(String source) {
  final lines = source.split('\n');
  final out = <String>[];
  bool inBlock = false;
  for (final rawLine in lines) {
    final sb = StringBuffer();
    int i = 0;
    while (i < rawLine.length) {
      if (inBlock) {
        final endIdx = rawLine.indexOf('*/', i);
        if (endIdx == -1) {
          i = rawLine.length;
        } else {
          inBlock = false;
          i = endIdx + 2;
        }
      } else {
        if (rawLine.startsWith('//', i)) {
          break;
        } else if (rawLine.startsWith('/*', i)) {
          inBlock = true;
          i += 2;
        } else {
          sb.write(rawLine[i]);
          i++;
        }
      }
    }
    out.add(sb.toString());
  }
  return out.join('\n');
}

/// Finds all non-declaration calls to `openRoomProfile(` in [source] (after
/// stripping comments), returning formatted `$filePath:$line: $trimmedLine`
/// strings.
List<String> findOpenRoomProfileCalls(String filePath, String source) {
  final normPath = normalizeSourceBarPath(filePath);
  final strippedLines = stripCommentsPreservingLines(source).split('\n');
  final rawLines = source.split('\n');
  final callRegex = RegExp(r'\bopenRoomProfile\s*\(');
  final declPrefixRegex = RegExp(
    r'\bFuture\s*<\s*CampaignProfile\s*\??\s*>\s*$',
  );

  final calls = <String>[];
  for (int i = 0; i < strippedLines.length; i++) {
    final line = strippedLines[i];
    for (final match in callRegex.allMatches(line)) {
      final prefix = line.substring(0, match.start);
      if (declPrefixRegex.hasMatch(prefix)) {
        continue;
      }
      calls.add('$normPath:${i + 1}: ${rawLines[i].trim()}');
    }
  }
  return calls;
}

/// Evaluates `filesByPath` against [allowlist].
/// Returns violations for any unallowlisted caller and any stale allowlist entry.
List<String> evaluateOpenRoomProfileSourceBar(
  Map<String, String> filesByPath, {
  Set<String> allowlist = kOpenRoomProfileCallerAllowlist,
}) {
  final problems = <String>[];
  final filesWithCalls = <String>{};

  final sortedPaths = filesByPath.keys.toList()..sort();
  for (final rawPath in sortedPaths) {
    final path = normalizeSourceBarPath(rawPath);
    final calls = findOpenRoomProfileCalls(path, filesByPath[rawPath]!);
    if (calls.isNotEmpty) {
      filesWithCalls.add(path);
      if (!allowlist.contains(path)) {
        problems.addAll(calls);
      }
    }
  }

  for (final allowed in allowlist) {
    if (!filesWithCalls.contains(allowed)) {
      problems.add(
        '$allowed:1: stale allowlist entry (no call to openRoomProfile() found)',
      );
    }
  }

  return problems;
}

void main() {
  group('openRoomProfile Source Bar — Fix 1.3', () {
    test('Controls (in memory): widget file with a call is flagged with its line; doc comment mentioning it is not flagged; stale allowlist entry fails', () {
      const widgetWithCall = '''
class SomeWidget {
  Future<void> connect(String effectiveRoom) async {
    await PartyRoomService().openRoomProfile(effectiveRoom);
  }
}
''';
      const fileWithDocCommentOnly = '''
/// Only campaign entry paths call [openRoomProfile] or `openRoomProfile(code)`.
/* openRoomProfile(ignoredInBlockComment) */
// PartyRoomService().openRoomProfile(ignoredInLineComment);
class CleanHelper {}
''';
      const allowedPartyService = '''
class PartyRoomService {
  Future<CampaignProfile> openRoomProfile(String roomCode) async => throw UnimplementedError();
  Future<void> create() async {
    await openRoomProfile('ROOM-1');
  }
}
''';
      const allowedPartyScreen = '''
class PartyRoomScreenState {
  Future<void> init() async {
    await _partyService.openRoomProfile(_roomCode);
  }
}
''';
      const allowedOpener = '''
class SharedRoomCampaignOpener {
  Future<CampaignProfile?> openIfCampaign(String code) {
    return party.openRoomProfile(code);
  }
}
''';

      // Control 1: widget file with a call is flagged and named with its line
      final widgetProblems = evaluateOpenRoomProfileSourceBar({
        'lib/services/party/party_room_service.dart': allowedPartyService,
        'lib/screens/party_room_screen.dart': allowedPartyScreen,
        'lib/services/party/shared_room_campaign_opener.dart': allowedOpener,
        'lib/widgets/room_banner_widget.dart': widgetWithCall,
      });
      expect(
        widgetProblems,
        equals([
          'lib/widgets/room_banner_widget.dart:3: await PartyRoomService().openRoomProfile(effectiveRoom);',
        ]),
      );

      // Control 2: doc/line/block comments mentioning openRoomProfile are not flagged
      final commentProblems = evaluateOpenRoomProfileSourceBar({
        'lib/services/party/party_room_service.dart': allowedPartyService,
        'lib/screens/party_room_screen.dart': allowedPartyScreen,
        'lib/services/party/shared_room_campaign_opener.dart': allowedOpener,
        'lib/widgets/comment_only_widget.dart': fileWithDocCommentOnly,
      });
      expect(commentProblems, isEmpty);

      // Control 3: allowlist entry with no call fails as stale
      final staleProblems = evaluateOpenRoomProfileSourceBar({
        'lib/services/party/party_room_service.dart': allowedPartyService,
        'lib/screens/party_room_screen.dart': allowedPartyScreen,
        'lib/services/party/shared_room_campaign_opener.dart': fileWithDocCommentOnly,
      });
      expect(
        staleProblems,
        equals([
          'lib/services/party/shared_room_campaign_opener.dart:1: stale allowlist entry (no call to openRoomProfile() found)',
        ]),
      );
    });

    test('Only campaign entry paths in kOpenRoomProfileCallerAllowlist call openRoomProfile( in lib/', () {
      final libDir = Directory('lib');
      expect(libDir.existsSync(), isTrue, reason: 'lib directory must exist');

      final dartFiles = libDir
          .listSync(recursive: true, followLinks: false)
          .whereType<File>()
          .where((f) => f.path.endsWith('.dart'))
          .toList()
        ..sort((a, b) => a.path.compareTo(b.path));

      expect(dartFiles, isNotEmpty);

      final filesByPath = <String, String>{};
      for (final file in dartFiles) {
        final path = normalizeSourceBarPath(file.path);
        filesByPath[path] = file.readAsStringSync();
      }

      final problems = evaluateOpenRoomProfileSourceBar(filesByPath);
      expect(
        problems,
        isEmpty,
        reason:
            'openRoomProfile source bar violations:\n${problems.join('\n')}',
      );
    });
  });
}
