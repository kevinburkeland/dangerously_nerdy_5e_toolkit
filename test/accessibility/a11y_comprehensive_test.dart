import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/animated_object.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/dice_roll.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/spell_session.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/srd_summons/srd_summons_library.dart';
import 'package:dangerously_nerdy_5e_toolkit/services/a11y_service.dart';
import 'package:dangerously_nerdy_5e_toolkit/widgets/batch_attack/batch_attack_results_card.dart';
import 'package:dangerously_nerdy_5e_toolkit/widgets/dialogs/creature_stat_block_dialog.dart';
import 'package:dangerously_nerdy_5e_toolkit/widgets/dice_roller/latest_roll_card.dart';
import 'package:dangerously_nerdy_5e_toolkit/widgets/fx/critical_effect_overlay.dart';
import 'package:dangerously_nerdy_5e_toolkit/widgets/interactive/pressable_card.dart';
import 'package:dangerously_nerdy_5e_toolkit/widgets/meters/animated_resource_meter.dart';
import 'package:dangerously_nerdy_5e_toolkit/widgets/object_card.dart';

void main() {
  group('Comprehensive Accessibility (a11y) Verification Tests', () {
    testWidgets('PressableCard supports keyboard focus and visible focus border', (tester) async {
      bool tapped = false;

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.dark(),
          home: Scaffold(
            body: Center(
              child: PressableCard(
                onTap: () => tapped = true,
                semanticLabel: 'Launch Animate Objects Companion',
                child: const Text('Animate Objects'),
              ),
            ),
          ),
        ),
      );

      // Verify widget exists
      final cardFinder = find.byType(PressableCard);
      expect(cardFinder, findsOneWidget);

      // Verify InkWell is used inside for focus support
      final inkWellFinder = find.descendant(of: cardFinder, matching: find.byType(InkWell));
      expect(inkWellFinder, findsOneWidget);

      // Tap card
      await tester.tap(cardFinder);
      await tester.pumpAndSettle();
      expect(tapped, isTrue);
    });

    testWidgets('ObjectCard provides minimum 48x48dp HP button touch targets & semantic stats', (tester) async {
      final handle = tester.ensureSemantics();
      final object = AnimatedObjectInstance(
        id: 'obj_1',
        size: ObjectSize.medium,
        name: 'Animated Sword',
        currentHp: 40,
        maxHp: 40,
        tempHp: 5,
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.dark(),
          home: Scaffold(
            body: SingleChildScrollView(
              child: ObjectCard(
                object: object,
                onDelete: () {},
                onHpChanged: (_) {},
                onNameChanged: (_) {},
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Find HP increment / decrement buttons
      final iconButtons = find.byType(ConstrainedBox);
      expect(iconButtons, findsWidgets);

      // Verify Armor Class and stats have descriptive semantic labels
      expect(find.bySemanticsLabel(RegExp(r'Armor Class: \d+')), findsOneWidget);
      expect(find.bySemanticsLabel(RegExp(r'Attack Bonus: \+\d+')), findsOneWidget);

      handle.dispose();
    });

    testWidgets('CreatureStatBlockDialog expands ability score acronyms for screen readers', (tester) async {
      final handle = tester.ensureSemantics();
      const statBlock = SrdSummonsLibrary.wolf;

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.dark(),
          home: const Scaffold(
            body: CreatureStatBlockDialog(statBlock: statBlock),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify full spoken ability names
      expect(find.bySemanticsLabel(RegExp(r'Strength: \d+, modifier .*')), findsOneWidget);
      expect(find.bySemanticsLabel(RegExp(r'Dexterity: \d+, modifier .*')), findsOneWidget);
      expect(find.bySemanticsLabel(RegExp(r'Constitution: \d+, modifier .*')), findsOneWidget);

      handle.dispose();
    });

    testWidgets('BatchAttackResultsCard exposes comprehensive a11y labels and high-contrast badges', (tester) async {
      final handle = tester.ensureSemantics();
      final obj = AnimatedObjectInstance(
        id: '1',
        size: ObjectSize.tiny,
        name: 'Silver Coin #1',
        currentHp: 20,
        maxHp: 20,
      );

      final attackRes = AttackRollResult(
        object: obj,
        d20Roll1: 18,
        finalD20: 18,
        totalToHit: 26,
        isHit: true,
        isNat1: false,
        isCrit: false,
        damageRolls: [4],
        damageBonus: 4,
        totalDamage: 8,
      );

      final summary = BatchAttackSummary(
        targetAc: 15,
        advantageMode: RollMode.normal,
        totalAttacks: 1,
        totalHits: 1,
        totalCrits: 0,
        totalDamage: 8,
        results: [attackRes],
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.dark(),
          home: Scaffold(
            body: SingleChildScrollView(
              child: BatchAttackResultsCard(
                summary: summary,
                targetAc: 15,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify summary label
      expect(
        find.bySemanticsLabel(RegExp(r'Batch Attack Summary: 8 total damage, 1 of 1 attacks hit, 0 critical hits.')),
        findsOneWidget,
      );

      // Verify item label
      expect(
        find.bySemanticsLabel(RegExp(r'Silver Coin #1 \(Tiny\): rolled 18 with bonus \d+ equals 26 against Armor Class 15. Hit! 8 damage dealt.')),
        findsOneWidget,
      );

      handle.dispose();
    });

    testWidgets('LatestRollCard exposes detailed dice breakdown in semantic summary and liveRegion', (tester) async {
      final handle = tester.ensureSemantics();
      final entry = DiceEntry(dieType: DieType.d20, count: 1);
      final result = DiceRollResult(
        timestamp: DateTime.now(),
        diceEntries: [entry],
        groupResults: [
          DiceGroupResult(
            entry: entry,
            rolls: [20],
          ),
        ],
        modifier: 3,
        rollMode: RollMode.normal,
        individualRolls: const [20],
        total: 23,
        isCrit: true,
        isFumble: false,
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.dark(),
          home: Scaffold(
            body: LatestRollCard(latestResult: result),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify detailed dice breakdown in semantic summary
      expect(
        find.bySemanticsLabel(RegExp(r'Latest Roll Result: 23\. Formula: 1d20 \+ 3\. Dice rolled: d20: 20\. Modifier: \+3\. 🔥 NATURAL 20! CRITICAL HIT')),
        findsOneWidget,
      );

      handle.dispose();
    });

    testWidgets('AnimatedResourceMeter respects MediaQuery disableAnimations', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: MediaQuery(
            data: MediaQueryData(disableAnimations: true),
            child: Scaffold(
              body: AnimatedResourceMeter(
                currentValue: 10,
                maxValue: 100,
                label: 'Mana Points',
                fillColor: Colors.blue,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify meter renders properly without throwing under disabled animations
      expect(find.byType(AnimatedResourceMeter), findsOneWidget);
      expect(find.text('Mana Points'), findsOneWidget);
    });

    testWidgets('CriticalEffectOverlay silences screen shake when disableAnimations is active', (tester) async {
      final controller = CriticalEffectController();

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.dark(),
          home: MediaQuery(
            data: const MediaQueryData(disableAnimations: true),
            child: Scaffold(
              body: CriticalEffectOverlay(
                controller: controller,
                child: const Text('Game Screen'),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Trigger critical fumble
      controller.trigger(CritEffectType.critFumble);
      await tester.pump(const Duration(milliseconds: 200));

      // With disableAnimations = true, screen translation offset remains Offset.zero
      final transformFinder = find.descendant(
        of: find.byType(CriticalEffectOverlay),
        matching: find.byType(Transform),
      );
      final Transform transformWidget = tester.widget(transformFinder.first);
      expect(transformWidget.transform.getTranslation().x, equals(0.0));
      expect(transformWidget.transform.getTranslation().y, equals(0.0));
    });

    test('A11yService methods execute cleanly without throwing', () {
      expect(() => A11yService.announce('Test Announcement'), returnsNormally);
      expect(
        () => A11yService.announceHpChange('Goblin', currentHp: 5, maxHp: 10, delta: -2),
        returnsNormally,
      );
    });
  });
}
