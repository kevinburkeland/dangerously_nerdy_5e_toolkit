import '../../../../domain/ingestion/descriptors/ingestion_field_descriptor.dart';
import '../../../../domain/ingestion/descriptors/ingestion_target_descriptor.dart';

/// 5e Ruleset ingestion descriptor providing parsing metadata, expected source labels,
/// and syntactic hints for 5e Character Classes.
class Dnd5eClassDescriptor extends IngestionTargetDescriptor {
  const Dnd5eClassDescriptor();

  @override
  String get typeKey => 'class';

  @override
  String get displayName => 'Character Class';

  @override
  List<IngestionFieldDescriptor> get fields => const [
        IngestionFieldDescriptor(
          key: 'name',
          label: 'Class Name',
          expectation: SourceFieldExpectation.requiredForRecognition,
          helpText: 'Title or heading of the class (e.g. "Warlord", "Fighter").',
        ),
        IngestionFieldDescriptor(
          key: 'hitDie',
          label: 'Hit Die',
          expectation: SourceFieldExpectation.requiredForRecognition,
          helpText: 'Dice size for hit point calculation (e.g. "d8", "d10", "d6", "d12").',
          aliases: ['hit_die', 'hit_dice', 'hd'],
        ),
        IngestionFieldDescriptor(
          key: 'primaryAbility',
          label: 'Primary Ability',
          expectation: SourceFieldExpectation.commonlyPresent,
          helpText: 'Core ability score (e.g. "Strength", "Intelligence").',
          aliases: ['primary_ability', 'core_ability'],
        ),
        IngestionFieldDescriptor(
          key: 'savingThrows',
          label: 'Saving Throw Proficiencies',
          expectation: SourceFieldExpectation.requiredForRecognition,
          valueType: FieldValueType.custom,
          helpText: 'Two saving throws proficient at 1st level (e.g. "Constitution, Wisdom").',
          aliases: ['saving_throws', 'saves'],
        ),
        IngestionFieldDescriptor(
          key: 'armorProficiencies',
          label: 'Armor Proficiencies',
          expectation: SourceFieldExpectation.commonlyPresent,
          valueType: FieldValueType.custom,
          helpText: 'Armor training granted (e.g. "Light armor, medium armor, shields").',
          aliases: ['armor_proficiencies', 'armor'],
        ),
        IngestionFieldDescriptor(
          key: 'weaponProficiencies',
          label: 'Weapon Proficiencies',
          expectation: SourceFieldExpectation.commonlyPresent,
          valueType: FieldValueType.custom,
          helpText: 'Weapon training granted (e.g. "Simple weapons, martial weapons").',
          aliases: ['weapon_proficiencies', 'weapons'],
        ),
        IngestionFieldDescriptor(
          key: 'spellcastingAbility',
          label: 'Spellcasting Ability',
          expectation: SourceFieldExpectation.optional,
          helpText: 'Spellcasting modifier ability if applicable (e.g. "Charisma").',
          aliases: ['spellcasting_ability'],
        ),
        IngestionFieldDescriptor(
          key: 'subclassSelectionLevel',
          label: 'Subclass Selection Level',
          expectation: SourceFieldExpectation.commonlyPresent,
          valueType: FieldValueType.integer,
          helpText: 'Level at which an archetype is chosen (standard 3 in 2024, varies in 2014).',
          aliases: ['subclass_level', 'archetype_level'],
        ),
        IngestionFieldDescriptor(
          key: 'featuresMarkdown',
          label: 'Class Features',
          expectation: SourceFieldExpectation.commonlyPresent,
          helpText: 'Full rules text detailing the class features and level progression.',
          aliases: ['features', 'description', 'text'],
        ),
      ];
}
