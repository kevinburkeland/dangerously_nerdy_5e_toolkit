// ignore_for_file: deprecated_member_use, avoid_web_libraries_in_flutter
import 'dart:html' as html;
import 'http_fetcher.dart';

HttpFetchClient createPlatformClient() => WebHttpFetchClient();

class WebHttpFetchClient implements HttpFetchClient {
  @override
  Future<String> get(Uri uri) async {
    return await html.HttpRequest.getString(uri.toString());
  }
}
