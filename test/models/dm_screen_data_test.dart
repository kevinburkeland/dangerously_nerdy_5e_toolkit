import 'package:flutter_test/flutter_test.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/dm_screen_data.dart';

void main() {
  group('DmScreenLibrary — Structural Integrity', () {
    test('allItems is non-empty and contains all 6 DmCategory values', () {
      const items = DmScreenLibrary.allItems;
      expect(items.isNotEmpty, isTrue);
      // Guard against list.clear mutation
      expect(items.length, greaterThanOrEqualTo(50));

      final categories = items.map((i) => i.category).toSet();
      expect(categories.contains(DmCategory.actions), isTrue);
      expect(categories.contains(DmCategory.conditions), isTrue);
      expect(categories.contains(DmCategory.environment), isTrue);
      expect(categories.contains(DmCategory.exploration), isTrue);
      expect(categories.contains(DmCategory.magicAndResting), isTrue);
      expect(categories.contains(DmCategory.tables), isTrue);
    });

    test('no duplicate item ids', () {
      const items = DmScreenLibrary.allItems;
      final ids = items.map((i) => i.id).toList();
      expect(ids.length, equals(ids.toSet().length),
          reason: 'Duplicate id in DmScreenLibrary.allItems');
    });

    test('every item has non-empty id, title, summary, and at least one tag', () {
      for (final item in DmScreenLibrary.allItems) {
        expect(item.id.isNotEmpty, isTrue,
            reason: 'Empty id in DmReferenceItem');
        expect(item.title.isNotEmpty, isTrue,
            reason: 'Empty title for item "${item.id}"');
        expect(item.summary.isNotEmpty, isTrue,
            reason: 'Empty summary for item "${item.id}"');
        expect(item.tags.isNotEmpty, isTrue,
            reason: 'No tags for item "${item.id}"');
      }
    });

    test('every item has non-empty rules2014 and rules2024', () {
      for (final item in DmScreenLibrary.allItems) {
        expect(item.rules2014.isNotEmpty, isTrue,
            reason: 'Empty rules2014 for item "${item.id}"');
        expect(item.rules2024.isNotEmpty, isTrue,
            reason: 'Empty rules2024 for item "${item.id}"');
      }
    });

    test('known core item ids are present', () {
      final ids = DmScreenLibrary.allItems.map((i) => i.id).toSet();
      expect(ids.contains('cond_exhaustion'), isTrue);
      expect(ids.contains('action_grapple_shove'), isTrue);
      expect(ids.contains('action_potions'), isTrue);
      expect(ids.contains('action_hide'), isTrue);
      expect(ids.contains('env_cover'), isTrue);
    });
  });

  group('DmReferenceItem.getRules() — Edition Routing', () {
    test('correctly returns 2014 vs 2024 rules for exhaustion', () {
      final exhaustion =
          DmScreenLibrary.allItems.firstWhere((i) => i.id == 'cond_exhaustion');
      expect(exhaustion.isChangedIn2024, isTrue);

      final rules2014 = exhaustion.getRules(DmRulesEdition.v2014);
      final rules2024 = exhaustion.getRules(DmRulesEdition.v2024);

      expect(
          rules2014
              .any((r) => r.contains('Level 1: Disadvantage on ability checks')),
          isTrue);
      expect(
          rules2024.any((r) =>
              r.contains('10 total levels') ||
              r.contains('Subtract 2 × your exhaustion level')),
          isTrue);
      // Rules must be genuinely different — kills getRules returning one branch always
      expect(rules2014, isNot(equals(rules2024)));
    });

    test('grapple/shove reflects 2014 Contested Check vs 2024 Saving Throw DC',
        () {
      final grapple = DmScreenLibrary.allItems
          .firstWhere((i) => i.id == 'action_grapple_shove');
      final r2014 = grapple.getRules(DmRulesEdition.v2014);
      final r2024 = grapple.getRules(DmRulesEdition.v2024);

      expect(r2014.any((r) => r.contains('Contested Check')), isTrue);
      expect(
          r2024.any((r) =>
              r.contains('Saving Throw DC') ||
              r.contains('DC = 8 + your Strength modifier')),
          isTrue);
    });

    test('potion drinking reflects Action (2014) vs Bonus Action (2024)', () {
      final potion =
          DmScreenLibrary.allItems.firstWhere((i) => i.id == 'action_potions');
      expect(potion.getRules(DmRulesEdition.v2014).any((r) => r.contains('1 Action')),
          isTrue);
      expect(
          potion
              .getRules(DmRulesEdition.v2024)
              .any((r) => r.contains('1 Bonus Action')),
          isTrue);
    });
  });

  group('DmReferenceItem.getTitle() — Null-Branch Fallback (mutation guards)', () {
    // getTitle() has the same && → || mutation risk as SpellItem.getName():
    //   if (edition == v2014 && title2014 != null) return title2014!;
    //   if (edition == v2024 && title2024 != null) return title2024!;
    // Without null-branch tests the mutation tool can flip && to || undetected.

    test('getTitle returns base title for all items where title2014 is null and edition is v2014',
        () {
      for (final item in DmScreenLibrary.allItems) {
        if (item.title2014 == null) {
          expect(item.getTitle(DmRulesEdition.v2014), equals(item.title),
              reason:
                  'Item "${item.id}" has no title2014 but getTitle(v2014) != base title');
        }
      }
    });

    test('getTitle returns base title for all items where title2024 is null and edition is v2024',
        () {
      for (final item in DmScreenLibrary.allItems) {
        if (item.title2024 == null) {
          expect(item.getTitle(DmRulesEdition.v2024), equals(item.title),
              reason:
                  'Item "${item.id}" has no title2024 but getTitle(v2024) != base title');
        }
      }
    });

    test('getTitle returns the correct override when both title2014 and title2024 exist',
        () {
      // attack action: title2014='Attack', title2024='Attack & Weapon Swapping'
      final attack =
          DmScreenLibrary.allItems.firstWhere((i) => i.id == 'action_attack');
      expect(attack.title2014, isNotNull);
      expect(attack.title2024, isNotNull);
      expect(attack.getTitle(DmRulesEdition.v2014), equals(attack.title2014));
      expect(attack.getTitle(DmRulesEdition.v2024), equals(attack.title2024));
      // Override must be different from base title
      expect(attack.getTitle(DmRulesEdition.v2014), isNot(equals(attack.title)));
    });

    test('getTitle never returns empty string for any item and edition', () {
      for (final item in DmScreenLibrary.allItems) {
        expect(item.getTitle(DmRulesEdition.v2014).isNotEmpty, isTrue,
            reason: 'Empty getTitle(v2014) for item "${item.id}"');
        expect(item.getTitle(DmRulesEdition.v2024).isNotEmpty, isTrue,
            reason: 'Empty getTitle(v2024) for item "${item.id}"');
      }
    });
  });

  group('DmReferenceItem.matches() — Boolean Logic & Operator Parsing', () {
    test('matches returns true for empty query (show-all shortcut)', () {
      for (final item in DmScreenLibrary.allItems) {
        expect(item.matches(''), isTrue,
            reason: 'Item "${item.id}" should match empty query');
      }
    });

    test('matches returns true when query matches title', () {
      final coverItem =
          DmScreenLibrary.allItems.firstWhere((i) => i.id == 'env_cover');
      expect(coverItem.matches('cover'), isTrue);
      expect(coverItem.matches('Cover'), isTrue); // case-insensitive
    });

    test('matches returns true when query matches summary', () {
      const items = DmScreenLibrary.allItems;
      final stealthMatches = items.where((i) => i.matches('stealth')).toList();
      expect(stealthMatches.any((i) => i.id == 'action_hide'), isTrue);
    });

    test('matches returns false for nonsense query', () {
      const garbage = 'xyzzy_impossible_query_42!';
      for (final item in DmScreenLibrary.allItems) {
        expect(item.matches(garbage), isFalse,
            reason: 'Item "${item.id}" should not match "$garbage"');
      }
    });

    test('tag: prefix matches items with that tag and rejects items without it',
        () {
      // Use 'cover_rule' — a tag that appears verbatim in exactly the cover items
      // and does not appear as a substring in any other items' tags.
      final withCoverRule = DmScreenLibrary.allItems
          .where((i) => i.tags.any((t) => t.contains('cover_rule')))
          .toList();
      final withoutCoverRule = DmScreenLibrary.allItems
          .where((i) => !i.tags.any((t) => t.contains('cover_rule')))
          .toList();

      expect(withCoverRule.isNotEmpty, isTrue,
          reason: 'Expected some cover_rule-tagged items');

      for (final item in withCoverRule) {
        expect(item.matches('tag:cover_rule'), isTrue,
            reason: '${item.id} has cover_rule tag, should match');
      }
      for (final item in withoutCoverRule) {
        expect(item.matches('tag:cover_rule'), isFalse,
            reason: '${item.id} lacks cover_rule tag, should not match');
      }
    });

    test('category: prefix matches items in that category only', () {
      final conditionItems = DmScreenLibrary.conditions;
      for (final item in conditionItems) {
        expect(item.matches('category:conditions'), isTrue,
            reason:
                '${item.id} is a condition, should match category:conditions');
      }
      final actionItems = DmScreenLibrary.allItems
          .where((i) => i.category == DmCategory.actions)
          .toList();
      for (final item in actionItems) {
        expect(item.matches('category:conditions'), isFalse,
            reason:
                '${item.id} is an action, should not match category:conditions');
      }
    });

    test('edition:diff matches only isChangedIn2024 items', () {
      final changedItems =
          DmScreenLibrary.allItems.where((i) => i.isChangedIn2024).toList();
      final unchangedItems =
          DmScreenLibrary.allItems.where((i) => !i.isChangedIn2024).toList();

      expect(changedItems.isNotEmpty, isTrue,
          reason: 'Expected some changed-in-2024 items');

      for (final item in changedItems) {
        expect(item.matches('edition:diff'), isTrue,
            reason: '${item.id} changed in 2024, should match edition:diff');
      }
      for (final item in unchangedItems) {
        expect(item.matches('edition:diff'), isFalse,
            reason: '${item.id} not changed, should not match edition:diff');
      }
    });
  });

  group('DmScreenLibrary — Filter Helpers', () {
    test('conditions getter returns only DmCategory.conditions items', () {
      final conds = DmScreenLibrary.conditions;
      expect(conds.isNotEmpty, isTrue);
      for (final c in conds) {
        expect(c.category, equals(DmCategory.conditions));
      }
    });

    test('reactions getter returns only items tagged "reaction"', () {
      final reactions = DmScreenLibrary.reactions;
      expect(reactions.isNotEmpty, isTrue);
      for (final r in reactions) {
        expect(r.tags.contains('reaction'), isTrue);
      }
    });

    test('coverRules getter returns only items tagged "cover_rule"', () {
      final cover = DmScreenLibrary.coverRules;
      expect(cover.isNotEmpty, isTrue);
      for (final c in cover) {
        expect(c.tags.contains('cover_rule'), isTrue);
      }
    });

    test('standardActions(v2014) includes attack item', () {
      final actions2014 =
          DmScreenLibrary.standardActions(DmRulesEdition.v2014);
      expect(actions2014.isNotEmpty, isTrue);
      expect(actions2014.any((i) => i.id == 'action_attack'), isTrue);
    });

    test('standardActions(v2024) includes attack item', () {
      final actions2024 =
          DmScreenLibrary.standardActions(DmRulesEdition.v2024);
      expect(actions2024.any((i) => i.id == 'action_attack'), isTrue);
    });

    test('potion is in standardActions for 2014 but bonusActions for 2024', () {
      final std2014 = DmScreenLibrary.standardActions(DmRulesEdition.v2014);
      final bonus2024 = DmScreenLibrary.bonusActions(DmRulesEdition.v2024);
      final bonus2014 = DmScreenLibrary.bonusActions(DmRulesEdition.v2014);
      final std2024 = DmScreenLibrary.standardActions(DmRulesEdition.v2024);

      expect(std2014.any((i) => i.id == 'action_potions'), isTrue,
          reason: 'Potions should be a standard action in 2014');
      expect(bonus2024.any((i) => i.id == 'action_potions'), isTrue,
          reason: 'Potions should be a bonus action in 2024');

      // Confirm potions are NOT in the wrong lists
      expect(bonus2014.any((i) => i.id == 'action_potions'), isFalse,
          reason: 'Potions should NOT be a bonus action in 2014');
      expect(std2024.any((i) => i.id == 'action_potions'), isFalse,
          reason: 'Potions should NOT be a standard action in 2024');
    });
  });

  group('DmCategory enum — Label Completeness', () {
    test('all DmCategory values have non-empty labels', () {
      for (final cat in DmCategory.values) {
        expect(cat.label.isNotEmpty, isTrue,
            reason: 'Empty label for DmCategory.${cat.name}');
      }
    });
  });

  group('DmRulesEdition enum — Label Completeness', () {
    test('all DmRulesEdition values have non-empty labels', () {
      for (final ed in DmRulesEdition.values) {
        expect(ed.label.isNotEmpty, isTrue,
            reason: 'Empty label for DmRulesEdition.${ed.name}');
      }
    });

    test('v2014 label is "2014" and v2024 label is "2024"', () {
      expect(DmRulesEdition.v2014.label, '2014');
      expect(DmRulesEdition.v2024.label, '2024');
    });
  });
}
