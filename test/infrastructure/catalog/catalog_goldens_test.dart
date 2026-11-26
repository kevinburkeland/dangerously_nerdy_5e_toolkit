import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import '../../support/catalog_golden_serializer.dart';
import '../../support/step6_normalizer.dart';

const _spellCatalogPath = 'test/fixtures/catalog_goldens/spell_catalog_golden.json';
const _itemCatalogPath = 'test/fixtures/catalog_goldens/item_catalog_golden.json';
const _lookupsPath = 'test/fixtures/catalog_goldens/catalog_lookups_golden.json';
const _rulesViewPath = 'test/fixtures/catalog_goldens/item_rules_view_golden.json';

Map<String, dynamic> _readFixture(String path) {
  final file = File(path);
  expect(
    file.existsSync(),
    isTrue,
    reason: 'Missing catalog golden fixture $path. Generate explicitly with UPDATE_STEP4_FIXTURES=1.',
  );
  return jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
}

void main() {
  group('Fix 4.1: Bundled spell and item catalog goldens', () {
    test('bundled spell catalog matches golden field by field in both editions', () {
      final expected = _readFixture(_spellCatalogPath);
      final actual = jsonDecode(jsonEncode(buildSpellCatalogGoldenMap())) as Map<String, dynamic>;
      expect(actual['count'], equals(expected['count']));

      final expSpells = expected['spells'] as Map<String, dynamic>;
      final actSpells = actual['spells'] as Map<String, dynamic>;
      expect(actSpells.keys.toList(), equals(expSpells.keys.toList()));

      for (final id in expSpells.keys) {
        final diff = firstJsonDiff(expSpells[id], actSpells[id], 'spell.$id');
        expect(diff, isNull, reason: 'Spell catalog golden mismatch at $id: $diff');
      }
    });

    test('bundled item catalog matches golden field by field in both editions', () {
      final expected = _readFixture(_itemCatalogPath);
      final actual = jsonDecode(jsonEncode(buildItemCatalogGoldenMap())) as Map<String, dynamic>;
      expect(actual['count'], equals(expected['count']));

      final expItems = expected['items'] as Map<String, dynamic>;
      final actItems = actual['items'] as Map<String, dynamic>;
      expect(actItems.keys.toList(), equals(expItems.keys.toList()));

      for (final id in expItems.keys) {
        final diff = firstJsonDiff(expItems[id], actItems[id], 'item.$id');
        expect(diff, isNull, reason: 'Item catalog golden mismatch at $id: $diff');
      }
    });

    test('spellbook and item library lookups match golden in exact order', () {
      final expected = _readFixture(_lookupsPath);
      final actual = jsonDecode(jsonEncode(buildCatalogLookupsGoldenMap())) as Map<String, dynamic>;
      final diff = firstJsonDiff(expected, actual, 'lookups');
      expect(diff, isNull, reason: 'Catalog lookups golden mismatch: $diff');
    });

    test('bundled item rules view (SrdEquipmentLibrary.allEquipmentItems) matches golden', () {
      final expected = _readFixture(_rulesViewPath);
      final actual = jsonDecode(jsonEncode(buildItemRulesViewGoldenMap())) as Map<String, dynamic>;
      expect(actual['count'], equals(expected['count']));

      final expItems = expected['items'] as Map<String, dynamic>;
      final actItems = actual['items'] as Map<String, dynamic>;
      expect(actItems.keys.toList(), equals(expItems.keys.toList()));

      for (final id in expItems.keys) {
        final diff = firstJsonDiff(expItems[id], actItems[id], 'rulesView.$id');
        expect(diff, isNull, reason: 'Item rules-view golden mismatch at $id: $diff');
      }
    });
  });
}
