import 'package:flutter/material.dart';

/// Semantic spell schools conforming to the Style Guide & 5e SRD.
enum SpellSchool {
  abjuration('Abjuration', Color(0xFF3B82F6), Color(0xFFEFF6FF), Color(0xFF1E3A8A), GlyphFrameShape.circle),
  conjuration('Conjuration', Color(0xFFA855F7), Color(0xFFFAF5FF), Color(0xFF581C87), GlyphFrameShape.hexagon),
  divination('Divination', Color(0xFF0EA5E9), Color(0xFFF0F9FF), Color(0xFF0C4A6E), GlyphFrameShape.eye),
  enchantment('Enchantment', Color(0xFFF43F5E), Color(0xFFFFF1F2), Color(0xFF881337), GlyphFrameShape.softRhombus),
  evocation('Evocation', Color(0xFFF97316), Color(0xFFFFF7ED), Color(0xFF7C2D12), GlyphFrameShape.diamond),
  illusion('Illusion', Color(0xFF6366F1), Color(0xFFEEF2FF), Color(0xFF312E81), GlyphFrameShape.overlappingCircle),
  necromancy('Necromancy', Color(0xFF10B981), Color(0xFFECFDF5), Color(0xFF064E3B), GlyphFrameShape.invertedTriangle),
  transmutation('Transmutation', Color(0xFFF59E0B), Color(0xFFFFFBEB), Color(0xFF78350F), GlyphFrameShape.upwardTriangle);

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

  /// Returns a high-contrast version of the primary color guaranteed legible on dark backgrounds.
  Color getLegibleColor(bool isDarkMode) {
    if (!isDarkMode) return primaryColor;
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
  aberration('Aberration', Color(0xFFA855F7), Color(0xFFFAF5FF), Color(0xFF3B0764), GlyphFrameShape.octagon),
  beast('Beast', Color(0xFF22C55E), Color(0xFFF0FDF4), Color(0xFF14532D), GlyphFrameShape.softShield),
  celestial('Celestial', Color(0xFFEAB308), Color(0xFFFEFCE8), Color(0xFF713F12), GlyphFrameShape.crest),
  construct('Construct', Color(0xFFD97706), Color(0xFFFFFBEB), Color(0xFF451A03), GlyphFrameShape.heavyHex),
  dragon('Dragon', Color(0xFFEF4444), Color(0xFFFEF2F2), Color(0xFF7F1D1D), GlyphFrameShape.sharpDiamondShield),
  elemental('Elemental', Color(0xFF0EA5E9), Color(0xFFF0F9FF), Color(0xFF082F49), GlyphFrameShape.rhombus),
  fey('Fey', Color(0xFFC084FC), Color(0xFFFAF5FF), Color(0xFF581C87), GlyphFrameShape.filigreeOval),
  fiend('Fiend', Color(0xFFF43F5E), Color(0xFFFEF2F2), Color(0xFF450A0A), GlyphFrameShape.pointedShield),
  giant('Giant', Color(0xFF94A3B8), Color(0xFFF8FAFC), Color(0xFF0F172A), GlyphFrameShape.heavySquare),
  humanoid('Humanoid', Color(0xFF94A3B8), Color(0xFFF8FAFC), Color(0xFF020617), GlyphFrameShape.heaterShield),
  monstrosity('Monstrosity', Color(0xFFD97706), Color(0xFFFEFCE8), Color(0xFF422006), GlyphFrameShape.jaggedCrest),
  ooze('Ooze', Color(0xFF84CC16), Color(0xFFF7FEE7), Color(0xFF1A2E05), GlyphFrameShape.blob),
  plant('Plant', Color(0xFF10B981), Color(0xFFF0FDF4), Color(0xFF052E16), GlyphFrameShape.teardrop),
  undead('Undead', Color(0xFFCBD5E1), Color(0xFFF9FAFB), Color(0xFF030712), GlyphFrameShape.tombstone);

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

  /// Returns a high-contrast version of the primary color guaranteed legible on dark backgrounds.
  Color getLegibleColor(bool isDarkMode) {
    if (!isDarkMode) {
      return switch (this) {
        CreatureType.undead => const Color(0xFF334155),
        CreatureType.humanoid => const Color(0xFF475569),
        CreatureType.giant => const Color(0xFF475569),
        _ => primaryColor,
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

/// Action & Attack Ring Types for Dynamic Wireframe Trait Composability.
enum ActionRingType {
  melee('Melee Attack'),       // Faceted Diamond / Octagonal Ring with blade ticks
  ranged('Ranged Attack'),     // Circular Crosshair Reticle Ring with 4-axis target tick marks
  recharge('Recharge / AoE'),  // Segmented Hexagonal Pulse Ring with energy burst gaps
  reaction('Reaction/Defense'),// Shielded Square Ring with corner deflection brackets
  legendary('Legendary Trait'),// Spiked Starburst Crown Ring
  concentration('Concentration');// Dual-Harmonic Orbital Wireframe Loop Ring

  final String displayName;
  const ActionRingType(this.displayName);
}

/// A dynamic action/attack trait ring that surrounds the glyph symbol and is colored by damage type.
class ActionTraitRing {
  final ActionRingType ringType;
  final DamageAccent? damageType; // If set, illuminates this specific ring with that damage type's neon color
  final String? label;

  const ActionTraitRing({
    required this.ringType,
    this.damageType,
    this.label,
  });

  Color getEffectiveColor(Color fallbackColor, {bool isDarkMode = false}) {
    // Concentration is pure harmonic orbital arcane wireframe and never has an elemental damage type
    if (ringType == ActionRingType.concentration) {
      return isDarkMode ? const Color(0xFF38BDF8) : const Color(0xFF0284C7); // Ethereal orbital cyan
    }
    if (damageType != null) {
      if (damageType == DamageAccent.physical) {
        return isDarkMode ? const Color(0xFFCBD5E1) : const Color(0xFF64748B);
      }
      return damageType!.color;
    }
    return isDarkMode ? const Color(0xFF94A3B8) : const Color(0xFF64748B);
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ActionTraitRing &&
          runtimeType == other.runtimeType &&
          ringType == other.ringType &&
          damageType == other.damageType &&
          label == other.label;

  @override
  int get hashCode => Object.hash(ringType, damageType, label);
}

/// 11 Damage Accents (10 Elemental + Physical/Neutral Titanium Steel).
enum DamageAccent {
  physical('Physical / Neutral', Color(0xFF94A3B8)),
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

  factory GlyphThemeData.fromSchool(SpellSchool school, {GlyphFrameShape? shapeOverride}) {
    return GlyphThemeData(
      primary: school.primaryColor,
      lightFill: school.lightFillTint,
      darkFill: school.darkFillTint,
      border: school.primaryColor,
      frameShape: shapeOverride ?? school.frameShape,
    );
  }

  factory GlyphThemeData.fromCreature(CreatureType type, {GlyphFrameShape? shapeOverride}) {
    return GlyphThemeData(
      primary: type.primaryColor,
      lightFill: type.lightFillTint,
      darkFill: type.darkFillTint,
      border: type.primaryColor,
      frameShape: shapeOverride ?? type.frameShape,
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
  int get hashCode => Object.hash(primary, lightFill, darkFill, border, frameShape);
}
