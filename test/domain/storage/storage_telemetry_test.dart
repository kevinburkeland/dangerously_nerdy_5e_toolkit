import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:dangerously_nerdy_5e_toolkit/domain/storage/models/engine_profile.dart';
import 'package:dangerously_nerdy_5e_toolkit/domain/storage/models/storage_checksum.dart';
import 'package:dangerously_nerdy_5e_toolkit/domain/storage/models/storage_snapshot_bundle.dart';
import 'package:dangerously_nerdy_5e_toolkit/domain/storage/models/storage_telemetry_report.dart';
import 'package:dangerously_nerdy_5e_toolkit/infrastructure/storage/user_agent_parser.dart';

void main() {
  group('EngineProfile Value Object Invariants', () {
    test('Token-based user agent detection without regex', () {
      // Chrome on macOS
      const chromeUa =
          'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36';
      final chromeProfile = UserAgentParser.parse(chromeUa);
      expect(chromeProfile.engine, equals(BrowserEngine.chromium));
      expect(chromeProfile.os, equals(PlatformOs.macos));
      expect(chromeProfile.isStandalonePwa, isFalse);
      expect(chromeProfile.isWebKitEvictionRisk, isFalse);
      expect(chromeProfile.requiresExplicitGesture, isFalse);

      // Safari on macOS
      const safariUa =
          'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.2 Safari/605.1.15';
      final safariProfile = UserAgentParser.parse(safariUa);
      expect(safariProfile.engine, equals(BrowserEngine.webkit));
      expect(safariProfile.os, equals(PlatformOs.macos));
      expect(safariProfile.isWebKitEvictionRisk, isTrue);

      // Firefox on Windows
      const firefoxUa =
          'Mozilla/5.0 (Windows NT 10.0; Win64; x64; rv:109.0) Gecko/20100101 Firefox/119.0';
      final firefoxProfile = UserAgentParser.parse(firefoxUa);
      expect(firefoxProfile.engine, equals(BrowserEngine.gecko));
      expect(firefoxProfile.os, equals(PlatformOs.windows));
      expect(firefoxProfile.requiresExplicitGesture, isTrue);
      expect(firefoxProfile.isWebKitEvictionRisk, isFalse);

      // Safari on iOS (iPhone)
      const iosSafariUa =
          'Mozilla/5.0 (iPhone; CPU iPhone OS 17_1 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.1 Mobile/15E148 Safari/604.1';
      final iosTabProfile = UserAgentParser.parse(iosSafariUa, isStandalonePwa: false);
      expect(iosTabProfile.engine, equals(BrowserEngine.webkit));
      expect(iosTabProfile.os, equals(PlatformOs.ios));
      expect(iosTabProfile.isWebKitEvictionRisk, isTrue);

      // Standalone PWA on iOS
      final iosPwaProfile = UserAgentParser.parse(iosSafariUa, isStandalonePwa: true);
      expect(iosPwaProfile.isWebKitEvictionRisk, isFalse);
      expect(iosPwaProfile.requiresExplicitGesture, isFalse);

      // Standalone PWA on Firefox Desktop
      final ffPwaProfile = UserAgentParser.parse(firefoxUa, isStandalonePwa: true);
      expect(ffPwaProfile.requiresExplicitGesture, isFalse);
    });
  });

  group('StorageTelemetryReport Permutations & Risk Properties', () {
    test('Evaluates isUnprotected strictly against WebKit eviction risk and persistence', () {
      const safariTab = EngineProfile(
        engine: BrowserEngine.webkit,
        os: PlatformOs.macos,
        isStandalonePwa: false,
      );

      final unpersistedSafari = StorageTelemetryReport(
        isPersisted: false,
        bytesUsed: 100,
        byteQuota: 1000,
        profile: safariTab,
        timestamp: DateTime.now(),
      );
      expect(unpersistedSafari.isWebKitEvictionRisk, isTrue);
      expect(unpersistedSafari.isUnprotected, isTrue);

      final persistedSafari = unpersistedSafari.copyWith(isPersisted: true);
      expect(persistedSafari.isWebKitEvictionRisk, isTrue);
      expect(persistedSafari.isUnprotected, isFalse);

      const safariPwa = EngineProfile(
        engine: BrowserEngine.webkit,
        os: PlatformOs.macos,
        isStandalonePwa: true,
      );
      final pwaReport = StorageTelemetryReport(
        isPersisted: false,
        bytesUsed: 100,
        byteQuota: 1000,
        profile: safariPwa,
        timestamp: DateTime.now(),
      );
      expect(pwaReport.isWebKitEvictionRisk, isFalse);
      expect(pwaReport.isUnprotected, isFalse);

      const chromeTab = EngineProfile(
        engine: BrowserEngine.chromium,
        os: PlatformOs.windows,
        isStandalonePwa: false,
      );
      final unpersistedChrome = StorageTelemetryReport(
        isPersisted: false,
        bytesUsed: 100,
        byteQuota: 1000,
        profile: chromeTab,
        timestamp: DateTime.now(),
      );
      expect(unpersistedChrome.isWebKitEvictionRisk, isFalse);
      expect(unpersistedChrome.isUnprotected, isFalse);
    });

    test('Computes quotaUsagePercent and flags critical pressure at >= 80%', () {
      const profile = EngineProfile(
        engine: BrowserEngine.chromium,
        os: PlatformOs.linux,
        isStandalonePwa: true,
      );

      final normalReport = StorageTelemetryReport(
        isPersisted: true,
        bytesUsed: 790,
        byteQuota: 1000,
        profile: profile,
        timestamp: DateTime.now(),
      );
      expect(normalReport.quotaUsagePercent, closeTo(79.0, 0.001));
      expect(normalReport.isCriticalPressure, isFalse);

      final criticalReport = normalReport.copyWith(bytesUsed: 800);
      expect(criticalReport.quotaUsagePercent, closeTo(80.0, 0.001));
      expect(criticalReport.isCriticalPressure, isTrue);

      final fullReport = normalReport.copyWith(bytesUsed: 1000);
      expect(fullReport.quotaUsagePercent, closeTo(100.0, 0.001));
      expect(fullReport.isCriticalPressure, isTrue);

      final zeroQuotaReport = StorageTelemetryReport(
        isPersisted: true,
        bytesUsed: 0,
        byteQuota: 0,
        profile: profile,
        timestamp: DateTime.now(),
      );
      expect(zeroQuotaReport.quotaUsagePercent, equals(0.0));
      expect(zeroQuotaReport.isCriticalPressure, isFalse);
    });
  });

  group('StorageSnapshotBundle Cryptographic Integrity', () {
    test('Validates authentic bundle with constant-time SHA-256 seal', () {
      final payload = Uint8List.fromList(utf8.encode('{"campaign":"Staging Node"}'));
      final bundle = StorageSnapshotBundle.create(
        vaultId: 'vault_alpha',
        payloadBytes: payload,
      );

      expect(bundle.isValid, isTrue);
      expect(() => bundle.validateOrThrow(), returnsNormally);

      final expectedChecksum = StorageChecksum.computeBundleChecksum('vault_alpha', payload);
      expect(bundle.sha256Checksum, equals(expectedChecksum));
    });

    test('Rejects tampered payloadBytes or altered vaultId', () {
      final payload = Uint8List.fromList(utf8.encode('{"gold": 1000}'));
      final bundle = StorageSnapshotBundle.create(
        vaultId: 'vault_beta',
        payloadBytes: payload,
      );

      // Tamper with payload
      final tamperedPayload = Uint8List.fromList(utf8.encode('{"gold": 999999}'));
      final tamperedBundle = bundle.copyWith(payloadBytes: tamperedPayload);

      expect(tamperedBundle.isValid, isFalse);
      expect(() => tamperedBundle.validateOrThrow(), throwsA(isA<StateError>()));

      // Tamper with vaultId
      final tamperedVaultBundle = bundle.copyWith(vaultId: 'vault_charlie');
      expect(tamperedVaultBundle.isValid, isFalse);
      expect(() => tamperedVaultBundle.validateOrThrow(), throwsA(isA<StateError>()));

      // Tamper with checksum string
      final tamperedChecksumBundle = bundle.copyWith(
        sha256Checksum: '0000000000000000000000000000000000000000000000000000000000000000',
      );
      expect(tamperedChecksumBundle.isValid, isFalse);
      expect(() => tamperedChecksumBundle.validateOrThrow(), throwsA(isA<StateError>()));
    });

    test('Round-trip envelope serialization preserves cryptographic seal', () {
      final payload = Uint8List.fromList(utf8.encode('{"characters": ["c1", "c2"]}'));
      final bundle = StorageSnapshotBundle.create(
        vaultId: 'vault_delta',
        payloadBytes: payload,
        schemaVersion: '1.2.0',
      );

      final bytes = bundle.toBytes();
      final restored = StorageSnapshotBundle.fromBytes(bytes);

      expect(restored.vaultId, equals('vault_delta'));
      expect(restored.schemaVersion, equals('1.2.0'));
      expect(restored.sha256Checksum, equals(bundle.sha256Checksum));
      expect(restored.payloadBytes, equals(bundle.payloadBytes));
      expect(restored.isValid, isTrue);
    });
  });
}
