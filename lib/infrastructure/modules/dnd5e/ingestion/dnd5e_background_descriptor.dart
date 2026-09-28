import '../../../../domain/ingestion/descriptors/ingestion_field_descriptor.dart';
import '../../../../domain/ingestion/descriptors/ingestion_target_descriptor.dart';

/// 5e Ruleset ingestion descriptor providing parsing metadata, expected source labels,
/// and syntactic hints for 5e Backgrounds.
class Dnd5eBackgroundDescriptor extends IngestionTargetDescriptor {
  const Dnd5eBackgroundDescriptor();

  @override
  String get typeKey => 'background';

  @override
  String get displayName => 'Background';

  @override
  List<IngestionFieldDescriptor> get fields => const [
        IngestionFieldDescriptor(
          key: 'name',
          label: 'Background Name',
          expectation: SourceFieldExpectation.requiredForRecognition,
          helpText: 'Title or heading of the background (e.g. "Sailor", "Soldier").',
        ),
        IngestionFieldDescriptor(
          key: 'skillProficiencies',
          label: 'Skill Proficiencies',
          expectation: SourceFieldExpectation.requiredForRecognition,
          valueType: FieldValueType.custom,
          helpText: 'Skills granted by background (e.g. "Athletics, Perception").',
          aliases: ['skills', 'skill_proficiencies'],
        ),
        IngestionFieldDescriptor(
          key: 'toolProficiencies',
          label: 'Tool Proficiencies',
          expectation: SourceFieldExpectation.optional,
          valueType: FieldValueType.custom,
          helpText: 'Tool proficiencies granted (e.g. "Navigator\'s tools, vehicles (water)").',
          aliases: ['tools', 'tool_proficiencies'],
        ),
        IngestionFieldDescriptor(
          key: 'languages',
          label: 'Languages',
          expectation: SourceFieldExpectation.optional,
          valueType: FieldValueType.custom,
          helpText: 'Languages granted by background.',
        ),
        IngestionFieldDescriptor(
          key: 'abilityScoreSummary',
          label: 'Ability Scores',
          expectation: SourceFieldExpectation.optional,
          helpText: 'Ability score bonuses (common in 2024 revised backgrounds).',
          aliases: ['ability_scores', 'asi'],
        ),
        IngestionFieldDescriptor(
          key: 'originFeat',
          label: 'Origin Feat',
          expectation: SourceFieldExpectation.optional,
          helpText: 'Bonus 1st-level origin feat granted (2024 backgrounds).',
          aliases: ['feat', 'bonus_feat'],
        ),
        IngestionFieldDescriptor(
          key: 'descriptionMarkdown',
          label: 'Description & Features',
          expectation: SourceFieldExpectation.commonlyPresent,
          helpText: 'Background narrative description, equipment package, and feature text.',
          aliases: ['description', 'feature', 'equipment', 'text'],
        ),
      ];
}
