import 'dart:math';

import 'package:flutter/material.dart';

/// Semantic spell schools conforming to the Style Guide & 5e SRD.
enum SpellSchool {
  abjuration('Abjuration', Color(0xFF3B82F6), Color(0xFFEFF6FF),
      Color(0xFF1E3A8A), GlyphFrameShape.circle),
  conjuration('Conjuration', Color(0xFFA855F7), Color(0xFFFAF5FF),
      Color(0xFF581C87), GlyphFrameShape.hexagon),
  divination('Divination', Color(0xFF0EA5E9), Color(0xFFF0F9FF),
      Color(0xFF0C4A6E), GlyphFrameShape.eye),
  enchantment('Enchantment', Color(0xFFF43F5E), Color(0xFFFFF1F2),
      Color(0xFF881337), GlyphFrameShape.softRhombus),
  evocation('Evocation', Color(0xFFF97316), Color(0xFFFFF7ED),
      Color(0xFF7C2D12), GlyphFrameShape.diamond),
  illusion('Illusion', Color(0xFF6366F1), Color(0xFFEEF2FF), Color(0xFF312E81),
      GlyphFrameShape.overlappingCircle),
  necromancy('Necromancy', Color(0xFF10B981), Color(0xFFECFDF5),
      Color(0xFF064E3B), GlyphFrameShape.invertedTriangle),
  transmutation('Transmutation', Color(0xFFF59E0B), Color(0xFFFFFBEB),
      Color(0xFF78350F), GlyphFrameShape.upwardTriangle);

  final String displayName;
  final Color primaryColor;
  final Color lightFillTint;
  final Color darkFillTint;
  final GlyphFrameShape frameShape;

  const SpellSchool(
    this.displayName,
    this.primaryColor,
    this.lightFillTint,
    this.darkFillTint,
    this.frameShape,
  );

  /// Returns a high-contrast version of the primary color guaranteed legible on dark or light backgrounds.
  Color getLegibleColor(bool isDarkMode) {
    if (!isDarkMode) {
      return switch (this) {
        SpellSchool.abjuration => const Color(0xFF1D4ED8),
        SpellSchool.conjuration => const Color(0xFF7E22CE),
        SpellSchool.divination => const Color(0xFF0369A1),
        SpellSchool.enchantment => const Color(0xFFBE123C),
        SpellSchool.evocation => const Color(0xFFC2410C),
        SpellSchool.illusion => const Color(0xFF4338CA),
        SpellSchool.necromancy => const Color(0xFF047857),
        SpellSchool.transmutation => const Color(0xFFB45309),
      };
    }
    return switch (this) {
      SpellSchool.abjuration => const Color(0xFF60A5FA),
      SpellSchool.conjuration => const Color(0xFFC084FC),
      SpellSchool.divination => const Color(0xFF38BDF8),
      SpellSchool.enchantment => const Color(0xFFFB7185),
      SpellSchool.evocation => const Color(0xFFFB923C),
      SpellSchool.illusion => const Color(0xFF818CF8),
      SpellSchool.necromancy => const Color(0xFF34D399),
      SpellSchool.transmutation => const Color(0xFFFBBF24),
    };
  }

  String get label => displayName;
  Color get color => primaryColor;
  IconData get icon => switch (this) {
        SpellSchool.abjuration => Icons.shield_outlined,
        SpellSchool.conjuration => Icons.auto_fix_high,
        SpellSchool.divination => Icons.visibility_outlined,
        SpellSchool.enchantment => Icons.favorite_border,
        SpellSchool.evocation => Icons.local_fire_department_outlined,
        SpellSchool.illusion => Icons.wb_twilight,
        SpellSchool.necromancy => Icons.coronavirus_outlined,
        SpellSchool.transmutation => Icons.change_circle_outlined,
      };
}

/// 14 Creature Classifications conforming to the Style Guide & SRD with dark-mode contrast tuning.
enum CreatureType {
  aberration('Aberration', Color(0xFFA855F7), Color(0xFFFAF5FF),
      Color(0xFF3B0764), GlyphFrameShape.octagon),
  beast('Beast', Color(0xFF22C55E), Color(0xFFF0FDF4), Color(0xFF14532D),
      GlyphFrameShape.softShield),
  celestial('Celestial', Color(0xFFEAB308), Color(0xFFFEFCE8),
      Color(0xFF713F12), GlyphFrameShape.crest),
  construct('Construct', Color(0xFFD97706), Color(0xFFFFFBEB),
      Color(0xFF451A03), GlyphFrameShape.heavyHex),
  dragon('Dragon', Color(0xFFEF4444), Color(0xFFFEF2F2), Color(0xFF7F1D1D),
      GlyphFrameShape.sharpDiamondShield),
  elemental('Elemental', Color(0xFF0EA5E9), Color(0xFFF0F9FF),
      Color(0xFF082F49), GlyphFrameShape.rhombus),
  fey('Fey', Color(0xFFC084FC), Color(0xFFFAF5FF), Color(0xFF581C87),
      GlyphFrameShape.filigreeOval),
  fiend('Fiend', Color(0xFFF43F5E), Color(0xFFFEF2F2), Color(0xFF450A0A),
      GlyphFrameShape.pointedShield),
  giant('Giant', Color(0xFF94A3B8), Color(0xFFF8FAFC), Color(0xFF0F172A),
      GlyphFrameShape.heavySquare),
  humanoid('Humanoid', Color(0xFF94A3B8), Color(0xFFF8FAFC), Color(0xFF020617),
      GlyphFrameShape.heaterShield),
  monstrosity('Monstrosity', Color(0xFFD97706), Color(0xFFFEFCE8),
      Color(0xFF422006), GlyphFrameShape.jaggedCrest),
  ooze('Ooze', Color(0xFF84CC16), Color(0xFFF7FEE7), Color(0xFF1A2E05),
      GlyphFrameShape.blob),
  plant('Plant', Color(0xFF10B981), Color(0xFFF0FDF4), Color(0xFF052E16),
      GlyphFrameShape.teardrop),
  undead('Undead', Color(0xFFCBD5E1), Color(0xFFF9FAFB), Color(0xFF030712),
      GlyphFrameShape.tombstone);

  final String displayName;
  final Color primaryColor;
  final Color lightFillTint;
  final Color darkFillTint;
  final GlyphFrameShape frameShape;

  const CreatureType(
    this.displayName,
    this.primaryColor,
    this.lightFillTint,
    this.darkFillTint,
    this.frameShape,
  );

  /// Returns a high-contrast version of the primary color guaranteed legible on dark or light backgrounds.
  Color getLegibleColor(bool isDarkMode) {
    if (!isDarkMode) {
      return switch (this) {
        CreatureType.aberration => const Color(0xFF7E22CE),
        CreatureType.beast => const Color(0xFF15803D),
        CreatureType.celestial => const Color(0xFFB45309),
        CreatureType.construct => const Color(0xFF9A3412),
        CreatureType.dragon => const Color(0xFFB91C1C),
        CreatureType.elemental => const Color(0xFF0369A1),
        CreatureType.fey => const Color(0xFF7E22CE),
        CreatureType.fiend => const Color(0xFF9F1239),
        CreatureType.giant => const Color(0xFF334155),
        CreatureType.humanoid => const Color(0xFF334155),
        CreatureType.monstrosity => const Color(0xFF9A3412),
        CreatureType.ooze => const Color(0xFF4D7C0F),
        CreatureType.plant => const Color(0xFF047857),
        CreatureType.undead => const Color(0xFF334155),
      };
    }
    return switch (this) {
      CreatureType.undead => const Color(0xFFE2E8F0),
      CreatureType.humanoid => const Color(0xFFCBD5E1),
      CreatureType.giant => const Color(0xFFCBD5E1),
      CreatureType.construct => const Color(0xFFFBBF24),
      CreatureType.monstrosity => const Color(0xFFFBBF24),
      CreatureType.aberration => const Color(0xFFC084FC),
      CreatureType.beast => const Color(0xFF4ADE80),
      CreatureType.celestial => const Color(0xFFFACC15),
      CreatureType.dragon => const Color(0xFFF87171),
      CreatureType.elemental => const Color(0xFF38BDF8),
      CreatureType.fey => const Color(0xFFE879F9),
      CreatureType.fiend => const Color(0xFFFB7185),
      CreatureType.ooze => const Color(0xFFA3E635),
      CreatureType.plant => const Color(0xFF34D399),
    };
  }
}

/// 10 Core D&D 5e Magic Item & Equipment Categories.
enum ItemCategory {
  weapon('Weapon', Color(0xFFEF4444), Color(0xFFFEF2F2), Color(0xFF7F1D1D),
      GlyphFrameShape.sharpDiamondShield),
  armor('Armor & Shield', Color(0xFF3B82F6), Color(0xFFEFF6FF),
      Color(0xFF1E3A8A), GlyphFrameShape.heaterShield),
  potion('Potion & Elixir', Color(0xFF10B981), Color(0xFFECFDF5),
      Color(0xFF064E3B), GlyphFrameShape.teardrop),
  ring('Ring & Band', Color(0xFFF59E0B), Color(0xFFFFFBEB),
      Color(0xFF78350F), GlyphFrameShape.circle),
  rod('Rod & Scepter', Color(0xFFA855F7), Color(0xFFFAF5FF),
      Color(0xFF581C87), GlyphFrameShape.heavySquare),
  scroll('Scroll & Tome', Color(0xFF0EA5E9), Color(0xFFF0F9FF),
      Color(0xFF0C4A6E), GlyphFrameShape.filigreeOval),
  staff('Staff & Focus', Color(0xFF8B5CF6), Color(0xFFF5F3FF),
      Color(0xFF4C1D95), GlyphFrameShape.heavyHex),
  wand('Wand & Baton', Color(0xFFF43F5E), Color(0xFFFFF1F2),
      Color(0xFF881337), GlyphFrameShape.diamond),
  wondrousItem('Wondrous Item', Color(0xFFEC4899), Color(0xFFFDF2F8),
      Color(0xFF831843), GlyphFrameShape.crest),
  adventuringGear('Adventuring Gear', Color(0xFF64748B), Color(0xFFF8FAFC),
      Color(0xFF0F172A), GlyphFrameShape.heavyHex),
  gemstone('Gemstone', Color(0xFF06B6D4), Color(0xFFECFEFF),
      Color(0xFF164E63), GlyphFrameShape.diamond),
  artObject('Art Object', Color(0xFFC084FC), Color(0xFFFAF5FF),
      Color(0xFF581C87), GlyphFrameShape.crest),
  trinket('Trinket', Color(0xFF10B981), Color(0xFFECFDF5),
      Color(0xFF064E3B), GlyphFrameShape.circle);

  final String displayName;
  final Color primaryColor;
  final Color lightFillTint;
  final Color darkFillTint;
  final GlyphFrameShape frameShape;

  const ItemCategory(
    this.displayName,
    this.primaryColor,
    this.lightFillTint,
    this.darkFillTint,
    this.frameShape,
  );

  Color getLegibleColor(bool isDarkMode) {
    if (!isDarkMode) {
      return switch (this) {
        ItemCategory.weapon => const Color(0xFFB91C1C),
        ItemCategory.armor => const Color(0xFF1D4ED8),
        ItemCategory.potion => const Color(0xFF047857),
        ItemCategory.ring => const Color(0xFFB45309),
        ItemCategory.rod => const Color(0xFF7E22CE),
        ItemCategory.scroll => const Color(0xFF0369A1),
        ItemCategory.staff => const Color(0xFF6D28D9),
        ItemCategory.wand => const Color(0xFFBE123C),
        ItemCategory.wondrousItem => const Color(0xFFBE185D),
        ItemCategory.adventuringGear => const Color(0xFF475569),
        ItemCategory.gemstone => const Color(0xFF0891B2),
        ItemCategory.artObject => const Color(0xFF9333EA),
        ItemCategory.trinket => const Color(0xFF059669),
      };
    }
    return switch (this) {
      ItemCategory.weapon => const Color(0xFFF87171),
      ItemCategory.armor => const Color(0xFF60A5FA),
      ItemCategory.potion => const Color(0xFF34D399),
      ItemCategory.ring => const Color(0xFFFBBF24),
      ItemCategory.rod => const Color(0xFFC084FC),
      ItemCategory.scroll => const Color(0xFF38BDF8),
      ItemCategory.staff => const Color(0xFFA78BFA),
      ItemCategory.wand => const Color(0xFFFB7185),
      ItemCategory.wondrousItem => const Color(0xFFF472B6),
      ItemCategory.adventuringGear => const Color(0xFF94A3B8),
      ItemCategory.gemstone => const Color(0xFF22D3EE),
      ItemCategory.artObject => const Color(0xFFC084FC),
      ItemCategory.trinket => const Color(0xFF34D399),
    };
  }

  String get label => displayName;
  Color get color => primaryColor;
  IconData get icon => switch (this) {
        ItemCategory.weapon => Icons.shield_outlined,
        ItemCategory.armor => Icons.shield_outlined,
        ItemCategory.potion => Icons.science_outlined,
        ItemCategory.ring => Icons.album_outlined,
        ItemCategory.rod => Icons.straighten_outlined,
        ItemCategory.scroll => Icons.article_outlined,
        ItemCategory.staff => Icons.brush_outlined,
        ItemCategory.wand => Icons.auto_fix_normal_outlined,
        ItemCategory.wondrousItem => Icons.diamond_outlined,
        ItemCategory.adventuringGear => Icons.backpack_outlined,
        ItemCategory.gemstone => Icons.diamond_outlined,
        ItemCategory.artObject => Icons.palette_outlined,
        ItemCategory.trinket => Icons.stars_outlined,
      };
}

/// 7 Standard 5e Item Rarities.
enum ItemRarity {
  nonmagical('Nonmagical', Color(0xFF64748B), 0),
  common('Common', Color(0xFF94A3B8), 0),
  uncommon('Uncommon', Color(0xFF22C55E), 1),
  rare('Rare', Color(0xFF3B82F6), 2),
  veryRare('Very Rare', Color(0xFFA855F7), 3),
  legendary('Legendary', Color(0xFFF59E0B), 4),
  artifact('Artifact', Color(0xFFEF4444), 5);

  final String displayName;
  final Color color;
  final int tierLevel;

  const ItemRarity(this.displayName, this.color, this.tierLevel);

  Color getLegibleColor(bool isDarkMode) {
    if (!isDarkMode) {
      return switch (this) {
        ItemRarity.nonmagical => const Color(0xFF475569),
        ItemRarity.common => const Color(0xFF475569),
        ItemRarity.uncommon => const Color(0xFF15803D),
        ItemRarity.rare => const Color(0xFF1D4ED8),
        ItemRarity.veryRare => const Color(0xFF7E22CE),
        ItemRarity.legendary => const Color(0xFFB45309),
        ItemRarity.artifact => const Color(0xFFB91C1C),
      };
    }
    return switch (this) {
      ItemRarity.nonmagical => const Color(0xFF94A3B8),
      ItemRarity.common => const Color(0xFFCBD5E1),
      ItemRarity.uncommon => const Color(0xFF4ADE80),
      ItemRarity.rare => const Color(0xFF60A5FA),
      ItemRarity.veryRare => const Color(0xFFC084FC),
      ItemRarity.legendary => const Color(0xFFFBBF24),
      ItemRarity.artifact => const Color(0xFFF87171),
    };
  }
}

/// 22 Geometric Frame Shapes specified by the Style Guide.
enum GlyphFrameShape {
  circle('Circle Shield'),
  hexagon('Hexagon Gate'),
  eye('Ocular Diamond'),
  softRhombus('Soft Rhombus'),
  diamond('Sharp Diamond'),
  overlappingCircle('Overlapping Vesica'),
  invertedTriangle('Inverted Crypt Delta'),
  upwardTriangle('Upward Transmute Delta'),
  octagon('Psionic Octagon'),
  softShield('Rounded Beast Shield'),
  crest('Seraph Crest Shield'),
  heavyHex('Heavy Anvil Hex'),
  sharpDiamondShield('Wyrm Diamond Shield'),
  rhombus('Vortex Rhombus'),
  filigreeOval('Sylvan Oval'),
  pointedShield('Barbed Abyss Shield'),
  heavySquare('Megalithic Square'),
  heaterShield('Classic Knight Shield'),
  jaggedCrest('Jagged Apex Crest'),
  blob('Cellular Blob'),
  teardrop('Phytogenic Teardrop'),
  tombstone('Sepulchral Tombstone');

  final String displayName;
  const GlyphFrameShape(this.displayName);
}

/// Category classification for all renderable glyph entities.
enum GlyphCategory {
  spell('Spell', Icons.memory),
  creature('Minion & Creature', Icons.hub),
  item('Magic Item & Gear', Icons.shield_outlined),
  classFeature('Class Feature', Icons.shield),
  species('Species & Heritage', Icons.groups_outlined),
  feat('Feat & Epic Boon', Icons.stars_outlined),
  genericUi('Generic UI & Dice', Icons.widgets_outlined);

  final String displayName;
  final IconData icon;
  const GlyphCategory(this.displayName, this.icon);
}

/// Abstract polymorphic interface implemented by any entity renderable as a techno-rune glyph.
abstract class GlyphRenderable {
  String get glyphId;
  String get displayName;
  GlyphCategory get glyphCategory;
  List<ActionTraitRing> get actionRings;
  DamageAccent? get primaryAccent;
  IconData? get fallbackIcon;
  Map<String, dynamic>? get metadata;
}

/// 13 Core D&D 5e Character Classes + Artificer.
enum DndClassType {
  barbarian('Barbarian', 12, Color(0xFFEF4444), GlyphFrameShape.heavySquare, 'Rage'),
  bard('Bard', 8, Color(0xFFEC4899), GlyphFrameShape.filigreeOval, 'Bardic Inspiration'),
  cleric('Cleric', 8, Color(0xFFF59E0B), GlyphFrameShape.crest, 'Channel Divinity'),
  druid('Druid', 8, Color(0xFF10B981), GlyphFrameShape.teardrop, 'Wild Shape'),
  fighter('Fighter', 10, Color(0xFFDC2626), GlyphFrameShape.heaterShield, 'Action Surge'),
  monk('Monk', 8, Color(0xFF06B6D4), GlyphFrameShape.circle, 'Ki / Focus'),
  paladin('Paladin', 10, Color(0xFFFBBF24), GlyphFrameShape.sharpDiamondShield, 'Lay on Hands'),
  ranger('Ranger', 10, Color(0xFF16A34A), GlyphFrameShape.softShield, 'Spell Slots / Hunter'),
  rogue('Rogue', 8, Color(0xFF64748B), GlyphFrameShape.softRhombus, 'Sneak Attack'),
  sorcerer('Sorcerer', 6, Color(0xFFF97316), GlyphFrameShape.diamond, 'Sorcery Points'),
  warlock('Warlock', 8, Color(0xFFA855F7), GlyphFrameShape.octagon, 'Pact Magic Slots'),
  wizard('Wizard', 6, Color(0xFF3B82F6), GlyphFrameShape.hexagon, 'Arcane Recovery'),
  artificer('Artificer', 8, Color(0xFFD97706), GlyphFrameShape.heavyHex, 'Infusions');

  final String displayName;
  final int hitDieSides;
  final Color primaryColor;
  final GlyphFrameShape frameShape;
  final String primaryResource;

  const DndClassType(
    this.displayName,
    this.hitDieSides,
    this.primaryColor,
    this.frameShape,
    this.primaryResource,
  );

  Color getLegibleColor(bool isDarkMode) {
    if (!isDarkMode) {
      return switch (this) {
        DndClassType.barbarian => const Color(0xFFB91C1C),
        DndClassType.bard => const Color(0xFFBE185D),
        DndClassType.cleric => const Color(0xFFB45309),
        DndClassType.druid => const Color(0xFF047857),
        DndClassType.fighter => const Color(0xFF991B1B),
        DndClassType.monk => const Color(0xFF0891B2),
        DndClassType.paladin => const Color(0xFFB45309),
        DndClassType.ranger => const Color(0xFF15803D),
        DndClassType.rogue => const Color(0xFF334155),
        DndClassType.sorcerer => const Color(0xFFC2410C),
        DndClassType.warlock => const Color(0xFF7E22CE),
        DndClassType.wizard => const Color(0xFF1D4ED8),
        DndClassType.artificer => const Color(0xFF9A3412),
      };
    }
    return switch (this) {
      DndClassType.barbarian => const Color(0xFFF87171),
      DndClassType.bard => const Color(0xFFF472B6),
      DndClassType.cleric => const Color(0xFFFBBF24),
      DndClassType.druid => const Color(0xFF34D399),
      DndClassType.fighter => const Color(0xFFEF4444),
      DndClassType.monk => const Color(0xFF22D3EE),
      DndClassType.paladin => const Color(0xFFFDE047),
      DndClassType.ranger => const Color(0xFF4ADE80),
      DndClassType.rogue => const Color(0xFF94A3B8),
      DndClassType.sorcerer => const Color(0xFFFB923C),
      DndClassType.warlock => const Color(0xFFC084FC),
      DndClassType.wizard => const Color(0xFF60A5FA),
      DndClassType.artificer => const Color(0xFFFBBF24),
    };
  }
}

/// Feat category classification (Origin, General, Epic Boon).
enum FeatCategory {
  origin('Origin Feat (Level 1)', Color(0xFF38BDF8), 1, GlyphFrameShape.softRhombus),
  general('General Feat (Level 4+)', Color(0xFFA855F7), 2, GlyphFrameShape.crest),
  epicBoon('Epic Boon (Level 19+)', Color(0xFFF59E0B), 4, GlyphFrameShape.diamond);

  final String displayName;
  final Color primaryColor;
  final int tierLevel;
  final GlyphFrameShape frameShape;

  const FeatCategory(
    this.displayName,
    this.primaryColor,
    this.tierLevel,
    this.frameShape,
  );

  Color getLegibleColor(bool isDarkMode) {
    if (!isDarkMode) {
      return switch (this) {
        FeatCategory.origin => const Color(0xFF0369A1),
        FeatCategory.general => const Color(0xFF7E22CE),
        FeatCategory.epicBoon => const Color(0xFFB45309),
      };
    }
    return switch (this) {
      FeatCategory.origin => const Color(0xFF38BDF8),
      FeatCategory.general => const Color(0xFFC084FC),
      FeatCategory.epicBoon => const Color(0xFFFBBF24),
    };
  }
}

/// Trigger economy activation for feats and traits.
enum FeatTriggerType {
  passive('Passive / Innate'),
  action('Action'),
  bonusAction('Bonus Action'),
  reaction('Reaction'),
  resource('Resource / Rest');

  final String displayName;
  const FeatTriggerType(this.displayName);
}

/// 10 Core D&D 5e Species / Races.
enum SpeciesType {
  human('Human', 'Medium', 30, 'Versatile / Resourceful', Color(0xFF94A3B8), GlyphFrameShape.circle),
  elf('Elf', 'Medium', 30, 'Darkvision (60 ft), Keen Senses', Color(0xFF34D399), GlyphFrameShape.filigreeOval),
  dwarf('Dwarf', 'Medium', 30, 'Darkvision (60 ft), Dwarven Resilience', Color(0xFFF59E0B), GlyphFrameShape.heavyHex),
  halfling('Halfling', 'Small', 30, 'Lucky, Brave, Halfling Nimbleness', Color(0xFF22C55E), GlyphFrameShape.softShield),
  dragonborn('Dragonborn', 'Medium', 30, 'Breath Weapon, Damage Resistance', Color(0xFFEF4444), GlyphFrameShape.sharpDiamondShield),
  gnome('Gnome', 'Small', 30, 'Darkvision (60 ft), Gnomish Cunning', Color(0xFF06B6D4), GlyphFrameShape.hexagon),
  tiefling('Tiefling', 'Medium', 30, 'Darkvision (60 ft), Hellish Resistance', Color(0xFFF43F5E), GlyphFrameShape.pointedShield),
  orc('Orc', 'Medium', 30, 'Darkvision (120 ft), Relentless Endurance', Color(0xFF84CC16), GlyphFrameShape.jaggedCrest),
  goliath('Goliath', 'Medium', 35, 'Giant Ancestry, Stone\'s Endurance', Color(0xFF64748B), GlyphFrameShape.heavySquare),
  aasimar('Aasimar', 'Medium', 30, 'Darkvision (60 ft), Celestial Revelation', Color(0xFFFBBF24), GlyphFrameShape.crest);

  final String displayName;
  final String size;
  final int speed;
  final String traits;
  final Color primaryColor;
  final GlyphFrameShape frameShape;

  const SpeciesType(
    this.displayName,
    this.size,
    this.speed,
    this.traits,
    this.primaryColor,
    this.frameShape,
  );

  Color getLegibleColor(bool isDarkMode) {
    if (!isDarkMode) {
      return switch (this) {
        SpeciesType.human => const Color(0xFF334155),
        SpeciesType.elf => const Color(0xFF047857),
        SpeciesType.dwarf => const Color(0xFFB45309),
        SpeciesType.halfling => const Color(0xFF15803D),
        SpeciesType.dragonborn => const Color(0xFFB91C1C),
        SpeciesType.gnome => const Color(0xFF0891B2),
        SpeciesType.tiefling => const Color(0xFFBE123C),
        SpeciesType.orc => const Color(0xFF4D7C0F),
        SpeciesType.goliath => const Color(0xFF334155),
        SpeciesType.aasimar => const Color(0xFFB45309),
      };
    }
    return switch (this) {
      SpeciesType.human => const Color(0xFFCBD5E1),
      SpeciesType.elf => const Color(0xFF34D399),
      SpeciesType.dwarf => const Color(0xFFFBBF24),
      SpeciesType.halfling => const Color(0xFF4ADE80),
      SpeciesType.dragonborn => const Color(0xFFF87171),
      SpeciesType.gnome => const Color(0xFF22D3EE),
      SpeciesType.tiefling => const Color(0xFFFB7185),
      SpeciesType.orc => const Color(0xFFA3E635),
      SpeciesType.goliath => const Color(0xFF94A3B8),
      SpeciesType.aasimar => const Color(0xFFFDE047),
    };
  }
}

/// Generic UI Glyphs: Polyhedrals, HUD Status Reticles, and Action Economy Badges.
enum GenericUiGlyphType {
  d4('d4 Tetrahedron', Color(0xFF60A5FA), GlyphFrameShape.upwardTriangle),
  d6('d6 Cube', Color(0xFF34D399), GlyphFrameShape.heavySquare),
  d8('d8 Octahedron', Color(0xFFFBBF24), GlyphFrameShape.diamond),
  d10('d10 Trapezohedron', Color(0xFFFB923C), GlyphFrameShape.rhombus),
  d12('d12 Dodecahedron', Color(0xFFA78BFA), GlyphFrameShape.heavyHex),
  d20('d20 Icosahedron', Color(0xFFF43F5E), GlyphFrameShape.hexagon),
  d100('d100 Percentile', Color(0xFFEC4899), GlyphFrameShape.circle),
  advantage('Advantage Beacon', Color(0xFF22C55E), GlyphFrameShape.upwardTriangle),
  disadvantage('Disadvantage Quench', Color(0xFFEF4444), GlyphFrameShape.invertedTriangle),
  concentrating('Concentrating', Color(0xFF38BDF8), GlyphFrameShape.circle),
  deathSave('Death Save Telemetry', Color(0xFFF43F5E), GlyphFrameShape.tombstone),
  actionEconomyAction('Standard Action', Color(0xFF3B82F6), GlyphFrameShape.diamond),
  actionEconomyBonus('Bonus Action', Color(0xFFF59E0B), GlyphFrameShape.softRhombus),
  actionEconomyReaction('Reaction Trigger', Color(0xFF06B6D4), GlyphFrameShape.heaterShield);

  final String displayName;
  final Color primaryColor;
  final GlyphFrameShape frameShape;

  const GenericUiGlyphType(
    this.displayName,
    this.primaryColor,
    this.frameShape,
  );

  Color getLegibleColor(bool isDarkMode) {
    if (!isDarkMode) {
      return switch (this) {
        GenericUiGlyphType.d4 => const Color(0xFF1D4ED8),
        GenericUiGlyphType.d6 => const Color(0xFF047857),
        GenericUiGlyphType.d8 => const Color(0xFFB45309),
        GenericUiGlyphType.d10 => const Color(0xFFC2410C),
        GenericUiGlyphType.d12 => const Color(0xFF6D28D9),
        GenericUiGlyphType.d20 => const Color(0xFFBE123C),
        GenericUiGlyphType.d100 => const Color(0xFFBE185D),
        GenericUiGlyphType.advantage => const Color(0xFF15803D),
        GenericUiGlyphType.disadvantage => const Color(0xFFB91C1C),
        GenericUiGlyphType.concentrating => const Color(0xFF0369A1),
        GenericUiGlyphType.deathSave => const Color(0xFF9F1239),
        GenericUiGlyphType.actionEconomyAction => const Color(0xFF1D4ED8),
        GenericUiGlyphType.actionEconomyBonus => const Color(0xFFB45309),
        GenericUiGlyphType.actionEconomyReaction => const Color(0xFF0891B2),
      };
    }
    return switch (this) {
      GenericUiGlyphType.d4 => const Color(0xFF60A5FA),
      GenericUiGlyphType.d6 => const Color(0xFF34D399),
      GenericUiGlyphType.d8 => const Color(0xFFFBBF24),
      GenericUiGlyphType.d10 => const Color(0xFFFB923C),
      GenericUiGlyphType.d12 => const Color(0xFFA78BFA),
      GenericUiGlyphType.d20 => const Color(0xFFFB7185),
      GenericUiGlyphType.d100 => const Color(0xFFF472B6),
      GenericUiGlyphType.advantage => const Color(0xFF4ADE80),
      GenericUiGlyphType.disadvantage => const Color(0xFFF87171),
      GenericUiGlyphType.concentrating => const Color(0xFF38BDF8),
      GenericUiGlyphType.deathSave => const Color(0xFFFB7185),
      GenericUiGlyphType.actionEconomyAction => const Color(0xFF60A5FA),
      GenericUiGlyphType.actionEconomyBonus => const Color(0xFFFBBF24),
      GenericUiGlyphType.actionEconomyReaction => const Color(0xFF22D3EE),
    };
  }
}

/// Action & Attack Ring Types for Dynamic Wireframe Trait Composability.
enum ActionRingType {
  melee('Melee Attack'), // Faceted Diamond / Octagonal Ring with blade ticks
  ranged(
      'Ranged Attack'), // Circular Crosshair Reticle Ring with 4-axis target tick marks
  recharge(
      'Recharge / AoE'), // Segmented Hexagonal Pulse Ring with energy burst gaps
  reaction(
      'Reaction/Defense'), // Shielded Square Ring with corner deflection brackets
  control(
      'Control Effect'), // Tri-node restraint lattice ring for disables and battlefield control
  sustain(
      'Sustain/Healing'), // Harmonic cradle ring for healing, regeneration, and shielding
  legendary('Legendary Trait'), // Spiked Starburst Crown Ring
  concentration('Concentration'), // Dual-Harmonic Orbital Wireframe Loop Ring
  attunement('Attunement'), // Sacred Attunement Tether Wireframe Ring
  bonusAction('Bonus Action'), // Triple-Spark Triangulation Ring
  resource('Resource Pool'), // Segmented Recharge & Rest Matrix Ring
  passive('Passive Trait'), // Continuous Harmonic Outer Ring
  speed('Speed / Mobility'), // Radial Motion Vector Arc Ring
  sense('Sensory Radar'), // Concentric Sonar Sweep Ring
  hitDie('Hit Die Geometry'); // Polyhedral Hit Die Ring

  final String displayName;
  const ActionRingType(this.displayName);
}

/// A dynamic action/attack trait ring that surrounds the glyph symbol and is colored by damage type.
class ActionTraitRing {
  final ActionRingType ringType;
  final DamageAccent?
      damageType; // If set, illuminates this specific ring with that damage type's neon color
  final List<DamageAccent>
      damageTypes; // Optional multi-damage palette used for animated color cycling
  final String? label;

  const ActionTraitRing({
    required this.ringType,
    this.damageType,
    this.damageTypes = const [],
    this.label,
  });

  List<DamageAccent> get allDamageTypes {
    final merged = <DamageAccent>[];
    if (damageType != null) {
      merged.add(damageType!);
    }
    for (final accent in damageTypes) {
      if (!merged.contains(accent)) {
        merged.add(accent);
      }
    }
    return merged;
  }

  bool get hasElementalDamageAccent =>
      allDamageTypes.any((accent) => accent != DamageAccent.physical);

  String get damageLegend =>
      allDamageTypes.map((accent) => accent.displayName).join(' / ');

  Color getEffectiveColor(Color fallbackColor, {bool isDarkMode = false}) {
    return getAnimatedColor(
      fallbackColor,
      isDarkMode: isDarkMode,
      phase: 0.0,
    );
  }

  Color getAnimatedColor(
    Color fallbackColor, {
    bool isDarkMode = false,
    double phase = 0.0,
  }) {
    if (ringType == ActionRingType.attunement) {
      return isDarkMode ? const Color(0xFF38BDF8) : const Color(0xFF0284C7);
    }
    if (ringType == ActionRingType.concentration) {
      return isDarkMode
          ? const Color(0xFF38BDF8)
          : const Color(0xFF0284C7); // Ethereal orbital cyan
    }
    if (ringType == ActionRingType.control) {
      return isDarkMode ? const Color(0xFFF9A8D4) : const Color(0xFFBE185D);
    }
    if (ringType == ActionRingType.sustain) {
      return isDarkMode ? const Color(0xFF86EFAC) : const Color(0xFF15803D);
    }
    if (ringType == ActionRingType.legendary) {
      return isDarkMode ? const Color(0xFFFDE047) : const Color(0xFFCA8A04);
    }
    if (ringType == ActionRingType.reaction) {
      return isDarkMode ? const Color(0xFF67E8F9) : const Color(0xFF0891B2);
    }
    if (ringType == ActionRingType.bonusAction) {
      return isDarkMode ? const Color(0xFFFBBF24) : const Color(0xFFD97706);
    }
    if (ringType == ActionRingType.resource) {
      return isDarkMode ? const Color(0xFF34D399) : const Color(0xFF059669);
    }
    if (ringType == ActionRingType.passive) {
      return isDarkMode ? const Color(0xFFCBD5E1) : const Color(0xFF64748B);
    }
    if (ringType == ActionRingType.speed) {
      return isDarkMode ? const Color(0xFF22D3EE) : const Color(0xFF0284C7);
    }
    if (ringType == ActionRingType.sense) {
      return isDarkMode ? const Color(0xFFC084FC) : const Color(0xFF7E22CE);
    }
    if (ringType == ActionRingType.hitDie) {
      return isDarkMode ? const Color(0xFFFDE047) : const Color(0xFFB45309);
    }

    final accents = allDamageTypes;
    if (accents.isEmpty) {
      return isDarkMode ? const Color(0xFF94A3B8) : const Color(0xFF64748B);
    }

    if (accents.length == 1) {
      return _accentToColor(accents.first, isDarkMode: isDarkMode);
    }

    final normalizedPhase = ((phase % 1.0) + 1.0) % 1.0;
    final scaled = normalizedPhase * accents.length;
    final index = scaled.floor();
    final nextIndex = (index + 1) % accents.length;
    final t = scaled - index;
    final smoothT = 0.5 - 0.5 * cos(pi * t);
    final currentColor = _accentToColor(accents[index], isDarkMode: isDarkMode);
    final nextColor =
        _accentToColor(accents[nextIndex], isDarkMode: isDarkMode);
    return Color.lerp(currentColor, nextColor, smoothT) ?? currentColor;
  }

  Color _accentToColor(DamageAccent accent, {required bool isDarkMode}) {
    if (accent == DamageAccent.physical) {
      return isDarkMode ? const Color(0xFFCBD5E1) : const Color(0xFF64748B);
    }
    return accent.color;
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ActionTraitRing &&
          runtimeType == other.runtimeType &&
          ringType == other.ringType &&
          damageType == other.damageType &&
          _sameDamageTypes(damageTypes, other.damageTypes) &&
          label == other.label;

  static bool _sameDamageTypes(List<DamageAccent> a, List<DamageAccent> b) {
    if (identical(a, b)) return true;
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  @override
  int get hashCode =>
      Object.hash(ringType, damageType, Object.hashAll(damageTypes), label);
}

/// 14 Damage Accents (10 Elemental + Physical/Neutral, Slashing, Piercing, Bludgeoning).
enum DamageAccent {
  physical('Physical / Neutral', Color(0xFF94A3B8)),
  slashing('Slashing', Color(0xFFE2E8F0)),
  piercing('Piercing', Color(0xFFCBD5E1)),
  bludgeoning('Bludgeoning', Color(0xFF94A3B8)),
  fire('Fire', Color(0xFFEF4444)),
  cold('Cold / Ice', Color(0xFF06B6D4)),
  lightning('Lightning', Color(0xFFEAB308)),
  acid('Acid', Color(0xFF84CC16)),
  poison('Poison', Color(0xFF10B981)),
  necrotic('Necrotic', Color(0xFF8B5CF6)),
  radiant('Radiant', Color(0xFFF59E0B)),
  psychic('Psychic', Color(0xFFEC4899)),
  force('Force', Color(0xFF3B82F6)),
  thunder('Thunder', Color(0xFF6366F1));

  final String displayName;
  final Color color;

  const DamageAccent(this.displayName, this.color);
}

/// Legacy Action Badges for backwards compatibility.
enum ActionBadge {
  melee('Melee Weapon Attack', Color(0xFFEF4444)),
  ranged('Ranged Weapon Attack', Color(0xFF3B82F6)),
  recharge('Recharge / Special Trait', Color(0xFFF59E0B)),
  legendary('Legendary Action', Color(0xFFEC4899)),
  lair('Lair Action', Color(0xFF8B5CF6));

  final String displayName;
  final Color color;

  const ActionBadge(this.displayName, this.color);
}

/// Theme Tokens per Glyph Container.
class GlyphThemeData {
  final Color primary;
  final Color lightFill;
  final Color darkFill;
  final Color border;
  final GlyphFrameShape frameShape;

  const GlyphThemeData({
    required this.primary,
    required this.lightFill,
    required this.darkFill,
    required this.border,
    required this.frameShape,
  });

  factory GlyphThemeData.fromSchool(
    SpellSchool school, {
    Color? primaryColorOverride,
    GlyphFrameShape? shapeOverride,
  }) {
    final effectivePrimary = primaryColorOverride ?? school.primaryColor;
    return GlyphThemeData(
      primary: effectivePrimary,
      lightFill: primaryColorOverride != null
          ? primaryColorOverride.withValues(alpha: 0.12)
          : school.lightFillTint,
      darkFill: primaryColorOverride != null
          ? primaryColorOverride.withValues(alpha: 0.20)
          : school.darkFillTint,
      border: effectivePrimary,
      frameShape: shapeOverride ?? school.frameShape,
    );
  }

  factory GlyphThemeData.fromCreature(
    CreatureType type, {
    Color? primaryColorOverride,
    GlyphFrameShape? shapeOverride,
  }) {
    final effectivePrimary = primaryColorOverride ?? type.primaryColor;
    return GlyphThemeData(
      primary: effectivePrimary,
      lightFill: primaryColorOverride != null
          ? primaryColorOverride.withValues(alpha: 0.12)
          : type.lightFillTint,
      darkFill: primaryColorOverride != null
          ? primaryColorOverride.withValues(alpha: 0.20)
          : type.darkFillTint,
      border: effectivePrimary,
      frameShape: shapeOverride ?? type.frameShape,
    );
  }

  factory GlyphThemeData.fromItem(
    ItemCategory category, {
    ItemRarity? rarity,
    Color? primaryColorOverride,
    GlyphFrameShape? shapeOverride,
  }) {
    final effectivePrimary =
        primaryColorOverride ?? rarity?.color ?? category.primaryColor;
    return GlyphThemeData(
      primary: effectivePrimary,
      lightFill: primaryColorOverride != null
          ? primaryColorOverride.withValues(alpha: 0.12)
          : category.lightFillTint,
      darkFill: primaryColorOverride != null
          ? primaryColorOverride.withValues(alpha: 0.20)
          : category.darkFillTint,
      border: effectivePrimary,
      frameShape: shapeOverride ?? category.frameShape,
    );
  }

  factory GlyphThemeData.fromClass(
    DndClassType classType, {
    Color? primaryColorOverride,
    GlyphFrameShape? shapeOverride,
  }) {
    final effectivePrimary = primaryColorOverride ?? classType.primaryColor;
    return GlyphThemeData(
      primary: effectivePrimary,
      lightFill: effectivePrimary.withValues(alpha: 0.12),
      darkFill: effectivePrimary.withValues(alpha: 0.20),
      border: effectivePrimary,
      frameShape: shapeOverride ?? classType.frameShape,
    );
  }

  factory GlyphThemeData.fromFeat(
    FeatCategory featCategory, {
    Color? primaryColorOverride,
    GlyphFrameShape? shapeOverride,
  }) {
    final effectivePrimary = primaryColorOverride ?? featCategory.primaryColor;
    return GlyphThemeData(
      primary: effectivePrimary,
      lightFill: effectivePrimary.withValues(alpha: 0.12),
      darkFill: effectivePrimary.withValues(alpha: 0.20),
      border: effectivePrimary,
      frameShape: shapeOverride ?? featCategory.frameShape,
    );
  }

  factory GlyphThemeData.fromSpecies(
    SpeciesType speciesType, {
    Color? primaryColorOverride,
    GlyphFrameShape? shapeOverride,
  }) {
    final effectivePrimary = primaryColorOverride ?? speciesType.primaryColor;
    return GlyphThemeData(
      primary: effectivePrimary,
      lightFill: effectivePrimary.withValues(alpha: 0.12),
      darkFill: effectivePrimary.withValues(alpha: 0.20),
      border: effectivePrimary,
      frameShape: shapeOverride ?? speciesType.frameShape,
    );
  }

  factory GlyphThemeData.fromGenericUi(
    GenericUiGlyphType uiType, {
    Color? primaryColorOverride,
    GlyphFrameShape? shapeOverride,
  }) {
    final effectivePrimary = primaryColorOverride ?? uiType.primaryColor;
    return GlyphThemeData(
      primary: effectivePrimary,
      lightFill: effectivePrimary.withValues(alpha: 0.12),
      darkFill: effectivePrimary.withValues(alpha: 0.20),
      border: effectivePrimary,
      frameShape: shapeOverride ?? uiType.frameShape,
    );
  }

  GlyphThemeData copyWith({
    Color? primary,
    Color? lightFill,
    Color? darkFill,
    Color? border,
    GlyphFrameShape? frameShape,
  }) {
    return GlyphThemeData(
      primary: primary ?? this.primary,
      lightFill: lightFill ?? this.lightFill,
      darkFill: darkFill ?? this.darkFill,
      border: border ?? this.border,
      frameShape: frameShape ?? this.frameShape,
    );
  }

  Color getFill(bool isDarkMode) => isDarkMode ? darkFill : lightFill;

  Color getPrimary(bool isDarkMode) {
    if (!isDarkMode) return primary;
    if (primary.computeLuminance() < 0.25) {
      return const Color(0xFFE2E8F0);
    }
    return primary;
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is GlyphThemeData &&
          runtimeType == other.runtimeType &&
          primary == other.primary &&
          lightFill == other.lightFill &&
          darkFill == other.darkFill &&
          border == other.border &&
          frameShape == other.frameShape;

  @override
  int get hashCode =>
      Object.hash(primary, lightFill, darkFill, border, frameShape);
}
