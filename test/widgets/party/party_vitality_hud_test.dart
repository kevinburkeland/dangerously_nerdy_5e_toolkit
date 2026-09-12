import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dangerously_nerdy_5e_toolkit/infrastructure/resolvers/character_telemetry_resolver.dart';
import 'package:dangerously_nerdy_5e_toolkit/widgets/party/party_vitality_hud.dart';

void main() {
  group('PartyVitalityHud Widget Tests', () {
    testWidgets('renders character vitality metrics, HP bar, AC, and speed', (tester) async {
      const character = ResolvedCharacterDisplay(
        id: 'hero-1',
        name: 'Valeros the Bold',
        speciesSlug: 'human',
        speciesName: 'Human',
        backgroundName: 'Soldier',
        classSummary: 'Fighter (Champion) 5',
        classes: [
          ResolvedClassInfo(
            classSlug: 'fighter',
            className: 'Fighter',
            subclassSlug: 'champion',
            subclassName: 'Champion',
            level: 5,
            isResolved: true,
          ),
        ],
        currentHp: 42,
        maxHp: 50,
        tempHp: 8,
        armorClass: 18,
        speed: 30,
        totalLevel: 5,
        passivePerception: 13,
        exhaustionLevel: 1,
        deathSaveSuccesses: 0,
        deathSaveFailures: 0,
        conditions: ['poisoned'],
        spellSlots: {'1': 2},
        featNames: ['Grappler'],
        equippedItemNames: ['Longsword'],
        hasUnresolvedPointers: false,
        unresolvedSlugs: [],
        rulesEdition: 'v2024',
        timestamp: 0,
      );

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: PartyVitalityHud(
              character: character,
            ),
          ),
        ),
      );

      expect(find.text('Valeros the Bold'), findsOneWidget);
      expect(find.text('Human • Fighter (Champion) 5'), findsOneWidget);
      expect(find.text('Lvl 5'), findsOneWidget);
      expect(find.text('HP: 42 / 50'), findsOneWidget);
      expect(find.text('+8 THP'), findsOneWidget);
      expect(find.text('AC 18'), findsOneWidget);
      expect(find.text('30 ft'), findsOneWidget);
      expect(find.text('PP 13'), findsOneWidget);
      expect(find.text('Exhaustion 1'), findsOneWidget);
      expect(find.text('poisoned'), findsOneWidget);

      // Verify no External Homebrew chip when all pointers resolved
      expect(find.text('External Homebrew'), findsNothing);
    });

    testWidgets('displays External Homebrew chip with tooltip when hasUnresolvedPointers is true', (tester) async {
      const homebrewChar = ResolvedCharacterDisplay(
        id: 'hb-1',
        name: 'Kallista Bloodhunter',
        speciesSlug: 'voidling',
        speciesName: 'Voidling',
        backgroundName: 'Astral Drifter',
        classSummary: 'Blood Hunter 7',
        classes: [],
        currentHp: 30,
        maxHp: 60,
        tempHp: 0,
        armorClass: 15,
        speed: 30,
        totalLevel: 7,
        passivePerception: 14,
        exhaustionLevel: 0,
        deathSaveSuccesses: 0,
        deathSaveFailures: 0,
        conditions: [],
        spellSlots: {},
        featNames: [],
        equippedItemNames: [],
        hasUnresolvedPointers: true,
        unresolvedSlugs: ['voidling', 'blood-hunter'],
        rulesEdition: 'v2024',
        timestamp: 0,
      );

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: PartyVitalityHud(
              character: homebrewChar,
            ),
          ),
        ),
      );

      expect(find.text('Kallista Bloodhunter'), findsOneWidget);
      expect(find.text('External Homebrew'), findsOneWidget);
      expect(find.byType(Tooltip), findsOneWidget);
    });

    testWidgets('renders death saves when character is downed (currentHp == 0)', (tester) async {
      const downedChar = ResolvedCharacterDisplay(
        id: 'downed-1',
        name: 'Fallen Fighter',
        speciesSlug: 'dwarf',
        speciesName: 'Dwarf',
        backgroundName: 'Soldier',
        classSummary: 'Fighter 3',
        classes: [],
        currentHp: 0,
        maxHp: 35,
        tempHp: 0,
        armorClass: 16,
        speed: 25,
        totalLevel: 3,
        passivePerception: 11,
        exhaustionLevel: 0,
        deathSaveSuccesses: 2,
        deathSaveFailures: 1,
        conditions: ['unconscious'],
        spellSlots: {},
        featNames: [],
        equippedItemNames: [],
        hasUnresolvedPointers: false,
        unresolvedSlugs: [],
        rulesEdition: 'v2024',
        timestamp: 0,
      );

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: PartyVitalityHud(
              character: downedChar,
            ),
          ),
        ),
      );

      expect(find.text('DEATH SAVES'), findsOneWidget);
      expect(find.text('unconscious'), findsOneWidget);
    });
  });
}
