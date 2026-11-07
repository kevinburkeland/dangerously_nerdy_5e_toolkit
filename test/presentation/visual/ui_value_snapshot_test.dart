import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:dangerously_nerdy_5e_toolkit/models/app_settings.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/arena/arena_simulation_models.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/characters/srd_equipment_library.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/dm_screen_data.dart'
    show DmRulesEdition;
import 'package:dangerously_nerdy_5e_toolkit/models/glyph_gallery_data.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/magic_items/magic_item_data.dart'
    show CurrencyCoinType, getCurrencyColor;
import 'package:dangerously_nerdy_5e_toolkit/models/magic_items/magic_item_library.dart'
    show MagicItemLibrary;
import 'package:dangerously_nerdy_5e_toolkit/models/monster_codex_data.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/spellbook_data.dart'
    show SpellClass, SpellClassUiExtension;
import 'package:dangerously_nerdy_5e_toolkit/models/srd_summons/srd_summons_library.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/tables/rollable_table.dart';
import 'package:dangerously_nerdy_5e_toolkit/widgets/glyphs/glyph_tokens.dart';

String _formatColor(Color color) {
  return '0x${color.toARGB32().toRadixString(16).padLeft(8, '0').toUpperCase()}';
}

String _formatIcon(IconData icon) {
  return 'U+${icon.codePoint.toRadixString(16).toUpperCase()} ${icon.fontFamily} ${icon.fontPackage} ${icon.matchTextDirection}';
}

String _sourceFileForKey(String key) {
  if (key.startsWith('SpellSchool.') ||
      key.startsWith('CreatureType.') ||
      key.startsWith('ItemCategory.') ||
      key.startsWith('ItemRarity.') ||
      key.startsWith('GlyphCategory.') ||
      key.startsWith('DndClassType.') ||
      key.startsWith('FeatCategory.') ||
      key.startsWith('SpeciesType.') ||
      key.startsWith('GenericUiGlyphType.') ||
      key.startsWith('DamageAccent.') ||
      key.startsWith('ActionBadge.')) {
    return 'lib/widgets/glyphs/glyph_tokens.dart';
  }
  if (key.startsWith('FantasyAccent.')) {
    return 'lib/models/app_settings.dart';
  }
  if (key.startsWith('ArenaEnvironment.')) {
    return 'lib/models/arena/arena_simulation_models.dart';
  }
  if (key.startsWith('equipment_pack:')) {
    return 'lib/models/characters/srd_equipment_library.dart';
  }
  if (key.startsWith('glyph_gallery:')) {
    return 'lib/models/glyph_gallery_data.dart';
  }
  if (key.startsWith('magic_item:') ||
      key.startsWith('CurrencyCoinType.') ||
      key.startsWith('getCurrencyColor(')) {
    return 'lib/models/magic_items/magic_item_data.dart';
  }
  if (key.startsWith('monster:') || key.startsWith('MonsterSortMode.')) {
    return 'lib/models/monster_codex_data.dart';
  }
  if (key.startsWith('SpellClass.')) {
    return 'lib/models/spellbook_data.dart';
  }
  if (key.startsWith('summons_preset:')) {
    return 'lib/models/srd_summons/minion_stat_block.dart';
  }
  if (key.startsWith('TableCategory.')) {
    return 'lib/models/tables/rollable_table.dart';
  }
  return 'unknown';
}

void main() {
  test('UI value snapshot characterization matches fixture exactly', () {
    final actual = <String, String>{};

    // 1. SpellSchool in glyph_tokens.dart
    for (final s in SpellSchool.values) {
      actual['SpellSchool.${s.name}.primaryColor'] = _formatColor(s.primaryColor);
      actual['SpellSchool.${s.name}.lightFillTint'] = _formatColor(s.lightFillTint);
      actual['SpellSchool.${s.name}.darkFillTint'] = _formatColor(s.darkFillTint);
      actual['SpellSchool.${s.name}.color'] = _formatColor(s.color);
      actual['SpellSchool.${s.name}.icon'] = _formatIcon(s.icon);
      actual['SpellSchool.${s.name}.getLegibleColor(true)'] =
          _formatColor(s.getLegibleColor(true));
      actual['SpellSchool.${s.name}.getLegibleColor(false)'] =
          _formatColor(s.getLegibleColor(false));
    }

    // 2. CreatureType in glyph_tokens.dart
    for (final c in CreatureType.values) {
      actual['CreatureType.${c.name}.primaryColor'] = _formatColor(c.primaryColor);
      actual['CreatureType.${c.name}.lightFillTint'] = _formatColor(c.lightFillTint);
      actual['CreatureType.${c.name}.darkFillTint'] = _formatColor(c.darkFillTint);
      actual['CreatureType.${c.name}.getLegibleColor(true)'] =
          _formatColor(c.getLegibleColor(true));
      actual['CreatureType.${c.name}.getLegibleColor(false)'] =
          _formatColor(c.getLegibleColor(false));
    }

    // 3. ItemCategory in glyph_tokens.dart
    for (final c in ItemCategory.values) {
      actual['ItemCategory.${c.name}.primaryColor'] = _formatColor(c.primaryColor);
      actual['ItemCategory.${c.name}.lightFillTint'] = _formatColor(c.lightFillTint);
      actual['ItemCategory.${c.name}.darkFillTint'] = _formatColor(c.darkFillTint);
      actual['ItemCategory.${c.name}.icon'] = _formatIcon(c.icon);
      actual['ItemCategory.${c.name}.getLegibleColor(true)'] =
          _formatColor(c.getLegibleColor(true));
      actual['ItemCategory.${c.name}.getLegibleColor(false)'] =
          _formatColor(c.getLegibleColor(false));
    }

    // 4. ItemRarity in glyph_tokens.dart
    for (final r in ItemRarity.values) {
      actual['ItemRarity.${r.name}.color'] = _formatColor(r.color);
      actual['ItemRarity.${r.name}.getLegibleColor(true)'] =
          _formatColor(r.getLegibleColor(true));
      actual['ItemRarity.${r.name}.getLegibleColor(false)'] =
          _formatColor(r.getLegibleColor(false));
    }

    // 5. GlyphCategory in glyph_tokens.dart
    for (final c in GlyphCategory.values) {
      actual['GlyphCategory.${c.name}.icon'] = _formatIcon(c.icon);
    }

    // 6. DndClassType in glyph_tokens.dart
    for (final c in DndClassType.values) {
      actual['DndClassType.${c.name}.primaryColor'] = _formatColor(c.primaryColor);
      actual['DndClassType.${c.name}.getLegibleColor(true)'] =
          _formatColor(c.getLegibleColor(true));
      actual['DndClassType.${c.name}.getLegibleColor(false)'] =
          _formatColor(c.getLegibleColor(false));
    }

    // 7. FeatCategory in glyph_tokens.dart
    for (final f in FeatCategory.values) {
      actual['FeatCategory.${f.name}.primaryColor'] = _formatColor(f.primaryColor);
      actual['FeatCategory.${f.name}.getLegibleColor(true)'] =
          _formatColor(f.getLegibleColor(true));
      actual['FeatCategory.${f.name}.getLegibleColor(false)'] =
          _formatColor(f.getLegibleColor(false));
    }

    // 8. SpeciesType in glyph_tokens.dart
    for (final s in SpeciesType.values) {
      actual['SpeciesType.${s.name}.primaryColor'] = _formatColor(s.primaryColor);
      actual['SpeciesType.${s.name}.getLegibleColor(true)'] =
          _formatColor(s.getLegibleColor(true));
      actual['SpeciesType.${s.name}.getLegibleColor(false)'] =
          _formatColor(s.getLegibleColor(false));
    }

    // 9. GenericUiGlyphType in glyph_tokens.dart
    for (final g in GenericUiGlyphType.values) {
      actual['GenericUiGlyphType.${g.name}.primaryColor'] =
          _formatColor(g.primaryColor);
      actual['GenericUiGlyphType.${g.name}.getLegibleColor(true)'] =
          _formatColor(g.getLegibleColor(true));
      actual['GenericUiGlyphType.${g.name}.getLegibleColor(false)'] =
          _formatColor(g.getLegibleColor(false));
    }

    // 10. DamageAccent in glyph_tokens.dart
    for (final d in DamageAccent.values) {
      actual['DamageAccent.${d.name}.color'] = _formatColor(d.color);
    }

    // 11. ActionBadge in glyph_tokens.dart
    for (final a in ActionBadge.values) {
      actual['ActionBadge.${a.name}.color'] = _formatColor(a.color);
    }

    // 12. FantasyAccent in app_settings.dart
    for (final f in FantasyAccent.values) {
      actual['FantasyAccent.${f.name}.primary'] = _formatColor(f.primary);
      actual['FantasyAccent.${f.name}.accent'] = _formatColor(f.accent);
      actual['FantasyAccent.${f.name}.lightPrimary'] = _formatColor(f.lightPrimary);
      actual['FantasyAccent.${f.name}.lightAccent'] = _formatColor(f.lightAccent);
      actual['FantasyAccent.${f.name}.getPrimary(true)'] =
          _formatColor(f.getPrimary(true));
      actual['FantasyAccent.${f.name}.getPrimary(false)'] =
          _formatColor(f.getPrimary(false));
      actual['FantasyAccent.${f.name}.getAccent(true)'] =
          _formatColor(f.getAccent(true));
      actual['FantasyAccent.${f.name}.getAccent(false)'] =
          _formatColor(f.getAccent(false));
    }

    // 13. ArenaEnvironment in arena_simulation_models.dart
    for (final e in ArenaEnvironment.values) {
      actual['ArenaEnvironment.${e.name}.icon'] = _formatIcon(e.icon);
      actual['ArenaEnvironment.${e.name}.themeColor'] = _formatColor(e.themeColor);
    }

    // 14. SrdEquipmentLibrary.allPackages in srd_equipment_library.dart
    for (final p in SrdEquipmentLibrary.allPackages) {
      actual['equipment_pack:${p.id}.icon'] = _formatIcon(p.icon);
    }

    // 15. GlyphGalleryData in glyph_gallery_data.dart
    for (final s in GlyphGalleryData.allSpells) {
      if (s.fallbackIcon != null) {
        actual['glyph_gallery:spell:${s.glyphId}.fallbackIcon'] =
            _formatIcon(s.fallbackIcon!);
      }
    }
    for (final c in GlyphGalleryData.allCreatures) {
      if (c.fallbackIcon != null) {
        actual['glyph_gallery:creature:${c.glyphId}.fallbackIcon'] =
            _formatIcon(c.fallbackIcon!);
      }
    }
    for (final i in GlyphGalleryData.allItems) {
      if (i.fallbackIcon != null) {
        actual['glyph_gallery:item:${i.glyphId}.fallbackIcon'] =
            _formatIcon(i.fallbackIcon!);
      }
    }
    for (final f in GlyphGalleryData.allFeats) {
      if (f.fallbackIcon != null) {
        actual['glyph_gallery:feat:${f.glyphId}.fallbackIcon'] =
            _formatIcon(f.fallbackIcon!);
      }
    }
    for (final c in GlyphGalleryData.allClasses) {
      if (c.fallbackIcon != null) {
        actual['glyph_gallery:class:${c.glyphId}.fallbackIcon'] =
            _formatIcon(c.fallbackIcon!);
      }
    }
    for (final s in GlyphGalleryData.allSpecies) {
      if (s.fallbackIcon != null) {
        actual['glyph_gallery:species:${s.glyphId}.fallbackIcon'] =
            _formatIcon(s.fallbackIcon!);
      }
    }
    for (final g in GlyphGalleryData.allGenericUi) {
      if (g.fallbackIcon != null) {
        actual['glyph_gallery:generic:${g.glyphId}.fallbackIcon'] =
            _formatIcon(g.fallbackIcon!);
      }
    }

    // 16. MagicItemLibrary.allItems in magic_item_library.dart
    final prices = <String>{'1 cp', '1 sp', '1 ep', '1 gp', '1 pp'};
    for (final item in MagicItemLibrary.allItems) {
      if (item.glyphColor != null) {
        actual['magic_item:${item.id}.glyphColor'] =
            _formatColor(item.glyphColor!);
      }
      if (item.effectiveGlyphColor != null) {
        actual['magic_item:${item.id}.effectiveGlyphColor'] =
            _formatColor(item.effectiveGlyphColor!);
      }
      if (item.cost != null && item.cost!.isNotEmpty) {
        prices.add(item.cost!);
      }
      if (item.cost2014 != null && item.cost2014!.isNotEmpty) {
        prices.add(item.cost2014!);
      }
      if (item.cost2024 != null && item.cost2024!.isNotEmpty) {
        prices.add(item.cost2024!);
      }
      final p14 = item.getEffectivePrice(DmRulesEdition.v2014);
      if (p14.isNotEmpty) prices.add(p14);
      final p24 = item.getEffectivePrice(DmRulesEdition.v2024);
      if (p24.isNotEmpty) prices.add(p24);
    }

    // 17. CurrencyCoinType in magic_item_data.dart
    for (final c in CurrencyCoinType.values) {
      actual['CurrencyCoinType.${c.name}.darkColor'] = _formatColor(c.darkColor);
      actual['CurrencyCoinType.${c.name}.lightColor'] = _formatColor(c.lightColor);
      actual['CurrencyCoinType.${c.name}.getLegibleColor(true)'] =
          _formatColor(c.getLegibleColor(true));
      actual['CurrencyCoinType.${c.name}.getLegibleColor(false)'] =
          _formatColor(c.getLegibleColor(false));
    }

    // 18. getCurrencyColor on all distinct prices
    final sortedPrices = prices.toList()..sort();
    for (final p in sortedPrices) {
      actual['getCurrencyColor($p, true)'] =
          _formatColor(getCurrencyColor(p, true));
      actual['getCurrencyColor($p, false)'] =
          _formatColor(getCurrencyColor(p, false));
    }

    // 19. MonsterCodexLibrary.allMonsters in monster_codex_data.dart
    for (final m in MonsterCodexLibrary.allMonsters) {
      actual['monster:${m.id}.statBlock2014.accentColor'] =
          _formatColor(m.statBlock2014.accentColor);
      actual['monster:${m.id}.statBlock2024.accentColor'] =
          _formatColor(m.statBlock2024.accentColor);
    }

    // 20. MonsterSortMode in monster_codex_data.dart
    for (final s in MonsterSortMode.values) {
      actual['MonsterSortMode.${s.name}.icon'] = _formatIcon(s.icon);
    }

    // 21. SpellClassUiExtension in spellbook_data.dart
    for (final c in SpellClass.values) {
      actual['SpellClass.${c.name}.icon'] = _formatIcon(c.icon);
    }

    // 22. SrdSummonsLibrary presets in srd_summons/
    for (final p in SrdSummonsLibrary.allPresets) {
      for (final sb in p.effectiveStatBlocks) {
        actual['summons_preset:${p.id}:${sb.id}.accentColor'] =
            _formatColor(sb.accentColor);
      }
    }

    // 23. TableCategory in tables/rollable_table.dart
    for (final c in TableCategory.values) {
      actual['TableCategory.${c.name}.icon'] = _formatIcon(c.icon);
      actual['TableCategory.${c.name}.accentColor'] = _formatColor(c.accentColor);
    }

    // Load fixture
    final fixtureFile = File('test/fixtures/ui_values/ui_value_snapshot.json');
    expect(fixtureFile.existsSync(), isTrue,
        reason: 'Snapshot fixture must exist at test/fixtures/ui_values/ui_value_snapshot.json');
    final expectedRaw = jsonDecode(fixtureFile.readAsStringSync()) as Map<String, dynamic>;
    final expected = expectedRaw.map((k, v) => MapEntry(k, v as String));

    // Compare
    final missingKeys = <String>[];
    final extraKeys = <String>[];
    final changedKeys = <String>[];
    final differences = <String>[];

    for (final entry in expected.entries) {
      if (!actual.containsKey(entry.key)) {
        missingKeys.add(entry.key);
      } else if (actual[entry.key] != entry.value) {
        changedKeys.add(entry.key);
        if (differences.length < 20) {
          differences.add('Diff on ${entry.key}: expected="${entry.value}", actual="${actual[entry.key]}"');
        }
      }
    }
    for (final key in actual.keys) {
      if (!expected.containsKey(key)) {
        extraKeys.add(key);
        if (differences.length < 20) {
          differences.add('Extra key in actual: $key = "${actual[key]}"');
        }
      }
    }

    // Print breakdown per source file
    final countsByFile = <String, int>{};
    for (final key in actual.keys) {
      final file = _sourceFileForKey(key);
      countsByFile[file] = (countsByFile[file] ?? 0) + 1;
    }
    stdout.writeln('UI Value Snapshot breakdown by source file:');
    final sortedFiles = countsByFile.keys.toList()..sort();
    for (final file in sortedFiles) {
      stdout.writeln('  $file: ${countsByFile[file]} entries');
    }
    stdout.writeln('Total entries: ${actual.length}');

    if (differences.isNotEmpty) {
      final msg = StringBuffer('Snapshot mismatch:\n')
        ..writeln('Missing keys count: ${missingKeys.length}')
        ..writeln('Extra keys count: ${extraKeys.length}')
        ..writeln('Changed keys count: ${changedKeys.length}')
        ..writeln('First ${differences.length} differences:')
        ..writeln(differences.join('\n'));
      fail(msg.toString());
    }

    expect(actual.length, equals(expected.length));
  });
}
