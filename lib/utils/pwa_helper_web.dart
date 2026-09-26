import 'dart:js_interop';
import '../services/logging_service.dart';

@JS('triggerPwaInstall')
external void _triggerPwaInstall();

void promptPwaInstallImpl() {
  try {
    _triggerPwaInstall();
  } catch (e, stackTrace) {
    LoggingService().logNonFatal(
      e,
      stackTrace,
      reason: 'Browser PWA install trigger JS interop unavailable',
    );
  }
}
