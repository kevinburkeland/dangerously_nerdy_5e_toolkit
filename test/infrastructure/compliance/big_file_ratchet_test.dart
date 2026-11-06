import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

const int kMaxFileLineLimit = 1500;

/// Allowlist of files in `lib/` permitted to exceed 1,500 lines, with their
/// exact line count ceilings at this cleanup step.
///
/// Any file exceeding 1,500 lines not on this list fails.
/// Any listed file that grows past its ceiling fails.
/// Any listed file that shrinks fails until its ceiling is lowered.
/// Any listed file that drops to 1,500 or below must be removed from this list.
const Map<String, int> kBigFileAllowlist = {
  'lib/screens/character_builder_screen.dart': 6242,
  'lib/models/monster_codex/bestiary/bestiary_cr_nine_plus.dart': 5527,
  'lib/models/magic_items/items/wondrous_items.dart': 5117,
  'lib/models/monster_codex/bestiary/bestiary_cr_two_to_four.dart': 4712,
  'lib/models/monster_codex/bestiary/bestiary_cr_0_to_quarter.dart': 4227,
  'lib/widgets/character_builder/level_up_wizard_dialog.dart': 4217,
  'lib/services/persistence/homebrew_persistence_service.dart': 4108,
  'lib/services/rules/arena_combat_engine.dart': 4056,
  'lib/screens/glyph_showcase_screen.dart': 3685,
  'lib/models/monster_codex/bestiary/bestiary_cr_five_to_eight.dart': 3617,
  'lib/services/party/party_room_service.dart': 3606,
  'lib/models/monster_codex/bestiary/bestiary_cr_half_to_one.dart': 3561,
  'lib/widgets/party/campaign_dialogs.dart': 3233,
  'lib/models/magic_items/items/adventuring_gear.dart': 3227,
  'lib/models/magic_items/items/weapons.dart': 3075,
  'lib/models/dm_screen_data.dart': 2684,
  'lib/models/spells/level_2_spells.dart': 2576,
  'lib/screens/dm_dashboard_screen.dart': 2575,
  'lib/screens/party_room_screen.dart': 2401,
  'lib/models/tables/srd_loot_tables.dart': 2397,
  'lib/widgets/character_sheet/character_sheet_tabs.dart': 2394,
  'lib/models/spells/level_1_spells.dart': 2349,
  'lib/models/spells/level_3_spells.dart': 2215,
  'lib/services/ingestion/compendium_json_ingestion_pipeline.dart': 2198,
  'lib/widgets/glyphs/glyph_motifs.dart': 2144,
  'lib/models/dpr/dpr_models.dart': 2040,
  'lib/models/glyph_gallery_data.dart': 2019,
  'lib/services/rules/character_actions_resolver.dart': 1980,
  'lib/screens/homebrew_studio_screen.dart': 1912,
  'lib/models/spells/level_5_spells.dart': 1892,
  'lib/models/domain/homebrew_extended_entities.dart': 1846,
  'lib/providers/character_sheet_controller.dart': 1817,
  'lib/models/characters/srd_classes_library.dart': 1794,
  'lib/models/magic_items/items/armor_and_shields.dart': 1698,
  'lib/infrastructure/modules/dnd5e/ingestion/dnd5e_ingestion_capability.dart': 1667,
  'lib/models/spells/level_4_spells.dart': 1593,
  'lib/screens/landing_screen.dart': 1568,
  'lib/models/spells/level_6_spells.dart': 1536,
};

/// Counts the number of newline characters (`\n`, byte 0x0A) in bytes,
/// matching what `wc -l` prints.
int countNewlines(List<int> bytes) {
  int count = 0;
  for (int i = 0; i < bytes.length; i++) {
    if (bytes[i] == 10) {
      count++;
    }
  }
  return count;
}

/// Evaluates file size counts against the allowlist and ceiling rule.
List<String> evaluateFileSizes({
  required Map<String, int> fileCounts,
  required Map<String, int> allowlist,
  int limit = kMaxFileLineLimit,
}) {
  final errors = <String>[];

  // 1. Check all allowlist entries
  for (final entry in allowlist.entries) {
    final path = entry.key;
    final ceiling = entry.value;
    final actual = fileCounts[path];
    if (actual == null) {
      errors.add(
        'Allowlisted file "$path" does not exist in scanned files; remove it from allowlist.',
      );
      continue;
    }
    if (actual <= limit) {
      errors.add(
        'Allowlisted file "$path" has $actual lines, which is at or below the limit of $limit; remove it from the allowlist.',
      );
    } else if (actual > ceiling) {
      errors.add(
        'File "$path" has grown: actual $actual lines exceeds allowlist ceiling of $ceiling lines.',
      );
    } else if (actual < ceiling) {
      errors.add(
        'File "$path" has shrunk: actual $actual lines is lower than ceiling $ceiling. Lower the ceiling to $actual.',
      );
    }
  }

  // 2. Check all scanned files for unallowlisted files over limit
  for (final entry in fileCounts.entries) {
    final path = entry.key;
    final count = entry.value;
    if (count > limit && !allowlist.containsKey(path)) {
      errors.add(
        'File "$path" has $count lines, exceeding the limit of $limit, but is not on the allowlist.',
      );
    }
  }

  return errors;
}

void main() {
  group('Big-File Ratchet Controls', () {
    test('new 1501-line file fails', () {
      final errors = evaluateFileSizes(
        fileCounts: {'lib/new_big_file.dart': 1501},
        allowlist: {},
      );
      expect(errors, hasLength(1));
      expect(
        errors.first,
        contains('exceeding the limit of 1500, but is not on the allowlist'),
      );
    });

    test('listed file one line over ceiling fails', () {
      final errors = evaluateFileSizes(
        fileCounts: {'lib/big_file.dart': 2001},
        allowlist: {'lib/big_file.dart': 2000},
      );
      expect(errors, hasLength(1));
      expect(errors.first, contains('exceeds allowlist ceiling of 2000 lines'));
    });

    test('listed file one line under ceiling fails with lower the ceiling', () {
      final errors = evaluateFileSizes(
        fileCounts: {'lib/big_file.dart': 1999},
        allowlist: {'lib/big_file.dart': 2000},
      );
      expect(errors, hasLength(1));
      expect(errors.first, contains('Lower the ceiling to 1999'));
    });

    test('exact match passes', () {
      final errors = evaluateFileSizes(
        fileCounts: {'lib/big_file.dart': 2000},
        allowlist: {'lib/big_file.dart': 2000},
      );
      expect(errors, isEmpty);
    });

    test('listed file at or below 1500 lines fails with remove it from the allowlist', () {
      final errors = evaluateFileSizes(
        fileCounts: {'lib/big_file.dart': 1500},
        allowlist: {'lib/big_file.dart': 1500},
      );
      expect(errors, hasLength(1));
      expect(errors.first, contains('remove it from the allowlist'));
    });
  });

  group('Big-File Ratchet Verification', () {
    test('every .dart file in lib/ obeys 1,500-line ceiling and allowlist', () {
      final libDir = Directory('lib');
      expect(libDir.existsSync(), isTrue, reason: 'lib directory must exist');

      final dartFiles = libDir
          .listSync(recursive: true)
          .whereType<File>()
          .where((f) => f.path.endsWith('.dart'))
          .toList();

      expect(dartFiles, isNotEmpty, reason: 'Must find .dart files under lib/');

      final fileCounts = <String, int>{};
      for (final file in dartFiles) {
        final normalizedPath = file.path.replaceAll(r'\', '/');
        final bytes = file.readAsBytesSync();
        fileCounts[normalizedPath] = countNewlines(bytes);
      }

      final errors = evaluateFileSizes(
        fileCounts: fileCounts,
        allowlist: kBigFileAllowlist,
      );

      final totalLines =
          kBigFileAllowlist.values.fold<int>(0, (sum, lines) => sum + lines);
      stdout.writeln(
        'Big-file ratchet: ${kBigFileAllowlist.length} files on allowlist, $totalLines total lines',
      );

      expect(
        errors,
        isEmpty,
        reason:
            'Big-file ratchet violations found:\n${errors.map((e) => ' - $e').join('\n')}',
      );
    });
  });
}

