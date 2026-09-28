import 'package:meta/meta.dart';
import 'field_descriptor.dart';
import 'object_descriptor.dart';

/// Schema descriptor for D&D 5e Monsters / Creatures.
@immutable
class MonsterDescriptor extends ObjectDescriptor {
  const MonsterDescriptor();

  @override
  String get typeKey => 'monster';

  @override
  String get displayName => 'Monster / Creature';

  @override
  String get description =>
      'Creature or NPC stat block containing combat statistics, attributes, and actions.';

  @override
  List<FieldDescriptor> get fields => const [
        FieldDescriptor(
          key: 'name',
          label: 'Name',
          valueType: FieldValueType.string,
          isRequired: true,
          description: 'The creature’s unique or generic name.',
          placeholder: 'e.g. Adult Red Dragon',
        ),
        FieldDescriptor(
          key: 'size',
          label: 'Size',
          valueType: FieldValueType.string,
          isRequired: true,
          description: 'Creature size category (Tiny, Small, Medium, Large, Huge, Gargantuan).',
          placeholder: 'e.g. Medium',
        ),
        FieldDescriptor(
          key: 'monsterType',
          label: 'Type',
          valueType: FieldValueType.string,
          isRequired: true,
          description: 'Creature classification (e.g. Beast, Humanoid, Dragon, Undead).',
          placeholder: 'e.g. Humanoid (any race)',
        ),
        FieldDescriptor(
          key: 'alignment',
          label: 'Alignment',
          valueType: FieldValueType.string,
          isRequired: true,
          description: 'Moral and ethical perspective (e.g. lawful good, chaotic evil, unaligned).',
          placeholder: 'e.g. unaligned',
        ),
        FieldDescriptor(
          key: 'armorClass',
          label: 'Armor Class',
          valueType: FieldValueType.integer,
          isRequired: true,
          description: 'AC value representing defense against physical and magical attacks.',
          placeholder: 'e.g. 15',
        ),
        FieldDescriptor(
          key: 'hitPoints',
          label: 'Hit Points',
          valueType: FieldValueType.integer,
          isRequired: true,
          description: 'Average maximum hit points.',
          placeholder: 'e.g. 45',
        ),
        FieldDescriptor(
          key: 'hitDieFormula',
          label: 'Hit Dice Formula',
          valueType: FieldValueType.string,
          isRequired: false,
          description: 'Hit dice calculation (e.g. 7d8 + 14).',
          placeholder: 'e.g. 7d8 + 14',
        ),
        FieldDescriptor(
          key: 'speed',
          label: 'Speed',
          valueType: FieldValueType.string,
          isRequired: false,
          description: 'Movement speeds (walking, fly, swim, burrow, climb).',
          placeholder: 'e.g. 30 ft., fly 60 ft.',
        ),
        FieldDescriptor(
          key: 'challengeRating',
          label: 'Challenge Rating (CR)',
          valueType: FieldValueType.string,
          isRequired: true,
          description: 'Difficulty rating (e.g. 0, 1/8, 1/4, 1/2, 1, 2... 30).',
          placeholder: 'e.g. 1/2 or 5',
        ),
        FieldDescriptor(
          key: 'strength',
          label: 'Strength (STR)',
          valueType: FieldValueType.integer,
          isRequired: false,
          placeholder: 'e.g. 16',
        ),
        FieldDescriptor(
          key: 'dexterity',
          label: 'Dexterity (DEX)',
          valueType: FieldValueType.integer,
          isRequired: false,
          placeholder: 'e.g. 14',
        ),
        FieldDescriptor(
          key: 'constitution',
          label: 'Constitution (CON)',
          valueType: FieldValueType.integer,
          isRequired: false,
          placeholder: 'e.g. 15',
        ),
        FieldDescriptor(
          key: 'intelligence',
          label: 'Intelligence (INT)',
          valueType: FieldValueType.integer,
          isRequired: false,
          placeholder: 'e.g. 10',
        ),
        FieldDescriptor(
          key: 'wisdom',
          label: 'Wisdom (WIS)',
          valueType: FieldValueType.integer,
          isRequired: false,
          placeholder: 'e.g. 12',
        ),
        FieldDescriptor(
          key: 'charisma',
          label: 'Charisma (CHA)',
          valueType: FieldValueType.integer,
          isRequired: false,
          placeholder: 'e.g. 8',
        ),
        FieldDescriptor(
          key: 'actionsMarkdown',
          label: 'Actions',
          valueType: FieldValueType.markdown,
          isRequired: false,
          description: 'Action options available to the creature in combat.',
          placeholder: 'e.g. Multiattack, Claw, Bite',
        ),
        FieldDescriptor(
          key: 'traitsMarkdown',
          label: 'Special Traits',
          valueType: FieldValueType.markdown,
          isRequired: false,
          description: 'Passive traits or active features (e.g. Pack Tactics, Magic Resistance).',
        ),
        FieldDescriptor(
          key: 'reactionsMarkdown',
          label: 'Reactions',
          valueType: FieldValueType.markdown,
          isRequired: false,
          description: 'Reactions the creature can take in response to triggers.',
        ),
        FieldDescriptor(
          key: 'legendaryActionsMarkdown',
          label: 'Legendary Actions',
          valueType: FieldValueType.markdown,
          isRequired: false,
          description: 'Special actions taken at the end of another creature’s turn.',
        ),
      ];
}
