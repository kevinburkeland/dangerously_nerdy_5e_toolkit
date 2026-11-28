import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../../support/dart_directive_reader.dart';

final Set<String> _forbiddenWebUris = {
  'dart:html',
  'dart:js',
  'dart:js_util',
};

List<String> scanSourcesForForbiddenWebLibraries(
  Map<String, String> sourcesByPath,
) {
  final violations = <String>[];
  final sortedPaths = sourcesByPath.keys.toList()..sort();
  for (final path in sortedPaths) {
    final directives = parseDartDirectives(sourcesByPath[path]!);
    for (final d in directives) {
      if (d.kind == DirectiveKind.importDirective ||
          d.kind == DirectiveKind.exportDirective) {
        final kindLabel =
            d.kind == DirectiveKind.importDirective ? 'import' : 'export';
        for (final du in d.detailedUris) {
          if (_forbiddenWebUris.contains(du.uri)) {
            if (du.isConditional) {
              violations.add('$path: forbidden conditional $kindLabel ${du.uri}');
            } else {
              violations.add('$path: forbidden $kindLabel ${du.uri}');
            }
          }
        }
      }
    }
  }
  return violations;
}

void main() {
  group('Fix 5.2 source bar: no dart:html, dart:js, or dart:js_util under lib/', () {
    test('control: direct and conditional imports fail; comment passes', () {
      expect(
        scanSourcesForForbiddenWebLibraries({
          'lib/bad_direct.dart': "import 'dart:html' as html;\n",
        }),
        equals(['lib/bad_direct.dart: forbidden import dart:html']),
      );
      expect(
        scanSourcesForForbiddenWebLibraries({
          'lib/bad_cond.dart':
              "import 'stub.dart' if (dart.library.html) 'dart:html';\n",
        }),
        equals(['lib/bad_cond.dart: forbidden conditional import dart:html']),
      );
      expect(
        scanSourcesForForbiddenWebLibraries({
          'lib/comment_only.dart': "// import 'dart:html' as html;\n",
        }),
        isEmpty,
      );
    });

    test('real bar: no file under lib/ imports dart:html, dart:js, or dart:js_util', () {
      final libDir = Directory('lib');
      expect(libDir.existsSync(), isTrue);
      final sourcesByPath = <String, String>{};
      for (final entity in libDir.listSync(recursive: true)) {
        if (entity is File && entity.path.endsWith('.dart')) {
          sourcesByPath[entity.path.replaceAll('\\', '/')] =
              entity.readAsStringSync();
        }
      }
      final violations = scanSourcesForForbiddenWebLibraries(sourcesByPath);
      expect(
        violations,
        isEmpty,
        reason: 'Forbidden legacy web imports in lib/:\n${violations.join('\n')}',
      );
    });
  });
}
