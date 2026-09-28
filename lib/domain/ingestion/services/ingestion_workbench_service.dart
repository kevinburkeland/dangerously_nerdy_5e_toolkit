import 'package:uuid/uuid.dart';
import '../conversion/candidate_to_entity_converter.dart';
import '../descriptors/descriptor_registry.dart';
import '../engine/candidate_detector.dart';
import '../engine/field_extractor.dart';
import '../engine/monster_field_extractor.dart';
import '../engine/source_block_parser.dart';
import '../engine/spell_field_extractor.dart';
import '../models/candidate_identification.dart';
import '../models/ingestion_candidate.dart';
import '../models/ingestion_document_result.dart';
import '../models/ingestion_field.dart';
import '../models/source_block.dart';
import '../models/source_span.dart';

/// Application/Domain service orchestrating the multi-stage ingestion workbench pipeline:
/// raw source → normalized blocks → candidate object identification → extracted fields
/// → missing/invalid/ambiguous fields → editable draft → validated domain object.
class IngestionWorkbenchService {
  final SourceBlockParser _blockParser;
  final CandidateDetector _detector;
  final Map<String, FieldExtractor> _extractors;
  final CandidateToEntityConverter _converter;
  final Uuid _uuid;

  IngestionWorkbenchService({
    SourceBlockParser? blockParser,
    CandidateDetector? detector,
    Map<String, FieldExtractor>? extractors,
    CandidateToEntityConverter? converter,
  })  : _blockParser = blockParser ?? const SourceBlockParser(),
        _detector = detector ?? const CandidateDetector(),
        _extractors = extractors ??
            {
              'monster': const MonsterFieldExtractor(),
              'spell': const SpellFieldExtractor(),
            },
        _converter = converter ?? const CandidateToEntityConverter(),
        _uuid = const Uuid();

  /// Parses raw text input into a full [IngestionDocumentResult] with candidates and unassigned blocks.
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

      // Step 3: Identify candidate type
      final ident = cluster.identification;
      final targetType = ident.identifiedTypeKey ??
          (ident.isAmbiguous && ident.plausibleTypeKeys.isNotEmpty
              ? ident.plausibleTypeKeys.first
              : 'monster');

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

  /// Changes the candidate's target object type (e.g. from Monster to Spell)
  /// and re-extracts fields according to the new descriptor schema.
  IngestionCandidate changeCandidateType(
    IngestionCandidate candidate,
    String newTypeKey,
  ) {
    return _buildCandidateFromBlocks(
      blocks: candidate.blocks,
      identification: candidate.identification,
      targetTypeKey: newTypeKey,
      span: candidate.span,
      isUserOverridden: true,
      existingIgnored: candidate.ignoredBlockIds,
    );
  }

  /// Updates an individual field value on a candidate due to user manual input.
  IngestionCandidate updateCandidateField(
    IngestionCandidate candidate,
    String fieldKey,
    dynamic newValue,
  ) {
    final existingField = candidate.fields[fieldKey];
    if (existingField == null) return candidate;

    final descriptor =
        DescriptorRegistry.getDescriptor(candidate.targetTypeKey);
    final fieldDesc = descriptor?.getField(fieldKey);

    // Run validator
    final validationError = fieldDesc?.validate(newValue);

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

  /// Validates candidate invariants against schema descriptor.
  CandidateValidationResult validate(IngestionCandidate candidate) {
    return _converter.validate(candidate);
  }

  /// Converts a validated candidate into a DomainEntity.
  DomainConversionResult convertToDomainEntity(IngestionCandidate candidate) {
    return _converter.convert(candidate);
  }

  IngestionCandidate _buildCandidateFromBlocks({
    required List<SourceBlock> blocks,
    required CandidateIdentification identification,
    required String targetTypeKey,
    required SourceSpan span,
    bool isUserOverridden = false,
    Set<String> existingIgnored = const {},
  }) {
    final descriptor = DescriptorRegistry.getDescriptor(targetTypeKey);
    final extractor = _extractors[targetTypeKey];

    Map<String, IngestionField<dynamic>> fields;
    List<SourceBlock> unrecognizedBlocks = const [];

    if (descriptor != null && extractor != null) {
      final result = extractor.extract(
        blocks: blocks,
        descriptor: descriptor,
      );
      fields = result.fields;
      unrecognizedBlocks = result.unrecognizedBlocks;
    } else {
      fields = {};
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
