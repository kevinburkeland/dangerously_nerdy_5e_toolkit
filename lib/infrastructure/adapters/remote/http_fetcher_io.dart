import 'dart:convert';
import 'dart:io';
import 'http_fetcher.dart';

HttpFetchClient createPlatformClient() => IoHttpFetchClient();

class IoHttpFetchClient implements HttpFetchClient {
  final HttpClient _client = HttpClient();

  @override
  Future<String> get(Uri uri) async {
    final request = await _client.getUrl(uri);
    request.headers.set('User-Agent', 'DangerouslyNerdy-5e-Toolkit/1.0');
    request.headers.set('Accept', 'application/json, text/plain, */*');
    final response = await request.close();
    if (response.statusCode >= 400) {
      throw HttpException('HTTP ${response.statusCode} for $uri');
    }
    return await response.transform(utf8.decoder).join();
  }
}
