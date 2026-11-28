import 'dart:js_interop';
import 'package:flutter/foundation.dart';
import 'package:web/web.dart' as web;
import '../logging_service.dart';
import 'debounced_storage_service.dart';

/// Binds browser lifecycle unload event listener on Web to forcefully flush debounced disk writes.
void setupWebLifecycle(DebouncedStorageService storage) {
  if (kIsWeb) {
    try {
      final listener = ((web.Event _) {
        storage.flushAllSync();
      }).toJS;
      web.window.addEventListener('beforeunload', listener);
      web.window.addEventListener('pagehide', listener);
    } catch (e, st) {
      LoggingService().logNonFatal(
        e,
        st,
        reason: 'Failed to bind browser lifecycle unload event listeners on Web',
      );
    }
  }
}
