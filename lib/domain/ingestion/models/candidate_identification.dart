import 'package:meta/meta.dart';
import 'candidate_evidence.dart';

/// Evidence-backed candidate object identification result.
@immutable
class CandidateIdentification {
  /// Confidently identified type key, or null if ambiguous or unknown.
  final String? identifiedTypeKey;

  /// Confidence score between 0.0 and 1.0.
  final double confidence;

  /// Granular pieces of evidence gathered from source text.
  final List<CandidateEvidence> evidence;

  /// Plausible candidate type keys when classification is ambiguous.
  final List<String> plausibleTypeKeys;

  /// True if candidate could belong to multiple candidate types with close confidence.
  final bool isAmbiguous;

  /// True if no plausible object type matched the source text.
  final bool isUnknown;

  const CandidateIdentification({
    this.identifiedTypeKey,
    required this.confidence,
    required this.evidence,
    this.plausibleTypeKeys = const [],
    this.isAmbiguous = false,
    this.isUnknown = false,
  });

  const CandidateIdentification.unknown([String reason = 'Insufficient evidence'])
      : identifiedTypeKey = null,
        confidence = 0.0,
        evidence = const [],
        plausibleTypeKeys = const [],
        isAmbiguous = false,
        isUnknown = true;

  const CandidateIdentification.ambiguous({
    required List<String> plausibleTypes,
    required this.evidence,
    this.confidence = 0.5,
  })  : identifiedTypeKey = null,
        plausibleTypeKeys = plausibleTypes,
        isAmbiguous = true,
        isUnknown = false;

  String get summaryLabel {
    if (isUnknown) return 'Unknown Object';
    if (isAmbiguous) {
      return 'Ambiguous (${plausibleTypeKeys.join(' / ')})';
    }
    return identifiedTypeKey != null
        ? identifiedTypeKey![0].toUpperCase() + identifiedTypeKey!.substring(1)
        : 'Unknown';
  }

  CandidateIdentification copyWith({
    String? identifiedTypeKey,
    double? confidence,
    List<CandidateEvidence>? evidence,
    List<String>? plausibleTypeKeys,
    bool? isAmbiguous,
    bool? isUnknown,
  }) {
    return CandidateIdentification(
      identifiedTypeKey: identifiedTypeKey ?? this.identifiedTypeKey,
      confidence: confidence ?? this.confidence,
      evidence: evidence ?? this.evidence,
      plausibleTypeKeys: plausibleTypeKeys ?? this.plausibleTypeKeys,
      isAmbiguous: isAmbiguous ?? this.isAmbiguous,
      isUnknown: isUnknown ?? this.isUnknown,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CandidateIdentification &&
          runtimeType == other.runtimeType &&
          identifiedTypeKey == other.identifiedTypeKey &&
          confidence == other.confidence &&
          isAmbiguous == other.isAmbiguous &&
          isUnknown == other.isUnknown;

  @override
  int get hashCode => Object.hash(
        identifiedTypeKey,
        confidence,
        isAmbiguous,
        isUnknown,
      );

  @override
  String toString() =>
      'CandidateIdentification($summaryLabel, ${(confidence * 100).toStringAsFixed(0)}% confidence)';
}
