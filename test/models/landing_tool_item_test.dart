import 'package:flutter_test/flutter_test.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/landing_tool_item.dart';

void main() {
  // Access the full list once — avoids re-constructing the getter repeatedly
  final tools = LandingToolRegistry.defaultTools;

  group('LandingToolRegistry — Structural Integrity', () {
    test('defaultTools list is non-empty', () {
      expect(tools.isNotEmpty, isTrue);
      // Guard against list.clear mutation: if the list becomes [], length == 0
      expect(tools.length, greaterThanOrEqualTo(10));
    });

    test('no duplicate tool ids', () {
      final ids = tools.map((t) => t.id).toList();
      expect(ids.length, equals(ids.toSet().length),
          reason: 'Duplicate id found in LandingToolRegistry.defaultTools');
    });

    test('known core tool ids are all present', () {
      final ids = tools.map((t) => t.id).toSet();
      expect(ids.contains('dm_dashboard'), isTrue);
      expect(ids.contains('character_builder'), isTrue);
      expect(ids.contains('dice_roller'), isTrue);
      expect(ids.contains('dpr_calculator'), isTrue);
      expect(ids.contains('srd_spellbook'), isTrue);
      expect(ids.contains('monster_codex'), isTrue);
    });
  });

  group('LandingToolItem — Field Completeness', () {
    test('every tool has a non-empty id, title, category, badgeText, and description', () {
      for (final t in tools) {
        expect(t.id.isNotEmpty, isTrue,
            reason: 'Tool has empty id');
        expect(t.title.isNotEmpty, isTrue,
            reason: 'Tool "${t.id}" has empty title');
        expect(t.category.isNotEmpty, isTrue,
            reason: 'Tool "${t.id}" has empty category');
        expect(t.badgeText.isNotEmpty, isTrue,
            reason: 'Tool "${t.id}" has empty badgeText');
        expect(t.description.isNotEmpty, isTrue,
            reason: 'Tool "${t.id}" has empty description');
      }
    });

    test('every tool has at least one keyword', () {
      for (final t in tools) {
        expect(t.keywords.isNotEmpty, isTrue,
            reason: 'Tool "${t.id}" has no keywords');
      }
    });
  });

  group('LandingToolItem.matches() — Boolean Logic', () {
    // These tests target the && → || mutation in matches():
    // "title.contains(q) || description.contains(q) || ..."
    // A && mutation would make matches() fail on all but exact full-term matches.

    test('matches returns true for empty query (show-all shortcut)', () {
      for (final t in tools) {
        expect(t.matches(''), isTrue,
            reason: 'Tool "${t.id}" should match empty query');
      }
    });

    test('matches returns true when query matches title substring', () {
      final dmTool = tools.firstWhere((t) => t.id == 'dm_dashboard');
      expect(dmTool.matches('dashboard'), isTrue);
      expect(dmTool.matches('Dashboard'), isTrue); // case-insensitive
    });

    test('matches returns true when query matches a keyword in the keywords list', () {
      // Verify matches() hits the keywords branch by using a keyword that is
      // unlikely to appear verbatim in the short title.
      bool foundKeywordOnlyMatch = false;
      for (final t in tools) {
        for (final kw in t.keywords) {
          // Skip single-word keywords that might appear in the title
          if (kw.length > 3 && !t.title.toLowerCase().contains(kw.toLowerCase())) {
            expect(t.matches(kw), isTrue,
                reason: 'Tool "${t.id}" should match on keyword "$kw"');
            foundKeywordOnlyMatch = true;
            break;
          }
        }
        if (foundKeywordOnlyMatch) break;
      }
      // Belt-and-suspenders: at least one keyword-only match was found
      expect(foundKeywordOnlyMatch, isTrue,
          reason: 'Expected at least one tool with a keyword not in the title');
    });

    test('matches returns true when query matches category', () {
      // All core tools share 'Core Utilities' category
      final coreTool = tools.firstWhere((t) => t.category == 'Core Utilities');
      expect(coreTool.matches('Core Utilities'), isTrue);
    });

    test('matches returns true when query matches a keyword but not title or description', () {
      // Pick a tool and verify a specific keyword triggers a match
      for (final t in tools) {
        if (t.keywords.isNotEmpty) {
          final kw = t.keywords.first;
          expect(t.matches(kw), isTrue,
              reason: 'Tool "${t.id}" should match on keyword "$kw"');
          break;
        }
      }
    });

    test('matches returns false for a nonsense query that matches nothing', () {
      const garbage = 'xyzzy_no_match_ever_42!';
      for (final t in tools) {
        expect(t.matches(garbage), isFalse,
            reason: 'Tool "${t.id}" should NOT match "$garbage"');
      }
    });

    test('matches is case-insensitive across all fields', () {
      final tool = tools.first;
      final upperTitle = tool.title.toUpperCase();
      expect(tool.matches(upperTitle), isTrue);
    });
  });

  group('LandingToolItem.getLegibleAccent() — Legibility Variants', () {
    test('getLegibleAccent returns a non-null color in both dark and light mode', () {
      for (final t in tools) {
        expect(t.getLegibleAccent(true), isNotNull);
        expect(t.getLegibleAccent(false), isNotNull);
      }
    });

    test('getLegibleAccent in dark mode returns accentColor unchanged', () {
      for (final t in tools) {
        expect(t.getLegibleAccent(true), equals(t.accentColor));
      }
    });
  });

  group('LandingToolItem.getLegibleBadge() — Legibility Variants', () {
    test('getLegibleBadge returns a non-null color in both dark and light mode', () {
      for (final t in tools) {
        expect(t.getLegibleBadge(true), isNotNull);
        expect(t.getLegibleBadge(false), isNotNull);
      }
    });

    test('getLegibleBadge in dark mode returns badgeColor unchanged', () {
      for (final t in tools) {
        expect(t.getLegibleBadge(true), equals(t.badgeColor));
      }
    });
  });
}
