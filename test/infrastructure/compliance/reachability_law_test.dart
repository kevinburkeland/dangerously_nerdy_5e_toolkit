import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../../support/dart_directive_reader.dart';

String normalizePath(String path) {
  final parts = path.split('/');
  final normalized = <String>[];
  for (final part in parts) {
    if (part == '' || part == '.') continue;
    if (part == '..') {
      if (normalized.isNotEmpty) normalized.removeLast();
    } else {
      normalized.add(part);
    }
  }
  return normalized.join('/');
}

String? resolveUri(String fromPath, String uri) {
  if (uri.startsWith('dart:')) return null;
  const pkgPrefix = 'package:dangerously_nerdy_5e_toolkit/';
  if (uri.startsWith(pkgPrefix)) {
    return normalizePath('lib/${uri.substring(pkgPrefix.length)}');
  }
  if (uri.startsWith('package:')) return null;
  final dir = fromPath.contains('/') ? fromPath.substring(0, fromPath.lastIndexOf('/')) : '';
  final combined = dir.isEmpty ? uri : '$dir/$uri';
  return normalizePath(combined);
}

List<String> directiveTargets(String path, String source) {
  final targets = <String>{};
  final directives = parseDartDirectives(source);
  for (final d in directives) {
    for (final uri in d.uris) {
      final resolved = resolveUri(path, uri);
      if (resolved != null) {
        targets.add(resolved);
      }
    }
  }
  return targets.toList()..sort();
}

class ReachabilityResult {
  final List<String> unreachable;
  final List<String> missingTargets;

  const ReachabilityResult({
    required this.unreachable,
    required this.missingTargets,
  });
}

ReachabilityResult analyzeReachability(Map<String, String> files, String root) {
  final visited = <String>{};
  final queue = <String>[root];
  final missing = <String>{};

  while (queue.isNotEmpty) {
    final curr = queue.removeLast();
    if (!visited.add(curr)) continue;
    final content = files[curr];
    if (content == null) continue;
    for (final target in directiveTargets(curr, content)) {
      if (target.startsWith('lib/')) {
        if (files.containsKey(target)) {
          if (!visited.contains(target)) {
            queue.add(target);
          }
        } else {
          missing.add('missing target $target (from $curr)');
        }
      }
    }
  }

  final unreachable = files.keys.where((k) => !visited.contains(k)).toList()..sort();
  final missingSorted = missing.toList()..sort();
  return ReachabilityResult(unreachable: unreachable, missingTargets: missingSorted);
}

List<String> unreachableFiles(Map<String, String> files, String root, {List<String>? missingProblems}) {
  final result = analyzeReachability(files, root);
  if (missingProblems != null) {
    missingProblems.addAll(result.missingTargets);
  }
  return result.unreachable;
}

void main() {
  group('RC1: Reachability in-memory controls', () {
    test('a chain main -> a (export) -> b reaches b', () {
      final files = {
        'lib/main.dart': "export 'a.dart';",
        'lib/a.dart': "export 'b.dart';",
        'lib/b.dart': 'void main() {}',
      };
      final unreachable = unreachableFiles(files, 'lib/main.dart');
      expect(unreachable, isEmpty);
    });

    test('conditional imports: js_interop and html branches are reachable', () {
      final files = {
        'lib/main.dart': "import 'stub.dart' if (dart.library.js_interop) 'web.dart' if (dart.library.html) 'web2.dart';",
        'lib/stub.dart': '',
        'lib/web.dart': '',
        'lib/web2.dart': '',
      };
      final unreachable = unreachableFiles(files, 'lib/main.dart');
      expect(unreachable, isEmpty);
    });

    test('comments do not count; literals with comment markers do not mask directives', () {
      final files = {
        'lib/main.dart': '''
// import 'x.dart';
/*
import 'x.dart';
*/
final m = 'image/*';
import 'real.dart';
''',
        'lib/real.dart': '',
        'lib/x.dart': '',
      };
      final unreachable = unreachableFiles(files, 'lib/main.dart');
      expect(unreachable, equals(['lib/x.dart']));
    });

    test('multi-line imports with show/hide and deferred as reach targets', () {
      final files = {
        'lib/main.dart': '''
import
    'a.dart'
    show A, B;
import 'b.dart' deferred as d;
''',
        'lib/a.dart': '',
        'lib/b.dart': '',
      };
      final unreachable = unreachableFiles(files, 'lib/main.dart');
      expect(unreachable, isEmpty);
    });

    test('part reaches file, but part of adds no edge', () {
      final files = {
        'lib/main.dart': "part 'p.dart';",
        'lib/p.dart': "part of 'lib.dart';",
        'lib/lib.dart': '',
      };
      final unreachable = unreachableFiles(files, 'lib/main.dart');
      expect(unreachable, equals(['lib/lib.dart']));
    });

    test('isolated circular dependencies are unreachable', () {
      final files = {
        'lib/main.dart': '',
        'lib/x.dart': "import 'y.dart';",
        'lib/y.dart': "import 'x.dart';",
      };
      final unreachable = unreachableFiles(files, 'lib/main.dart');
      expect(unreachable, equals(['lib/x.dart', 'lib/y.dart']));
    });

    test('import of missing file reports missing target problem', () {
      final files = {
        'lib/main.dart': "import 'no_such.dart';",
      };
      final missing = <String>[];
      unreachableFiles(files, 'lib/main.dart', missingProblems: missing);
      expect(missing, equals(['missing target lib/no_such.dart (from lib/main.dart)']));
    });

    test('relative import with parent directory reaches target', () {
      final files = {
        'lib/main.dart': "import 'a/b.dart';",
        'lib/a/b.dart': "import '../x.dart';",
        'lib/x.dart': '',
      };
      final unreachable = unreachableFiles(files, 'lib/main.dart');
      expect(unreachable, isEmpty);
    });
  });

  group('RL: Reachability law on live lib/ tree', () {
    Map<String, String> loadRealLibFiles() {
      final files = <String, String>{};
      for (final entity in Directory('lib').listSync(recursive: true)) {
        if (entity is File && entity.path.endsWith('.dart')) {
          final p = entity.path.replaceAll('\\', '/');
          files[p] = entity.readAsStringSync();
        }
      }
      return files;
    }

    test('RL1: unreachableFiles is empty with zero missing targets', () {
      final files = loadRealLibFiles();
      final missing = <String>[];
      final unreached = unreachableFiles(files, 'lib/main.dart', missingProblems: missing);

      expect(missing, isEmpty, reason: 'Found missing targets: $missing');
      expect(unreached, isEmpty, reason: 'Found unreachable files: $unreached');
    });
  });
}
