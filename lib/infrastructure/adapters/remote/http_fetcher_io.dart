import 'dart:convert';
import 'dart:io';
import 'http_fetcher.dart';

HttpFetchClient createPlatformClient() => IoHttpFetchClient();

class IoHttpFetchClient implements HttpFetchClient {
  final HttpClient _client = HttpClient();

  @override
  Future<String> get(Uri uri) async {
    try {
      final request = await _client.getUrl(uri);
      request.headers.set('User-Agent', 'DangerouslyNerdy-5e-Toolkit/1.0');
      request.headers.set('Accept', 'application/json, text/plain, */*');
      final response = await request.close();
      if (response.statusCode >= 400) {
        if (response.statusCode == 404) {
          throw HttpFetchException(
            'Resource not found on GitHub. Verify the repository and branch name.',
            statusCode: 404,
            uri: uri,
          );
        }
        if (response.statusCode == 403) {
          throw HttpFetchException(
            'GitHub API rate limit exceeded or access forbidden.',
            statusCode: 403,
            uri: uri,
          );
        }
        throw HttpFetchException(
          'Failed to retrieve remote resource.',
          statusCode: response.statusCode,
          uri: uri,
        );
      }
      return await response.transform(utf8.decoder).join();
    } on HttpFetchException {
      rethrow;
    } catch (e) {
      throw HttpFetchException('Network connection failure: $e', uri: uri);
    }
  }
}
