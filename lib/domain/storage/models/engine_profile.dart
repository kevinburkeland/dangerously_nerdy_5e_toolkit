import 'package:meta/meta.dart';

/// Browser rendering engines with distinct storage eviction characteristics.
enum BrowserEngine {
  chromium,
  webkit,
  gecko,
  other,
}

/// Host operating system classification.
enum PlatformOs {
  ios,
  android,
  macos,
  windows,
  linux,
  other,
}

/// Immutable client profile capturing browser engine and display mode characteristics.
@immutable
class EngineProfile {
  final BrowserEngine engine;
  final PlatformOs os;
  final bool isStandalonePwa;

  const EngineProfile({
    required this.engine,
    required this.os,
    required this.isStandalonePwa,
  });

  /// Deterministic token-matching factory parsing user agent and standalone mode
  /// without regular expressions.
  factory EngineProfile.fromUserAgent({
    required String userAgent,
    bool isStandalonePwa = false,
  }) {
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
    // On iOS, all non-standalone browsers share WebKit storage restrictions.
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

  /// WebKit 7-day ITP eviction risk applies to non-standalone WebKit engines and all non-standalone iOS browsers.
  bool get isWebKitEvictionRisk =>
      (engine == BrowserEngine.webkit || os == PlatformOs.ios) && !isStandalonePwa;

  /// Firefox enforces strict permission fences requiring explicit user gestures for persistent storage.
  bool get requiresExplicitGesture =>
      engine == BrowserEngine.gecko && !isStandalonePwa;

  EngineProfile copyWith({
    BrowserEngine? engine,
    PlatformOs? os,
    bool? isStandalonePwa,
  }) {
    return EngineProfile(
      engine: engine ?? this.engine,
      os: os ?? this.os,
      isStandalonePwa: isStandalonePwa ?? this.isStandalonePwa,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is EngineProfile &&
          runtimeType == other.runtimeType &&
          engine == other.engine &&
          os == other.os &&
          isStandalonePwa == other.isStandalonePwa;

  @override
  int get hashCode => Object.hash(engine, os, isStandalonePwa);

  @override
  String toString() =>
      'EngineProfile(engine: $engine, os: $os, isStandalonePwa: $isStandalonePwa)';
}
