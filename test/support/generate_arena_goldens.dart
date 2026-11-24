import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/dm_screen_data.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/monster_codex_data.dart';

import 'arena_goldens_codec.dart';

/// Separate entry point for regenerating Step 4 arena golden fixtures.
/// Run only explicitly with:
///   UPDATE_ARENA_GOLDENS=1 flutter test test/support/generate_arena_goldens.dart
void main() {
  test('generate arena golden fixtures (explicit opt-in only)', () {
    if (Platform.environment['UPDATE_ARENA_GOLDENS'] != '1') {
      fail('Set UPDATE_ARENA_GOLDENS=1 to run the fixture generator.');
    }

    Directory(kArenaGoldensDir).createSync(recursive: true);
    const encoder = JsonEncoder.withIndent('  ');

    final presets = buildAllPresetMatchRecords();
    File(kPresetMatchesFile).writeAsStringSync('${encoder.convert(presets)}\n');

    final creatures = collectArenaCreatures();
    final opponent = selectFixedDuelOpponent(creatures);
    final duels = buildAllCreatureDuelRecords();
    File(kCreatureDuelsFile).writeAsStringSync('${encoder.convert(duels)}\n');

    final mc = buildAllMonteCarloRecords();
    File(kMonteCarloFile).writeAsStringSync('${encoder.convert(mc)}\n');

    final defenseRows = buildDamageDefenseTableRows();
    File(kDamageDefenseTableFile)
        .writeAsStringSync('${encoder.convert(defenseRows)}\n');

    final immuneCount =
        defenseRows.where((r) => r['colosseum'] == 'immune').length;
    final resistantCount = defenseRows
        .where((r) =>
            r['colosseum'] == 'resistant' ||
            r['colosseum'] == 'resistant+vulnerable')
        .length;
    final vulnerableCount = defenseRows
        .where((r) =>
            r['colosseum'] == 'vulnerable' ||
            r['colosseum'] == 'resistant+vulnerable')
        .length;

    final emptyNonNone = defenseRows
        .where((r) => r['damageType'] == '' && r['colosseum'] != 'none')
        .toList();
    final zzzNonNone = defenseRows
        .where((r) => r['damageType'] == 'zzz' && r['colosseum'] != 'none')
        .toList();

    // Check whether any bundled creature stat block produces an empty or unknown damageType.
    final knownTypes = kSrdDamageTypes.toSet();
    final unusualAttackTypes = <String>[];
    for (final m in MonsterCodexLibrary.allMonsters) {
      for (final ed in DmRulesEdition.values) {
        final sb = m.getStatBlock(ed);
        final dt = sb.damageType.toLowerCase().trim();
        if (dt.isEmpty || !knownTypes.contains(dt)) {
          unusualAttackTypes.add('${m.id} (${ed.name}) primary: "$dt"');
        }
        if (sb.secondaryDamageType != null) {
          final sdt = sb.secondaryDamageType!.toLowerCase().trim();
          if (sdt.isEmpty || !knownTypes.contains(sdt)) {
            unusualAttackTypes.add('${m.id} (${ed.name}) secondary: "$sdt"');
          }
        }
      }
    }

    stdout.writeln('Generated preset_matches.json: ${presets.length} matches');
    stdout.writeln(
        'Generated creature_duels.json: ${duels.length} creatures (opponent=${opponent.id}, CR ${opponent.challengeRating})');
    stdout.writeln('Generated monte_carlo.json: ${mc.length} presets');
    stdout.writeln(
        'Generated damage_defense_table.json: statBlocks=${MonsterCodexLibrary.allMonsters.length * 2}, '
        'rows=${defenseRows.length}, immune=$immuneCount, resistant=$resistantCount, vulnerable=$vulnerableCount');
    stdout.writeln('Empty-string non-none rows: ${emptyNonNone.length}');
    for (final r in emptyNonNone) {
      stdout.writeln(
          '  empty: ${r['monsterId']} (${r['edition']}) -> ${r['colosseum']}');
    }
    stdout.writeln('zzz non-none rows: ${zzzNonNone.length}');
    for (final r in zzzNonNone) {
      stdout.writeln(
          '  zzz: ${r['monsterId']} (${r['edition']}) -> ${r['colosseum']}');
    }
    stdout.writeln(
        'Bundled attacks with empty/unknown damageType: ${unusualAttackTypes.length}');
    for (final u in unusualAttackTypes) {
      stdout.writeln('  attack: $u');
    }
  });
}
