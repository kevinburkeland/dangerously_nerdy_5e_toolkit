import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/dm_screen_data.dart';
import 'package:dangerously_nerdy_5e_toolkit/providers/settings_provider.dart';
import 'package:dangerously_nerdy_5e_toolkit/screens/rules_compendium_screen.dart';
import 'package:dangerously_nerdy_5e_toolkit/widgets/dm_reference/dm_interactive_tools.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Widget createTestableWidget(Widget child, {SettingsProvider? provider}) {
    final settingsProvider = provider ?? SettingsProvider();
    return SettingsScope(
      notifier: settingsProvider,
      child: MaterialApp(
        home: child,
      ),
    );
  }

  group('Rules Compendium Dataset & Search Engine Tests', () {
    test('comprehensive rules corpus indexes all SRD categories and required rules', () {
      const items = DmScreenLibrary.allItems;
      expect(items.length, greaterThanOrEqualTo(35));

      // Category coverage
      final categories = items.map((i) => i.category).toSet();
      expect(categories, containsAll(DmCategory.values));

      // Verify every item has valid non-empty rules and tags
      for (final item in items) {
        expect(item.id.isNotEmpty, isTrue);
        expect(item.title.isNotEmpty, isTrue);
        expect(item.summary.isNotEmpty, isTrue);
        expect(item.tags.isNotEmpty, isTrue, reason: 'Item ${item.id} has empty tags');
        expect(item.rules2014.isNotEmpty, isTrue, reason: 'Item ${item.id} has empty 2014 rules');
        expect(item.rules2024.isNotEmpty, isTrue, reason: 'Item ${item.id} has empty 2024 rules');
      }
    });

    test('verifies all 15 core conditions and statuses are indexed', () {
      final conditionIds = DmScreenLibrary.conditions.map((c) => c.id).toSet();
      const expectedConditions = [
        'cond_blinded',
        'cond_charmed',
        'cond_deafened',
        'cond_frightened',
        'cond_grappled',
        'cond_incapacitated',
        'cond_invisible',
        'cond_paralyzed',
        'cond_petrified',
        'cond_poisoned',
        'cond_prone',
        'cond_restrained',
        'cond_stunned',
        'cond_unconscious',
        'cond_exhaustion',
        'cond_surprise',
      ];

      for (final cond in expectedConditions) {
        expect(conditionIds.contains(cond), isTrue, reason: 'Missing condition $cond');
      }
    });

    test('verifies core combat actions, magic, hazards, and tables are indexed', () {
      final itemIds = DmScreenLibrary.allItems.map((i) => i.id).toSet();
      const expectedItems = [
        'action_attack',
        'action_cast_spell',
        'action_dash',
        'action_disengage',
        'action_dodge',
        'action_help',
        'action_hide',
        'action_ready',
        'action_search',
        'action_study',
        'action_influence',
        'action_use_object',
        'action_grapple_shove',
        'action_potions',
        'action_death_saves',
        'action_two_weapon_fighting',
        'action_opportunity_attack',
        'action_underwater_combat',
        'action_mounted_combat',
        'env_cover',
        'env_falling',
        'env_vision_lighting',
        'env_suffocation',
        'env_extreme_temperatures',
        'env_survival_foraging',
        'exp_dc_scale',
        'exp_travel_pace',
        'magic_concentration',
        'magic_spell_components',
        'magic_casting_times_rituals',
        'magic_combining_effects',
        'magic_resting',
        'table_improvised_damage',
        'table_object_ac_hp',
        'table_size_space_carrying',
        'table_weapon_properties_masteries',
        'table_armor_don_doff',
      ];

      for (final id in expectedItems) {
        expect(itemIds.contains(id), isTrue, reason: 'Missing item $id');
      }
    });

    test('tokenized multi-word search and search operators (tag:, category:, edition:) work accurately', () {
      const items = DmScreenLibrary.allItems;

      // Operator tag:
      final actionMatches = items.where((i) => i.matches('tag:standard_action')).toList();
      expect(actionMatches.isNotEmpty, isTrue);
      expect(actionMatches.every((i) => i.tags.contains('standard_action')), isTrue);

      // Operator category:
      final envMatches = items.where((i) => i.matches('category:environment')).toList();
      expect(envMatches.isNotEmpty, isTrue);
      expect(envMatches.every((i) => i.category == DmCategory.environment), isTrue);

      // Operator edition:diff
      final diffMatches = items.where((i) => i.matches('edition:diff')).toList();
      expect(diffMatches.isNotEmpty, isTrue);
      expect(diffMatches.every((i) => i.isChangedIn2024), isTrue);

      // Multi-word search
      final potionBonus = items.where((i) => i.matches('potion bonus action')).toList();
      expect(potionBonus.any((i) => i.id == 'action_potions'), isTrue);

      // Weapon masteries search
      final nickMastery = items.where((i) => i.matches('nick mastery')).toList();
      expect(nickMastery.any((i) => i.id == 'table_weapon_properties_masteries' || i.id == 'action_two_weapon_fighting'), isTrue);
    });
  });

  group('Interactive Rules Calculators Unit & Widget Tests', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    testWidgets('ConcentrationCalculatorWidget computes DC and performs roll test', (WidgetTester tester) async {
      await tester.pumpWidget(createTestableWidget(const Scaffold(body: ConcentrationCalculatorWidget())));

      expect(find.text('Concentration DC Calculator'), findsOneWidget);
      // Default damage 22 => half is 11 => DC 11
      expect(find.text('DC 11'), findsOneWidget);

      // Tap Roll CON Save button
      final rollBtn = find.textContaining('Roll CON Save');
      expect(rollBtn, findsOneWidget);
      await tester.tap(rollBtn);
      await tester.pumpAndSettle();

      expect(find.textContaining('Rolled '), findsOneWidget);
    });

    testWidgets('FallingDamageCalculatorWidget computes dice pool and rolls damage', (WidgetTester tester) async {
      await tester.pumpWidget(createTestableWidget(const Scaffold(body: FallingDamageCalculatorWidget())));

      expect(find.text('Falling Damage Calculator'), findsOneWidget);
      // Default fall 30 ft => 3d6
      expect(find.text('3d6'), findsOneWidget);

      // Tap Roll Impact Damage
      final rollBtn = find.textContaining('Roll 3d6 Impact Damage');
      expect(rollBtn, findsOneWidget);
      await tester.tap(rollBtn);
      await tester.pumpAndSettle();

      expect(find.textContaining('Rolled: ['), findsOneWidget);
      expect(find.textContaining('bludgeoning damage'), findsOneWidget);
    });

    testWidgets('GrappleShoveCalculatorWidget computes 2024 Save DC', (WidgetTester tester) async {
      await tester.pumpWidget(createTestableWidget(const Scaffold(body: GrappleShoveCalculatorWidget())));

      expect(find.text('Grapple / Shove DC Engine'), findsOneWidget);
      // Default STR +3, PB +2 => 8 + 3 + 2 = DC 13
      expect(find.text('DC 13'), findsOneWidget);
    });

    testWidgets('DcBenchmarkSelectorWidget renders DC scale from 5 to 30', (WidgetTester tester) async {
      await tester.pumpWidget(createTestableWidget(const Scaffold(body: DcBenchmarkSelectorWidget())));

      expect(find.text('DC Quick Benchmarks (Tap to copy)'), findsOneWidget);
      expect(find.text('DC 5'), findsOneWidget);
      expect(find.text('DC 10'), findsOneWidget);
      expect(find.text('DC 15'), findsOneWidget);
      expect(find.text('DC 20'), findsOneWidget);
      expect(find.text('DC 25'), findsOneWidget);
      expect(find.text('DC 30'), findsOneWidget);

      // Tap DC 15 to trigger copy
      await tester.tap(find.text('DC 15'));
      await tester.pumpAndSettle();

      expect(find.text('Copied DC 15 (Medium) to clipboard!'), findsOneWidget);
    });
  });

  group('RulesCompendiumScreen Integrated UI Tests', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    testWidgets('renders Rules Compendium with all category chips and quick dice', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1200, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(createTestableWidget(const RulesCompendiumScreen()));

      expect(find.text("Rules Compendium"), findsOneWidget);
      expect(find.text('Quick Roller:'), findsOneWidget);
      expect(find.widgetWithText(ChoiceChip, 'All Rules'), findsOneWidget);
      expect(find.widgetWithText(ChoiceChip, 'Actions & Combat'), findsOneWidget);
      expect(find.widgetWithText(ChoiceChip, 'Conditions & Statuses'), findsOneWidget);
      expect(find.widgetWithText(ChoiceChip, 'Environment & Hazards'), findsOneWidget);
      expect(find.widgetWithText(ChoiceChip, 'Exploration & DCs'), findsOneWidget);
      expect(find.widgetWithText(ChoiceChip, 'Magic & Resting'), findsOneWidget);
      expect(find.widgetWithText(ChoiceChip, 'Quick Reference Tables'), findsOneWidget);
    });

    testWidgets('search highlighting and operator filtering work in UI', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1200, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(createTestableWidget(const RulesCompendiumScreen()));

      final searchField = find.byType(TextField);
      expect(searchField, findsOneWidget);

      // Search using operator tag:cover_rule
      await tester.enterText(searchField, 'tag:cover_rule');
      await tester.pumpAndSettle();

      expect(find.text('Cover Rules (+2, +5, Total)'), findsOneWidget);
      expect(find.text('Attack Action & Extra Attack'), findsNothing);
    });

    testWidgets('opening interactive calculator inside rule card expands calculator widget', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1200, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(createTestableWidget(const RulesCompendiumScreen()));

      // Filter to Concentration
      final searchField = find.byType(TextField);
      await tester.enterText(searchField, 'Concentration Rules');
      await tester.pumpAndSettle();

      final openCalcBtn = find.text('Open Interactive Calculator');
      expect(openCalcBtn, findsOneWidget);

      await tester.ensureVisible(openCalcBtn);
      await tester.pumpAndSettle();

      await tester.tap(openCalcBtn);
      await tester.pumpAndSettle();

      expect(find.text('Concentration DC Calculator'), findsOneWidget);
      expect(find.text('Hide Interactive Calculator'), findsOneWidget);
    });
  });
}
