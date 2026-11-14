import 'package:flutter_test/flutter_test.dart';

import 'dart_directive_reader.dart';

void main() {
  group('DartDirectiveReader Tests', () {
    test('extracts basic imports, exports, and parts', () {
      const source = '''
import 'package:foo/foo.dart';
export 'package:foo/bar.dart';
part 'foo.g.dart';
''';
      final directives = parseDartDirectives(source);
      expect(directives.length, equals(3));

      expect(directives[0].isImport, isTrue);
      expect(directives[0].primaryUri, equals('package:foo/foo.dart'));
      expect(directives[0].lineNumber, equals(1));

      expect(directives[1].isExport, isTrue);
      expect(directives[1].primaryUri, equals('package:foo/bar.dart'));
      expect(directives[1].lineNumber, equals(2));

      expect(directives[2].isPart, isTrue);
      expect(directives[2].primaryUri, equals('foo.g.dart'));
      expect(directives[2].lineNumber, equals(3));
    });

    test('skips part of directives', () {
      const source = '''
part of 'parent.dart';
part of my_cool_library;
part 'real_part.dart';
''';
      final directives = parseDartDirectives(source);
      expect(directives.length, equals(1));
      expect(directives[0].primaryUri, equals('real_part.dart'));
      expect(directives[0].lineNumber, equals(3));
    });

    test('handles multiline imports where URI is on subsequent lines', () {
      const source = '''
import
    'package:material_ui/material_ui.dart';

export
    'package:material_ui/widgets.dart'
    show Button;
''';
      final directives = parseDartDirectives(source);
      expect(directives.length, equals(2));

      expect(directives[0].isImport, isTrue);
      expect(directives[0].primaryUri, equals('package:material_ui/material_ui.dart'));
      expect(directives[0].lineNumber, equals(1));

      expect(directives[1].isExport, isTrue);
      expect(directives[1].primaryUri, equals('package:material_ui/widgets.dart'));
      expect(directives[1].lineNumber, equals(4));
    });

    test('handles conditional imports and configuration branches', () {
      const source = '''
import 'dart:core'
    if (dart.library.ui) 'package:material_ui/material_ui.dart'
    if (dart.library.html) 'package:web/web.dart';
''';
      final directives = parseDartDirectives(source);
      expect(directives.length, equals(1));

      final d = directives[0];
      expect(d.isImport, isTrue);
      expect(d.lineNumber, equals(1));
      expect(d.uris, equals([
        'dart:core',
        'package:material_ui/material_ui.dart',
        'package:web/web.dart',
      ]));

      expect(d.detailedUris.length, equals(3));
      expect(d.detailedUris[0].isConditional, isFalse);
      expect(d.detailedUris[0].uri, equals('dart:core'));

      expect(d.detailedUris[1].isConditional, isTrue);
      expect(d.detailedUris[1].condition, equals('dart.library.ui'));
      expect(d.detailedUris[1].uri, equals('package:material_ui/material_ui.dart'));

      expect(d.detailedUris[2].isConditional, isTrue);
      expect(d.detailedUris[2].condition, equals('dart.library.html'));
      expect(d.detailedUris[2].uri, equals('package:web/web.dart'));
    });

    test('ignores import statements in single-line and multi-line comments', () {
      const source = '''
// import 'package:commented/out.dart';
/*
import 'package:blocked/out.dart';
/* nested block comment */
import 'package:nested/blocked.dart';
*/
import 'package:real/real.dart';
''';
      final directives = parseDartDirectives(source);
      expect(directives.length, equals(1));
      expect(directives[0].primaryUri, equals('package:real/real.dart'));
      expect(directives[0].lineNumber, equals(7));
    });

    test('handles comments inside directives', () {
      const source = '''
import /* inline comment */ 'package:foo/foo.dart' // line comment
    as foo;
''';
      final directives = parseDartDirectives(source);
      expect(directives.length, equals(1));
      expect(directives[0].primaryUri, equals('package:foo/foo.dart'));
    });

    test('ignores import statements inside string literals and raw string literals', () {
      const source = '''
final str1 = "import 'package:fake/str1.dart';";
final str2 = 'export "package:fake/str2.dart";';
final rawStr = r"import 'package:fake/raw.dart';";
final multiStr = """
import 'package:fake/multi.dart';
""";
import 'package:actual/actual.dart';
''';
      final directives = parseDartDirectives(source);
      expect(directives.length, equals(1));
      expect(directives[0].primaryUri, equals('package:actual/actual.dart'));
      expect(directives[0].lineNumber, equals(7));
    });

    test('does not confuse identifiers starting with directive words', () {
      const source = '''
final importantVariable = 42;
final exportData = 'test';
final participant = true;
import 'package:target/target.dart';
''';
      final directives = parseDartDirectives(source);
      expect(directives.length, equals(1));
      expect(directives[0].primaryUri, equals('package:target/target.dart'));
      expect(directives[0].lineNumber, equals(4));
    });

    test('handles raw string import URIs', () {
      const source = '''
import r'package:raw_uri/raw_uri.dart';
''';
      final directives = parseDartDirectives(source);
      expect(directives.length, equals(1));
      expect(directives[0].primaryUri, equals('package:raw_uri/raw_uri.dart'));
    });

    test('extractImportExportUris provides backwards-compatible flat list', () {
      const source = '''
import
    'package:foo/foo.dart';
export 'package:bar/bar.dart';
part 'qux.dart';
''';
      final uris = extractImportExportUris(source);
      expect(uris, equals(['package:foo/foo.dart', 'package:bar/bar.dart']));
    });

    test('extractAllDirectiveUris provides all URIs including parts and conditionals', () {
      const source = '''
import 'a.dart' if (dart.library.html) 'b.dart';
export 'c.dart';
part 'd.dart';
''';
      final uris = extractAllDirectiveUris(source);
      expect(uris, equals(['a.dart', 'b.dart', 'c.dart', 'd.dart']));
    });
  });
}
