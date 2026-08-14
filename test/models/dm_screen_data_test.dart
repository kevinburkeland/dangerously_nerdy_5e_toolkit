import 'package:flutter_test/flutter_test.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/dm_screen_data.dart';

void main() {
  group('DmScreenLibrary & DmReferenceItem Tests', () {
    test('contains comprehensive items across all categories', () {
      const items = DmScreenLibrary.allItems;
      expect(items.isNotEmpty, isTrue);

      final categories = items.map((i) => i.category).toSet();
      expect(categories.contains(DmCategory.actions), isTrue);
      expect(categories.contains(DmCategory.conditions), isTrue);
      expect(categories.contains(DmCategory.environment), isTrue);
      expect(categories.contains(DmCategory.exploration), isTrue);
      expect(categories.contains(DmCategory.magicAndResting), isTrue);
      expect(categories.contains(DmCategory.tables), isTrue);
    });

    test('correctly returns 2014 vs 2024 rules per item', () {
      final exhaustion = DmScreenLibrary.allItems.firstWhere((i) => i.id == 'cond_exhaustion');
      expect(exhaustion.isChangedIn2024, isTrue);

      final rules2014 = exhaustion.getRules(DmRulesEdition.v2014);
      final rules2024 = exhaustion.getRules(DmRulesEdition.v2024);

      expect(rules2014.any((r) => r.contains('Level 1: Disadvantage on ability checks')), isTrue);
      expect(rules2024.any((r) => r.contains('10 total levels') || r.contains('Subtract 2 × your exhaustion level')), isTrue);
    });

    test('grapple/shove reflects 2014 contest vs 2024 save DC', () {
      final grapple = DmScreenLibrary.allItems.firstWhere((i) => i.id == 'action_grapple_shove');
      final r2014 = grapple.getRules(DmRulesEdition.v2014);
      final r2024 = grapple.getRules(DmRulesEdition.v2024);

      expect(r2014.any((r) => r.contains('Contested Check')), isTrue);
      expect(r2024.any((r) => r.contains('Saving Throw DC') || r.contains('DC = 8 + your Strength modifier')), isTrue);
    });

    test('potion drinking reflects Action in 2014 vs Bonus Action in 2024', () {
      final potion = DmScreenLibrary.allItems.firstWhere((i) => i.id == 'action_potions');
      final r2014 = potion.getRules(DmRulesEdition.v2014);
      final r2024 = potion.getRules(DmRulesEdition.v2024);

      expect(r2014.any((r) => r.contains('1 Action')), isTrue);
      expect(r2024.any((r) => r.contains('1 Bonus Action')), isTrue);
    });

    test('matching query works across title, summary, tags, and rules', () {
      const items = DmScreenLibrary.allItems;
      final coverMatches = items.where((i) => i.matches('cover')).toList();
      expect(coverMatches.any((i) => i.id == 'env_cover'), isTrue);

      final stealthMatches = items.where((i) => i.matches('stealth')).toList();
      expect(stealthMatches.any((i) => i.id == 'action_hide'), isTrue);
    });
  });
}
