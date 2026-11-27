import 'domain/core_types.dart';
import 'domain/spell_monster_equipment.dart';

EquipmentItem buildUnlistedProbeItem() => EquipmentItem.singleEdition(
  id: const EntityId(slug: 'probe', ruleset: RulesetVersion.homebrew),
  name: 'Probe',
  itemType: 'Weapon',
  rarity: 'Common',
  requiresAttunement: false,
  descriptionMarkdown: 'Probe item.',
);
