// ignore_for_file: deprecated_member_use, avoid_web_libraries_in_flutter
import 'dart:html' as html;
import 'package:flutter/foundation.dart';
import 'debounced_storage_service.dart';

/// Binds browser lifecycle unload event listener on Web to forcefully flush debounced disk writes.
void setupWebLifecycle(DebouncedStorageService storage) {
  if (kIsWeb) {
    try {
      html.window.onBeforeUnload.listen((event) {
        storage.flushAllSync();
      });
      html.window.onPageHide.listen((event) {
        storage.flushAllSync();
      });
    } catch (_) {
      // Non-fatal if environment restrictions prevent listener registration
    }
  }
}
