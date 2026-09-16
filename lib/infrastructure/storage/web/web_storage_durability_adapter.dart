import 'dart:js_interop';
import 'dart:js_interop_unsafe';
import 'package:web/web.dart' as web;
import '../../../domain/storage/models/engine_profile.dart';
import '../../../domain/storage/models/storage_telemetry_report.dart';
import '../../../domain/storage/ports/i_storage_durability_port.dart';
import '../user_agent_parser.dart';

/// Web implementation of [IStorageDurabilityPort] utilizing W3C StorageManager standards.
class StorageDurabilityAdapter implements IStorageDurabilityPort {
  const StorageDurabilityAdapter();

  @override
  EngineProfile detectProfile() {
    final ua = web.window.navigator.userAgent;
    bool isStandalone = false;

    try {
      if (web.window.matchMedia('(display-mode: standalone)').matches) {
        isStandalone = true;
      } else {
        final nav = web.window.navigator as JSObject;
        if (nav.has('standalone')) {
          final val = nav['standalone'];
          // ignore: sdk_version_since
          if (val != null && val.isA<JSBoolean>() && (val as JSBoolean).toDart) {
            isStandalone = true;
          }
        }
      }
    } catch (_) {}

    return UserAgentParser.parse(
      ua,
      isStandalonePwa: isStandalone,
    );
  }

  @override
  Future<StorageTelemetryReport> inspectStorage() async {
    final profile = detectProfile();
    bool isPersisted = false;
    int bytesUsed = 0;
    int byteQuota = 0;

    try {
      final persistedJs = await web.window.navigator.storage.persisted().toDart;
      isPersisted = persistedJs.toDart;
    } catch (_) {}

    try {
      final estimate = await web.window.navigator.storage.estimate().toDart;
      bytesUsed = (estimate.usage as num?)?.toInt() ?? 0;
      byteQuota = (estimate.quota as num?)?.toInt() ?? 0;
    } catch (_) {}

    return StorageTelemetryReport.safe(
      isPersisted: isPersisted,
      bytesUsed: bytesUsed,
      byteQuota: byteQuota,
      profile: profile,
    );
  }

  @override
  Future<bool> requestPersistence() async {
    try {
      final grantedJs = await web.window.navigator.storage.persist().toDart;
      return grantedJs.toDart;
    } catch (_) {
      return false;
    }
  }
}
