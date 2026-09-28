import '../../../../domain/ingestion/descriptors/ingestion_field_descriptor.dart';
import '../../../../domain/ingestion/descriptors/ingestion_target_descriptor.dart';

/// 5e Ruleset ingestion descriptor providing parsing metadata, expected source labels,
/// and syntactic hints for 5e Monster / Creature stat blocks.
///
/// This is an ingestion adapter owned by the 5e ruleset module, NOT an independent
/// domain authority. Domain invariants are enforced by Dnd5eIngestionCapability.
class Dnd5eMonsterDescriptor extends IngestionTargetDescriptor {
  const Dnd5eMonsterDescriptor();

  @override
  String get typeKey => 'monster';

  @override
  String get displayName => 'Monster / Creature';

  @override
  List<IngestionFieldDescriptor> get fields => const [
        // Identity & Core Vitals
        IngestionFieldDescriptor(
          key: 'name',
          label: 'Name',
          expectation: SourceFieldExpectation.requiredForRecognition,
          helpText: 'Creature name as stated in heading or title line.',
        ),
        IngestionFieldDescriptor(
          key: 'size',
          label: 'Size',
          expectation: SourceFieldExpectation.commonlyPresent,
          helpText: 'e.g. Tiny, Small, Medium, Large, Huge, Gargantuan',
        ),
        IngestionFieldDescriptor(
          key: 'monsterType',
          label: 'Creature Type',
          expectation: SourceFieldExpectation.commonlyPresent,
          helpText: 'e.g. Beast, Humanoid, Dragon, Undead, Fiend, Construct',
        ),
        IngestionFieldDescriptor(
          key: 'alignment',
          label: 'Alignment',
          expectation: SourceFieldExpectation.commonlyPresent,
          helpText: 'e.g. unaligned, lawful good, chaotic evil',
        ),
        IngestionFieldDescriptor(
          key: 'armorClass',
          label: 'Armor Class',
          expectation: SourceFieldExpectation.requiredForRecognition,
          valueType: FieldValueType.integer,
          helpText: 'Base AC integer value (e.g. 15, 18).',
          aliases: ['ac', 'armor_class'],
        ),
        IngestionFieldDescriptor(
          key: 'hitPoints',
          label: 'Hit Points',
          expectation: SourceFieldExpectation.requiredForRecognition,
          valueType: FieldValueType.integer,
          helpText: 'Average maximum hit points integer (e.g. 45, 136).',
          aliases: ['hp', 'hit_points'],
        ),
        IngestionFieldDescriptor(
          key: 'hitDieFormula',
          label: 'Hit Dice Formula',
          expectation: SourceFieldExpectation.optional,
          valueType: FieldValueType.diceFormula,
          helpText: 'Dice expression for creature HP (e.g. "7d8 + 14").',
          aliases: ['hit_dice', 'hd'],
        ),
        IngestionFieldDescriptor(
          key: 'speed',
          label: 'Speed',
          expectation: SourceFieldExpectation.commonlyPresent,
          helpText: 'Walking, fly, swim, or burrow speeds (e.g. "30 ft., fly 60 ft.").',
        ),
        IngestionFieldDescriptor(
          key: 'challengeRating',
          label: 'Challenge Rating',
          expectation: SourceFieldExpectation.commonlyPresent,
          helpText: 'Challenge rating value (e.g. "1/4", "1/2", "3", "12").',
          aliases: ['cr', 'challenge'],
        ),

        // 6 Core Ability Scores
        IngestionFieldDescriptor(
          key: 'strength',
          label: 'Strength (STR)',
          expectation: SourceFieldExpectation.commonlyPresent,
          valueType: FieldValueType.integer,
          aliases: ['str'],
        ),
        IngestionFieldDescriptor(
          key: 'dexterity',
          label: 'Dexterity (DEX)',
          expectation: SourceFieldExpectation.commonlyPresent,
          valueType: FieldValueType.integer,
          aliases: ['dex'],
        ),
        IngestionFieldDescriptor(
          key: 'constitution',
          label: 'Constitution (CON)',
          expectation: SourceFieldExpectation.commonlyPresent,
          valueType: FieldValueType.integer,
          aliases: ['con'],
        ),
        IngestionFieldDescriptor(
          key: 'intelligence',
          label: 'Intelligence (INT)',
          expectation: SourceFieldExpectation.commonlyPresent,
          valueType: FieldValueType.integer,
          aliases: ['int'],
        ),
        IngestionFieldDescriptor(
          key: 'wisdom',
          label: 'Wisdom (WIS)',
          expectation: SourceFieldExpectation.commonlyPresent,
          valueType: FieldValueType.integer,
          aliases: ['wis'],
        ),
        IngestionFieldDescriptor(
          key: 'charisma',
          label: 'Charisma (CHA)',
          expectation: SourceFieldExpectation.commonlyPresent,
          valueType: FieldValueType.integer,
          aliases: ['cha'],
        ),

        // Action Blocks
        IngestionFieldDescriptor(
          key: 'traitsMarkdown',
          label: 'Special Traits',
          expectation: SourceFieldExpectation.optional,
          helpText: 'Passive abilities and features before Actions.',
        ),
        IngestionFieldDescriptor(
          key: 'actionsMarkdown',
          label: 'Actions',
          expectation: SourceFieldExpectation.commonlyPresent,
          helpText: 'Attacks and active abilities.',
        ),
        IngestionFieldDescriptor(
          key: 'reactionsMarkdown',
          label: 'Reactions',
          expectation: SourceFieldExpectation.optional,
        ),
        IngestionFieldDescriptor(
          key: 'legendaryActionsMarkdown',
          label: 'Legendary Actions',
          expectation: SourceFieldExpectation.optional,
        ),
      ];
}
