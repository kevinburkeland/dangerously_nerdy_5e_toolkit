import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dangerously_nerdy_5e_toolkit/domain/homebrew/ports/i_github_ingestor_port.dart';
import 'package:dangerously_nerdy_5e_toolkit/domain/homebrew/value_objects/github_repo_source.dart';
import 'package:dangerously_nerdy_5e_toolkit/domain/homebrew/value_objects/ruleset_version.dart';
import 'package:dangerously_nerdy_5e_toolkit/presentation/screens/homebrew/homebrew_expert_options_view.dart';

class MockTestIngestorPort implements IGithubIngestorPort {
  @override
  Future<List<String>> discoverJsonManifest(GithubRepoSource source) async {
    return ['https://raw.githubusercontent.com/test/repo/main/spell.json'];
  }

  @override
  Stream<IngestionResult> ingestPayloadStream({
    required List<String> rawUrls,
    required RulesetVersion ruleset,
  }) async* {
    yield IngestionSkipResult(
      sourceUrl: rawUrls.first,
      reason: 'Validation test skip',
      ruleset: ruleset,
    );
  }
}

void main() {
  group('HomebrewExpertOptionsView Widget & A11y Tests', () {
    testWidgets('Renders warnings, keeps submit disabled until explicit ruleset and agreement',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: HomebrewExpertOptionsView(
            customIngestorPort: MockTestIngestorPort(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Assert warning banner and legal disclaimer exist
      expect(find.text('HOMOGENEOUS SINGLE-RULESET MANDATE'), findsOneWidget);
      expect(find.text('Client-Side Ingestion & Licensing Disclaimer'), findsOneWidget);

      // Verify submit button is disabled initially
      final submitFinder = find.byType(FilledButton);
      expect(submitFinder, findsOneWidget);
      final FilledButton button = tester.widget(submitFinder);
      expect(button.onPressed, isNull);

      // Select 2024 ruleset
      final radioOption = find.text('2024 SRD 5.2');
      expect(radioOption, findsOneWidget);
      await tester.tap(radioOption);
      await tester.pumpAndSettle();

      // Enter valid URL
      final urlField = find.byType(TextFormField);
      await tester.enterText(urlField, 'https://github.com/brewers/vault');
      await tester.pumpAndSettle();

      // Button is still disabled because single-ruleset checkbox is unchecked
      expect(tester.widget<FilledButton>(submitFinder).onPressed, isNull);

      // Check confirmation checkbox
      final checkboxFinder = find.byType(CheckboxListTile);
      await tester.tap(checkboxFinder);
      await tester.pumpAndSettle();

      // Button should now be enabled
      expect(tester.widget<FilledButton>(submitFinder).onPressed, isNotNull);

      // Ensure submit button is scrolled into view and tap
      await tester.ensureVisible(submitFinder);
      await tester.pumpAndSettle();
      await tester.tap(submitFinder);
      await tester.pump();
      await tester.pumpAndSettle();

      expect(find.text('Ingestion Telemetry'), findsOneWidget);
      expect(find.textContaining('Validation test skip'), findsOneWidget);
    });

    testWidgets('Renders cleanly without overflow under TextScaler.linear(2.0)',
        (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(
              textScaler: TextScaler.linear(2.0),
              size: Size(1080, 2400),
            ),
            child: HomebrewExpertOptionsView(
              customIngestorPort: MockTestIngestorPort(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('HOMOGENEOUS SINGLE-RULESET MANDATE'), findsOneWidget);
    });
  });
}
