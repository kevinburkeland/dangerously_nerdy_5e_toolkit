import 'package:vtt_ruleset_dnd5e/vtt_ruleset_dnd5e.dart' show SpellSchool;

import '../dm_screen_data.dart' show DmRulesEdition;
import 'app_icon.dart';
import 'argb.dart';

export 'package:vtt_ruleset_dnd5e/vtt_ruleset_dnd5e.dart' show SpellSchool;
export 'app_icon.dart';
export 'argb.dart';

/// Semantic spell school visual styling conforming to the Style Guide.
extension SpellSchoolVisuals on SpellSchool {
  Argb get primaryArgb => switch (this) {
        SpellSchool.abjuration => const Argb(0xFF3B82F6),
        SpellSchool.conjuration => const Argb(0xFFA855F7),
        SpellSchool.divination => const Argb(0xFF0EA5E9),
        SpellSchool.enchantment => const Argb(0xFFF43F5E),
        SpellSchool.evocation => const Argb(0xFFF97316),
        SpellSchool.illusion => const Argb(0xFF6366F1),
        SpellSchool.necromancy => const Argb(0xFF10B981),
        SpellSchool.transmutation => const Argb(0xFFF59E0B),
      };

  Argb get lightFillArgb => switch (this) {
        SpellSchool.abjuration => const Argb(0xFFEFF6FF),
        SpellSchool.conjuration => const Argb(0xFFFAF5FF),
        SpellSchool.divination => const Argb(0xFFF0F9FF),
        SpellSchool.enchantment => const Argb(0xFFFFF1F2),
        SpellSchool.evocation => const Argb(0xFFFFF7ED),
        SpellSchool.illusion => const Argb(0xFFEEF2FF),
        SpellSchool.necromancy => const Argb(0xFFECFDF5),
        SpellSchool.transmutation => const Argb(0xFFFFFBEB),
      };

  Argb get darkFillArgb => switch (this) {
        SpellSchool.abjuration => const Argb(0xFF1E3A8A),
        SpellSchool.conjuration => const Argb(0xFF581C87),
        SpellSchool.divination => const Argb(0xFF0C4A6E),
        SpellSchool.enchantment => const Argb(0xFF881337),
        SpellSchool.evocation => const Argb(0xFF7C2D12),
        SpellSchool.illusion => const Argb(0xFF312E81),
        SpellSchool.necromancy => const Argb(0xFF064E3B),
        SpellSchool.transmutation => const Argb(0xFF78350F),
      };

  GlyphFrameShape get frameShape => switch (this) {
        SpellSchool.abjuration => GlyphFrameShape.circle,
        SpellSchool.conjuration => GlyphFrameShape.hexagon,
        SpellSchool.divination => GlyphFrameShape.eye,
        SpellSchool.enchantment => GlyphFrameShape.softRhombus,
        SpellSchool.evocation => GlyphFrameShape.diamond,
        SpellSchool.illusion => GlyphFrameShape.overlappingCircle,
        SpellSchool.necromancy => GlyphFrameShape.invertedTriangle,
        SpellSchool.transmutation => GlyphFrameShape.upwardTriangle,
      };

  Argb legibleArgb(bool isDarkMode) {
    if (!isDarkMode) {
      return switch (this) {
        SpellSchool.abjuration => const Argb(0xFF1D4ED8),
        SpellSchool.conjuration => const Argb(0xFF7E22CE),
        SpellSchool.divination => const Argb(0xFF0369A1),
        SpellSchool.enchantment => const Argb(0xFFBE123C),
        SpellSchool.evocation => const Argb(0xFFC2410C),
        SpellSchool.illusion => const Argb(0xFF4338CA),
        SpellSchool.necromancy => const Argb(0xFF047857),
        SpellSchool.transmutation => const Argb(0xFFB45309),
      };
    }
    return switch (this) {
      SpellSchool.abjuration => const Argb(0xFF60A5FA),
      SpellSchool.conjuration => const Argb(0xFFC084FC),
      SpellSchool.divination => const Argb(0xFF38BDF8),
      SpellSchool.enchantment => const Argb(0xFFFB7185),
      SpellSchool.evocation => const Argb(0xFFFB923C),
      SpellSchool.illusion => const Argb(0xFF818CF8),
      SpellSchool.necromancy => const Argb(0xFF34D399),
      SpellSchool.transmutation => const Argb(0xFFFBBF24),
    };
  }

  String get label => displayName;
  Argb get colorArgb => primaryArgb;
  AppIcon get iconKey => switch (this) {
        SpellSchool.abjuration => AppIcon.shieldOutlined,
        SpellSchool.conjuration => AppIcon.autoFixHigh,
        SpellSchool.divination => AppIcon.visibilityOutlined,
        SpellSchool.enchantment => AppIcon.favoriteBorder,
        SpellSchool.evocation => AppIcon.localFireDepartmentOutlined,
        SpellSchool.illusion => AppIcon.wbTwilight,
        SpellSchool.necromancy => AppIcon.coronavirusOutlined,
        SpellSchool.transmutation => AppIcon.changeCircleOutlined,
      };
}

/// 14 Creature Classifications conforming to the Style Guide & SRD with dark-mode contrast tuning.
enum CreatureType {
  aberration('Aberration', Argb(0xFFA855F7), Argb(0xFFFAF5FF),
      Argb(0xFF3B0764), GlyphFrameShape.octagon),
  beast('Beast', Argb(0xFF111111), Argb(0xFFF0FDF4), Argb(0xFF14532D),
      GlyphFrameShape.softShield),
  celestial('Celestial', Argb(0xFFEAB308), Argb(0xFFFEFCE8),
      Argb(0xFF713F12), GlyphFrameShape.crest),
  construct('Construct', Argb(0xFFD97706), Argb(0xFFFFFBEB),
      Argb(0xFF451A03), GlyphFrameShape.heavyHex),
  dragon('Dragon', Argb(0xFFEF4444), Argb(0xFFFEF2F2), Argb(0xFF7F1D1D),
      GlyphFrameShape.sharpDiamondShield),
  elemental('Elemental', Argb(0xFF0EA5E9), Argb(0xFFF0F9FF),
      Argb(0xFF082F49), GlyphFrameShape.rhombus),
  fey('Fey', Argb(0xFFC084FC), Argb(0xFFFAF5FF), Argb(0xFF581C87),
      GlyphFrameShape.filigreeOval),
  fiend('Fiend', Argb(0xFFF43F5E), Argb(0xFFFEF2F2), Argb(0xFF450A0A),
      GlyphFrameShape.pointedShield),
  giant('Giant', Argb(0xFF94A3B8), Argb(0xFFF8FAFC), Argb(0xFF0F172A),
      GlyphFrameShape.heavySquare),
  humanoid('Humanoid', Argb(0xFF94A3B8), Argb(0xFFF8FAFC), Argb(0xFF020617),
      GlyphFrameShape.heaterShield),
  monstrosity('Monstrosity', Argb(0xFFD97706), Argb(0xFFFEFCE8),
      Argb(0xFF422006), GlyphFrameShape.jaggedCrest),
  ooze('Ooze', Argb(0xFF84CC16), Argb(0xFFF7FEE7), Argb(0xFF1A2E05),
      GlyphFrameShape.blob),
  plant('Plant', Argb(0xFF10B981), Argb(0xFFF0FDF4), Argb(0xFF052E16),
      GlyphFrameShape.teardrop),
  undead('Undead', Argb(0xFFCBD5E1), Argb(0xFFF9FAFB), Argb(0xFF030712),
      GlyphFrameShape.tombstone);

  final String displayName;
  final Argb primaryArgb;
  final Argb lightFillArgb;
  final Argb darkFillArgb;
  final GlyphFrameShape frameShape;

  const CreatureType(
    this.displayName,
    this.primaryArgb,
    this.lightFillArgb,
    this.darkFillArgb,
    this.frameShape,
  );

  Argb legibleArgb(bool isDarkMode) {
    if (!isDarkMode) {
      return switch (this) {
        CreatureType.aberration => const Argb(0xFF7E22CE),
        CreatureType.beast => const Argb(0xFF15803D),
        CreatureType.celestial => const Argb(0xFFB45309),
        CreatureType.construct => const Argb(0xFF9A3412),
        CreatureType.dragon => const Argb(0xFFB91C1C),
        CreatureType.elemental => const Argb(0xFF0369A1),
        CreatureType.fey => const Argb(0xFF7E22CE),
        CreatureType.fiend => const Argb(0xFF9F1239),
        CreatureType.giant => const Argb(0xFF334155),
        CreatureType.humanoid => const Argb(0xFF334155),
        CreatureType.monstrosity => const Argb(0xFF9A3412),
        CreatureType.ooze => const Argb(0xFF4D7C0F),
        CreatureType.plant => const Argb(0xFF047857),
        CreatureType.undead => const Argb(0xFF334155),
      };
    }
    return switch (this) {
      CreatureType.undead => const Argb(0xFFE2E8F0),
      CreatureType.humanoid => const Argb(0xFFCBD5E1),
      CreatureType.giant => const Argb(0xFFCBD5E1),
      CreatureType.construct => const Argb(0xFFFBBF24),
      CreatureType.monstrosity => const Argb(0xFFFBBF24),
      CreatureType.aberration => const Argb(0xFFC084FC),
      CreatureType.beast => const Argb(0xFF4ADE80),
      CreatureType.celestial => const Argb(0xFFFACC15),
      CreatureType.dragon => const Argb(0xFFF87171),
      CreatureType.elemental => const Argb(0xFF38BDF8),
      CreatureType.fey => const Argb(0xFFE879F9),
      CreatureType.fiend => const Argb(0xFFFB7185),
      CreatureType.ooze => const Argb(0xFFA3E635),
      CreatureType.plant => const Argb(0xFF34D399),
    };
  }

  static CreatureType? tryParse(String? nameOrSlug) {
    if (nameOrSlug == null || nameOrSlug.isEmpty) return null;
    final clean = nameOrSlug.trim().toLowerCase();
    for (final t in values) {
      if (t.name.toLowerCase() == clean ||
          t.displayName.toLowerCase() == clean) {
        return t;
      }
    }
    return null;
  }
}

/// 13 Item Classifications conforming to the Style Guide & SRD.
enum ItemCategory {
  weapon('Weapon', Argb(0xFFEF4444), Argb(0xFFFEF2F2), Argb(0xFF7F1D1D),
      GlyphFrameShape.sharpDiamondShield),
  armor('Armor & Shield', Argb(0xFF3B82F6), Argb(0xFFEFF6FF),
      Argb(0xFF1E3A8A), GlyphFrameShape.heaterShield),
  potion('Potion & Elixir', Argb(0xFF10B981), Argb(0xFFECFDF5),
      Argb(0xFF064E3B), GlyphFrameShape.teardrop),
  ring('Ring & Band', Argb(0xFFF59E0B), Argb(0xFFFFFBEB), Argb(0xFF78350F),
      GlyphFrameShape.circle),
  rod('Rod & Scepter', Argb(0xFFA855F7), Argb(0xFFFAF5FF), Argb(0xFF581C87),
      GlyphFrameShape.heavySquare),
  scroll('Scroll & Tome', Argb(0xFF0EA5E9), Argb(0xFFF0F9FF),
      Argb(0xFF0C4A6E), GlyphFrameShape.filigreeOval),
  staff('Staff & Focus', Argb(0xFF8B5CF6), Argb(0xFFF5F3FF),
      Argb(0xFF4C1D95), GlyphFrameShape.heavyHex),
  wand('Wand & Baton', Argb(0xFFF43F5E), Argb(0xFFFFF1F2), Argb(0xFF881337),
      GlyphFrameShape.diamond),
  wondrousItem('Wondrous Item', Argb(0xFFEC4899), Argb(0xFFFDF2F8),
      Argb(0xFF831843), GlyphFrameShape.crest),
  adventuringGear('Adventuring Gear', Argb(0xFF64748B), Argb(0xFFF8FAFC),
      Argb(0xFF0F172A), GlyphFrameShape.heavyHex),
  gemstone('Gemstone', Argb(0xFF06B6D4), Argb(0xFFECFEFF), Argb(0xFF164E63),
      GlyphFrameShape.diamond),
  artObject('Art Object', Argb(0xFFC084FC), Argb(0xFFFAF5FF),
      Argb(0xFF581C87), GlyphFrameShape.crest),
  trinket('Trinket', Argb(0xFF10B981), Argb(0xFFECFDF5), Argb(0xFF064E3B),
      GlyphFrameShape.circle);

  final String displayName;
  final Argb primaryArgb;
  final Argb lightFillArgb;
  final Argb darkFillArgb;
  final GlyphFrameShape frameShape;

  const ItemCategory(
    this.displayName,
    this.primaryArgb,
    this.lightFillArgb,
    this.darkFillArgb,
    this.frameShape,
  );

  Argb legibleArgb(bool isDarkMode) {
    if (!isDarkMode) {
      return switch (this) {
        ItemCategory.weapon => const Argb(0xFFB91C1C),
        ItemCategory.armor => const Argb(0xFF1D4ED8),
        ItemCategory.potion => const Argb(0xFF047857),
        ItemCategory.ring => const Argb(0xFFB45309),
        ItemCategory.rod => const Argb(0xFF7E22CE),
        ItemCategory.scroll => const Argb(0xFF0369A1),
        ItemCategory.staff => const Argb(0xFF6D28D9),
        ItemCategory.wand => const Argb(0xFFBE123C),
        ItemCategory.wondrousItem => const Argb(0xFFBE185D),
        ItemCategory.adventuringGear => const Argb(0xFF475569),
        ItemCategory.gemstone => const Argb(0xFF0891B2),
        ItemCategory.artObject => const Argb(0xFF9333EA),
        ItemCategory.trinket => const Argb(0xFF059669),
      };
    }
    return switch (this) {
      ItemCategory.weapon => const Argb(0xFFF87171),
      ItemCategory.armor => const Argb(0xFF60A5FA),
      ItemCategory.potion => const Argb(0xFF34D399),
      ItemCategory.ring => const Argb(0xFFFBBF24),
      ItemCategory.rod => const Argb(0xFFC084FC),
      ItemCategory.scroll => const Argb(0xFF38BDF8),
      ItemCategory.staff => const Argb(0xFFA78BFA),
      ItemCategory.wand => const Argb(0xFFFB7185),
      ItemCategory.wondrousItem => const Argb(0xFFF472B6),
      ItemCategory.adventuringGear => const Argb(0xFF94A3B8),
      ItemCategory.gemstone => const Argb(0xFF22D3EE),
      ItemCategory.artObject => const Argb(0xFFC084FC),
      ItemCategory.trinket => const Argb(0xFF34D399),
    };
  }

  String get label => displayName;
  Argb get colorArgb => primaryArgb;
  AppIcon get iconKey => switch (this) {
        ItemCategory.weapon => AppIcon.shieldOutlined,
        ItemCategory.armor => AppIcon.shieldOutlined,
        ItemCategory.potion => AppIcon.scienceOutlined,
        ItemCategory.ring => AppIcon.albumOutlined,
        ItemCategory.rod => AppIcon.straightenOutlined,
        ItemCategory.scroll => AppIcon.articleOutlined,
        ItemCategory.staff => AppIcon.brushOutlined,
        ItemCategory.wand => AppIcon.autoFixNormalOutlined,
        ItemCategory.wondrousItem => AppIcon.diamondOutlined,
        ItemCategory.adventuringGear => AppIcon.backpackOutlined,
        ItemCategory.gemstone => AppIcon.diamondOutlined,
        ItemCategory.artObject => AppIcon.paletteOutlined,
        ItemCategory.trinket => AppIcon.starsOutlined,
      };
}

/// 7 Standard 5e Item Rarities.
enum ItemRarity {
  nonmagical('Nonmagical', Argb(0xFF64748B), 0),
  common('Common', Argb(0xFF94A3B8), 0),
  uncommon('Uncommon', Argb(0xFF22C55E), 1),
  rare('Rare', Argb(0xFF3B82F6), 2),
  veryRare('Very Rare', Argb(0xFFA855F7), 3),
  legendary('Legendary', Argb(0xFFF59E0B), 4),
  artifact('Artifact', Argb(0xFFEF4444), 5);

  final String displayName;
  final Argb colorArgb;
  final int tierLevel;

  const ItemRarity(this.displayName, this.colorArgb, this.tierLevel);

  Argb legibleArgb(bool isDarkMode) {
    if (!isDarkMode) {
      return switch (this) {
        ItemRarity.nonmagical => const Argb(0xFF475569),
        ItemRarity.common => const Argb(0xFF475569),
        ItemRarity.uncommon => const Argb(0xFF15803D),
        ItemRarity.rare => const Argb(0xFF1D4ED8),
        ItemRarity.veryRare => const Argb(0xFF7E22CE),
        ItemRarity.legendary => const Argb(0xFFB45309),
        ItemRarity.artifact => const Argb(0xFFB91C1C),
      };
    }
    return switch (this) {
      ItemRarity.nonmagical => const Argb(0xFF94A3B8),
      ItemRarity.common => const Argb(0xFFCBD5E1),
      ItemRarity.uncommon => const Argb(0xFF4ADE80),
      ItemRarity.rare => const Argb(0xFF60A5FA),
      ItemRarity.veryRare => const Argb(0xFFC084FC),
      ItemRarity.legendary => const Argb(0xFFFBBF24),
      ItemRarity.artifact => const Argb(0xFFF87171),
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

/// Top-level Domain Classification of a Glyph Entity.
enum GlyphCategory {
  spell('Spell', AppIcon.memory),
  creature('Minion & Creature', AppIcon.hub),
  item('Magic Item & Gear', AppIcon.shieldOutlined),
  classFeature('Class Feature', AppIcon.shield),
  species('Species & Heritage', AppIcon.groupsOutlined),
  feat('Feat & Epic Boon', AppIcon.starsOutlined),
  genericUi('Generic UI & Dice', AppIcon.widgetsOutlined);

  final String displayName;
  final AppIcon iconKey;
  const GlyphCategory(this.displayName, this.iconKey);
}

/// Abstract polymorphic interface implemented by any entity renderable as a techno-rune glyph.
abstract class GlyphRenderable {
  String get glyphId;
  String get displayName;
  GlyphCategory get glyphCategory;
  List<ActionTraitRing> get actionRings;
  DamageAccent? get primaryAccent;
  AppIcon? get fallbackIconKey;
  Map<String, dynamic>? get metadata;
}

/// 12 Core 5E Character Classes.
enum DndClassType {
  barbarian('Barbarian', 12, Argb(0xFFEF4444), GlyphFrameShape.heavySquare,
      'Rage'),
  bard('Bard', 8, Argb(0xFFEC4899), GlyphFrameShape.filigreeOval,
      'Bardic Inspiration'),
  cleric(
      'Cleric', 8, Argb(0xFFF59E0B), GlyphFrameShape.crest, 'Channel Divinity'),
  druid(
      'Druid', 8, Argb(0xFF10B981), GlyphFrameShape.teardrop, 'Wild Shape'),
  fighter('Fighter', 10, Argb(0xFFDC2626), GlyphFrameShape.heaterShield,
      'Action Surge'),
  monk('Monk', 8, Argb(0xFF06B6D4), GlyphFrameShape.circle, 'Ki / Focus'),
  paladin('Paladin', 10, Argb(0xFFFBBF24), GlyphFrameShape.sharpDiamondShield,
      'Lay on Hands'),
  ranger('Ranger', 10, Argb(0xFF16A34A), GlyphFrameShape.softShield,
      'Spell Slots / Hunter'),
  rogue('Rogue', 8, Argb(0xFF64748B), GlyphFrameShape.softRhombus,
      'Sneak Attack'),
  sorcerer(
      'Sorcerer', 6, Argb(0xFFF97316), GlyphFrameShape.diamond, 'Sorcery Points'),
  warlock('Warlock', 8, Argb(0xFFA855F7), GlyphFrameShape.octagon,
      'Pact Magic Slots'),
  wizard('Wizard', 6, Argb(0xFF3B82F6), GlyphFrameShape.hexagon,
      'Arcane Recovery');

  final String displayName;
  final int hitDieSides;
  final Argb primaryArgb;
  final GlyphFrameShape frameShape;
  final String primaryResource;

  const DndClassType(
    this.displayName,
    this.hitDieSides,
    this.primaryArgb,
    this.frameShape,
    this.primaryResource,
  );

  Argb legibleArgb(bool isDarkMode) {
    if (!isDarkMode) {
      return switch (this) {
        DndClassType.barbarian => const Argb(0xFFB91C1C),
        DndClassType.bard => const Argb(0xFFBE185D),
        DndClassType.cleric => const Argb(0xFFB45309),
        DndClassType.druid => const Argb(0xFF047857),
        DndClassType.fighter => const Argb(0xFF991B1B),
        DndClassType.monk => const Argb(0xFF0891B2),
        DndClassType.paladin => const Argb(0xFFB45309),
        DndClassType.ranger => const Argb(0xFF15803D),
        DndClassType.rogue => const Argb(0xFF334155),
        DndClassType.sorcerer => const Argb(0xFFC2410C),
        DndClassType.warlock => const Argb(0xFF7E22CE),
        DndClassType.wizard => const Argb(0xFF1D4ED8),
      };
    }
    return switch (this) {
      DndClassType.barbarian => const Argb(0xFFF87171),
      DndClassType.bard => const Argb(0xFFF472B6),
      DndClassType.cleric => const Argb(0xFFFBBF24),
      DndClassType.druid => const Argb(0xFF34D399),
      DndClassType.fighter => const Argb(0xFFEF4444),
      DndClassType.monk => const Argb(0xFF22D3EE),
      DndClassType.paladin => const Argb(0xFFFDE047),
      DndClassType.ranger => const Argb(0xFF4ADE80),
      DndClassType.rogue => const Argb(0xFF94A3B8),
      DndClassType.sorcerer => const Argb(0xFFFB923C),
      DndClassType.warlock => const Argb(0xFFC084FC),
      DndClassType.wizard => const Argb(0xFF60A5FA),
    };
  }

  static DndClassType? tryParse(String? nameOrSlug) {
    if (nameOrSlug == null || nameOrSlug.isEmpty) return null;
    final clean = nameOrSlug
        .trim()
        .toLowerCase()
        .replaceAll('-', '')
        .replaceAll('_', '')
        .replaceAll(' ', '');
    for (final c in values) {
      final cClean =
          c.name.toLowerCase().replaceAll('-', '').replaceAll('_', '');
      final dClean = c.displayName
          .toLowerCase()
          .replaceAll('-', '')
          .replaceAll('_', '')
          .replaceAll(' ', '');
      if (clean == cClean || clean == dClean || clean.contains(cClean)) {
        return c;
      }
    }
    return null;
  }
}

/// Feat category classification (Origin, General, Epic Boon).
enum FeatCategory {
  origin('Origin Feat (Level 1)', Argb(0xFF38BDF8), 1,
      GlyphFrameShape.softRhombus),
  general(
      'General Feat (Level 4+)', Argb(0xFFA855F7), 2, GlyphFrameShape.crest),
  epicBoon(
      'Epic Boon (Level 19+)', Argb(0xFFF59E0B), 4, GlyphFrameShape.diamond);

  final String displayName;
  final Argb primaryArgb;
  final int tierLevel;
  final GlyphFrameShape frameShape;

  const FeatCategory(
    this.displayName,
    this.primaryArgb,
    this.tierLevel,
    this.frameShape,
  );

  Argb legibleArgb(bool isDarkMode) {
    if (!isDarkMode) {
      return switch (this) {
        FeatCategory.origin => const Argb(0xFF0369A1),
        FeatCategory.general => const Argb(0xFF7E22CE),
        FeatCategory.epicBoon => const Argb(0xFFB45309),
      };
    }
    return switch (this) {
      FeatCategory.origin => const Argb(0xFF38BDF8),
      FeatCategory.general => const Argb(0xFFC084FC),
      FeatCategory.epicBoon => const Argb(0xFFFBBF24),
    };
  }

  static FeatCategory parse(String? category) {
    if (category == null) return FeatCategory.general;
    final lower = category.toLowerCase();
    if (lower.contains('origin')) return FeatCategory.origin;
    if (lower.contains('boon') || lower.contains('epic')) {
      return FeatCategory.epicBoon;
    }
    return FeatCategory.general;
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

/// 9 Core 5E Species / Races across 2014 and 2024 rules editions.
enum SpeciesType {
  human('Human', Argb(0xFF94A3B8), GlyphFrameShape.circle),
  elf('Elf', Argb(0xFF10B981), GlyphFrameShape.filigreeOval),
  dwarf('Dwarf', Argb(0xFFF59E0B), GlyphFrameShape.heavyHex),
  halfling('Halfling', Argb(0xFF22C55E), GlyphFrameShape.softShield),
  dragonborn(
      'Dragonborn', Argb(0xFFEF4444), GlyphFrameShape.sharpDiamondShield),
  gnome('Gnome', Argb(0xFF06B6D4), GlyphFrameShape.hexagon),
  tiefling('Tiefling', Argb(0xFFF43F5E), GlyphFrameShape.pointedShield),
  orc('Orc', Argb(0xFF84CC16), GlyphFrameShape.jaggedCrest),
  goliath('Goliath', Argb(0xFF64748B), GlyphFrameShape.heavySquare);

  final String displayName;
  final Argb primaryArgb;
  final GlyphFrameShape frameShape;

  const SpeciesType(
    this.displayName,
    this.primaryArgb,
    this.frameShape,
  );

  String get size => getSize(DmRulesEdition.v2024);
  int get speed => getSpeed(DmRulesEdition.v2024);
  String get traits => getTraits(DmRulesEdition.v2024);

  int getSpeed([DmRulesEdition edition = DmRulesEdition.v2024]) {
    if (edition == DmRulesEdition.v2014) {
      return switch (this) {
        SpeciesType.dwarf => 25,
        SpeciesType.halfling => 25,
        SpeciesType.gnome => 25,
        SpeciesType.goliath => 30,
        _ => 30,
      };
    }
    return switch (this) {
      SpeciesType.goliath => 35,
      _ => 30,
    };
  }

  String getSize([DmRulesEdition edition = DmRulesEdition.v2024]) {
    if (edition == DmRulesEdition.v2014) {
      return switch (this) {
        SpeciesType.halfling || SpeciesType.gnome => 'Small',
        _ => 'Medium',
      };
    }
    return switch (this) {
      SpeciesType.human || SpeciesType.tiefling => 'Medium or Small',
      SpeciesType.halfling || SpeciesType.gnome => 'Small',
      _ => 'Medium',
    };
  }

  String getTraits([DmRulesEdition edition = DmRulesEdition.v2024]) {
    if (edition == DmRulesEdition.v2014) {
      return switch (this) {
        SpeciesType.human =>
          '+1 to All Ability Scores (or Feat + Skill for Variant)',
        SpeciesType.elf =>
          'Darkvision (60 ft), Keen Senses, Fey Ancestry, Trance, Elf Weapon Training',
        SpeciesType.dwarf =>
          'Speed 25 ft (Armor Unhindered), Darkvision (60 ft), Dwarven Resilience, Stonecunning',
        SpeciesType.halfling =>
          'Speed 25 ft, Lucky (Reroll 1s), Brave, Halfling Nimbleness, Naturally Stealthy',
        SpeciesType.dragonborn =>
          'Draconic Ancestry, Breath Weapon (Action), Damage Resistance',
        SpeciesType.gnome =>
          'Speed 25 ft, Darkvision (60 ft), Gnome Cunning (Advantage vs Magic)',
        SpeciesType.tiefling =>
          'Darkvision (60 ft), Hellish Resistance (Fire), Infernal Legacy',
        SpeciesType.orc =>
          'Darkvision (60 ft), Relentless Endurance, Savage Attacks, Menacing',
        SpeciesType.goliath =>
          'Natural Athlete, Stone\'s Endurance (1d12+Con), Powerful Build, Mountain Born',
      };
    }
    return switch (this) {
      SpeciesType.human =>
        'Resourceful (Heroic Inspiration), Skillful, Versatile (Origin Feat)',
      SpeciesType.elf =>
        'Darkvision (60 ft), Keen Senses, Fey Ancestry, Trance, Elven Lineage',
      SpeciesType.dwarf =>
        'Darkvision (120 ft), Dwarven Resilience, Dwarven Toughness (+1 HP/level), Stonecunning (Tremorsense 60 ft)',
      SpeciesType.halfling =>
        'Brave, Halfling Nimbleness, Luck, Naturally Stealthy',
      SpeciesType.dragonborn =>
        'Breath Weapon (Replaces Attack), Damage Resistance, Darkvision (60 ft), Flight (Lv 5)',
      SpeciesType.gnome =>
        'Darkvision (60 ft), Gnomish Cunning (Mental Saves), Gnomish Lineage (Forest/Rock)',
      SpeciesType.tiefling =>
        'Darkvision (60 ft), Fiendish Legacy (Abyssal/Chthonic/Infernal), Otherworldly Presence',
      SpeciesType.orc =>
        'Darkvision (120 ft), Adrenaline Rush (Dash + Temp HP), Relentless Endurance',
      SpeciesType.goliath =>
        'Giant Ancestry, Large Form (Bonus Action, Lv 5), Powerful Build, Stone\'s Endurance',
    };
  }

  Argb legibleArgb(bool isDarkMode) {
    if (!isDarkMode) {
      return switch (this) {
        SpeciesType.human => const Argb(0xFF334155),
        SpeciesType.elf => const Argb(0xFF047857),
        SpeciesType.dwarf => const Argb(0xFFB45309),
        SpeciesType.halfling => const Argb(0xFF15803D),
        SpeciesType.dragonborn => const Argb(0xFFB91C1C),
        SpeciesType.gnome => const Argb(0xFF0891B2),
        SpeciesType.tiefling => const Argb(0xFFBE123C),
        SpeciesType.orc => const Argb(0xFF4D7C0F),
        SpeciesType.goliath => const Argb(0xFF334155),
      };
    }
    return switch (this) {
      SpeciesType.human => const Argb(0xFFCBD5E1),
      SpeciesType.elf => const Argb(0xFF34D399),
      SpeciesType.dwarf => const Argb(0xFFFBBF24),
      SpeciesType.halfling => const Argb(0xFF4ADE80),
      SpeciesType.dragonborn => const Argb(0xFFF87171),
      SpeciesType.gnome => const Argb(0xFF22D3EE),
      SpeciesType.tiefling => const Argb(0xFFFB7185),
      SpeciesType.orc => const Argb(0xFFA3E635),
      SpeciesType.goliath => const Argb(0xFF94A3B8),
    };
  }

  static SpeciesType? tryParse(String? nameOrSlug) {
    if (nameOrSlug == null || nameOrSlug.isEmpty) return null;
    final clean = nameOrSlug
        .trim()
        .toLowerCase()
        .replaceAll('-', '')
        .replaceAll('_', '')
        .replaceAll(' ', '');
    for (final s in values) {
      final sClean = s.name.toLowerCase();
      final dClean = s.displayName.toLowerCase().replaceAll(' ', '');
      if (clean == sClean || clean == dClean || clean.contains(sClean)) {
        return s;
      }
    }
    return null;
  }
}

/// Generic UI Glyphs: Polyhedrals, HUD Status Reticles, and Action Economy Badges.
enum GenericUiGlyphType {
  d4('d4 Tetrahedron', Argb(0xFF60A5FA), GlyphFrameShape.upwardTriangle),
  d6('d6 Cube', Argb(0xFF34D399), GlyphFrameShape.heavySquare),
  d8('d8 Octahedron', Argb(0xFFFBBF24), GlyphFrameShape.diamond),
  d10('d10 Trapezohedron', Argb(0xFFFB923C), GlyphFrameShape.rhombus),
  d12('d12 Dodecahedron', Argb(0xFFA78BFA), GlyphFrameShape.heavyHex),
  d20('d20 Icosahedron', Argb(0xFFF43F5E), GlyphFrameShape.hexagon),
  d100('d100 Percentile', Argb(0xFFEC4899), GlyphFrameShape.circle),
  advantage(
      'Advantage Beacon', Argb(0xFF22C55E), GlyphFrameShape.upwardTriangle),
  disadvantage('Disadvantage Quench', Argb(0xFFEF4444),
      GlyphFrameShape.invertedTriangle),
  concentrating('Concentrating', Argb(0xFF38BDF8), GlyphFrameShape.circle),
  deathSave(
      'Death Save Telemetry', Argb(0xFFF43F5E), GlyphFrameShape.tombstone),
  actionEconomyAction(
      'Standard Action', Argb(0xFF3B82F6), GlyphFrameShape.diamond),
  actionEconomyBonus(
      'Bonus Action', Argb(0xFFF59E0B), GlyphFrameShape.softRhombus),
  actionEconomyReaction(
      'Reaction Trigger', Argb(0xFF06B6D4), GlyphFrameShape.heaterShield);

  final String displayName;
  final Argb primaryArgb;
  final GlyphFrameShape frameShape;

  const GenericUiGlyphType(
    this.displayName,
    this.primaryArgb,
    this.frameShape,
  );

  Argb legibleArgb(bool isDarkMode) {
    if (!isDarkMode) {
      return switch (this) {
        GenericUiGlyphType.d4 => const Argb(0xFF1D4ED8),
        GenericUiGlyphType.d6 => const Argb(0xFF047857),
        GenericUiGlyphType.d8 => const Argb(0xFFB45309),
        GenericUiGlyphType.d10 => const Argb(0xFFC2410C),
        GenericUiGlyphType.d12 => const Argb(0xFF6D28D9),
        GenericUiGlyphType.d20 => const Argb(0xFFBE123C),
        GenericUiGlyphType.d100 => const Argb(0xFFBE185D),
        GenericUiGlyphType.advantage => const Argb(0xFF15803D),
        GenericUiGlyphType.disadvantage => const Argb(0xFFB91C1C),
        GenericUiGlyphType.concentrating => const Argb(0xFF0369A1),
        GenericUiGlyphType.deathSave => const Argb(0xFF9F1239),
        GenericUiGlyphType.actionEconomyAction => const Argb(0xFF1D4ED8),
        GenericUiGlyphType.actionEconomyBonus => const Argb(0xFFB45309),
        GenericUiGlyphType.actionEconomyReaction => const Argb(0xFF0891B2),
      };
    }
    return switch (this) {
      GenericUiGlyphType.d4 => const Argb(0xFF60A5FA),
      GenericUiGlyphType.d6 => const Argb(0xFF34D399),
      GenericUiGlyphType.d8 => const Argb(0xFFFBBF24),
      GenericUiGlyphType.d10 => const Argb(0xFFFB923C),
      GenericUiGlyphType.d12 => const Argb(0xFFA78BFA),
      GenericUiGlyphType.d20 => const Argb(0xFFFB7185),
      GenericUiGlyphType.d100 => const Argb(0xFFF472B6),
      GenericUiGlyphType.advantage => const Argb(0xFF4ADE80),
      GenericUiGlyphType.disadvantage => const Argb(0xFFF87171),
      GenericUiGlyphType.concentrating => const Argb(0xFF38BDF8),
      GenericUiGlyphType.deathSave => const Argb(0xFFFB7185),
      GenericUiGlyphType.actionEconomyAction => const Argb(0xFF60A5FA),
      GenericUiGlyphType.actionEconomyBonus => const Argb(0xFFFBBF24),
      GenericUiGlyphType.actionEconomyReaction => const Argb(0xFF22D3EE),
    };
  }

  static GenericUiGlyphType? fromDie(String? dieName) {
    if (dieName == null) return null;
    final clean = dieName.toLowerCase().trim();
    return switch (clean) {
      'd4' => GenericUiGlyphType.d4,
      'd6' => GenericUiGlyphType.d6,
      'd8' => GenericUiGlyphType.d8,
      'd10' => GenericUiGlyphType.d10,
      'd12' => GenericUiGlyphType.d12,
      'd20' => GenericUiGlyphType.d20,
      'd100' || 'percentile' => GenericUiGlyphType.d100,
      _ => null,
    };
  }
}

/// Action & Attack Ring Types for Dynamic Wireframe Trait Composability.
enum ActionRingType {
  melee('Melee Attack'),
  ranged('Ranged Attack'),
  recharge('Recharge / AoE'),
  reaction('Reaction/Defense'),
  control('Control Effect'),
  sustain('Sustain/Healing'),
  legendary('Legendary Trait'),
  concentration('Concentration'),
  attunement('Attunement'),
  bonusAction('Bonus Action'),
  resource('Resource Pool'),
  passive('Passive Trait'),
  speed('Speed / Mobility'),
  sense('Sensory Radar'),
  hitDie('Hit Die Geometry');

  final String displayName;
  const ActionRingType(this.displayName);
}

/// A dynamic action/attack trait ring that surrounds the glyph symbol and is colored by damage type.
class ActionTraitRing {
  final ActionRingType ringType;
  final DamageAccent? damageType;
  final List<DamageAccent> damageTypes;
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
    for (var i = 0; i < a.length; i++) {
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
  physical('Physical / Neutral', Argb(0xFF94A3B8)),
  slashing('Slashing', Argb(0xFFE2E8F0)),
  piercing('Piercing', Argb(0xFFCBD5E1)),
  bludgeoning('Bludgeoning', Argb(0xFF94A3B8)),
  fire('Fire', Argb(0xFFEF4444)),
  cold('Cold / Ice', Argb(0xFF06B6D4)),
  lightning('Lightning', Argb(0xFFEAB308)),
  acid('Acid', Argb(0xFF84CC16)),
  poison('Poison', Argb(0xFF10B981)),
  necrotic('Necrotic', Argb(0xFF8B5CF6)),
  radiant('Radiant', Argb(0xFFF59E0B)),
  psychic('Psychic', Argb(0xFFEC4899)),
  force('Force', Argb(0xFF3B82F6)),
  thunder('Thunder', Argb(0xFF6366F1));

  final String displayName;
  final Argb colorArgb;

  const DamageAccent(this.displayName, this.colorArgb);
}

/// Legacy Action Badges for backwards compatibility.
enum ActionBadge {
  melee('Melee Weapon Attack', Argb(0xFFEF4444)),
  ranged('Ranged Weapon Attack', Argb(0xFF3B82F6)),
  recharge('Recharge / Special Trait', Argb(0xFFF59E0B)),
  legendary('Legendary Action', Argb(0xFFEC4899)),
  lair('Lair Action', Argb(0xFF8B5CF6));

  final String displayName;
  final Argb colorArgb;

  const ActionBadge(this.displayName, this.colorArgb);
}
