import '../../domain/storage/models/engine_profile.dart';

/// Infrastructure service that parses raw HTTP User-Agent strings and standalone display mode
/// into pure domain [EngineProfile] classifications.
class UserAgentParser {
  const UserAgentParser._();

  static EngineProfile parse(String userAgent, {bool isStandalonePwa = false}) {
    final ua = userAgent.toLowerCase();

    // 1. Detect Host OS via deterministic substring matching
    final PlatformOs detectedOs;
    if (ua.contains('iphone') || ua.contains('ipad') || ua.contains('ipod')) {
      detectedOs = PlatformOs.ios;
    } else if (ua.contains('android')) {
      detectedOs = PlatformOs.android;
    } else if (ua.contains('macintosh') || ua.contains('mac os x')) {
      detectedOs = PlatformOs.macos;
    } else if (ua.contains('windows')) {
      detectedOs = PlatformOs.windows;
    } else if (ua.contains('linux')) {
      detectedOs = PlatformOs.linux;
    } else {
      detectedOs = PlatformOs.other;
    }

    // 2. Detect Browser Engine via deterministic substring matching
    final BrowserEngine detectedEngine;
    if (detectedOs == PlatformOs.ios) {
      detectedEngine = BrowserEngine.webkit;
    } else if (ua.contains('firefox') || ua.contains('fxios') || ua.contains('gecko/')) {
      detectedEngine = BrowserEngine.gecko;
    } else if (ua.contains('edg/') ||
        ua.contains('chrome') ||
        ua.contains('chromium') ||
        ua.contains('crios')) {
      detectedEngine = BrowserEngine.chromium;
    } else if (ua.contains('safari') || ua.contains('applewebkit')) {
      detectedEngine = BrowserEngine.webkit;
    } else {
      detectedEngine = BrowserEngine.other;
    }

    return EngineProfile(
      engine: detectedEngine,
      os: detectedOs,
      isStandalonePwa: isStandalonePwa,
    );
  }
}
