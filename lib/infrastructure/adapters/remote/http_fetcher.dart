import 'http_fetcher_io.dart' if (dart.library.html) 'http_fetcher_web.dart';

/// Pure Dart HTTP fetch abstraction decoupling remote ingestion from concrete I/O.
abstract class HttpFetchClient {
  Future<String> get(Uri uri);

  /// Creates a platform-appropriate default client (HttpClient on native, HttpRequest on web).
  factory HttpFetchClient() => createPlatformClient();
}
