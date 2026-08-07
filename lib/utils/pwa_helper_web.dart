import 'dart:js_interop';

@JS('triggerPwaInstall')
external void _triggerPwaInstall();

void promptPwaInstallImpl() {
  try {
    _triggerPwaInstall();
  } catch (_) {
    // Fallback if JS interop fails
  }
}
