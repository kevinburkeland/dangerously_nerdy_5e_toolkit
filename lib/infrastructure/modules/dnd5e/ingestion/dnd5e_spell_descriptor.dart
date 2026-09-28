import '../../../../domain/ingestion/descriptors/ingestion_field_descriptor.dart';
import '../../../../domain/ingestion/descriptors/ingestion_target_descriptor.dart';

/// 5e Ruleset ingestion descriptor providing parsing metadata, expected source labels,
/// and syntactic hints for 5e Spell entries.
///
/// This is an ingestion adapter owned by the 5e ruleset module, NOT an independent
/// domain authority. Domain invariants are enforced by Dnd5eIngestionCapability.
class Dnd5eSpellDescriptor extends IngestionTargetDescriptor {
  const Dnd5eSpellDescriptor();

  @override
  String get typeKey => 'spell';

  @override
  String get displayName => 'Spell';

  @override
  List<IngestionFieldDescriptor> get fields => const [
        IngestionFieldDescriptor(
          key: 'name',
          label: 'Spell Name',
          expectation: SourceFieldExpectation.requiredForRecognition,
          helpText: 'Title or heading of the spell.',
        ),
        IngestionFieldDescriptor(
          key: 'level',
          label: 'Spell Level',
          expectation: SourceFieldExpectation.requiredForRecognition,
          valueType: FieldValueType.integer,
          helpText: '0 for cantrips, 1-9 for leveled spells.',
        ),
        IngestionFieldDescriptor(
          key: 'school',
          label: 'School of Magic',
          expectation: SourceFieldExpectation.requiredForRecognition,
          helpText: 'Abjuration, Conjuration, Divination, Enchantment, Evocation, Illusion, Necromancy, Transmutation',
        ),
        IngestionFieldDescriptor(
          key: 'castingTime',
          label: 'Casting Time',
          expectation: SourceFieldExpectation.requiredForRecognition,
          helpText: 'e.g. 1 action, 1 bonus action, 1 reaction, 10 minutes',
          aliases: ['casting_time'],
        ),
        IngestionFieldDescriptor(
          key: 'range',
          label: 'Range',
          expectation: SourceFieldExpectation.requiredForRecognition,
          helpText: 'e.g. Self, Touch, 60 feet, 120 feet',
        ),
        IngestionFieldDescriptor(
          key: 'components',
          label: 'Components',
          expectation: SourceFieldExpectation.requiredForRecognition,
          helpText: 'V, S, M (and optional material description)',
        ),
        IngestionFieldDescriptor(
          key: 'duration',
          label: 'Duration',
          expectation: SourceFieldExpectation.requiredForRecognition,
          helpText: 'e.g. Instantaneous, Concentration up to 1 minute, 8 hours',
        ),
        IngestionFieldDescriptor(
          key: 'descriptionMarkdown',
          label: 'Description',
          expectation: SourceFieldExpectation.commonlyPresent,
          helpText: 'Primary rules text describing the spell effects.',
          aliases: ['description', 'text'],
        ),
        IngestionFieldDescriptor(
          key: 'higherLevelsMarkdown',
          label: 'At Higher Levels',
          expectation: SourceFieldExpectation.optional,
          helpText: 'Scaling or upcasting rules text.',
          aliases: ['higher_levels', 'at_higher_levels', 'upcast'],
        ),
      ];
}
