import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Matches File('...') / Directory('...') calls whose literal path is outside
/// lib/ and test/ (and not .dart_tool/), or Directory.current / repoRoot walks.
final RegExp _outsidePathPattern = RegExp(
  r'''\b(?:File|Directory)\(\s*['"]([^'"]+)['"]''',
);
final RegExp _repoWalkPattern = RegExp(
  r'''\bDirectory\.current\b|\bDirectory\(\s*repoRoot\b''',
);
final RegExp _repoTextTagPattern = RegExp(
  r'''@Tags\(\s*\[[^\]]*['"]repo-text['"][^\]]*\]\s*\)''',
);

bool _isOutsideLibAndTest(String path) {
  if (path == 'lib' ||
      path.startsWith('lib/') ||
      path == 'test' ||
      path.startsWith('test/') ||
      path.startsWith(r'$') ||
      path.startsWith('{') ||
      path.startsWith('.dart_tool/')) {
    return false;
  }
  return true;
}

List<String> findUntaggedRepoTextTests(
  Map<String, String> filesByPath,
) {
  final untagged = <String>[];
  final sortedPaths = filesByPath.keys.toList()..sort();
  for (final path in sortedPaths) {
    if (path == 'test/infrastructure/compliance/repo_text_tag_bar_test.dart' ||
        path == 'test/infrastructure/compliance/sibling_repo_reference_source_bar_test.dart') {
      continue;
    }
    final content = filesByPath[path]!;
    var readsOutside = _repoWalkPattern.hasMatch(content);
    if (!readsOutside) {
      for (final m in _outsidePathPattern.allMatches(content)) {
        final target = m.group(1)!;
        if (_isOutsideLibAndTest(target)) {
          readsOutside = true;
          break;
        }
      }
    }
    if (readsOutside && !_repoTextTagPattern.hasMatch(content)) {
      untagged.add(path);
    }
  }
  return untagged;
}

void main() {
  group('Fix 3.3 repo-text tag bar', () {
    test('control: a tagged test with @Tags([repo-text]) removed fails naming the file', () {
      final sample = File('test/infrastructure/compliance/docs_truth_test.dart')
          .readAsStringSync()
          .replaceFirst(RegExp(r"@Tags\(\[[^\]]*\]\)\s*\n"), '');
      final untagged = findUntaggedRepoTextTests({
        'test/infrastructure/compliance/docs_truth_test.dart': sample,
      });
      expect(
        untagged,
        equals(['test/infrastructure/compliance/docs_truth_test.dart']),
      );
    });

    test('real bar: every test reading outside lib/ and test/ carries repo-text tag', () {
      final testDir = Directory('test');
      expect(testDir.existsSync(), isTrue);
      final filesByPath = <String, String>{};
      for (final entity in testDir.listSync(recursive: true)) {
        if (entity is File && entity.path.endsWith('_test.dart')) {
          final rel = entity.path.replaceAll('\\', '/');
          filesByPath[rel] = entity.readAsStringSync();
        }
      }
      final untagged = findUntaggedRepoTextTests(filesByPath);
      expect(
        untagged,
        isEmpty,
        reason: 'Tests reading outside lib/ and test/ must carry @Tags([\'repo-text\']): $untagged',
      );
    });
  });
}
