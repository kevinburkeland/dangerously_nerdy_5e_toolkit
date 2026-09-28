import '../../../../domain/ingestion/descriptors/ingestion_field_descriptor.dart';
import '../../../../domain/ingestion/descriptors/ingestion_target_descriptor.dart';

/// 5e Ruleset ingestion descriptor providing parsing metadata, expected source labels,
/// and syntactic hints for 5e Magic Item and Equipment entries.
class Dnd5eItemDescriptor extends IngestionTargetDescriptor {
  const Dnd5eItemDescriptor();

  @override
  String get typeKey => 'item';

  @override
  String get displayName => 'Magic Item / Equipment';

  @override
  List<IngestionFieldDescriptor> get fields => const [
        IngestionFieldDescriptor(
          key: 'name',
          label: 'Item Name',
          expectation: SourceFieldExpectation.requiredForRecognition,
          helpText: 'Title or heading of the item.',
        ),
        IngestionFieldDescriptor(
          key: 'itemType',
          label: 'Item Type',
          expectation: SourceFieldExpectation.requiredForRecognition,
          helpText: 'Weapon, Armor, Wondrous Item, Potion, Ring, Rod, Staff, Wand, etc.',
          aliases: ['item_type', 'type', 'category'],
        ),
        IngestionFieldDescriptor(
          key: 'rarity',
          label: 'Rarity',
          expectation: SourceFieldExpectation.requiredForRecognition,
          helpText: 'Common, Uncommon, Rare, Very Rare, Legendary, Artifact, or Varies.',
          aliases: ['item_rarity'],
        ),
        IngestionFieldDescriptor(
          key: 'requiresAttunement',
          label: 'Requires Attunement',
          expectation: SourceFieldExpectation.commonlyPresent,
          valueType: FieldValueType.boolean,
          helpText: 'True if the item requires attunement to use its properties.',
          aliases: ['attunement'],
        ),
        IngestionFieldDescriptor(
          key: 'attunementDetails',
          label: 'Attunement Details',
          expectation: SourceFieldExpectation.optional,
          helpText: 'Attunement restrictions (e.g. "by a spellcaster", "by a cleric").',
          aliases: ['attunement_requirement', 'attunement_restriction'],
        ),
        IngestionFieldDescriptor(
          key: 'descriptionMarkdown',
          label: 'Description & Properties',
          expectation: SourceFieldExpectation.commonlyPresent,
          helpText: 'Full rules text describing the item, properties, and active abilities.',
          aliases: ['description', 'text'],
        ),
      ];
}
