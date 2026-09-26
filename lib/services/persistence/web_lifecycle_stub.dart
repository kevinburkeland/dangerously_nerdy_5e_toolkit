import 'debounced_storage_service.dart';

/// Platform-safe no-op for non-web environments (mobile, desktop, unit tests).
void setupWebLifecycle(DebouncedStorageService storage) {
  // No-op on non-web platforms
}
