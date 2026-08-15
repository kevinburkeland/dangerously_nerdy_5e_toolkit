import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dangerously_nerdy_5e_toolkit/providers/settings_provider.dart';
import 'package:dangerously_nerdy_5e_toolkit/widgets/interactive/pressable_card.dart';
import 'package:dangerously_nerdy_5e_toolkit/widgets/meters/animated_resource_meter.dart';
import 'package:dangerously_nerdy_5e_toolkit/widgets/fx/critical_effect_overlay.dart';

void main() {
  testWidgets('PressableCard renders child and fires onTap', (tester) async {
    bool tapped = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PressableCard(
            onTap: () => tapped = true,
            child: const Text('Tap Me'),
          ),
        ),
      ),
    );

    expect(find.text('Tap Me'), findsOneWidget);
    await tester.tap(find.text('Tap Me'));
    await tester.pumpAndSettle();
    expect(tapped, isTrue);
  });

  testWidgets('AnimatedResourceMeter renders labels and ratios correctly', (tester) async {
    final settingsProvider = SettingsProvider();

    await tester.pumpWidget(
      SettingsScope(
        notifier: settingsProvider,
        child: const MaterialApp(
          home: Scaffold(
            body: AnimatedResourceMeter(
              currentValue: 50,
              maxValue: 100,
              label: 'Hit Points',
              fillColor: Colors.blue,
            ),
          ),
        ),
      ),
    );

    expect(find.text('Hit Points'), findsOneWidget);
    expect(find.text('50 / 100'), findsOneWidget);
  });

  testWidgets('AnimatedResourceMeter triggers low-resource critical alert and pulse when <= 25%', (tester) async {
    final settingsProvider = SettingsProvider();

    await tester.pumpWidget(
      SettingsScope(
        notifier: settingsProvider,
        child: const MaterialApp(
          home: Scaffold(
            body: AnimatedResourceMeter(
              currentValue: 18,
              maxValue: 100,
              label: 'Hit Points',
              fillColor: Colors.blue,
            ),
          ),
        ),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    // When <= 25%, semantics description includes Warning: Low resource critical alert
    final semantics = tester.getSemantics(find.byType(AnimatedResourceMeter));
    expect(semantics.label, contains('Warning: Low resource critical alert'));
  });

  testWidgets('CriticalEffectOverlay triggers without error', (tester) async {
    final controller = CriticalEffectController();
    final settingsProvider = SettingsProvider();

    await tester.pumpWidget(
      SettingsScope(
        notifier: settingsProvider,
        child: MaterialApp(
          home: Scaffold(
            body: CriticalEffectOverlay(
              controller: controller,
              child: const Text('Game Canvas'),
            ),
          ),
        ),
      ),
    );

    expect(find.text('Game Canvas'), findsOneWidget);

    controller.trigger(CritEffectType.critSuccess);
    await tester.pump(const Duration(milliseconds: 100));
    controller.trigger(CritEffectType.critFumble);
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pumpAndSettle();
  });
}
