import 'package:flutter_test/flutter_test.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/magic_items/magic_item_library.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/tables/srd_tables_library.dart';

bool _labelMatchesItemName(String label, MagicItem item) {
  final validNames = <String>{
    item.name,
    if (item.name2014 != null) item.name2014!,
    if (item.name2024 != null) item.name2024!,
  };

  for (final name in validNames) {
    if (label == name) return true;
    // Allow leading quantity/count prefix (e.g. "2x Potion of Healing", "1d4 Potion of Healing")
    if (RegExp('^(\\d+d\\d+(?:\\s*[+-]\\s*\\d+)?|\\d+x?)\\s+${RegExp.escape(name)}\$')
        .hasMatch(label)) {
      return true;
    }
    // Allow trailing parenthetical variant/quantity (e.g. "Spell Scroll (1st Level)", "Feather Token (Tree)")
    if (RegExp('^${RegExp.escape(name)}\\s*\\([^)]+\\)\$').hasMatch(label)) {
      return true;
    }
  }
  return false;
}

void main() {
  test('every itemRefId in bundled tables resolves to a bundled MagicItem with matching label', () {
    final baseItemsById = <String, MagicItem>{
      for (final item in MagicItemLibrary.baseItems) item.id: item,
    };

    final unresolvedExact = <String>[];
    final unresolvedEvenWithPrefix = <String>{};
    final labelMismatches = <String>[];

    for (final table in SrdTablesLibrary.srdTables) {
      for (final entry in table.entries) {
        final refId = entry.itemRefId;
        if (refId == null) continue;

        final exactItem = baseItemsById[refId];
        if (exactItem == null) {
          unresolvedExact.add('${table.id} [${entry.minRoll}-${entry.maxRoll}]: $refId (label: "${entry.label}")');
          if (!baseItemsById.containsKey('item_$refId')) {
            unresolvedEvenWithPrefix.add(refId);
          }
          continue;
        }

        if (!_labelMatchesItemName(entry.label, exactItem)) {
          labelMismatches.add(
            '${table.id} [${entry.minRoll}-${entry.maxRoll}]: ref=$refId label="${entry.label}" != item.name="${exactItem.name}"',
          );
        }
      }
    }

    expect(
      unresolvedExact,
      isEmpty,
      reason: 'Unresolved exact itemRefIds (${unresolvedExact.length}; '
          '${unresolvedEvenWithPrefix.length} unresolved even with item_ prefix: '
          '${(unresolvedEvenWithPrefix.toList()..sort()).join(', ')}):\n'
          '${unresolvedExact.join('\n')}',
    );
    expect(
      labelMismatches,
      isEmpty,
      reason: 'Label mismatches (${labelMismatches.length}):\n'
          '${labelMismatches.join('\n')}',
    );
  });
}
