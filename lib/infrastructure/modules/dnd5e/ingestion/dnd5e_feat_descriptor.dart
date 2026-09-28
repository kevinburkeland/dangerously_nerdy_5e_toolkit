import '../../../../domain/ingestion/descriptors/ingestion_field_descriptor.dart';
import '../../../../domain/ingestion/descriptors/ingestion_target_descriptor.dart';

/// 5e Ruleset ingestion descriptor providing parsing metadata, expected source labels,
/// and syntactic hints for 5e Feats.
class Dnd5eFeatDescriptor extends IngestionTargetDescriptor {
  const Dnd5eFeatDescriptor();

  @override
  String get typeKey => 'feat';

  @override
  String get displayName => 'Feat';

  @override
  List<IngestionFieldDescriptor> get fields => const [
        IngestionFieldDescriptor(
          key: 'name',
          label: 'Feat Name',
          expectation: SourceFieldExpectation.requiredForRecognition,
          helpText: 'Title or heading of the feat.',
        ),
        IngestionFieldDescriptor(
          key: 'category',
          label: 'Category',
          expectation: SourceFieldExpectation.commonlyPresent,
          helpText: 'General, Origin, Fighting Style, or Epic Boon.',
          aliases: ['feat_category', 'type'],
        ),
        IngestionFieldDescriptor(
          key: 'prerequisite',
          label: 'Prerequisite',
          expectation: SourceFieldExpectation.optional,
          helpText: 'Requirements needed to select this feat (e.g. "Strength 13 or higher").',
          aliases: ['prerequisites', 'requirement'],
        ),
        IngestionFieldDescriptor(
          key: 'descriptionMarkdown',
          label: 'Description & Benefits',
          expectation: SourceFieldExpectation.commonlyPresent,
          helpText: 'Full rules text and bulleted benefits granted by the feat.',
          aliases: ['description', 'text', 'benefits'],
        ),
      ];
}
