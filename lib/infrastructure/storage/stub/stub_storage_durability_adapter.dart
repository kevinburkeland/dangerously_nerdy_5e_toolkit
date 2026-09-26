import 'dart:io';
import 'package:vtt_engine_core/storage/models/engine_profile.dart';
import 'package:vtt_engine_core/storage/models/storage_telemetry_report.dart';
import 'package:vtt_engine_core/storage/ports/i_storage_durability_port.dart';

/// Non-web fallback adapter for storage durability inspection and persistence.
class StorageDurabilityAdapter implements IStorageDurabilityPort {
  const StorageDurabilityAdapter();

  @override
  EngineProfile detectProfile() {
    PlatformOs os = PlatformOs.other;
    try {
      if (Platform.isIOS) {
        os = PlatformOs.ios;
      } else if (Platform.isAndroid) {
        os = PlatformOs.android;
      } else if (Platform.isMacOS) {
        os = PlatformOs.macos;
      } else if (Platform.isWindows) {
        os = PlatformOs.windows;
      } else if (Platform.isLinux) {
        os = PlatformOs.linux;
      }
    } catch (_) {}

    return EngineProfile(
      engine: BrowserEngine.other,
      os: os,
      isStandalonePwa: true,
    );
  }

  @override
  Future<StorageTelemetryReport> inspectStorage() async {
    return StorageTelemetryReport.safe(
      isPersisted: true,
      bytesUsed: 0,
      byteQuota: 1024 * 1024 * 1024,
      profile: detectProfile(),
    );
  }

  @override
  Future<bool> requestPersistence() async {
    return true;
  }
}
