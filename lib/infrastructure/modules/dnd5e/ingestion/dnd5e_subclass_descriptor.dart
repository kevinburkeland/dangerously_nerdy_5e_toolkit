import '../../../../domain/ingestion/descriptors/ingestion_field_descriptor.dart';
import '../../../../domain/ingestion/descriptors/ingestion_target_descriptor.dart';

/// 5e Ruleset ingestion descriptor providing parsing metadata, expected source labels,
/// and syntactic hints for 5e Subclasses / Archetypes.
class Dnd5eSubclassDescriptor extends IngestionTargetDescriptor {
  const Dnd5eSubclassDescriptor();

  @override
  String get typeKey => 'subclass';

  @override
  String get displayName => 'Subclass / Archetype';

  @override
  List<IngestionFieldDescriptor> get fields => const [
        IngestionFieldDescriptor(
          key: 'name',
          label: 'Subclass Name',
          expectation: SourceFieldExpectation.requiredForRecognition,
          helpText: 'Title or heading of the subclass (e.g. "Echo Knight", "Circle of Spores").',
        ),
        IngestionFieldDescriptor(
          key: 'classSlug',
          label: 'Parent Class',
          expectation: SourceFieldExpectation.requiredForRecognition,
          helpText: 'Parent class identifier (e.g. "fighter", "druid", "wizard").',
          aliases: ['class_slug', 'class_name', 'parent_class', 'class'],
        ),
        IngestionFieldDescriptor(
          key: 'shortName',
          label: 'Short Name',
          expectation: SourceFieldExpectation.optional,
          helpText: 'Concise display name if distinct from full title.',
          aliases: ['short_name'],
        ),
        IngestionFieldDescriptor(
          key: 'featuresMarkdown',
          label: 'Subclass Features',
          expectation: SourceFieldExpectation.commonlyPresent,
          helpText: 'Rules text detailing all level-gated subclass archetype features.',
          aliases: ['features', 'description', 'text'],
        ),
      ];
}
