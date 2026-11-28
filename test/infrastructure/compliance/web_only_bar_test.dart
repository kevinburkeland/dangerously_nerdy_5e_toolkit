@Tags(['repo-text'])
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../../support/dart_directive_reader.dart';

void main() {
  test('Fix 7.3 web-only bar: no android/linux, no Crashlytics, no Play Integrity', () {
    expect(
      Directory('android').existsSync(),
      isFalse,
      reason: 'android/ directory must be deleted for web-only app',
    );
    expect(
      Directory('linux').existsSync(),
      isFalse,
      reason: 'linux/ directory must be deleted for web-only app',
    );

    final pubspec = File('pubspec.yaml').readAsStringSync();
    expect(
      pubspec.contains('firebase_crashlytics'),
      isFalse,
      reason: 'firebase_crashlytics must be removed from pubspec.yaml',
    );

    final libHits = <String>[];
    for (final entity in Directory('lib').listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      final stripped = stripCommentsPreservingNewlines(entity.readAsStringSync());
      for (final banned in const [
        'firebase_crashlytics',
        'FirebaseCrashlytics',
        'AndroidPlayIntegrityProvider',
      ]) {
        if (stripped.contains(banned)) {
          libHits.add('${entity.path}: $banned');
        }
      }
    }
    expect(libHits, isEmpty, reason: 'Found Crashlytics/Play Integrity in lib/: $libHits');

    final policy = File('web/legal/PRIVACY_POLICY.md').readAsStringSync();
    expect(policy, isNot(contains('Crashlytics')));
    expect(policy, isNot(contains('Android')));
  });
}
