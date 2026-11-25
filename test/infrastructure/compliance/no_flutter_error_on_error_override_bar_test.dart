import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../../support/dart_directive_reader.dart';

final _flutterErrorOnErrorAssignRe = RegExp(
  r'\bFlutterError\s*\.\s*onError\s*=(?!=)',
);

/// Scans every `.dart` file under [dir] (comments and string literals stripped)
/// for assignments to `FlutterError.onError`.
List<String> scanFlutterErrorOnErrorAssignments(Directory dir) {
  if (!dir.existsSync()) {
    throw StateError('Test directory does not exist: ${dir.path}');
  }
  final violations = <String>[];
  final files = dir
      .listSync(recursive: true)
      .whereType<File>()
      .where((f) => f.path.endsWith('.dart'))
      .toList()
    ..sort((a, b) => a.path.compareTo(b.path));

  for (final file in files) {
    final stripped =
        stripCommentsAndStringsPreservingNewlines(file.readAsStringSync());
    final lines = stripped.split('\n');
    for (var i = 0; i < lines.length; i++) {
      final line = lines[i];
      if (_flutterErrorOnErrorAssignRe.hasMatch(line)) {
        violations.add(
          '${file.path}:${i + 1}: assigns FlutterError.onError '
          '(use tester.takeException() instead)',
        );
      }
    }
  }
  return violations;
}

void main() {
  group('Fix 1.4 compliance bar: no test assigns FlutterError.onError', () {
    test(
      'controls: assignment fails; comment and string literal pass',
      () {
        final tmp = Directory.systemTemp.createTempSync('onerror_bar_ctrl_');
        addTearDown(() => tmp.deleteSync(recursive: true));

        final badFile = File('${tmp.path}/bad_test.dart')
          ..writeAsStringSync('''
void main() {
  final prev = FlutterError.onError;
  FlutterError.onError = (details) {};
  addTearDown(() => FlutterError.onError = prev);
}
''');
        final badHits = scanFlutterErrorOnErrorAssignments(tmp);
        expect(badHits, hasLength(2));
        expect(badHits[0], contains('bad_test.dart:3'));
        expect(badHits[1], contains('bad_test.dart:4'));

        badFile.writeAsStringSync('''
void main() {
  // FlutterError.onError = (details) {};
  /* FlutterError.onError = prev; */
  const msg = 'FlutterError.onError = null';
  final current = FlutterError.onError;
  if (FlutterError.onError == current) {}
}
''');
        final okHits = scanFlutterErrorOnErrorAssignments(tmp);
        expect(okHits, isEmpty);
      },
    );

    test('real bar: no file under test/ assigns FlutterError.onError', () {
      final hits = scanFlutterErrorOnErrorAssignments(Directory('test'));
      expect(hits, isEmpty, reason: hits.join('\n'));
    });
  });
}
