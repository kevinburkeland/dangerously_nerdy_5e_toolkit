import 'package:dangerously_nerdy_5e_toolkit/models/monster_codex_data.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/srd_summons/srd_summons_library.dart';
import 'package:flutter_test/flutter_test.dart';

/// Animate Objects constructs have fixed HP in SRD 5.1/5.2.1 with no hit dice
/// formula (`ao_tiny`, `ao_small`, `ao_medium`, `ao_large`, `ao_huge`).
const _kFixedHpStatBlockIds = <String>{
  'ao_tiny',
  'ao_small',
  'ao_medium',
  'ao_large',
  'ao_huge',
};

void main() {
  group('Fix 7.1 guard: bundled monsters and summon stat blocks state all in-scope facts', () {
    setUp(() {
      MonsterCodexLibrary.clearHomebrewMonsters();
    });

    test('every bundled monster stat block (2014 and 2024) has non-null F-16 facts', () {
      final monsters = MonsterCodexLibrary.allMonsters;
      expect(monsters, isNotEmpty);

      final missing = <String>[];
      for (final m in monsters) {
        for (final entry in [
          ('2014', m.statBlock2014),
          ('2024', m.statBlock2024),
        ]) {
          final ed = entry.$1;
          final sb = entry.$2;
          final Object? size = sb.sizeDisplay;
          final Object? type = sb.typeDisplay;
          final Object? alignment = sb.alignment;
          final Object? ac = sb.ac;
          final Object? maxHp = sb.maxHp;
          final Object? hitDice = sb.hitDice;
          final Object? cr = sb.crDisplay;
          if (size == null || (size is String && size.trim().isEmpty)) {
            missing.add('${m.id.slug} ($ed): sizeDisplay');
          }
          if (type == null || (type is String && type.trim().isEmpty)) {
            missing.add('${m.id.slug} ($ed): typeDisplay');
          }
          if (alignment == null || (alignment is String && alignment.trim().isEmpty)) {
            missing.add('${m.id.slug} ($ed): alignment');
          }
          if (ac == null) {
            missing.add('${m.id.slug} ($ed): ac');
          }
          if (maxHp == null) {
            missing.add('${m.id.slug} ($ed): maxHp');
          }
          if (!_kFixedHpStatBlockIds.contains(sb.id) &&
              (hitDice == null || (hitDice is String && hitDice.trim().isEmpty))) {
            missing.add('${m.id.slug} ($ed): hitDice');
          }
          if (cr == null || (cr is String && cr.trim().isEmpty)) {
            missing.add('${m.id.slug} ($ed): crDisplay');
          }
        }
      }

      expect(missing, isEmpty, reason: 'Bundled monsters missing F-16 facts:\n${missing.join('\n')}');
    });

    test('every bundled summon preset stat block has non-null F-16 facts', () {
      final presets = SrdSummonsLibrary.allPresets;
      expect(presets, isNotEmpty);

      final missing = <String>[];
      var checkedCount = 0;
      for (final preset in presets) {
        for (final sb in preset.statBlocks) {
          checkedCount++;
          final Object? size = sb.sizeDisplay;
          final Object? type = sb.typeDisplay;
          final Object? alignment = sb.alignment;
          final Object? ac = sb.ac;
          final Object? maxHp = sb.maxHp;
          final Object? hitDice = sb.hitDice;
          final Object? cr = sb.crDisplay;
          if (size == null || (size is String && size.trim().isEmpty)) {
            missing.add('${preset.id}/${sb.id}: sizeDisplay');
          }
          if (type == null || (type is String && type.trim().isEmpty)) {
            missing.add('${preset.id}/${sb.id}: typeDisplay');
          }
          if (alignment == null || (alignment is String && alignment.trim().isEmpty)) {
            missing.add('${preset.id}/${sb.id}: alignment');
          }
          if (ac == null) {
            missing.add('${preset.id}/${sb.id}: ac');
          }
          if (maxHp == null) {
            missing.add('${preset.id}/${sb.id}: maxHp');
          }
          if (!_kFixedHpStatBlockIds.contains(sb.id) &&
              (hitDice == null || (hitDice is String && hitDice.trim().isEmpty))) {
            missing.add('${preset.id}/${sb.id}: hitDice');
          }
          if (cr == null || (cr is String && cr.trim().isEmpty)) {
            missing.add('${preset.id}/${sb.id}: crDisplay');
          }
        }
      }

      expect(checkedCount, greaterThan(0));
      expect(missing, isEmpty, reason: 'Summon stat blocks missing F-16 facts:\n${missing.join('\n')}');
    });
  });
}
