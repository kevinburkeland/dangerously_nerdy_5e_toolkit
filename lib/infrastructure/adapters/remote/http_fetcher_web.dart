import 'dart:async';
import 'dart:js_interop';
import 'package:web/web.dart' as web;
import '../../../services/logging_service.dart';
import 'http_fetcher.dart';

HttpFetchClient createPlatformClient() => WebHttpFetchClient();

class WebHttpFetchClient implements HttpFetchClient {
  @override
  Future<String> get(Uri uri) {
    final completer = Completer<String>();
    final xhr = web.XMLHttpRequest();

    xhr.open('GET', uri.toString());
    // On web, User-Agent is forbidden by browser specs, but Accept header is allowed
    try {
      xhr.setRequestHeader('Accept', 'application/json, text/plain, */*');
    } catch (e, st) {
      LoggingService().logNonFatal(e, st,
          reason: 'Failed to set Accept header on HttpRequest');
    }

    xhr.addEventListener(
      'load',
      ((web.Event _) {
        try {
          completer.complete(
            resolveHttpFetchStatus(
              uri: uri,
              status: xhr.status,
              statusText: xhr.statusText,
              responseText: xhr.responseText,
            ),
          );
        } catch (e) {
          completer.completeError(e);
        }
      }).toJS,
    );

    xhr.addEventListener(
      'error',
      ((web.Event _) {
        final status = xhr.status;
        completer.completeError(
          HttpFetchException(
            'Network / Security Error: Request to $uri was blocked. '
            'Please verify the repository URL exists and that your network permits GitHub API connections.',
            statusCode: status != 0 ? status : null,
            uri: uri,
          ),
        );
      }).toJS,
    );

    xhr.addEventListener(
      'abort',
      ((web.Event _) {
        completer.completeError(
          HttpFetchException(
            'Request to $uri was aborted.',
            uri: uri,
          ),
        );
      }).toJS,
    );

    xhr.send();
    return completer.future;
  }
}
