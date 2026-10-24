import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Firebase Hosting Security Headers Compliance', () {
    test('firebase.json includes required security headers on source **', () {
      final file = File('firebase.json');
      expect(file.existsSync(), isTrue, reason: 'firebase.json must exist');

      final content = file.readAsStringSync();
      final json = jsonDecode(content) as Map<String, dynamic>;

      final hosting = json['hosting'] as Map<String, dynamic>?;
      expect(hosting, isNotNull, reason: 'firebase.json must define "hosting"');

      final headers = hosting!['headers'] as List<dynamic>?;
      expect(headers, isNotNull, reason: 'hosting must define "headers"');

      // Find the rule for source: "**"
      final wildcardRule = headers!.cast<Map<String, dynamic>>().firstWhere(
            (rule) => rule['source'] == '**',
            orElse: () => throw AssertionError('No header rule found for "source": "**"'),
          );

      final headerList = (wildcardRule['headers'] as List<dynamic>).cast<Map<String, dynamic>>();

      final headerMap = <String, String>{};
      for (final h in headerList) {
        headerMap[h['key'] as String] = h['value'] as String;
      }

      // Assert the three required security headers
      expect(
        headerMap['X-Content-Type-Options'],
        equals('nosniff'),
        reason: 'X-Content-Type-Options must be nosniff',
      );
      expect(
        headerMap['X-Frame-Options'],
        equals('DENY'),
        reason: 'X-Frame-Options must be DENY',
      );
      expect(
        headerMap['Content-Security-Policy'],
        equals("frame-ancestors 'none'"),
        reason: "Content-Security-Policy must enforce frame-ancestors 'none'",
      );
    });
  });
}
