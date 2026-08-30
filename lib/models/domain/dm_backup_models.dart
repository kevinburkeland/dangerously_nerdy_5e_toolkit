import 'package:flutter/foundation.dart';

/// Status classification of an imported campaign or system snapshot payload.
enum ImportValidationStatus {
  valid,
  validWithWarnings,
  corrupt,
  incompatibleVersion,
}

/// Comprehensive diagnostic report of a JSON snapshot validation inspection.
@immutable
class ImportValidationReport {
  final ImportValidationStatus status;
  final int schemaVersion;
  final String appVersion;
  final String payloadType; // 'campaign_profile' | 'full_system_snapshot' | 'unknown'
  final List<String> warnings;
  final List<String> errors;

  const ImportValidationReport({
    required this.status,
    this.schemaVersion = 1,
    this.appVersion = '1.0.0',
    this.payloadType = 'unknown',
    this.warnings = const [],
    this.errors = const [],
  });

  bool get isValid =>
      status == ImportValidationStatus.valid ||
      status == ImportValidationStatus.validWithWarnings;

  bool get isFullSystemSnapshot => payloadType == 'full_system_snapshot';
  bool get isCampaignProfile => payloadType == 'campaign_profile';
}
