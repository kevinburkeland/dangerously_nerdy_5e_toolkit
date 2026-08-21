import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/magic_items/magic_item_library.dart';
import 'package:dangerously_nerdy_5e_toolkit/providers/settings_provider.dart';
import 'package:dangerously_nerdy_5e_toolkit/widgets/item_compendium/item_card.dart';
import 'package:dangerously_nerdy_5e_toolkit/widgets/item_compendium/item_detail_dialog.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Widget buildTestDialog({
    required Widget child,
    SettingsProvider? provider,
  }) {
    final settingsProvider = provider ?? SettingsProvider();
    return SettingsScope(
      notifier: settingsProvider,
      child: MaterialApp(
        home: Scaffold(
          body: child,
        ),
      ),
    );
  }

  group('Item Compendium Pricing & Crafting Widget Tests', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    testWidgets('ItemCard renders item price badge', (tester) async {
      final flameTongue = MagicItemLibrary.findById('item_flame_tongue')!;
      await tester.pumpWidget(
        buildTestDialog(
          child: ItemCard(
            item: flameTongue,
            isPinned: false,
            onTogglePin: () {},
            onTap: () {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('500–5,000 gp'), findsOneWidget);
      expect(find.byIcon(Icons.monetization_on_outlined), findsWidgets);
    });

    testWidgets('ItemDetailDialog renders tab bar with Rules & Traits and Crafting Rules', (tester) async {
      tester.view.physicalSize = const Size(1200, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final flameTongue = MagicItemLibrary.findById('item_flame_tongue')!;

      await tester.pumpWidget(
        buildTestDialog(
          child: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () {
                ItemDetailDialog.show(
                  context,
                  item: flameTongue,
                  edition: DmRulesEdition.v2024,
                  isPinned: false,
                  onTogglePin: () {},
                );
              },
              child: const Text('Open Dialog'),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Open dialog
      await tester.tap(find.text('Open Dialog'));
      await tester.pumpAndSettle();

      // Verify Header & Tabs
      expect(find.text('Rules & Traits'), findsOneWidget);
      expect(find.text('Crafting Rules'), findsOneWidget);
      expect(find.text('Market Price:'), findsOneWidget);
      expect(find.text('500–5,000 gp'), findsWidgets);

      // Switch to Crafting Rules tab
      await tester.tap(find.text('Crafting Rules'));
      await tester.pumpAndSettle();

      // Verify Crafting Tab contents
      expect(find.textContaining('Downtime Crafting Requirements'), findsOneWidget);
      expect(find.text('Primary Tool:'), findsOneWidget);
      expect(find.text('Smith\'s Tools'), findsWidgets);
      expect(find.text('Raw Materials Cost:'), findsOneWidget);
      expect(find.textContaining('2000 gp'), findsWidgets);
      expect(find.text('2024 Crafting Time:'), findsOneWidget);
      expect(find.textContaining('200 days'), findsWidgets);
      expect(find.text('Minimum Character Level:'), findsOneWidget);
      expect(find.text('6th Level'), findsWidgets);
      expect(find.text('Creature / Harvest CR:'), findsOneWidget);
      expect(find.textContaining('CR 9–12'), findsWidgets);
      expect(find.text('2024 Bastion Facility:'), findsOneWidget);
      expect(find.textContaining('Smithy'), findsWidgets);
    });

    testWidgets('ItemDetailDialog supports switching rules editions inside dialog', (tester) async {
      tester.view.physicalSize = const Size(1200, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final potionOfHealing = MagicItemLibrary.findByName('Potion of Healing')!;

      await tester.pumpWidget(
        buildTestDialog(
          child: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () {
                ItemDetailDialog.show(
                  context,
                  item: potionOfHealing,
                  edition: DmRulesEdition.v2024,
                  isPinned: false,
                  onTogglePin: () {},
                );
              },
              child: const Text('Open Dialog'),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Open Dialog'));
      await tester.pumpAndSettle();

      // Switch to Crafting Tab
      await tester.tap(find.text('Crafting Rules'));
      await tester.pumpAndSettle();

      expect(find.text('Herbalism Kit'), findsWidgets);
      expect(find.textContaining('Consumable half-cost'), findsWidgets);
    });

    testWidgets('ItemCard renders silver (sp) price badge with silver color coding', (tester) async {
      final club = MagicItemLibrary.findById('weapon_club')!;
      expect(club.getEffectivePrice(), equals('1 sp'));

      await tester.pumpWidget(
        buildTestDialog(
          child: ItemCard(
            item: club,
            isPinned: false,
            onTogglePin: () {},
            onTap: () {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('1 sp'), findsOneWidget);
    });
  });
}
