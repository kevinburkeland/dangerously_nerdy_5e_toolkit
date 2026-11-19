import 'dart:collection';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../support/dart_directive_reader.dart';

const String kAppPackagePrefix = 'package:dangerously_nerdy_5e_toolkit/';

const List<String> kTransitivePureFolders = [
  'lib/models',
  'lib/domain',
  'lib/application',
  'lib/infrastructure/dtos',
];

/// Empty allowlist — no pure-layer file may transitively reach Flutter or Crashlytics.
const Set<String> kTransitivePurityAllowlist = <String>{};

bool isForbiddenTransitiveUri(String uri) {
  return uri.startsWith('package:flutter/') ||
      uri.startsWith('package:flutter_test/') ||
      uri.startsWith('package:material_ui/') ||
      uri == 'dart:ui' ||
      uri == 'dart:ui_web' ||
      uri.startsWith('package:firebase_crashlytics/');
}

String _normalizePath(String path) {
  final parts = path.replaceAll('\\', '/').split('/');
  final normalized = <String>[];
  for (final part in parts) {
    if (part.isEmpty || part == '.') continue;
    if (part == '..') {
      if (normalized.isNotEmpty) normalized.removeLast();
    } else {
      normalized.add(part);
    }
  }
  return normalized.join('/');
}

String? _resolveAppLibPath(String fromPath, String uri) {
  if (uri.startsWith('dart:')) return null;
  if (uri.startsWith(kAppPackagePrefix)) {
    return _normalizePath('lib/${uri.substring(kAppPackagePrefix.length)}');
  }
  if (uri.startsWith('package:')) return null;
  final normFrom = _normalizePath(fromPath);
  final slash = normFrom.lastIndexOf('/');
  final dir = slash >= 0 ? normFrom.substring(0, slash) : '';
  return _normalizePath(dir.isEmpty ? uri : '$dir/$uri');
}

/// Finds the shortest transitive import/export chain from [startFile] to any
/// forbidden URI, or returns `null` if [startFile] is transitively pure.
List<String>? findForbiddenChain(
  String startFile,
  Map<String, String> libFiles,
) {
  final start = _normalizePath(startFile);
  final queue = Queue<List<String>>()..add([start]);
  final visited = <String>{start};

  while (queue.isNotEmpty) {
    final chain = queue.removeFirst();
    final current = chain.last;
    final source = libFiles[current];
    if (source == null) continue;

    final directives = parseDartDirectives(source);
    for (final directive in directives) {
      for (final uri in directive.uris) {
        if (isForbiddenTransitiveUri(uri)) {
          return [...chain, uri];
        }
        final resolved = _resolveAppLibPath(current, uri);
        if (resolved != null &&
            libFiles.containsKey(resolved) &&
            visited.add(resolved)) {
          queue.add([...chain, resolved]);
        }
      }
    }
  }
  return null;
}

class TransitivePurityScanResult {
  final Map<String, List<List<String>>> violationsByFolder;

  const TransitivePurityScanResult(this.violationsByFolder);

  int get totalViolations =>
      violationsByFolder.values.fold(0, (sum, list) => sum + list.length);

  String formatCounts() {
    return kTransitivePureFolders
        .map((f) => '$f=${violationsByFolder[f]?.length ?? 0}')
        .join(', ');
  }

  String formatReport() {
    final buf = StringBuffer();
    buf.writeln('Transitive purity violations (${formatCounts()}):');
    for (final folder in kTransitivePureFolders) {
      final list = violationsByFolder[folder] ?? const [];
      for (final chain in list) {
        buf.writeln('  ${chain.join('\n    -> ')}');
      }
    }
    return buf.toString();
  }
}

TransitivePurityScanResult scanTransitivePurity(Map<String, String> libFiles) {
  final byFolder = <String, List<List<String>>>{
    for (final folder in kTransitivePureFolders) folder: <List<String>>[],
  };

  final sortedPaths = libFiles.keys.toList()..sort();
  for (final path in sortedPaths) {
    if (kTransitivePurityAllowlist.contains(path)) continue;
    for (final folder in kTransitivePureFolders) {
      if (path.startsWith('$folder/')) {
        final chain = findForbiddenChain(path, libFiles);
        if (chain != null) {
          byFolder[folder]!.add(chain);
        }
      }
    }
  }

  return TransitivePurityScanResult(byFolder);
}

Map<String, String> _loadAllLibDartFiles() {
  final files = <String, String>{};
  final libDir = Directory('lib');
  for (final entity in libDir.listSync(recursive: true)) {
    if (entity is File && entity.path.endsWith('.dart')) {
      final normalized = _normalizePath(entity.path);
      files[normalized] = entity.readAsStringSync();
    }
  }
  return files;
}

void main() {
  group('Fix 6.1: Transitive Purity Controls (in-memory)', () {
    test('control: models -> services -> flutter/foundation.dart is flagged with both hops', () {
      final files = <String, String>{
        'lib/models/a.dart': "import '../services/b.dart';\nclass A {}\n",
        'lib/services/b.dart': "import 'package:flutter/foundation.dart';\nclass B {}\n",
      };

      final result = scanTransitivePurity(files);
      expect(result.violationsByFolder['lib/models'], hasLength(1));
      final chain = result.violationsByFolder['lib/models']!.single;
      expect(
        chain,
        equals([
          'lib/models/a.dart',
          'lib/services/b.dart',
          'package:flutter/foundation.dart',
        ]),
      );
      expect(result.formatReport(), contains('lib/models/a.dart'));
      expect(result.formatReport(), contains('lib/services/b.dart'));
      expect(result.formatReport(), contains('package:flutter/foundation.dart'));
    });

    test('control: conditional import branch reaching Flutter or Crashlytics is flagged', () {
      final files = <String, String>{
        'lib/models/a.dart':
            "import '../services/pure.dart'\n    if (dart.library.io) '../services/io_sink.dart';\nclass A {}\n",
        'lib/services/pure.dart': 'class Pure {}\n',
        'lib/services/io_sink.dart':
            "import 'package:firebase_crashlytics/firebase_crashlytics.dart';\nclass IoSink {}\n",
      };

      final result = scanTransitivePurity(files);
      expect(result.violationsByFolder['lib/models'], hasLength(1));
      expect(
        result.violationsByFolder['lib/models']!.single,
        equals([
          'lib/models/a.dart',
          'lib/services/io_sink.dart',
          'package:firebase_crashlytics/firebase_crashlytics.dart',
        ]),
      );
    });

    test('control: models file importing only dart: and pure package files passes', () {
      final files = <String, String>{
        'lib/models/a.dart':
            "import 'dart:convert';\nimport 'package:meta/meta.dart';\nimport 'package:dangerously_nerdy_5e_toolkit/domain/b.dart';\nclass A {}\n",
        'lib/domain/b.dart': "import 'dart:math';\nclass B {}\n",
      };

      final result = scanTransitivePurity(files);
      expect(result.totalViolations, equals(0));
    });

    test('control: Flutter import inside a comment is not flagged', () {
      final files = <String, String>{
        'lib/models/a.dart': '''
// import 'package:flutter/material.dart';
/*
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
*/
import 'dart:core';
class A {}
''',
      };

      final result = scanTransitivePurity(files);
      expect(result.totalViolations, equals(0));
    });
  });

  group('Fix 6.1: Transitive Purity Law on live lib/ tree', () {
    test('allowlist is empty', () {
      expect(kTransitivePurityAllowlist, isEmpty);
    });

    test(
        'lib/models, lib/domain, lib/application, and lib/infrastructure/dtos never transitively reach Flutter or Crashlytics',
        () {
      final files = _loadAllLibDartFiles();
      final result = scanTransitivePurity(files);
      // Print per-folder counts for audit trail.
      stdout.writeln('Transitive purity counts: ${result.formatCounts()}');

      expect(
        result.totalViolations,
        equals(0),
        reason: result.formatReport(),
      );
    });
  });
}
