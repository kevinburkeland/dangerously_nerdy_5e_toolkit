import 'package:flutter/widgets.dart';
import '../../models/srd_summons/minion_stat_block.dart';
import '../../models/srd_summons/summon_preset.dart';
import '../../widgets/glyphs/dnd_glyph.dart';

extension SummonPresetGlyphUiExtension on SummonPreset {
  Widget buildGlyph({
    double size = 40,
    bool isDarkMode = true,
    Color? glyphColor,
  }) {
    if (category == SummonCategory.magicItem) {
      return DndGlyph.item(
        category: glyphItemCategory,
        rarity: glyphItemRarity,
        actionRings: glyphActionRings,
        glyphColor: glyphColor,
        size: size,
        isDarkMode: isDarkMode,
      );
    }
    return DndGlyph.spell(
      school: glyphSchool,
      level: glyphSpellLevel,
      actionRings: glyphActionRings,
      glyphColor: glyphColor,
      size: size,
      isDarkMode: isDarkMode,
    );
  }
}
