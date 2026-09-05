import 'package:flutter/material.dart';
import '../../services/rules/character_factory.dart';
import '../domain/core_types.dart';
import '../domain/character_models.dart';
import '../domain/entity_reference.dart';
import '../domain/spell_monster_equipment.dart';
import '../magic_items/magic_item_library.dart';

/// Predefined SRD starting equipment package with specific items, slot mappings, and starting purse.
@immutable
class SrdEquipmentPackage {
  final String id;
  final String classSlug;
  final String name;
  final String subtitle;
  final IconData icon;
  final List<StartingEquipmentItemRequest> items;
  final int startingGold;

  const SrdEquipmentPackage({
    required this.id,
    required this.classSlug,
    required this.name,
    required this.subtitle,
    required this.icon,
    required this.items,
    this.startingGold = 10,
  });
}

/// Official SRD 5.1 & 5.2 Equipment and Starting Inventory Packages Library.
class SrdEquipmentLibrary {
  SrdEquipmentLibrary._();

  /// All SRD Class Starting Equipment Packages
  static final List<SrdEquipmentPackage> allPackages = [
    // -------------------------------------------------------------------------
    // BARBARIAN
    // -------------------------------------------------------------------------
    const SrdEquipmentPackage(
      id: 'barbarian_greataxe_pack',
      classSlug: 'barbarian',
      name: 'Greataxe & Javelins Loadout',
      subtitle: 'Greataxe (2-Handed 1d12) + 2 Handaxes (1d6 light) + 4 Javelins + Explorer\'s Pack + 10 GP',
      icon: Icons.sports_kabaddi,
      items: [
        StartingEquipmentItemRequest(
          itemRef: EntityReference(refType: EntityType.equipment, slug: 'greataxe', displayName: 'Greataxe'),
          quantity: 1,
          equipImmediately: true,
          defaultSlot: EquipmentSlot.twoHand,
        ),
        StartingEquipmentItemRequest(
          itemRef: EntityReference(refType: EntityType.equipment, slug: 'handaxe', displayName: 'Handaxe'),
          quantity: 2,
        ),
        StartingEquipmentItemRequest(
          itemRef: EntityReference(refType: EntityType.equipment, slug: 'javelin', displayName: 'Javelin'),
          quantity: 4,
        ),
        StartingEquipmentItemRequest(
          itemRef: EntityReference(refType: EntityType.equipment, slug: 'explorers-pack', displayName: 'Explorer\'s Pack'),
          quantity: 1,
        ),
      ],
      startingGold: 10,
    ),
    const SrdEquipmentPackage(
      id: 'barbarian_dual_martial_pack',
      classSlug: 'barbarian',
      name: 'Dual Martial Weapons Loadout',
      subtitle: 'Warhammer (1d8) + Longsword (1d8) + 2 Handaxes + 4 Javelins + Explorer\'s Pack + 10 GP',
      icon: Icons.fitness_center,
      items: [
        StartingEquipmentItemRequest(
          itemRef: EntityReference(refType: EntityType.equipment, slug: 'warhammer', displayName: 'Warhammer'),
          quantity: 1,
          equipImmediately: true,
          defaultSlot: EquipmentSlot.mainHand,
        ),
        StartingEquipmentItemRequest(
          itemRef: EntityReference(refType: EntityType.equipment, slug: 'longsword', displayName: 'Longsword'),
          quantity: 1,
          equipImmediately: true,
          defaultSlot: EquipmentSlot.offHand,
        ),
        StartingEquipmentItemRequest(
          itemRef: EntityReference(refType: EntityType.equipment, slug: 'handaxe', displayName: 'Handaxe'),
          quantity: 2,
        ),
        StartingEquipmentItemRequest(
          itemRef: EntityReference(refType: EntityType.equipment, slug: 'javelin', displayName: 'Javelin'),
          quantity: 4,
        ),
        StartingEquipmentItemRequest(
          itemRef: EntityReference(refType: EntityType.equipment, slug: 'explorers-pack', displayName: 'Explorer\'s Pack'),
          quantity: 1,
        ),
      ],
      startingGold: 10,
    ),

    // -------------------------------------------------------------------------
    // BARD
    // -------------------------------------------------------------------------
    const SrdEquipmentPackage(
      id: 'bard_rapier_entertainer_pack',
      classSlug: 'bard',
      name: 'Entertainer Rapier Loadout',
      subtitle: 'Rapier (1d8 finesse) + Leather Armor (AC 11+Dex) + Lute + Entertainer\'s Pack + Dagger + 15 GP',
      icon: Icons.music_note,
      items: [
        StartingEquipmentItemRequest(
          itemRef: EntityReference(refType: EntityType.equipment, slug: 'rapier', displayName: 'Rapier'),
          quantity: 1,
          equipImmediately: true,
          defaultSlot: EquipmentSlot.mainHand,
        ),
        StartingEquipmentItemRequest(
          itemRef: EntityReference(refType: EntityType.equipment, slug: 'leather-armor', displayName: 'Leather Armor'),
          quantity: 1,
          equipImmediately: true,
          defaultSlot: EquipmentSlot.armor,
        ),
        StartingEquipmentItemRequest(
          itemRef: EntityReference(refType: EntityType.equipment, slug: 'lute', displayName: 'Lute'),
          quantity: 1,
        ),
        StartingEquipmentItemRequest(
          itemRef: EntityReference(refType: EntityType.equipment, slug: 'dagger', displayName: 'Dagger'),
          quantity: 1,
        ),
        StartingEquipmentItemRequest(
          itemRef: EntityReference(refType: EntityType.equipment, slug: 'entertainers-pack', displayName: 'Entertainer\'s Pack'),
          quantity: 1,
        ),
      ],
      startingGold: 15,
    ),
    const SrdEquipmentPackage(
      id: 'bard_longsword_diplomat_pack',
      classSlug: 'bard',
      name: 'Diplomat Longsword Loadout',
      subtitle: 'Longsword (1d8) + Leather Armor (AC 11+Dex) + Lute + Diplomat\'s Pack + Dagger + 15 GP',
      icon: Icons.auto_stories,
      items: [
        StartingEquipmentItemRequest(
          itemRef: EntityReference(refType: EntityType.equipment, slug: 'longsword', displayName: 'Longsword'),
          quantity: 1,
          equipImmediately: true,
          defaultSlot: EquipmentSlot.mainHand,
        ),
        StartingEquipmentItemRequest(
          itemRef: EntityReference(refType: EntityType.equipment, slug: 'leather-armor', displayName: 'Leather Armor'),
          quantity: 1,
          equipImmediately: true,
          defaultSlot: EquipmentSlot.armor,
        ),
        StartingEquipmentItemRequest(
          itemRef: EntityReference(refType: EntityType.equipment, slug: 'lute', displayName: 'Lute'),
          quantity: 1,
        ),
        StartingEquipmentItemRequest(
          itemRef: EntityReference(refType: EntityType.equipment, slug: 'dagger', displayName: 'Dagger'),
          quantity: 1,
        ),
        StartingEquipmentItemRequest(
          itemRef: EntityReference(refType: EntityType.equipment, slug: 'diplomats-pack', displayName: 'Diplomat\'s Pack'),
          quantity: 1,
        ),
      ],
      startingGold: 15,
    ),

    // -------------------------------------------------------------------------
    // CLERIC
    // -------------------------------------------------------------------------
    const SrdEquipmentPackage(
      id: 'cleric_warhammer_scale_pack',
      classSlug: 'cleric',
      name: 'War Cleric: Scale Mail, Warhammer & Shield',
      subtitle: 'Scale Mail (AC 14+Dex max 2) + Warhammer (1d8) + Shield (+2 AC) + Holy Symbol + Priest\'s Pack + 15 GP',
      icon: Icons.shield,
      items: [
        StartingEquipmentItemRequest(
          itemRef: EntityReference(refType: EntityType.equipment, slug: 'scale-mail', displayName: 'Scale Mail'),
          quantity: 1,
          equipImmediately: true,
          defaultSlot: EquipmentSlot.armor,
        ),
        StartingEquipmentItemRequest(
          itemRef: EntityReference(refType: EntityType.equipment, slug: 'warhammer', displayName: 'Warhammer'),
          quantity: 1,
          equipImmediately: true,
          defaultSlot: EquipmentSlot.mainHand,
        ),
        StartingEquipmentItemRequest(
          itemRef: EntityReference(refType: EntityType.equipment, slug: 'shield', displayName: 'Shield'),
          quantity: 1,
          equipImmediately: true,
          defaultSlot: EquipmentSlot.offHand,
        ),
        StartingEquipmentItemRequest(
          itemRef: EntityReference(refType: EntityType.equipment, slug: 'holy-symbol', displayName: 'Holy Symbol'),
          quantity: 1,
        ),
        StartingEquipmentItemRequest(
          itemRef: EntityReference(refType: EntityType.equipment, slug: 'priests-pack', displayName: 'Priest\'s Pack'),
          quantity: 1,
        ),
      ],
      startingGold: 15,
    ),
    const SrdEquipmentPackage(
      id: 'cleric_chain_mace_pack',
      classSlug: 'cleric',
      name: 'Life Cleric: Chain Mail, Mace & Shield',
      subtitle: 'Chain Mail (AC 16) + Mace (1d6) + Shield (+2 AC) + Light Crossbow (20 bolts) + Priest\'s Pack + 15 GP',
      icon: Icons.healing,
      items: [
        StartingEquipmentItemRequest(
          itemRef: EntityReference(refType: EntityType.equipment, slug: 'chain-mail', displayName: 'Chain Mail'),
          quantity: 1,
          equipImmediately: true,
          defaultSlot: EquipmentSlot.armor,
        ),
        StartingEquipmentItemRequest(
          itemRef: EntityReference(refType: EntityType.equipment, slug: 'mace', displayName: 'Mace'),
          quantity: 1,
          equipImmediately: true,
          defaultSlot: EquipmentSlot.mainHand,
        ),
        StartingEquipmentItemRequest(
          itemRef: EntityReference(refType: EntityType.equipment, slug: 'shield', displayName: 'Shield'),
          quantity: 1,
          equipImmediately: true,
          defaultSlot: EquipmentSlot.offHand,
        ),
        StartingEquipmentItemRequest(
          itemRef: EntityReference(refType: EntityType.equipment, slug: 'light-crossbow', displayName: 'Light Crossbow'),
          quantity: 1,
        ),
        StartingEquipmentItemRequest(
          itemRef: EntityReference(refType: EntityType.equipment, slug: 'crossbow-bolts', displayName: 'Crossbow Bolts (20)'),
          quantity: 1,
        ),
        StartingEquipmentItemRequest(
          itemRef: EntityReference(refType: EntityType.equipment, slug: 'holy-symbol', displayName: 'Holy Symbol'),
          quantity: 1,
        ),
        StartingEquipmentItemRequest(
          itemRef: EntityReference(refType: EntityType.equipment, slug: 'priests-pack', displayName: 'Priest\'s Pack'),
          quantity: 1,
        ),
      ],
      startingGold: 15,
    ),

    // -------------------------------------------------------------------------
    // DRUID
    // -------------------------------------------------------------------------
    const SrdEquipmentPackage(
      id: 'druid_scimitar_shield_pack',
      classSlug: 'druid',
      name: 'Warden: Scimitar, Wooden Shield & Focus',
      subtitle: 'Leather Armor (AC 11+Dex) + Scimitar (1d6 finesse) + Wooden Shield (+2 AC) + Druidic Focus + Explorer\'s Pack + 10 GP',
      icon: Icons.park,
      items: [
        StartingEquipmentItemRequest(
          itemRef: EntityReference(refType: EntityType.equipment, slug: 'leather-armor', displayName: 'Leather Armor'),
          quantity: 1,
          equipImmediately: true,
          defaultSlot: EquipmentSlot.armor,
        ),
        StartingEquipmentItemRequest(
          itemRef: EntityReference(refType: EntityType.equipment, slug: 'scimitar', displayName: 'Scimitar'),
          quantity: 1,
          equipImmediately: true,
          defaultSlot: EquipmentSlot.mainHand,
        ),
        StartingEquipmentItemRequest(
          itemRef: EntityReference(refType: EntityType.equipment, slug: 'shield', displayName: 'Wooden Shield'),
          quantity: 1,
          equipImmediately: true,
          defaultSlot: EquipmentSlot.offHand,
        ),
        StartingEquipmentItemRequest(
          itemRef: EntityReference(refType: EntityType.equipment, slug: 'druidic-focus', displayName: 'Druidic Focus'),
          quantity: 1,
        ),
        StartingEquipmentItemRequest(
          itemRef: EntityReference(refType: EntityType.equipment, slug: 'herbalism-kit', displayName: 'Herbalism Kit'),
          quantity: 1,
        ),
        StartingEquipmentItemRequest(
          itemRef: EntityReference(refType: EntityType.equipment, slug: 'explorers-pack', displayName: 'Explorer\'s Pack'),
          quantity: 1,
        ),
      ],
      startingGold: 10,
    ),

    // -------------------------------------------------------------------------
    // FIGHTER
    // -------------------------------------------------------------------------
    const SrdEquipmentPackage(
      id: 'fighter_heavy_knight',
      classSlug: 'fighter',
      name: 'Heavy Knight: Chain Mail & Longsword + Shield',
      subtitle: 'Chain Mail (AC 16) + Versatile Longsword (1d8) + Shield (+2 AC) + Light Crossbow (20 bolts) + Dungeoneer\'s Pack + 15 GP',
      icon: Icons.shield,
      items: [
        StartingEquipmentItemRequest(
          itemRef: EntityReference(refType: EntityType.equipment, slug: 'chain-mail', displayName: 'Chain Mail'),
          quantity: 1,
          equipImmediately: true,
          defaultSlot: EquipmentSlot.armor,
        ),
        StartingEquipmentItemRequest(
          itemRef: EntityReference(refType: EntityType.equipment, slug: 'longsword', displayName: 'Longsword'),
          quantity: 1,
          equipImmediately: true,
          defaultSlot: EquipmentSlot.mainHand,
        ),
        StartingEquipmentItemRequest(
          itemRef: EntityReference(refType: EntityType.equipment, slug: 'shield', displayName: 'Shield'),
          quantity: 1,
          equipImmediately: true,
          defaultSlot: EquipmentSlot.offHand,
        ),
        StartingEquipmentItemRequest(
          itemRef: EntityReference(refType: EntityType.equipment, slug: 'light-crossbow', displayName: 'Light Crossbow'),
          quantity: 1,
        ),
        StartingEquipmentItemRequest(
          itemRef: EntityReference(refType: EntityType.equipment, slug: 'crossbow-bolts', displayName: 'Crossbow Bolts (20)'),
          quantity: 1,
        ),
        StartingEquipmentItemRequest(
          itemRef: EntityReference(refType: EntityType.equipment, slug: 'dungeoneers-pack', displayName: 'Dungeoneer\'s Pack'),
          quantity: 1,
        ),
      ],
      startingGold: 15,
    ),
    const SrdEquipmentPackage(
      id: 'fighter_great_weapon',
      classSlug: 'fighter',
      name: 'Great Weapon Fighter: Chain Mail & Greatsword',
      subtitle: 'Chain Mail (AC 16) + Greatsword (2d6 heavy) + 2 Handaxes + Explorer\'s Pack + 15 GP',
      icon: Icons.sports_kabaddi,
      items: [
        StartingEquipmentItemRequest(
          itemRef: EntityReference(refType: EntityType.equipment, slug: 'chain-mail', displayName: 'Chain Mail'),
          quantity: 1,
          equipImmediately: true,
          defaultSlot: EquipmentSlot.armor,
        ),
        StartingEquipmentItemRequest(
          itemRef: EntityReference(refType: EntityType.equipment, slug: 'greatsword', displayName: 'Greatsword'),
          quantity: 1,
          equipImmediately: true,
          defaultSlot: EquipmentSlot.twoHand,
        ),
        StartingEquipmentItemRequest(
          itemRef: EntityReference(refType: EntityType.equipment, slug: 'handaxe', displayName: 'Handaxe'),
          quantity: 2,
        ),
        StartingEquipmentItemRequest(
          itemRef: EntityReference(refType: EntityType.equipment, slug: 'explorers-pack', displayName: 'Explorer\'s Pack'),
          quantity: 1,
        ),
      ],
      startingGold: 15,
    ),
    const SrdEquipmentPackage(
      id: 'fighter_archer_scout',
      classSlug: 'fighter',
      name: 'Archer Scout: Leather Armor, Longbow & Shortswords',
      subtitle: 'Leather Armor (AC 11+Dex) + Longbow (1d8 150/600 ft) + 20 Arrows + 2 Shortswords (1d6 finesse) + Dungeoneer\'s Pack + 15 GP',
      icon: Icons.track_changes,
      items: [
        StartingEquipmentItemRequest(
          itemRef: EntityReference(refType: EntityType.equipment, slug: 'leather-armor', displayName: 'Leather Armor'),
          quantity: 1,
          equipImmediately: true,
          defaultSlot: EquipmentSlot.armor,
        ),
        StartingEquipmentItemRequest(
          itemRef: EntityReference(refType: EntityType.equipment, slug: 'longbow', displayName: 'Longbow'),
          quantity: 1,
          equipImmediately: true,
          defaultSlot: EquipmentSlot.twoHand,
        ),
        StartingEquipmentItemRequest(
          itemRef: EntityReference(refType: EntityType.equipment, slug: 'arrows', displayName: 'Arrows (20)'),
          quantity: 1,
        ),
        StartingEquipmentItemRequest(
          itemRef: EntityReference(refType: EntityType.equipment, slug: 'shortsword', displayName: 'Shortsword'),
          quantity: 2,
        ),
        StartingEquipmentItemRequest(
          itemRef: EntityReference(refType: EntityType.equipment, slug: 'dungeoneers-pack', displayName: 'Dungeoneer\'s Pack'),
          quantity: 1,
        ),
      ],
      startingGold: 15,
    ),

    // -------------------------------------------------------------------------
    // MONK
    // -------------------------------------------------------------------------
    const SrdEquipmentPackage(
      id: 'monk_shortsword_darts_pack',
      classSlug: 'monk',
      name: 'Monastic Martial: Shortsword & 10 Darts',
      subtitle: 'Shortsword (1d6 finesse monk weapon) + 10 Darts (1d4 thrown) + Dungeoneer\'s Pack + 10 GP',
      icon: Icons.sports_mma,
      items: [
        StartingEquipmentItemRequest(
          itemRef: EntityReference(refType: EntityType.equipment, slug: 'shortsword', displayName: 'Shortsword'),
          quantity: 1,
          equipImmediately: true,
          defaultSlot: EquipmentSlot.mainHand,
        ),
        StartingEquipmentItemRequest(
          itemRef: EntityReference(refType: EntityType.equipment, slug: 'dart', displayName: 'Dart'),
          quantity: 10,
        ),
        StartingEquipmentItemRequest(
          itemRef: EntityReference(refType: EntityType.equipment, slug: 'dungeoneers-pack', displayName: 'Dungeoneer\'s Pack'),
          quantity: 1,
        ),
      ],
      startingGold: 10,
    ),
    const SrdEquipmentPackage(
      id: 'monk_spear_pack',
      classSlug: 'monk',
      name: 'Wanderer: Spear & 10 Darts',
      subtitle: 'Spear (1d6/1d8 versatile) + 10 Darts + Explorer\'s Pack + 10 GP',
      icon: Icons.directions_walk,
      items: [
        StartingEquipmentItemRequest(
          itemRef: EntityReference(refType: EntityType.equipment, slug: 'spear', displayName: 'Spear'),
          quantity: 1,
          equipImmediately: true,
          defaultSlot: EquipmentSlot.mainHand,
        ),
        StartingEquipmentItemRequest(
          itemRef: EntityReference(refType: EntityType.equipment, slug: 'dart', displayName: 'Dart'),
          quantity: 10,
        ),
        StartingEquipmentItemRequest(
          itemRef: EntityReference(refType: EntityType.equipment, slug: 'explorers-pack', displayName: 'Explorer\'s Pack'),
          quantity: 1,
        ),
      ],
      startingGold: 10,
    ),

    // -------------------------------------------------------------------------
    // PALADIN
    // -------------------------------------------------------------------------
    const SrdEquipmentPackage(
      id: 'paladin_sword_shield_pack',
      classSlug: 'paladin',
      name: 'Holy Crusader: Chain Mail, Longsword & Shield',
      subtitle: 'Chain Mail (AC 16) + Longsword (1d8) + Shield (+2 AC) + 5 Javelins + Holy Symbol + Priest\'s Pack + 15 GP',
      icon: Icons.shield,
      items: [
        StartingEquipmentItemRequest(
          itemRef: EntityReference(refType: EntityType.equipment, slug: 'chain-mail', displayName: 'Chain Mail'),
          quantity: 1,
          equipImmediately: true,
          defaultSlot: EquipmentSlot.armor,
        ),
        StartingEquipmentItemRequest(
          itemRef: EntityReference(refType: EntityType.equipment, slug: 'longsword', displayName: 'Longsword'),
          quantity: 1,
          equipImmediately: true,
          defaultSlot: EquipmentSlot.mainHand,
        ),
        StartingEquipmentItemRequest(
          itemRef: EntityReference(refType: EntityType.equipment, slug: 'shield', displayName: 'Shield'),
          quantity: 1,
          equipImmediately: true,
          defaultSlot: EquipmentSlot.offHand,
        ),
        StartingEquipmentItemRequest(
          itemRef: EntityReference(refType: EntityType.equipment, slug: 'javelin', displayName: 'Javelin'),
          quantity: 5,
        ),
        StartingEquipmentItemRequest(
          itemRef: EntityReference(refType: EntityType.equipment, slug: 'holy-symbol', displayName: 'Holy Symbol'),
          quantity: 1,
        ),
        StartingEquipmentItemRequest(
          itemRef: EntityReference(refType: EntityType.equipment, slug: 'priests-pack', displayName: 'Priest\'s Pack'),
          quantity: 1,
        ),
      ],
      startingGold: 15,
    ),

    // -------------------------------------------------------------------------
    // RANGER
    // -------------------------------------------------------------------------
    const SrdEquipmentPackage(
      id: 'ranger_scale_shortswords_pack',
      classSlug: 'ranger',
      name: 'Wilderness Hunter: Scale Mail, Shortswords & Longbow',
      subtitle: 'Scale Mail (AC 14+Dex max 2) + 2 Shortswords (1d6) + Longbow (1d8) + 20 Arrows + Dungeoneer\'s Pack + 15 GP',
      icon: Icons.explore,
      items: [
        StartingEquipmentItemRequest(
          itemRef: EntityReference(refType: EntityType.equipment, slug: 'scale-mail', displayName: 'Scale Mail'),
          quantity: 1,
          equipImmediately: true,
          defaultSlot: EquipmentSlot.armor,
        ),
        StartingEquipmentItemRequest(
          itemRef: EntityReference(refType: EntityType.equipment, slug: 'shortsword', displayName: 'Shortsword'),
          quantity: 2,
          equipImmediately: true,
          defaultSlot: EquipmentSlot.mainHand,
        ),
        StartingEquipmentItemRequest(
          itemRef: EntityReference(refType: EntityType.equipment, slug: 'longbow', displayName: 'Longbow'),
          quantity: 1,
        ),
        StartingEquipmentItemRequest(
          itemRef: EntityReference(refType: EntityType.equipment, slug: 'arrows', displayName: 'Arrows (20)'),
          quantity: 1,
        ),
        StartingEquipmentItemRequest(
          itemRef: EntityReference(refType: EntityType.equipment, slug: 'dungeoneers-pack', displayName: 'Dungeoneer\'s Pack'),
          quantity: 1,
        ),
      ],
      startingGold: 15,
    ),

    // -------------------------------------------------------------------------
    // ROGUE
    // -------------------------------------------------------------------------
    const SrdEquipmentPackage(
      id: 'rogue_rapier_shortbow_pack',
      classSlug: 'rogue',
      name: 'Infiltrator: Leather Armor, Rapier & Shortbow',
      subtitle: 'Leather Armor (AC 11+Dex) + Rapier (1d8 finesse) + Shortbow (1d6) + 20 Arrows + 2 Daggers + Thieves\' Tools + Burglar\'s Pack + 15 GP',
      icon: Icons.visibility_off,
      items: [
        StartingEquipmentItemRequest(
          itemRef: EntityReference(refType: EntityType.equipment, slug: 'leather-armor', displayName: 'Leather Armor'),
          quantity: 1,
          equipImmediately: true,
          defaultSlot: EquipmentSlot.armor,
        ),
        StartingEquipmentItemRequest(
          itemRef: EntityReference(refType: EntityType.equipment, slug: 'rapier', displayName: 'Rapier'),
          quantity: 1,
          equipImmediately: true,
          defaultSlot: EquipmentSlot.mainHand,
        ),
        StartingEquipmentItemRequest(
          itemRef: EntityReference(refType: EntityType.equipment, slug: 'shortbow', displayName: 'Shortbow'),
          quantity: 1,
        ),
        StartingEquipmentItemRequest(
          itemRef: EntityReference(refType: EntityType.equipment, slug: 'arrows', displayName: 'Arrows (20)'),
          quantity: 1,
        ),
        StartingEquipmentItemRequest(
          itemRef: EntityReference(refType: EntityType.equipment, slug: 'dagger', displayName: 'Dagger'),
          quantity: 2,
        ),
        StartingEquipmentItemRequest(
          itemRef: EntityReference(refType: EntityType.equipment, slug: 'thieves-tools', displayName: 'Thieves\' Tools'),
          quantity: 1,
        ),
        StartingEquipmentItemRequest(
          itemRef: EntityReference(refType: EntityType.equipment, slug: 'burglars-pack', displayName: 'Burglar\'s Pack'),
          quantity: 1,
        ),
      ],
      startingGold: 15,
    ),

    // -------------------------------------------------------------------------
    // SORCERER
    // -------------------------------------------------------------------------
    const SrdEquipmentPackage(
      id: 'sorcerer_focus_crossbow_pack',
      classSlug: 'sorcerer',
      name: 'Arcane Adept: Light Crossbow, Arcane Focus & Daggers',
      subtitle: 'Light Crossbow (1d8) + 20 Bolts + Arcane Focus + 2 Daggers + Dungeoneer\'s Pack + 15 GP',
      icon: Icons.flash_on,
      items: [
        StartingEquipmentItemRequest(
          itemRef: EntityReference(refType: EntityType.equipment, slug: 'light-crossbow', displayName: 'Light Crossbow'),
          quantity: 1,
          equipImmediately: true,
          defaultSlot: EquipmentSlot.twoHand,
        ),
        StartingEquipmentItemRequest(
          itemRef: EntityReference(refType: EntityType.equipment, slug: 'crossbow-bolts', displayName: 'Crossbow Bolts (20)'),
          quantity: 1,
        ),
        StartingEquipmentItemRequest(
          itemRef: EntityReference(refType: EntityType.equipment, slug: 'arcane-focus', displayName: 'Arcane Focus (Wand)'),
          quantity: 1,
        ),
        StartingEquipmentItemRequest(
          itemRef: EntityReference(refType: EntityType.equipment, slug: 'dagger', displayName: 'Dagger'),
          quantity: 2,
        ),
        StartingEquipmentItemRequest(
          itemRef: EntityReference(refType: EntityType.equipment, slug: 'dungeoneers-pack', displayName: 'Dungeoneer\'s Pack'),
          quantity: 1,
        ),
      ],
      startingGold: 15,
    ),

    // -------------------------------------------------------------------------
    // WARLOCK
    // -------------------------------------------------------------------------
    const SrdEquipmentPackage(
      id: 'warlock_pact_pack',
      classSlug: 'warlock',
      name: 'Eldritch Initiate: Leather Armor, Crossbow & Focus',
      subtitle: 'Leather Armor (AC 11+Dex) + Light Crossbow (20 bolts) + Arcane Focus + 2 Daggers + Scholar\'s Pack + 15 GP',
      icon: Icons.auto_awesome,
      items: [
        StartingEquipmentItemRequest(
          itemRef: EntityReference(refType: EntityType.equipment, slug: 'leather-armor', displayName: 'Leather Armor'),
          quantity: 1,
          equipImmediately: true,
          defaultSlot: EquipmentSlot.armor,
        ),
        StartingEquipmentItemRequest(
          itemRef: EntityReference(refType: EntityType.equipment, slug: 'light-crossbow', displayName: 'Light Crossbow'),
          quantity: 1,
          equipImmediately: true,
          defaultSlot: EquipmentSlot.twoHand,
        ),
        StartingEquipmentItemRequest(
          itemRef: EntityReference(refType: EntityType.equipment, slug: 'crossbow-bolts', displayName: 'Crossbow Bolts (20)'),
          quantity: 1,
        ),
        StartingEquipmentItemRequest(
          itemRef: EntityReference(refType: EntityType.equipment, slug: 'arcane-focus', displayName: 'Arcane Focus (Orb)'),
          quantity: 1,
        ),
        StartingEquipmentItemRequest(
          itemRef: EntityReference(refType: EntityType.equipment, slug: 'dagger', displayName: 'Dagger'),
          quantity: 2,
        ),
        StartingEquipmentItemRequest(
          itemRef: EntityReference(refType: EntityType.equipment, slug: 'scholars-pack', displayName: 'Scholar\'s Pack'),
          quantity: 1,
        ),
      ],
      startingGold: 15,
    ),

    // -------------------------------------------------------------------------
    // WIZARD
    // -------------------------------------------------------------------------
    const SrdEquipmentPackage(
      id: 'wizard_scholar_spellbook_pack',
      classSlug: 'wizard',
      name: 'Spellweaver: Quarterstaff, Arcane Focus & Spellbook',
      subtitle: 'Quarterstaff (1d6) + Arcane Focus (Crystal) + Spellbook + Scholar\'s Pack + 15 GP',
      icon: Icons.menu_book,
      items: [
        StartingEquipmentItemRequest(
          itemRef: EntityReference(refType: EntityType.equipment, slug: 'quarterstaff', displayName: 'Quarterstaff'),
          quantity: 1,
          equipImmediately: true,
          defaultSlot: EquipmentSlot.mainHand,
        ),
        StartingEquipmentItemRequest(
          itemRef: EntityReference(refType: EntityType.equipment, slug: 'arcane-focus', displayName: 'Arcane Focus (Crystal)'),
          quantity: 1,
        ),
        StartingEquipmentItemRequest(
          itemRef: EntityReference(refType: EntityType.equipment, slug: 'spellbook', displayName: 'Spellbook'),
          quantity: 1,
        ),
        StartingEquipmentItemRequest(
          itemRef: EntityReference(refType: EntityType.equipment, slug: 'scholars-pack', displayName: 'Scholar\'s Pack'),
          quantity: 1,
        ),
      ],
      startingGold: 15,
    ),
    const SrdEquipmentPackage(
      id: 'wizard_dagger_explorer_pack',
      classSlug: 'wizard',
      name: 'Arcane Explorer: Dagger, Component Pouch & Spellbook',
      subtitle: 'Dagger (1d4 finesse) + Component Pouch + Spellbook + Explorer\'s Pack + Potion of Healing + 15 GP',
      icon: Icons.explore,
      items: [
        StartingEquipmentItemRequest(
          itemRef: EntityReference(refType: EntityType.equipment, slug: 'dagger', displayName: 'Dagger'),
          quantity: 1,
          equipImmediately: true,
          defaultSlot: EquipmentSlot.mainHand,
        ),
        StartingEquipmentItemRequest(
          itemRef: EntityReference(refType: EntityType.equipment, slug: 'component-pouch', displayName: 'Component Pouch'),
          quantity: 1,
        ),
        StartingEquipmentItemRequest(
          itemRef: EntityReference(refType: EntityType.equipment, slug: 'spellbook', displayName: 'Spellbook'),
          quantity: 1,
        ),
        StartingEquipmentItemRequest(
          itemRef: EntityReference(refType: EntityType.equipment, slug: 'potion-of-healing', displayName: 'Potion of Healing'),
          quantity: 1,
        ),
        StartingEquipmentItemRequest(
          itemRef: EntityReference(refType: EntityType.equipment, slug: 'explorers-pack', displayName: 'Explorer\'s Pack'),
          quantity: 1,
        ),
      ],
      startingGold: 15,
    ),

    // -------------------------------------------------------------------------
    // GENERIC FALLBACKS FOR HOMEBREW CLASSES
    // -------------------------------------------------------------------------
    const SrdEquipmentPackage(
      id: 'chain_and_sword',
      classSlug: 'generic',
      name: 'Heavy Knight: Chain Mail & Longsword + Shield',
      subtitle: 'Heavy armor (AC 16) + Versatile longsword (1d8) + Shield (+2 AC) + 15 GP',
      icon: Icons.shield,
      items: [
        StartingEquipmentItemRequest(
          itemRef: EntityReference(refType: EntityType.equipment, slug: 'chain-mail', displayName: 'Chain Mail'),
          quantity: 1,
          equipImmediately: true,
          defaultSlot: EquipmentSlot.armor,
        ),
        StartingEquipmentItemRequest(
          itemRef: EntityReference(refType: EntityType.equipment, slug: 'longsword', displayName: 'Longsword'),
          quantity: 1,
          equipImmediately: true,
          defaultSlot: EquipmentSlot.mainHand,
        ),
        StartingEquipmentItemRequest(
          itemRef: EntityReference(refType: EntityType.equipment, slug: 'shield', displayName: 'Shield'),
          quantity: 1,
          equipImmediately: true,
          defaultSlot: EquipmentSlot.offHand,
        ),
      ],
      startingGold: 15,
    ),
    const SrdEquipmentPackage(
      id: 'medium_skirmisher',
      classSlug: 'generic',
      name: 'Medium Skirmisher: Breastplate & Greatsword + Potion',
      subtitle: 'Medium armor (AC 14+Dex max 2) + Heavy greatsword (2d6) + Potion of Healing + 15 GP',
      icon: Icons.sports_kabaddi,
      items: [
        StartingEquipmentItemRequest(
          itemRef: EntityReference(refType: EntityType.equipment, slug: 'breastplate', displayName: 'Breastplate'),
          quantity: 1,
          equipImmediately: true,
          defaultSlot: EquipmentSlot.armor,
        ),
        StartingEquipmentItemRequest(
          itemRef: EntityReference(refType: EntityType.equipment, slug: 'greatsword', displayName: 'Greatsword'),
          quantity: 1,
          equipImmediately: true,
          defaultSlot: EquipmentSlot.twoHand,
        ),
        StartingEquipmentItemRequest(
          itemRef: EntityReference(refType: EntityType.equipment, slug: 'potion-of-healing', displayName: 'Potion of Healing'),
          quantity: 1,
        ),
      ],
      startingGold: 15,
    ),
    const SrdEquipmentPackage(
      id: 'light_scout',
      classSlug: 'generic',
      name: 'Light Scout: Leather Armor & Shortsword + Longbow',
      subtitle: 'Light armor (AC 11+Dex) + Finesse shortsword (1d6) + Longbow (1d8) + 15 GP',
      icon: Icons.track_changes,
      items: [
        StartingEquipmentItemRequest(
          itemRef: EntityReference(refType: EntityType.equipment, slug: 'leather-armor', displayName: 'Leather Armor'),
          quantity: 1,
          equipImmediately: true,
          defaultSlot: EquipmentSlot.armor,
        ),
        StartingEquipmentItemRequest(
          itemRef: EntityReference(refType: EntityType.equipment, slug: 'shortsword', displayName: 'Shortsword'),
          quantity: 1,
          equipImmediately: true,
          defaultSlot: EquipmentSlot.mainHand,
        ),
        StartingEquipmentItemRequest(
          itemRef: EntityReference(refType: EntityType.equipment, slug: 'longbow', displayName: 'Longbow'),
          quantity: 1,
          equipImmediately: true,
          defaultSlot: EquipmentSlot.twoHand,
        ),
      ],
      startingGold: 15,
    ),
  ];

  /// Returns starting equipment packages tailored to the selected character class.
  static List<SrdEquipmentPackage> getPackagesForClass(String classSlug) {
    final normalized = classSlug.trim().toLowerCase();
    final classSpecific = allPackages.where((p) => p.classSlug.toLowerCase() == normalized).toList();
    if (classSpecific.isNotEmpty) {
      return [
        ...classSpecific,
        getStartingGoldPackage(normalized),
      ];
    }
    // Generic fallback for custom/homebrew classes
    return [
      ...allPackages.where((p) => p.classSlug == 'generic'),
      getStartingGoldPackage(normalized),
    ];
  }

  /// Returns the SRD Starting Wealth (Gold Only) package for a class.
  static SrdEquipmentPackage getStartingGoldPackage(String classSlug) {
    final goldAmount = getStandardStartingGold(classSlug);
    return SrdEquipmentPackage(
      id: 'starting_wealth_$classSlug',
      classSlug: classSlug,
      name: 'Starting Wealth (Gold Only Option)',
      subtitle: 'Start with $goldAmount GP in your party purse to purchase custom equipment in-game (SRD 5e RAW Chapter 5).',
      icon: Icons.monetization_on,
      items: const [],
      startingGold: goldAmount,
    );
  }

  /// Calculates official standard starting gold for a class.
  static int getStandardStartingGold(String classSlug) {
    switch (classSlug.toLowerCase()) {
      case 'barbarian':
      case 'druid':
        return 50; // 2d4 x 10
      case 'bard':
      case 'cleric':
      case 'fighter':
      case 'paladin':
      case 'ranger':
        return 125; // 5d4 x 10
      case 'monk':
        return 12; // 5d4
      case 'rogue':
      case 'wizard':
      case 'warlock':
        return 100; // 4d4 x 10
      case 'sorcerer':
        return 75; // 3d4 x 10
      default:
        return 100;
    }
  }

  /// Finds an equipment package by ID.
  static SrdEquipmentPackage? findPackageById(String id) {
    try {
      return allPackages.firstWhere((p) => p.id == id);
    } catch (_) {
      if (id.startsWith('starting_wealth_')) {
        final slug = id.replaceFirst('starting_wealth_', '');
        return getStartingGoldPackage(slug);
      }
      return null;
    }
  }

  /// Converts all MagicItem and standard gear into Domain EquipmentItem entities.
  static List<EquipmentItem> get allEquipmentItems {
    return MagicItemLibrary.allItems.map((item) {
      final props = <String, dynamic>{
        'cost': item.cost ?? item.cost2024 ?? item.cost2014,
        'category': item.category.name,
        'tags': item.tags,
      };

      // Extract Rod of the Pact Keeper bonuses
      final pactKeeperMatch = RegExp(r'rod\s+of\s+the\s+pact\s+keeper(?:,\s*|\s*)\+(\d+)', caseSensitive: false).firstMatch(item.name);
      if (pactKeeperMatch != null) {
        final b = int.tryParse(pactKeeperMatch.group(1)!) ?? 0;
        props['bonusSpellAttack'] = b;
        props['bonusSpellSaveDc'] = b;
        props['spellDcBonus'] = b;
        props['spellClass'] = 'warlock';
      }

      // Extract Wand of the War Mage bonuses
      final warMageMatch = RegExp(r'wand\s+of\s+the\s+war\s+mage(?:,\s*|\s*)\+(\d+)', caseSensitive: false).firstMatch(item.name);
      if (warMageMatch != null) {
        final b = int.tryParse(warMageMatch.group(1)!) ?? 0;
        props['bonusSpellAttack'] = b;
      }

      // Extract AC bonuses (e.g. Ring/Cloak of Protection, +N Armor/Shield)
      final acMatch = RegExp(r'(?:armor|shield|ring of protection|cloak of protection)(?:,\s*|\s*)\+(\d+)', caseSensitive: false).firstMatch(item.name);
      if (acMatch != null) {
        final b = int.tryParse(acMatch.group(1)!) ?? 0;
        props['bonusAc'] = b;
      } else if (item.name.toLowerCase() == 'ring of protection' || item.name.toLowerCase() == 'cloak of protection') {
        props['bonusAc'] = 1;
      }

      // Extract Weapon bonuses (+N Weapon)
      final weaponMatch = RegExp(r'(?:weapon|sword|bow|axe|dagger|mace|hammer|spear)(?:,\s*|\s*)\+(\d+)', caseSensitive: false).firstMatch(item.name);
      if (weaponMatch != null) {
        final b = int.tryParse(weaponMatch.group(1)!) ?? 0;
        props['attackBonus'] = b;
        props['magicBonus'] = b;
        props['bonusWeapon'] = b;
      }

      return EquipmentItem(
        id: EntityId(slug: item.id.replaceAll('_', '-'), ruleset: RulesetVersion.v2024),
        name: item.name,
        itemType: item.category.name,
        rarity: item.rarity.name,
        requiresAttunement: item.requiresAttunement,
        descriptionMarkdown: item.rules2024.summary.isNotEmpty ? item.rules2024.summary : item.rules2014.summary,
        customProperties: props,
      );
    }).toList();
  }
}
