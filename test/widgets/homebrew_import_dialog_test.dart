import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/domain/core_types.dart';
import 'package:dangerously_nerdy_5e_toolkit/widgets/homebrew/homebrew_import_dialog.dart';
import 'package:dangerously_nerdy_5e_toolkit/widgets/homebrew/homebrew_import_preview_dialog.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Homebrew Importer Default Ruleset Tests', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });
    testWidgets('HomebrewImportDialog defaults to Auto-Detect', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: HomebrewImportDialog(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final segmentedButton = tester.widget<SegmentedButton<RulesetVersion?>>(
        find.byType(SegmentedButton<RulesetVersion?>),
      );

      expect(segmentedButton.selected, equals({null}));
    });

    testWidgets('HomebrewImportPreviewDialog defaults to Auto-Detect', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: HomebrewImportPreviewDialog(useIsolate: false),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final segmentedButton = tester.widget<SegmentedButton<RulesetVersion?>>(
        find.byType(SegmentedButton<RulesetVersion?>),
      );

      expect(segmentedButton.selected, equals({null}));
    });

    testWidgets('HomebrewImportPreviewDialog displays dedicated sections for Deities and Vehicles', (tester) async {
      const jsonBundle = '''
      {
        "deity": [
          {
            "name": "Solas the Dawnbringer",
            "source": "HOMEBREW",
            "pantheon": "Solar Covenant"
          }
        ],
        "vehicle": [
          {
            "name": "Sand Crawler",
            "source": "HOMEBREW",
            "vehicleType": "Land"
          }
        ]
      }
      ''';

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: HomebrewImportPreviewDialog(
              useIsolate: false,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), jsonBundle);
      await tester.pumpAndSettle();

      await tester.tap(find.text('Analyze Bundle'));
      await tester.pumpAndSettle();

      expect(find.text('Deities & Pantheons (1/1)'), findsOneWidget);
      expect(find.text('Vehicles & Vessels (1/1)'), findsOneWidget);
      expect(find.text('Solas the Dawnbringer'), findsOneWidget);
      expect(find.text('Sand Crawler'), findsOneWidget);
    });
  });
}
