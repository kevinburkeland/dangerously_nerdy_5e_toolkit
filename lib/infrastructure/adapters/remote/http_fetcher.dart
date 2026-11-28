import 'http_fetcher_io.dart' if (dart.library.html) 'http_fetcher_web.dart';

/// Cross-platform HTTP exception providing clear error status codes and messages.
class HttpFetchException implements Exception {
  final String message;
  final int? statusCode;
  final Uri? uri;

  const HttpFetchException(this.message, {this.statusCode, this.uri});

  @override
  String toString() {
    final status = statusCode != null ? ' (HTTP $statusCode)' : '';
    final url = uri != null ? ' for $uri' : '';
    return 'HttpFetchException$status: $message$url';
  }
}

/// Pure Dart HTTP fetch abstraction decoupling remote ingestion from concrete I/O.
abstract class HttpFetchClient {
  Future<String> get(Uri uri);

  /// Creates a platform-appropriate default client (HttpClient on native, HttpRequest on web).
  factory HttpFetchClient() => createPlatformClient();
}

/// Maps an HTTP response status to its body string or throws [HttpFetchException]
/// with the exact status-specific error message.
String resolveHttpFetchStatus({
  required Uri uri,
  required int status,
  required String? statusText,
  required String? responseText,
}) {
  if (status >= 200 && status < 300) {
    return responseText ?? '';
  } else if (status == 404) {
    throw HttpFetchException(
      'Resource not found on GitHub (HTTP 404). Verify the repository name and branch.',
      statusCode: 404,
      uri: uri,
    );
  } else if (status == 403) {
    throw HttpFetchException(
      'GitHub API rate limit exceeded or access forbidden (HTTP 403).',
      statusCode: 403,
      uri: uri,
    );
  } else {
    throw HttpFetchException(
      'HTTP $status ${statusText ?? "Error"}: Failed to fetch $uri',
      statusCode: status,
      uri: uri,
    );
  }
}
