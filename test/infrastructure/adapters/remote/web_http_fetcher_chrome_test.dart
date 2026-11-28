@TestOn('browser')
library;

import 'package:dangerously_nerdy_5e_toolkit/infrastructure/adapters/remote/http_fetcher.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('WebHttpFetchClient reads a data: URL and returns its text', () async {
    final client = HttpFetchClient();
    final body = await client.get(Uri.parse('data:text/plain,hello%20world'));
    expect(body, equals('hello world'));
  });
}
