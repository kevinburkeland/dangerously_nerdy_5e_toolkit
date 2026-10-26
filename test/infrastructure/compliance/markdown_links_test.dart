import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

String _getDirname(String filePath) {
  final idx = filePath.lastIndexOf('/');
  if (idx == -1) return '.';
  if (idx == 0) return '/';
  return filePath.substring(0, idx);
}

String _joinAndNormalize(String dir, String rel) {
  final combined = (dir == '.' || dir.isEmpty) ? rel : '$dir/$rel';
  final isAbsolute = combined.startsWith('/');
  final segments = <String>[];
  for (final part in combined.split('/')) {
    if (part == '' || part == '.') continue;
    if (part == '..') {
      if (segments.isNotEmpty && segments.last != '..') {
        segments.removeLast();
      } else {
        segments.add('..');
      }
    } else {
      segments.add(part);
    }
  }
  final res = segments.join('/');
  if (isAbsolute) return '/$res';
  return res.isEmpty ? '.' : res;
}

/// Checks markdown content for bad links, returning one problem per bad link.
/// Names the link text and target in each problem description.
List<String> markdownLinkProblems(String markdown, String fileDir) {
  // 1. Strip fenced code blocks (``` or ~~~) line by line
  final lines = markdown.split('\n');
  final withoutFencesLines = <String>[];
  bool inFence = false;
  String fenceChar = '';
  int fenceLen = 0;

  for (final line in lines) {
    final trimmed = line.trimLeft();
    if (!inFence) {
      if (trimmed.startsWith('```') || trimmed.startsWith('~~~')) {
        inFence = true;
        fenceChar = trimmed[0];
        fenceLen = 0;
        while (fenceLen < trimmed.length && trimmed[fenceLen] == fenceChar) {
          fenceLen++;
        }
        continue;
      }
      withoutFencesLines.add(line);
    } else {
      if (trimmed.startsWith(fenceChar * fenceLen)) {
        inFence = false;
      }
    }
  }
  final withoutFences = withoutFencesLines.join('\n');

  // 2. Strip inline code (`code` or ``code``)
  final codePattern = RegExp(r'`+[^`\n]+`+');
  final cleanMarkdown = withoutFences.replaceAll(codePattern, '');

  final problems = <String>[];

  void checkTarget(String label, String rawTarget) {
    var t = rawTarget.trim();
    if (t.startsWith('<') && t.endsWith('>')) {
      t = t.substring(1, t.length - 1).trim();
    }
    // Handle optional title: (target "title") or (target 'title')
    final titleMatch = RegExp(r'''^(\S+)(?:\s+["'].*?["'])?$''').firstMatch(t);
    if (titleMatch != null) {
      t = titleMatch.group(1)!;
    }

    if (t.startsWith('file:')) {
      problems.add('$label($t): file: scheme is forbidden');
      return;
    }
    if (t.startsWith('http:') || t.startsWith('https:') || t.startsWith('mailto:')) {
      return;
    }
    if (t.startsWith('#')) {
      return;
    }
    if (t.startsWith('/')) {
      problems.add('$label($t): leading slash is forbidden');
      return;
    }

    // Strip #anchor and ?query
    var targetPath = t.split('#').first.split('?').first;
    try {
      targetPath = Uri.decodeComponent(targetPath);
    } catch (_) {
      // Keep raw if decoding fails
    }
    if (targetPath.isEmpty) return;

    final resolved = _joinAndNormalize(fileDir, targetPath);
    if (!File(resolved).existsSync() && !Directory(resolved).existsSync()) {
      problems.add('$label($t): target does not exist: $resolved');
    }
  }

  // Reference definitions: ^[id]: target
  final refDefPattern = RegExp(r'^[ \t]*\[([^\]]+)\]:[ \t]*([^\s]+)', multiLine: true);
  for (final m in refDefPattern.allMatches(cleanMarkdown)) {
    checkTarget('[${m.group(1)!}]', m.group(2)!);
  }

  // Inline links and images: ![alt](target) or [text](target)
  final linkPattern = RegExp(r'(!?)\[([^\]]*)\]\(([^)]+)\)');
  for (final m in linkPattern.allMatches(cleanMarkdown)) {
    final prefix = m.group(1) ?? '';
    final text = m.group(2) ?? '';
    checkTarget('$prefix[$text]', m.group(3)!);
  }

  // HTML src and href attributes
  final htmlPattern = RegExp(r'''\b(?:src|href)=["']([^"']+)["']''', caseSensitive: false);
  for (final m in htmlPattern.allMatches(cleanMarkdown)) {
    checkTarget('[<HTML>]', m.group(1)!);
  }

  return problems;
}

void main() {
  group('Markdown Link Checks', () {
    test('ML1: real check on app markdown files and docs/ recursively', () {
      final explicitFiles = [
        'README.md',
        'CONTRIBUTING.md',
        'CODE_OF_CONDUCT.md',
        'CHANGELOG.md',
        'PRIVACY_POLICY.md',
        'TERMS_OF_SERVICE.md',
      ];

      for (final relPath in explicitFiles) {
        final file = File(relPath);
        expect(file.existsSync(), isTrue, reason: 'Expected $relPath to exist');
      }

      final docsDir = Directory('docs');
      expect(docsDir.existsSync(), isTrue);
      final docsFiles = docsDir
          .listSync(recursive: true)
          .whereType<File>()
          .where((f) => f.path.endsWith('.md'))
          .map((f) => f.path)
          .toList();

      expect(docsFiles.length, greaterThanOrEqualTo(4),
          reason: 'Expected at least 4 markdown files under docs/');

      final allFilesToCheck = [...explicitFiles, ...docsFiles];
      final allProblems = <String>[];

      for (final filePath in allFilesToCheck) {
        final content = File(filePath).readAsStringSync();
        final fileDir = _getDirname(filePath);
        final problems = markdownLinkProblems(content, fileDir);
        if (problems.isNotEmpty) {
          allProblems.add('$filePath problems:\n  ${problems.join('\n  ')}');
        }
      }

      expect(allProblems, isEmpty,
          reason: 'Found markdown link problems in repository:\n${allProblems.join('\n')}');
    });

    test('ML2: control on the old README fixture', () {
      final fixtureFile = File('test/fixtures/docs/old_readme.md');
      expect(fixtureFile.existsSync(), isTrue);

      final content = fixtureFile.readAsStringSync();
      final problems = markdownLinkProblems(content, '.');

      const expectedTargets = [
        'file:///AGENTS.md',
        'file:///.agents/rules/',
        'file:///.agents/rules/architecture.md',
        'file:///.agents/rules/crdt_and_sync.md',
        'file:///.agents/rules/dnd_rulesets.md',
        'file:///.agents/rules/a11y_and_ui.md',
        'file:///.agents/rules/data_and_performance.md',
        'file:///.agents/rules/testing_and_workflows.md',
        'file:///.antigravityrules',
        'file:///GEMINI.md',
      ];

      expect(problems.length, equals(10),
          reason: 'Expected exactly 10 problems on old README fixture');

      final extractedTargets = problems.map((p) {
        final match = RegExp(r'\((file:///[^)]+)\)').firstMatch(p);
        return match?.group(1);
      }).toList();

      expect(extractedTargets, equals(expectedTargets));
    });

    test('ML3: cases with strings and temporary directory', () {
      final tempDir = Directory.systemTemp.createTempSync('ml3_cases_');
      try {
        final goodFile = File('${tempDir.path}/good.txt')..writeAsStringSync('good');
        final spaceFile = File('${tempDir.path}/foo bar.txt')..writeAsStringSync('space');
        final goodImg = File('${tempDir.path}/good.png')..writeAsStringSync('png');

        expect(goodFile.existsSync(), isTrue);
        expect(spaceFile.existsSync(), isTrue);
        expect(goodImg.existsSync(), isTrue);

        // a good relative link
        expect(markdownLinkProblems('[good](good.txt)', tempDir.path), isEmpty);

        // a missing file
        final missingRes = markdownLinkProblems('[missing](missing.txt)', tempDir.path);
        expect(missingRes, hasLength(1));
        expect(missingRes.first, contains('[missing](missing.txt)'));
        expect(missingRes.first, contains('target does not exist'));

        // a file: link
        final fileLinkRes = markdownLinkProblems('[local](file:///etc/hosts)', tempDir.path);
        expect(fileLinkRes, hasLength(1));
        expect(fileLinkRes.first, contains('[local](file:///etc/hosts)'));
        expect(fileLinkRes.first, contains('file: scheme is forbidden'));

        // a link to an existing file with #anchor
        expect(markdownLinkProblems('[anchor](good.txt#section-1)', tempDir.path), isEmpty);

        // a %20 in a path
        expect(markdownLinkProblems('[spaced](foo%20bar.txt)', tempDir.path), isEmpty);

        // a leading /
        final leadingSlashRes = markdownLinkProblems('[root](/var/log)', tempDir.path);
        expect(leadingSlashRes, hasLength(1));
        expect(leadingSlashRes.first, contains('[root](/var/log)'));
        expect(leadingSlashRes.first, contains('leading slash is forbidden'));

        // a link inside a code fence (ignored)
        const fencedSample = '''
```
[ignored](missing.txt)
```
''';
        expect(markdownLinkProblems(fencedSample, tempDir.path), isEmpty);

        // inline code (ignored)
        expect(markdownLinkProblems('Here is `[ignored](missing.txt)` inline code', tempDir.path), isEmpty);

        // an image
        expect(markdownLinkProblems('![good img](good.png)', tempDir.path), isEmpty);
        final badImgRes = markdownLinkProblems('![bad img](missing.png)', tempDir.path);
        expect(badImgRes, hasLength(1));
        expect(badImgRes.first, contains('![bad img](missing.png)'));
        expect(badImgRes.first, contains('target does not exist'));

        // a reference definition
        expect(markdownLinkProblems('[ref1]: good.txt', tempDir.path), isEmpty);
        final badRefRes = markdownLinkProblems('[ref2]: missing.txt', tempDir.path);
        expect(badRefRes, hasLength(1));
        expect(badRefRes.first, contains('[ref2](missing.txt)'));
        expect(badRefRes.first, contains('target does not exist'));

        // an HTML src
        expect(markdownLinkProblems('<img src="good.png" alt="img" />', tempDir.path), isEmpty);
        final badHtmlRes = markdownLinkProblems('<img src="missing.png" />', tempDir.path);
        expect(badHtmlRes, hasLength(1));
        expect(badHtmlRes.first, contains('[<HTML>](missing.png)'));
        expect(badHtmlRes.first, contains('target does not exist'));

        // a title after the target
        expect(markdownLinkProblems('[titled](good.txt "Title text")', tempDir.path), isEmpty);
        final badTitleRes = markdownLinkProblems('[bad title](missing.txt "Title text")', tempDir.path);
        expect(badTitleRes, hasLength(1));
        expect(badTitleRes.first, contains('[bad title](missing.txt)'));
        expect(badTitleRes.first, contains('target does not exist'));

        // an https link (fine)
        expect(markdownLinkProblems('[remote](https://example.com/docs)', tempDir.path), isEmpty);
      } finally {
        tempDir.deleteSync(recursive: true);
      }
    });
  });
}
