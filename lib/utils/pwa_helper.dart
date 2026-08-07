import 'pwa_helper_stub.dart'
    if (dart.library.html) 'pwa_helper_web.dart';

abstract class PwaHelper {
  static void promptInstall() {
    promptPwaInstallImpl();
  }
}
