import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/srd_summons.dart';
import 'package:dangerously_nerdy_5e_toolkit/screens/minion_tool_screen.dart';
import 'package:dangerously_nerdy_5e_toolkit/theme/app_theme.dart';

void main() {
  testWidgets('MinionToolScreen renders dual pane simultaneously on wide screen', (WidgetTester tester) async {
    // Set widescreen tablet resolution
    tester.view.physicalSize = const Size(1200, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final preset = SrdSummonsLibrary.allPresets.firstWhere((p) => p.id == 'animate_objects');

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.darkTheme,
        home: MinionToolScreen(preset: preset),
      ),
    );

    // Left pane: Active Squad elements
    expect(find.text('BATCH ATTACK'), findsOneWidget);
    expect(find.text('Silver Coin #1'), findsOneWidget);

    // Right pane: Rulebook elements simultaneously visible
    expect(find.text('ANIMATE OBJECTS CREATURE PROFILES'), findsOneWidget);
  });
}
