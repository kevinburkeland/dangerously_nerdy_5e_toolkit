import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/domain/core_types.dart';
import 'package:dangerously_nerdy_5e_toolkit/widgets/homebrew/homebrew_import_dialog.dart';
import 'package:dangerously_nerdy_5e_toolkit/widgets/homebrew/homebrew_import_preview_dialog.dart';

void main() {
  group('Homebrew Importer Default Ruleset Tests', () {
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
  });
}
