import 'package:meta/meta.dart';
import 'field_descriptor.dart';
import 'object_descriptor.dart';

/// Schema descriptor for D&D 5e Spells.
@immutable
class SpellDescriptor extends ObjectDescriptor {
  const SpellDescriptor();

  @override
  String get typeKey => 'spell';

  @override
  String get displayName => 'Spell';

  @override
  String get description =>
      'Magical effect with level, school, casting parameters, and rules description.';

  @override
  List<FieldDescriptor> get fields => const [
        FieldDescriptor(
          key: 'name',
          label: 'Name',
          valueType: FieldValueType.string,
          isRequired: true,
          description: 'The title of the spell.',
          placeholder: 'e.g. Fireball',
        ),
        FieldDescriptor(
          key: 'level',
          label: 'Spell Level',
          valueType: FieldValueType.integer,
          isRequired: true,
          description: 'Circle level from 0 (cantrip) to 9.',
          placeholder: 'e.g. 3 (or 0 for cantrip)',
          customValidator: _validateSpellLevel,
        ),
        FieldDescriptor(
          key: 'school',
          label: 'School of Magic',
          valueType: FieldValueType.string,
          isRequired: true,
          description: 'Magical school (Abjuration, Conjuration, Divination, Enchantment, Evocation, Illusion, Necromancy, Transmutation).',
          placeholder: 'e.g. Evocation',
        ),
        FieldDescriptor(
          key: 'castingTime',
          label: 'Casting Time',
          valueType: FieldValueType.string,
          isRequired: true,
          description: 'Activation cost (e.g. 1 action, 1 bonus action, 1 reaction, 10 minutes).',
          placeholder: 'e.g. 1 action',
        ),
        FieldDescriptor(
          key: 'range',
          label: 'Range',
          valueType: FieldValueType.string,
          isRequired: true,
          description: 'Targeting distance or area (e.g. 120 feet, Self, Touch).',
          placeholder: 'e.g. 150 feet',
        ),
        FieldDescriptor(
          key: 'components',
          label: 'Components',
          valueType: FieldValueType.string,
          isRequired: true,
          description: 'Required components (V, S, M with optional material cost).',
          placeholder: 'e.g. V, S, M (a tiny ball of bat guano and pitch)',
        ),
        FieldDescriptor(
          key: 'duration',
          label: 'Duration',
          valueType: FieldValueType.string,
          isRequired: true,
          description: 'How long the spell persists (e.g. Instantaneous, Concentration, up to 1 minute).',
          placeholder: 'e.g. Instantaneous',
        ),
        FieldDescriptor(
          key: 'descriptionMarkdown',
          label: 'Description',
          valueType: FieldValueType.markdown,
          isRequired: true,
          description: 'Rules prose explaining the spell’s primary mechanics and effects.',
          placeholder: 'A bright streak flashes from your pointing finger...',
        ),
        FieldDescriptor(
          key: 'higherLevelsMarkdown',
          label: 'At Higher Levels',
          valueType: FieldValueType.markdown,
          isRequired: false,
          description: 'Scaling damage or additional targets when cast using a higher-level slot.',
          placeholder: 'When you cast this spell using a spell slot of 4th level or higher...',
        ),
      ];

  static String? _validateSpellLevel(dynamic value) {
    if (value == null) return null;
    final lvl = int.tryParse(value.toString().trim());
    if (lvl == null || lvl < 0 || lvl > 9) {
      return 'Spell level must be an integer between 0 and 9.';
    }
    return null;
  }
}
