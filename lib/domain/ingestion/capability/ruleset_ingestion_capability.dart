import '../descriptors/ingestion_target_descriptor.dart';
import '../models/ingestion_candidate.dart';
import '../models/ingestion_field.dart';
import '../models/source_block.dart';
import '../models/source_span.dart';

/// Validation report on whether an IngestionCandidate satisfies the domain invariants
/// of a specific tabletop ruleset.
class CandidateValidationResult {
  final bool isValid;
  final List<String> blockingErrors;
  final List<String> nonBlockingWarnings;

  const CandidateValidationResult({
    required this.isValid,
    required this.blockingErrors,
    this.nonBlockingWarnings = const [],
  });

  factory CandidateValidationResult.valid({List<String> warnings = const []}) {
    return CandidateValidationResult(
      isValid: true,
      blockingErrors: const [],
      nonBlockingWarnings: warnings,
    );
  }

  factory CandidateValidationResult.invalid({
    required List<String> errors,
    List<String> warnings = const [],
  }) {
    return CandidateValidationResult(
      isValid: false,
      blockingErrors: errors,
      nonBlockingWarnings: warnings,
    );
  }
}

/// Result of converting an IngestionCandidate into an authentic ruleset domain object.
class DomainConversionResult {
  final bool isSuccess;
  final Object? entity;
  final List<String> errors;

  const DomainConversionResult.success(this.entity)
      : isSuccess = true,
        errors = const [];

  const DomainConversionResult.failure(this.errors)
      : isSuccess = false,
        entity = null;
}

/// Capability interface implemented by ruleset modules (e.g. D&D 5e, Pathfinder 2e)
/// to govern candidate extraction, domain validation, and entity construction.
///
/// This boundary guarantees that generic ingestion code does not import concrete
/// domain entity models or define shadow domain schemas.
abstract interface class RulesetIngestionCapability {
  /// Unique ruleset identifier (e.g. 'dnd5e_2024', 'dnd5e_2014', 'pf2e').
  String get rulesetId;

  /// User-facing display title for the ruleset (e.g. 'D&D 5e (2024 Revised)').
  String get displayName;

  /// Ingestion target descriptors supported by this ruleset (e.g. Monster, Spell).
  Iterable<IngestionTargetDescriptor> get supportedTargets;

  /// Returns the descriptor for [typeKey] or null if unsupported by this ruleset.
  IngestionTargetDescriptor? getTargetDescriptor(String? typeKey);

  /// Validates [candidate] against actual domain invariants before conversion.
  CandidateValidationResult validateCandidate(IngestionCandidate candidate);

  /// Converts a validated [candidate] into a real ruleset domain object.
  /// Fails loudly without fabricating plausible defaults if required values are absent.
  DomainConversionResult convertCandidate(IngestionCandidate candidate);

  /// Performs ruleset-specific field extraction on candidate [blocks] for [targetTypeKey].
  Map<String, IngestionField> extractFields({
    required String targetTypeKey,
    required List<SourceBlock> blocks,
    SourceSpan? span,
  });

  /// Persists a successfully converted domain [entity] into storage.
  Future<void> persistEntity(Object entity, dynamic persistenceService);
}
