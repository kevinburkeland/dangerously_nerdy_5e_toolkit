import '../../../../domain/ingestion/descriptors/ingestion_field_descriptor.dart';
import '../../../../domain/ingestion/descriptors/ingestion_target_descriptor.dart';

/// 5e Ruleset ingestion descriptor providing parsing metadata, expected source labels,
/// and syntactic hints for 5e Species / Races.
class Dnd5eSpeciesDescriptor extends IngestionTargetDescriptor {
  const Dnd5eSpeciesDescriptor();

  @override
  String get typeKey => 'species';

  @override
  String get displayName => 'Species / Race';

  @override
  List<IngestionFieldDescriptor> get fields => const [
        IngestionFieldDescriptor(
          key: 'name',
          label: 'Species Name',
          expectation: SourceFieldExpectation.requiredForRecognition,
          helpText: 'Title or heading of the species/race (e.g. "Aasimar", "Wood Elf").',
        ),
        IngestionFieldDescriptor(
          key: 'size',
          label: 'Size',
          expectation: SourceFieldExpectation.requiredForRecognition,
          helpText: 'Creature size category (e.g. "Medium", "Small", "Small or Medium").',
          aliases: ['creature_size'],
        ),
        IngestionFieldDescriptor(
          key: 'speed',
          label: 'Speed',
          expectation: SourceFieldExpectation.requiredForRecognition,
          helpText: 'Base walking speed (e.g. "30 ft.", "25 ft.", "35 ft.").',
          aliases: ['walking_speed', 'movement'],
        ),
        IngestionFieldDescriptor(
          key: 'creatureType',
          label: 'Creature Type',
          expectation: SourceFieldExpectation.commonlyPresent,
          helpText: 'Type category (e.g. "Humanoid", "Fey").',
          aliases: ['creature_type', 'type'],
        ),
        IngestionFieldDescriptor(
          key: 'abilityScoreSummary',
          label: 'Ability Score Increases',
          expectation: SourceFieldExpectation.optional,
          helpText: 'Fixed or flexible ability bonuses (e.g. "+2 Dex, +1 Wis").',
          aliases: ['ability_scores', 'asi', 'ability_score_increase'],
        ),
        IngestionFieldDescriptor(
          key: 'traitsMarkdown',
          label: 'Species Traits',
          expectation: SourceFieldExpectation.commonlyPresent,
          helpText: 'Rules text describing all innate features, sensory traits, and lineages.',
          aliases: ['traits', 'description', 'features', 'text'],
        ),
      ];
}
