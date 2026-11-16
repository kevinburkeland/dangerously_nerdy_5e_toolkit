import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Privacy Policy Truth Test', () {
    test('PRIVACY_POLICY.md and web/legal/PRIVACY_POLICY.md are byte-identical', () {
      final rootPolicy = File('PRIVACY_POLICY.md').readAsBytesSync();
      final webPolicy = File('web/legal/PRIVACY_POLICY.md').readAsBytesSync();

      expect(
        rootPolicy,
        equals(webPolicy),
        reason: 'web/legal/PRIVACY_POLICY.md must be a byte-identical copy of PRIVACY_POLICY.md',
      );
    });

    test('Firestore collections used in PRIVACY_POLICY.md matches firestore.rules exactly', () {
      final rulesContent = File('firestore.rules').readAsStringSync();
      final policyContent = File('PRIVACY_POLICY.md').readAsStringSync();

      final matchPattern = RegExp(r'match\s+(/[^\n]+?)\s*\{\s*$', multiLine: true);
      final rulesCollections = <String>{};

      for (final match in matchPattern.allMatches(rulesContent)) {
        final path = match.group(1)!.trim();
        if (path.startsWith('/databases/')) continue;
        final segs = path.split('/').where((s) => s.isNotEmpty).toList();
        for (var i = 0; i < segs.length; i += 2) {
          rulesCollections.add(segs[i]);
        }
      }

      final collectionLinePattern = RegExp(r'Firestore collections used:\s*(.+)$', multiLine: true);
      final lineMatch = collectionLinePattern.firstMatch(policyContent);
      expect(
        lineMatch,
        isNotNull,
        reason: 'PRIVACY_POLICY.md must contain "Firestore collections used: ..."',
      );

      final lineText = lineMatch!.group(1)!;
      final backtickPattern = RegExp(r'`([^`]+)`');
      final policyCollections = backtickPattern.allMatches(lineText).map((m) => m.group(1)!).toSet();

      expect(
        policyCollections,
        equals(rulesCollections),
        reason: 'Collections in PRIVACY_POLICY.md must exactly match the collections declared in firestore.rules',
      );
    });
  });
}
