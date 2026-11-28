import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../../support/dart_directive_reader.dart';

const String _kHelperPath = 'lib/utils/opaque_id.dart';

/// Hits that are NOT opaque ids (or are frozen by scope rules) with reasons.
const Map<String, String> _kNonIdAllowlistByFile = {
  'lib/application/storage/storage_durability_coordinator.dart':
      'Exported .dndvault snapshot filename includes bundle.exportedAt.millisecondsSinceEpoch, not an entity id.',
  'lib/services/party/party_room_service.dart':
      'Outbox/copy ids (outbox_create_*, outbox_claim_*, *_copy_*) frozen outside Fix 5.3 scope; evt_ line uses newOpaqueId.',
};

final RegExp _kUuidCtorRe = RegExp(r'\bUuid\s*\(');
final RegExp _kInterpolatedWeakIdRe = RegExp(
  r'''['"][^'"]*\$\{[^}]*(?:\.nextInt\(|millisecondsSinceEpoch)[^}]*\}[^'"]*['"]''',
);

List<String> scanSourcesForWeakOrDuplicateIds(
  Map<String, String> sourcesByPath,
) {
  final violations = <String>[];
  final sortedPaths = sourcesByPath.keys.toList()..sort();
  for (final path in sortedPaths) {
    final stripped = stripCommentsPreservingNewlines(sourcesByPath[path]!);
    final lines = stripped.split('\n');
    for (var i = 0; i < lines.length; i++) {
      final line = lines[i];
      if (path != _kHelperPath && _kUuidCtorRe.hasMatch(line)) {
        violations.add('$path:${i + 1}: direct Uuid( outside $_kHelperPath');
      }
      if (!_kNonIdAllowlistByFile.containsKey(path) &&
          _kInterpolatedWeakIdRe.hasMatch(line)) {
        violations.add(
          '$path:${i + 1}: string interpolation with nextInt/millisecondsSinceEpoch',
        );
      }
    }
  }
  return violations;
}

void main() {
  group('Fix 5.3 source bar: one opaque id helper under lib/', () {
    test('control: weak id interpolation and direct Uuid() fail; comment passes', () {
      const badWeak = '''
String makeId() {
  return 'evt_\${DateTime.now().millisecondsSinceEpoch}_\${math.Random().nextInt(9999)}';
}
''';
      final weakHits = scanSourcesForWeakOrDuplicateIds({'lib/bad_weak.dart': badWeak});
      expect(weakHits, hasLength(1));
      expect(weakHits.single, contains('lib/bad_weak.dart:2:'));

      const commentOnly = '''
// id: 'evt_\${DateTime.now().millisecondsSinceEpoch}_\${math.Random().nextInt(9999)}'
''';
      expect(
        scanSourcesForWeakOrDuplicateIds({'lib/comment.dart': commentOnly}),
        isEmpty,
      );

      const badUuid = '''
String makeUuid() => const Uuid().v4();
''';
      final uuidHits = scanSourcesForWeakOrDuplicateIds({'lib/bad_uuid.dart': badUuid});
      expect(uuidHits, hasLength(1));
      expect(uuidHits.single, contains('lib/bad_uuid.dart:1:'));
    });

    test('real bar: lib/ uses opaque_id.dart for all UUIDs and opaque ids', () {
      final libDir = Directory('lib');
      expect(libDir.existsSync(), isTrue);
      final sourcesByPath = <String, String>{};
      for (final entity in libDir.listSync(recursive: true)) {
        if (entity is File && entity.path.endsWith('.dart')) {
          sourcesByPath[entity.path.replaceAll('\\', '/')] =
              entity.readAsStringSync();
        }
      }
      final violations = scanSourcesForWeakOrDuplicateIds(sourcesByPath);
      expect(
        violations,
        isEmpty,
        reason: 'Weak or duplicate id sites in lib/:\n${violations.join('\n')}',
      );
    });
  });
}
