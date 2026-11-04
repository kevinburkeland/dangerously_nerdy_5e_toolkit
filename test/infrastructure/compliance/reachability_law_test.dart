import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

String stripCommentsOutsideStrings(String source) {
  final buf = StringBuffer();
  final n = source.length;
  int i = 0;
  while (i < n) {
    if (source[i] == 'r' && i + 1 < n && (source[i + 1] == "'" || source[i + 1] == '"')) {
      final q = source[i + 1];
      final isTriple = i + 3 < n && source[i + 2] == q && source[i + 3] == q;
      final delim = isTriple ? q * 3 : q;
      buf.write(source.substring(i, i + 1 + delim.length));
      i += 1 + delim.length;
      while (i < n) {
        if (source.startsWith(delim, i)) {
          buf.write(delim);
          i += delim.length;
          break;
        } else {
          buf.write(source[i]);
          i++;
        }
      }
      continue;
    }

    if (source[i] == "'" || source[i] == '"') {
      final q = source[i];
      final isTriple = i + 2 < n && source[i + 1] == q && source[i + 2] == q;
      final delim = isTriple ? q * 3 : q;
      buf.write(delim);
      i += delim.length;
      while (i < n) {
        if (source[i] == r'\' && i + 1 < n) {
          buf.write(source.substring(i, i + 2));
          i += 2;
        } else if (source.startsWith(delim, i)) {
          buf.write(delim);
          i += delim.length;
          break;
        } else {
          buf.write(source[i]);
          i++;
        }
      }
      continue;
    }

    if (source.startsWith('//', i)) {
      while (i < n && source[i] != '\n') {
        buf.write(' ');
        i++;
      }
      continue;
    }

    if (source.startsWith('/*', i)) {
      int depth = 1;
      buf.write('  ');
      i += 2;
      while (i < n && depth > 0) {
        if (source.startsWith('/*', i)) {
          depth++;
          buf.write('  ');
          i += 2;
        } else if (source.startsWith('*/', i)) {
          depth--;
          buf.write('  ');
          i += 2;
        } else {
          if (source[i] == '\n') {
            buf.write('\n');
          } else {
            buf.write(' ');
          }
          i++;
        }
      }
      continue;
    }

    buf.write(source[i]);
    i++;
  }
  return buf.toString();
}

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

bool _isIdentChar(int codeUnit) {
  return (codeUnit >= 65 && codeUnit <= 90) ||
      (codeUnit >= 97 && codeUnit <= 122) ||
      (codeUnit >= 48 && codeUnit <= 57) ||
      codeUnit == 95 ||
      codeUnit == 36;
}

List<String> directiveTargets(String path, String source) {
  final clean = stripCommentsOutsideStrings(source);
  final targets = <String>{};
  final n = clean.length;
  int i = 0;
  int braceDepth = 0;

  int skipStringLiteral(int idx) {
    if (idx >= n) return idx;
    var start = idx;
    bool isRaw = false;
    if (clean[idx] == 'r' && idx + 1 < n && (clean[idx + 1] == "'" || clean[idx + 1] == '"')) {
      isRaw = true;
      idx++;
    }
    if (idx >= n || (clean[idx] != "'" && clean[idx] != '"')) return start;
    final q = clean[idx];
    final isTriple = idx + 2 < n && clean[idx + 1] == q && clean[idx + 2] == q;
    final delim = isTriple ? q * 3 : q;
    idx += delim.length;
    while (idx < n) {
      if (!isRaw && clean[idx] == r'\' && idx + 1 < n) {
        idx += 2;
      } else if (clean.startsWith(delim, idx)) {
        idx += delim.length;
        break;
      } else {
        idx++;
      }
    }
    return idx;
  }

  String? extractStringAt(int idx) {
    if (idx >= n) return null;
    bool isRaw = false;
    if (clean[idx] == 'r' && idx + 1 < n && (clean[idx + 1] == "'" || clean[idx + 1] == '"')) {
      isRaw = true;
      idx++;
    }
    if (idx >= n || (clean[idx] != "'" && clean[idx] != '"')) return null;
    final q = clean[idx];
    final isTriple = idx + 2 < n && clean[idx + 1] == q && clean[idx + 2] == q;
    final delim = isTriple ? q * 3 : q;
    idx += delim.length;
    final contentStart = idx;
    while (idx < n) {
      if (!isRaw && clean[idx] == r'\' && idx + 1 < n) {
        idx += 2;
      } else if (clean.startsWith(delim, idx)) {
        final content = clean.substring(contentStart, idx);
        return content;
      } else {
        idx++;
      }
    }
    return null;
  }

  while (i < n) {
    final c = clean[i];

    if (c == "'" || c == '"' || (c == 'r' && i + 1 < n && (clean[i + 1] == "'" || clean[i + 1] == '"'))) {
      i = skipStringLiteral(i);
      continue;
    }

    if (c == '{') {
      braceDepth++;
      i++;
      continue;
    }
    if (c == '}') {
      if (braceDepth > 0) braceDepth--;
      i++;
      continue;
    }

    if (braceDepth == 0) {
      final isStart = i == 0 || !_isIdentChar(clean.codeUnitAt(i - 1));
      if (isStart && _isIdentChar(clean.codeUnitAt(i))) {
        final start = i;
        while (i < n && _isIdentChar(clean.codeUnitAt(i))) {
          i++;
        }
        final ident = clean.substring(start, i);
        if (ident == 'import' || ident == 'export' || ident == 'part') {
          int prev = start - 1;
          while (prev >= 0 && (clean[prev] == ' ' || clean[prev] == '\t' || clean[prev] == '\n' || clean[prev] == '\r')) {
            prev--;
          }
          if (prev >= 0 && clean[prev] == '.') {
            continue;
          }

          bool isPartOf = false;
          if (ident == 'part') {
            int look = i;
            while (look < n && (clean[look] == ' ' || clean[look] == '\t' || clean[look] == '\n' || clean[look] == '\r')) {
              look++;
            }
            if (look + 2 <= n && clean.substring(look, look + 2) == 'of') {
              if (look + 2 == n || !_isIdentChar(clean.codeUnitAt(look + 2))) {
                isPartOf = true;
              }
            }
          }

          while (i < n && clean[i] != ';') {
            final ch = clean[i];
            if (ch == "'" || ch == '"' || (ch == 'r' && i + 1 < n && (clean[i + 1] == "'" || clean[i + 1] == '"'))) {
              final uri = extractStringAt(i);
              final nextI = skipStringLiteral(i);
              i = nextI;
              if (!isPartOf && uri != null) {
                final resolved = resolveUri(path, uri);
                if (resolved != null) {
                  targets.add(resolved);
                }
              }
            } else {
              i++;
            }
          }
          if (i < n && clean[i] == ';') {
            i++;
          }
          continue;
        }
      }
    }

    i++;
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
