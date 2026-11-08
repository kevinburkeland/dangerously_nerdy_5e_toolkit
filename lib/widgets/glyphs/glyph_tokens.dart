import 'package:flutter/material.dart';

import '../../presentation/visual/glyph_kinds_ui.dart';

export 'package:vtt_ruleset_dnd5e/vtt_ruleset_dnd5e.dart' show SpellSchool;
export '../../models/visual/glyph_kinds.dart';
export '../../presentation/visual/glyph_kinds_ui.dart';
export '../../presentation/visual/visual_ui.dart';

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
