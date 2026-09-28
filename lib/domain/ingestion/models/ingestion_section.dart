import 'package:meta/meta.dart';
import 'candidate_evidence.dart';
import 'source_block.dart';
import 'source_span.dart';

/// A structural decomposition unit of a source document (e.g. heading section,
/// nested sub-heading, table, stat block cluster, or descriptive block).
///
/// Sections form a hierarchical tree representing document containment independently
/// from domain entities. A section may represent a domain candidate (e.g. a Class or Subclass)
/// or a subcomponent (e.g. a Class Feature, Progression Table, or Unknown Section)
/// that contributes to a parent domain entity during conversion.
@immutable
class IngestionSection {
  final String id;
  final SourceSpan span;
  final String rawSource;
  final String? headingText;
  final int headingLevel;
  final int structuralDepth;
  final String? parentSectionId;
  final List<String> childSectionIds;
  final List<IngestionSection> children;
  final List<SourceBlock> blocks;

  /// Classification of this section (e.g. 'class', 'subclass', 'classFeature',
  /// 'subclassFeature', 'progressionTable', 'proficiencies', 'startingEquipment',
  /// 'descriptiveProse', 'unknown').
  final String classification;

  /// Confidence score between 0.0 and 1.0.
  final double confidence;

  /// Structural and semantic evidence that contributed to this classification.
  final List<CandidateEvidence> evidence;

  /// True if the classification is ambiguous between multiple possibilities.
  final bool isAmbiguous;

  /// Plausible classification keys when [isAmbiguous] is true.
  final List<String> plausibleClassifications;

  /// Blocks within this section that were not mapped or recognized.
  final List<SourceBlock> unrecognizedBlocks;

  /// Additional section metadata (e.g. table headers and row data, stat block hints).
  final Map<String, dynamic> metadata;

  /// ID of the [IngestionCandidate] associated with this section if it represents
  /// a convertible domain candidate.
  final String? candidateId;

  /// True if the classification was explicitly modified or selected by the user.
  final bool isUserReclassified;

  const IngestionSection({
    required this.id,
    required this.span,
    required this.rawSource,
    this.headingText,
    this.headingLevel = 0,
    this.structuralDepth = 0,
    this.parentSectionId,
    this.childSectionIds = const [],
    this.children = const [],
    this.blocks = const [],
    this.classification = 'unknown',
    this.confidence = 0.0,
    this.evidence = const [],
    this.isAmbiguous = false,
    this.plausibleClassifications = const [],
    this.unrecognizedBlocks = const [],
    this.metadata = const {},
    this.candidateId,
    this.isUserReclassified = false,
  });

  /// Best display title available for this section.
  String get displayTitle {
    if (headingText != null && headingText!.trim().isNotEmpty) {
      return headingText!.trim();
    }
    if (metadata.containsKey('tableTitle') &&
        metadata['tableTitle'].toString().trim().isNotEmpty) {
      return metadata['tableTitle'].toString().trim();
    }
    if (classification == 'progressionTable') {
      return 'Class Progression Table';
    }
    if (blocks.isNotEmpty && blocks.first.normalizedText.isNotEmpty) {
      final firstLine = blocks.first.normalizedText;
      return firstLine.length > 40
          ? '${firstLine.substring(0, 37)}...'
          : firstLine;
    }
    return 'Untitled Section';
  }

  /// True if this section is an unrecognized / unknown section.
  bool get isUnknown => classification == 'unknown';

  /// True if this section contains child sections.
  bool get hasChildren => children.isNotEmpty;

  /// Recursively finds a section by [targetId] in this section or its descendants.
  IngestionSection? findSection(String targetId) {
    if (id == targetId) return this;
    for (final child in children) {
      final match = child.findSection(targetId);
      if (match != null) return match;
    }
    return null;
  }

  /// Returns all descendant sections flattened into a list (depth-first).
  List<IngestionSection> get allDescendants {
    final list = <IngestionSection>[];
    for (final child in children) {
      list.add(child);
      list.addAll(child.allDescendants);
    }
    return list;
  }

  /// Returns this section and all of its descendants flattened into a list.
  List<IngestionSection> get allSections => [this, ...allDescendants];

  /// Recursively updates a section matching [targetId] with [updated].
  IngestionSection updateSection(String targetId, IngestionSection updated) {
    if (id == targetId) {
      return updated;
    }
    if (children.isEmpty) {
      return this;
    }
    final nextChildren = children.map((c) => c.updateSection(targetId, updated)).toList();
    return copyWith(
      children: nextChildren,
      childSectionIds: nextChildren.map((c) => c.id).toList(),
    );
  }

  IngestionSection copyWith({
    String? id,
    SourceSpan? span,
    String? rawSource,
    String? headingText,
    int? headingLevel,
    int? structuralDepth,
    String? parentSectionId,
    bool clearParent = false,
    List<String>? childSectionIds,
    List<IngestionSection>? children,
    List<SourceBlock>? blocks,
    String? classification,
    double? confidence,
    List<CandidateEvidence>? evidence,
    bool? isAmbiguous,
    List<String>? plausibleClassifications,
    List<SourceBlock>? unrecognizedBlocks,
    Map<String, dynamic>? metadata,
    String? candidateId,
    bool clearCandidateId = false,
    bool? isUserReclassified,
  }) {
    return IngestionSection(
      id: id ?? this.id,
      span: span ?? this.span,
      rawSource: rawSource ?? this.rawSource,
      headingText: headingText ?? this.headingText,
      headingLevel: headingLevel ?? this.headingLevel,
      structuralDepth: structuralDepth ?? this.structuralDepth,
      parentSectionId: clearParent ? null : (parentSectionId ?? this.parentSectionId),
      childSectionIds: childSectionIds ?? this.childSectionIds,
      children: children ?? this.children,
      blocks: blocks ?? this.blocks,
      classification: classification ?? this.classification,
      confidence: confidence ?? this.confidence,
      evidence: evidence ?? this.evidence,
      isAmbiguous: isAmbiguous ?? this.isAmbiguous,
      plausibleClassifications:
          plausibleClassifications ?? this.plausibleClassifications,
      unrecognizedBlocks: unrecognizedBlocks ?? this.unrecognizedBlocks,
      metadata: metadata ?? this.metadata,
      candidateId: clearCandidateId ? null : (candidateId ?? this.candidateId),
      isUserReclassified: isUserReclassified ?? this.isUserReclassified,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is IngestionSection &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          classification == other.classification &&
          isUserReclassified == other.isUserReclassified;

  @override
  int get hashCode => Object.hash(id, classification, isUserReclassified);

  @override
  String toString() =>
      'IngestionSection(id: $id, title: "$displayTitle", class: $classification, depth: $structuralDepth, children: ${children.length})';
}
