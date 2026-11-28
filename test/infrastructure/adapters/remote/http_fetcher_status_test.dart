import 'package:dangerously_nerdy_5e_toolkit/infrastructure/adapters/remote/http_fetcher.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Fix 5.2 HTTP status-to-result mapping table', () {
    final uri = Uri.parse('https://api.github.com/repos/example/repo');

    test('2xx statuses return responseText (or empty string when null)', () {
      for (final status in [200, 201, 204, 299]) {
        expect(
          resolveHttpFetchStatus(
            uri: uri,
            status: status,
            statusText: 'OK',
            responseText: '{"ok":true}',
          ),
          equals('{"ok":true}'),
        );
      }
      expect(
        resolveHttpFetchStatus(
          uri: uri,
          status: 200,
          statusText: 'OK',
          responseText: null,
        ),
        equals(''),
      );
    });

    test('404, 403, and other non-2xx statuses throw exact HttpFetchException', () {
      final cases = <(int, String?, String)>[
        (
          404,
          'Not Found',
          'Resource not found on GitHub (HTTP 404). Verify the repository name and branch.',
        ),
        (
          403,
          'Forbidden',
          'GitHub API rate limit exceeded or access forbidden (HTTP 403).',
        ),
        (500, 'Internal Server Error', 'HTTP 500 Internal Server Error: Failed to fetch $uri'),
        (502, null, 'HTTP 502 Error: Failed to fetch $uri'),
        (0, '', 'HTTP 0 : Failed to fetch $uri'),
      ];

      for (final (status, statusText, expectedMsg) in cases) {
        expect(
          () => resolveHttpFetchStatus(
            uri: uri,
            status: status,
            statusText: statusText,
            responseText: '',
          ),
          throwsA(
            isA<HttpFetchException>()
                .having((e) => e.statusCode, 'statusCode', status)
                .having((e) => e.uri, 'uri', uri)
                .having((e) => e.message, 'message', expectedMsg),
          ),
        );
      }
    });
  });
}
