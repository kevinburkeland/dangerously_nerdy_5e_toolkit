// ignore_for_file: deprecated_member_use, avoid_web_libraries_in_flutter
import 'dart:async';
import 'dart:html' as html;
import 'http_fetcher.dart';

HttpFetchClient createPlatformClient() => WebHttpFetchClient();

class WebHttpFetchClient implements HttpFetchClient {
  @override
  Future<String> get(Uri uri) {
    final completer = Completer<String>();
    final xhr = html.HttpRequest();

    xhr.open('GET', uri.toString());
    // On web, User-Agent is forbidden by browser specs, but Accept header is allowed
    try {
      xhr.setRequestHeader('Accept', 'application/json, text/plain, */*');
    } catch (_) {}

    xhr.onLoad.listen((_) {
      final status = xhr.status ?? 0;
      if (status >= 200 && status < 300) {
        completer.complete(xhr.responseText ?? '');
      } else if (status == 404) {
        completer.completeError(
          HttpFetchException(
            'Resource not found on GitHub (HTTP 404). Verify the repository name and branch.',
            statusCode: 404,
            uri: uri,
          ),
        );
      } else if (status == 403) {
        completer.completeError(
          HttpFetchException(
            'GitHub API rate limit exceeded or access forbidden (HTTP 403).',
            statusCode: 403,
            uri: uri,
          ),
        );
      } else {
        completer.completeError(
          HttpFetchException(
            'HTTP $status ${xhr.statusText ?? "Error"}: Failed to fetch $uri',
            statusCode: status,
            uri: uri,
          ),
        );
      }
    });

    xhr.onError.listen((_) {
      final status = xhr.status ?? 0;
      completer.completeError(
        HttpFetchException(
          'Network / Security Error: Request to $uri was blocked. '
          'Please verify the repository URL exists and that your network permits GitHub API connections.',
          statusCode: status != 0 ? status : null,
          uri: uri,
        ),
      );
    });

    xhr.onAbort.listen((_) {
      completer.completeError(
        HttpFetchException(
          'Request to $uri was aborted.',
          uri: uri,
        ),
      );
    });

    xhr.send();
    return completer.future;
  }
}
