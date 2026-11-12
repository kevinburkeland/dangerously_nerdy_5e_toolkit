import 'dart:math';

import 'package:material_ui/material_ui.dart';

import 'visual_ui.dart';

export '../../models/visual/glyph_kinds.dart';
export 'visual_ui.dart';

/// Presentation extension on [SpellSchool] restoring Flutter UI types.
extension SpellSchoolUiExtension on SpellSchool {
  Color get primaryColor => primaryArgb.toColor();
  Color get lightFillTint => lightFillArgb.toColor();
  Color get darkFillTint => darkFillArgb.toColor();
  Color get color => colorArgb.toColor();
  IconData get icon => iconKey.iconData;
  Color getLegibleColor(bool isDarkMode) =>
      legibleArgb(isDarkMode).toColor();
}

/// Presentation extension on [CreatureType] restoring Flutter UI types.
extension CreatureTypeUi on CreatureType {
  Color get primaryColor => primaryArgb.toColor();
  Color get lightFillTint => lightFillArgb.toColor();
  Color get darkFillTint => darkFillArgb.toColor();
  Color getLegibleColor(bool isDarkMode) =>
      legibleArgb(isDarkMode).toColor();
}

/// Presentation extension on [ItemCategory] restoring Flutter UI types.
extension ItemCategoryUi on ItemCategory {
  Color get primaryColor => primaryArgb.toColor();
  Color get lightFillTint => lightFillArgb.toColor();
  Color get darkFillTint => darkFillArgb.toColor();
  Color get color => colorArgb.toColor();
  IconData get icon => iconKey.iconData;
  Color getLegibleColor(bool isDarkMode) =>
      legibleArgb(isDarkMode).toColor();
}

/// Presentation extension on [ItemRarity] restoring Flutter UI types.
extension ItemRarityUi on ItemRarity {
  Color get color => colorArgb.toColor();
  Color getLegibleColor(bool isDarkMode) =>
      legibleArgb(isDarkMode).toColor();
}

/// Presentation extension on [GlyphCategory] restoring Flutter UI types.
extension GlyphCategoryUi on GlyphCategory {
  IconData get icon => iconKey.iconData;
}

/// Presentation extension on [DndClassType] restoring Flutter UI types.
extension DndClassTypeUi on DndClassType {
  Color get primaryColor => primaryArgb.toColor();
  Color getLegibleColor(bool isDarkMode) =>
      legibleArgb(isDarkMode).toColor();
}

/// Presentation extension on [FeatCategory] restoring Flutter UI types.
extension FeatCategoryUi on FeatCategory {
  Color get primaryColor => primaryArgb.toColor();
  Color getLegibleColor(bool isDarkMode) =>
      legibleArgb(isDarkMode).toColor();
}

/// Presentation extension on [SpeciesType] restoring Flutter UI types.
extension SpeciesTypeUi on SpeciesType {
  Color get primaryColor => primaryArgb.toColor();
  Color getLegibleColor(bool isDarkMode) =>
      legibleArgb(isDarkMode).toColor();
}

/// Presentation extension on [GenericUiGlyphType] restoring Flutter UI types.
extension GenericUiGlyphTypeUi on GenericUiGlyphType {
  Color get primaryColor => primaryArgb.toColor();
  Color getLegibleColor(bool isDarkMode) =>
      legibleArgb(isDarkMode).toColor();
}

/// Presentation extension on [DamageAccent] restoring Flutter UI types.
extension DamageAccentUi on DamageAccent {
  Color get color => colorArgb.toColor();
}

/// Presentation extension on [ActionBadge] restoring Flutter UI types.
extension ActionBadgeUi on ActionBadge {
  Color get color => colorArgb.toColor();
}

/// Presentation extension on [GlyphRenderable] restoring Flutter UI types.
extension GlyphRenderableUi on GlyphRenderable {
  IconData? get fallbackIcon => fallbackIconKey?.iconData;
}

/// Color arithmetic and animation methods on [ActionTraitRing].
extension ActionTraitRingUi on ActionTraitRing {
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
}

