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

List<String> findMarkdownFiles(String repoRoot) {
  final rootDir = Directory(repoRoot);
  final skipNames = {'.git', '.dart_tool', 'build', 'ephemeral', 'node_modules'};
  final results = <String>[];

  void walk(Directory dir) {
    for (final entity in dir.listSync(followLinks: false)) {
      final p = entity.path.replaceAll('\\', '/');
      final segs = p.split('/');
      if (segs.any((s) => skipNames.contains(s))) continue;
      if (p.contains('test/fixtures')) continue;
      if (entity is Directory) {
        walk(entity);
      } else if (entity is File) {
        var rel = p.startsWith('./') ? p.substring(2) : p;
        if (repoRoot != '.' && repoRoot.isNotEmpty && rel.startsWith('$repoRoot/')) {
          rel = rel.substring(repoRoot.length + 1);
        }
        if (rel.startsWith('./')) rel = rel.substring(2);
        if (rel.endsWith('.md') || rel.endsWith('.antigravityrules')) {
          results.add(rel);
        }
      }
    }
  }

  walk(rootDir);
  results.sort();
  return results;
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

    final lower = t.toLowerCase();
    if (lower.startsWith('file:')) {
      problems.add('$label($t): file: scheme is forbidden');
      return;
    }
    if (lower.startsWith('http:') || lower.startsWith('https:') || lower.startsWith('mailto:')) {
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

  // Reference definitions: ^[id]: target (excluding footnote definitions)
  final refDefPattern = RegExp(r'^[ \t]*\[([^\]]+)\]:[ \t]*([^\s]+)', multiLine: true);
  for (final m in refDefPattern.allMatches(cleanMarkdown)) {
    final ref = m.group(1)!;
    if (ref.startsWith('^')) {
      continue;
    }
    checkTarget('[$ref]', m.group(2)!);
  }

  // Autolinks: <scheme:...>
  final autolinkPattern = RegExp(r'<([a-zA-Z][a-zA-Z0-9+.-]*:[^>\s]+)>');
  for (final m in autolinkPattern.allMatches(cleanMarkdown)) {
    final target = m.group(1)!;
    checkTarget('<$target>', target);
  }

  // Inline links and images: find every ](target)
  final targetPattern = RegExp(r'\]\(([^)\n]+)\)');
  for (final m in targetPattern.allMatches(cleanMarkdown)) {
    final target = m.group(1)!;
    final closeBracketIdx = m.start;

    int depth = 1;
    int idx = closeBracketIdx - 1;
    int startBracketIdx = -1;

    while (idx >= 0) {
      final ch = cleanMarkdown[idx];
      if (ch == '\n') break;
      if (ch == ']') {
        depth++;
      } else if (ch == '[') {
        depth--;
        if (depth == 0) {
          startBracketIdx = idx;
          break;
        }
      }
      idx--;
    }

    String label;
    if (startBracketIdx != -1) {
      if (startBracketIdx > 0 && cleanMarkdown[startBracketIdx - 1] == '!') {
        label = cleanMarkdown.substring(startBracketIdx - 1, closeBracketIdx + 1);
      } else {
        label = cleanMarkdown.substring(startBracketIdx, closeBracketIdx + 1);
      }
    } else {
      label = '[link]';
    }

    checkTarget(label, target);
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
    test('ML1: real check on all repository markdown files and .antigravityrules', () {
      final allFilesToCheck = findMarkdownFiles('.');
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

    test('ML4: scope control verifying markdown file collection', () {
      final files = findMarkdownFiles('.');
      // ignore: avoid_print
      print('ML4 collected markdown file count: ${files.length}');

      const requiredFiles = [
        'README.md',
        'AGENTS.md',
        'GEMINI.md',
        '.antigravityrules',
        '.agents/rules/a11y_and_ui.md',
        '.agents/rules/architecture.md',
        '.agents/rules/codebase_map.md',
        '.agents/rules/crdt_and_sync.md',
        '.agents/rules/data_and_performance.md',
        '.agents/rules/dnd_rulesets.md',
        '.agents/rules/testing_and_workflows.md',
        '.github/PULL_REQUEST_TEMPLATE.md',
        'docs/ARCHITECTURE.md',
        'docs/decisions/0001-party-state-owner.md',
        'firestore_rules_test/README.md',
        'web/legal/PRIVACY_POLICY.md',
      ];

      for (final req in requiredFiles) {
        expect(files, contains(req), reason: 'ML1 file list must contain $req');
      }

      for (final f in files) {
        expect(f.startsWith('test/fixtures/'), isFalse,
            reason: 'ML1 must not include test/fixtures/: $f');
        expect(f.contains('.dart_tool/'), isFalse,
            reason: 'ML1 must not include .dart_tool/: $f');
        expect(f.startsWith('build/'), isFalse,
            reason: 'ML1 must not include build/: $f');
      }
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

        // new ML3 cases:
        // 1. badge wrapped link missing outer target
        final badgeMissingLicense = markdownLinkProblems(
          '[![b](https://x/y.svg)](MISSING_LICENSE)',
          tempDir.path,
        );
        expect(badgeMissingLicense, hasLength(1));
        expect(badgeMissingLicense.first, contains('MISSING_LICENSE'));

        // 2. badge wrapped link with existing files
        expect(
          markdownLinkProblems('[![b](good.png)](good.txt)', tempDir.path),
          isEmpty,
        );

        // 3. badge wrapped link with missing inner image
        final badgeMissingImg = markdownLinkProblems(
          '[![b](missing.png)](good.txt)',
          tempDir.path,
        );
        expect(badgeMissingImg, hasLength(1));
        expect(badgeMissingImg.first, contains('missing.png'));

        // 4. footnotes
        expect(
          markdownLinkProblems('[^1]: Some text here.', tempDir.path),
          isEmpty,
        );
        expect(
          markdownLinkProblems('See this[^1].', tempDir.path),
          isEmpty,
        );

        // 5. autolinks
        final autoFile = markdownLinkProblems('<file:///x>', tempDir.path);
        expect(autoFile, hasLength(1));
        expect(autoFile.first, contains('file:'));
        expect(markdownLinkProblems('<https://example.com>', tempDir.path), isEmpty);

        // 6. case-insensitive schemes
        final upperFile = markdownLinkProblems('[a](FILE:///x)', tempDir.path);
        expect(upperFile, hasLength(1));
        expect(upperFile.first, contains('file:'));
        expect(markdownLinkProblems('[a](HTTPS://example.com)', tempDir.path), isEmpty);

        // 7. two links on one line
        final twoOnOneLine = markdownLinkProblems(
          '[a](good.txt) and [b](missing.txt)',
          tempDir.path,
        );
        expect(twoOnOneLine, hasLength(1));
        expect(twoOnOneLine.first, contains('missing.txt'));
      } finally {
        tempDir.deleteSync(recursive: true);
      }
    });
  });
}
