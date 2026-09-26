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
