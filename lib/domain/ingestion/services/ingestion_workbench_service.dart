import 'package:uuid/uuid.dart';
import '../capability/ruleset_ingestion_capability.dart';
import '../engine/candidate_detector.dart';
import '../engine/source_block_parser.dart';
import '../models/candidate_identification.dart';
import '../models/ingestion_candidate.dart';
import '../models/ingestion_document_result.dart';
import '../models/ingestion_field.dart';
import '../models/source_block.dart';
import '../models/source_span.dart';

/// Application/Domain service orchestrating the multi-stage ingestion workbench pipeline:
/// raw source → normalized blocks → candidate object identification → ruleset capability extraction
/// → missing/invalid/ambiguous fields → editable draft → validated domain object.
///
/// This service is 100% ruleset-agnostic and relies on [RulesetIngestionCapability]
/// to interpret domain semantics, validate invariants, and construct domain entities.
class IngestionWorkbenchService {
  final SourceBlockParser _blockParser;
  final CandidateDetector _detector;
  final RulesetIngestionCapability _capability;
  final Uuid _uuid;

  IngestionWorkbenchService({
    required RulesetIngestionCapability capability,
    SourceBlockParser? blockParser,
    CandidateDetector? detector,
    Uuid? uuid,
  })  : _capability = capability,
        _blockParser = blockParser ?? const SourceBlockParser(),
        _detector = detector ?? const CandidateDetector(),
        _uuid = uuid ?? const Uuid();

  RulesetIngestionCapability get capability => _capability;

  /// Parses raw text input into an [IngestionDocumentResult] with detected candidates
  /// and unassigned blocks. Unknown and ambiguous candidates remain unresolved.
  IngestionDocumentResult parse(String rawText) {
    final stopwatch = Stopwatch()..start();

    if (rawText.trim().isEmpty) {
      return const IngestionDocumentResult.empty();
    }

    // Step 1: Syntactic parsing into blocks with character spans
    final doc = _blockParser.parse(rawText);

    // Step 2: Boundary detection and candidate clustering
    final clusters = _detector.detectClusters(doc);

    final candidates = <IngestionCandidate>[];
    final unassignedBlocks = <SourceBlock>[];

    for (final cluster in clusters) {
      if (!cluster.isCandidate) {
        // Collect unassigned blocks (e.g. surrounding prose, instructions, notes)
        unassignedBlocks.addAll(cluster.blocks);
        continue;
      }

      // Step 3: Identify candidate type without coercion!
      // Unknown or ambiguous candidates MUST REMAIN UNRESOLVED (targetTypeKey = null).
      final ident = cluster.identification;
      final String? targetType = (ident.isUnknown || ident.isAmbiguous)
          ? null
          : ident.identifiedTypeKey;

      final candidate = _buildCandidateFromBlocks(
        blocks: cluster.blocks,
        identification: ident,
        targetTypeKey: targetType,
        span: cluster.span,
      );

      candidates.add(candidate);
    }

    stopwatch.stop();

    return IngestionDocumentResult(
      source: doc,
      candidates: candidates,
      unassignedBlocks: unassignedBlocks,
      parseDurationMs: stopwatch.elapsedMilliseconds,
    );
  }

  /// Explicitly resolves or changes a candidate's target type (e.g. user chooses 'Monster' or 'Spell').
  /// Preserves any existing user edits where field keys match.
  IngestionCandidate changeCandidateType(
    IngestionCandidate candidate,
    String newTypeKey,
  ) {
    final newCandidate = _buildCandidateFromBlocks(
      blocks: candidate.blocks,
      identification: candidate.identification,
      targetTypeKey: newTypeKey,
      span: candidate.span,
      isUserOverridden: true,
      existingIgnored: candidate.ignoredBlockIds,
    );

    // Reapply any user-edited fields from previous candidate draft if keys align
    final mergedFields = Map<String, IngestionField<dynamic>>.from(newCandidate.fields);
    for (final entry in candidate.fields.entries) {
      if (entry.value.isUserEdited && mergedFields.containsKey(entry.key)) {
        mergedFields[entry.key] = entry.value;
      }
    }

    return newCandidate.copyWith(fields: mergedFields);
  }

  /// Updates an individual field value on a candidate due to user manual input.
  IngestionCandidate updateCandidateField(
    IngestionCandidate candidate,
    String fieldKey,
    dynamic newValue,
  ) {
    final existingField = candidate.fields[fieldKey];
    if (existingField == null) return candidate;

    final descriptor = _capability.getTargetDescriptor(candidate.targetTypeKey);
    final fieldDesc = descriptor?.getField(fieldKey);

    // Syntactic validation only; domain validation is handled by capability.validateCandidate
    final validationError = fieldDesc?.validateSyntactic(newValue);

    final updatedField = existingField.withUserEdit(newValue).copyWith(
          validationError: validationError,
        );

    return candidate.updateField(fieldKey, updatedField);
  }

  /// Toggles ignore status on an unrecognized block.
  IngestionCandidate toggleIgnoreBlock(
    IngestionCandidate candidate,
    String blockId,
  ) {
    return candidate.toggleIgnoreBlock(blockId);
  }

  /// Validates candidate invariants against the active ruleset capability.
  CandidateValidationResult validate(IngestionCandidate candidate) {
    return _capability.validateCandidate(candidate);
  }

  /// Converts a validated candidate into an authentic ruleset domain object.
  DomainConversionResult convertToDomainEntity(IngestionCandidate candidate) {
    return _capability.convertCandidate(candidate);
  }

  IngestionCandidate _buildCandidateFromBlocks({
    required List<SourceBlock> blocks,
    required CandidateIdentification identification,
    required String? targetTypeKey,
    required SourceSpan span,
    bool isUserOverridden = false,
    Set<String> existingIgnored = const {},
  }) {
    Map<String, IngestionField<dynamic>> fields;
    List<SourceBlock> unrecognizedBlocks;

    if (targetTypeKey != null && targetTypeKey.isNotEmpty) {
      fields = _capability.extractFields(
        targetTypeKey: targetTypeKey,
        blocks: blocks,
        span: span,
      );
      // Blocks not consumed as heading or statlines remain unrecognized
      unrecognizedBlocks = blocks.where((b) {
        if (b.type == SourceBlockType.divider) return false;
        // If a field span references this block's span, it is recognized
        final isReferenced = fields.values.any((f) =>
            f.span != null &&
            !f.span!.isEmpty &&
            f.span!.startOffset <= b.span.startOffset &&
            f.span!.endOffset >= b.span.endOffset);
        return !isReferenced;
      }).toList();
    } else {
      // Unresolved candidate (unknown or ambiguous)
      fields = const {};
      unrecognizedBlocks = blocks;
    }

    final rawSource = blocks.map((b) => b.rawText).join('\n');
    final normalizedSource = blocks.map((b) => b.normalizedText).join('\n');

    return IngestionCandidate(
      id: _uuid.v4(),
      span: span,
      rawSource: rawSource,
      normalizedSource: normalizedSource,
      blocks: blocks,
      identification: identification,
      targetTypeKey: targetTypeKey,
      fields: fields,
      unrecognizedBlocks: unrecognizedBlocks,
      ignoredBlockIds: existingIgnored,
      isUserOverridden: isUserOverridden,
    );
  }
}
