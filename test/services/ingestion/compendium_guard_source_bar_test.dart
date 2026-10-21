import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:dangerously_nerdy_5e_toolkit/services/ingestion/compendium_json_ingestion_pipeline.dart';
import 'package:vtt_ruleset_dnd5e/vtt_ruleset_dnd5e.dart'
    show CatalogNotInstalledError;

void _assertSourceBar(String source) {
  final catchMatches = RegExp(r'\bcatch\b').allMatches(source).toList();
  final catalogMatches =
      RegExp(r'on\s+CatalogNotInstalledError').allMatches(source).toList();

  if (catchMatches.length != 1) {
    throw StateError(
        'Expected exactly 1 catch block in pipeline, found ${catchMatches.length}');
  }
  if (catalogMatches.length != 1) {
    throw StateError(
        'Expected exactly 1 on CatalogNotInstalledError in pipeline, found ${catalogMatches.length}');
  }

  // Verify that the single catch and on CatalogNotInstalledError live within _guard definition
  final guardIndex = source.indexOf('static T _guard<T>');
  if (guardIndex == -1) {
    throw StateError('_guard helper definition not found in pipeline source');
  }
  final guardSnippet = source.substring(guardIndex, guardIndex + 250);
  if (!guardSnippet.contains('on CatalogNotInstalledError') ||
      !guardSnippet.contains('catch (e)')) {
    throw StateError(
        'Both on CatalogNotInstalledError and catch (e) must be located inside _guard');
  }
}

void main() {
  group('Compendium Ingestion Guard Source Bar (F4)', () {
    test('compendium_json_ingestion_pipeline.dart has exactly 1 catch and 1 on CatalogNotInstalledError inside _guard', () {
      final file = File('lib/services/ingestion/compendium_json_ingestion_pipeline.dart');
      expect(file.existsSync(), isTrue,
          reason: 'Pipeline source file must exist');

      final source = file.readAsStringSync();
      expect(() => _assertSourceBar(source), returnsNormally);
    });

    test('negative test: source bar validator rejects source with extra catch or catalog handler', () {
      const extraCatchSource = '''
static T _guard<T>(T Function() body, T Function(Object error) onError) {
  try {
    return body();
  } on CatalogNotInstalledError {
    rethrow;
  } catch (e) {
    return onError(e);
  }
}
void foo() {
  try {} catch (e) {}
}
''';
      expect(() => _assertSourceBar(extraCatchSource), throwsStateError);

      const missingCatalogSource = '''
static T _guard<T>(T Function() body, T Function(Object error) onError) {
  try {
    return body();
  } catch (e) {
    return onError(e);
  }
}
''';
      expect(() => _assertSourceBar(missingCatalogSource), throwsStateError);
    });

    test('guardForTesting unit tests: rethrows CatalogNotInstalledError, catches other errors, returns value', () {
      // 1. Returns normal value
      final value = CompendiumJsonIngestionPipeline.guardForTesting(
        () => 42,
        (error) => -1,
      );
      expect(value, equals(42));

      // 2. Intercepts standard exceptions and routes to onError
      final fromStateError = CompendiumJsonIngestionPipeline.guardForTesting(
        () => throw StateError('corrupted element'),
        (error) => 'caught: $error',
      );
      expect(fromStateError, contains('caught: Bad state: corrupted element'));

      final fromFormatException = CompendiumJsonIngestionPipeline.guardForTesting(
        () => throw const FormatException('malformed json'),
        (error) => 'caught: $error',
      );
      expect(fromFormatException, contains('caught: FormatException: malformed json'));

      // 3. Rethrows CatalogNotInstalledError unconditionally
      expect(
        () => CompendiumJsonIngestionPipeline.guardForTesting(
          () => throw CatalogNotInstalledError(),
          (error) => 'should not reach',
        ),
        throwsA(isA<CatalogNotInstalledError>()),
      );
    });
  });
}
