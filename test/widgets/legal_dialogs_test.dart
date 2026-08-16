import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dangerously_nerdy_5e_toolkit/widgets/dialogs/legal_dialogs.dart';

void main() {
  Widget createTestableWidget(Widget child) {
    return MaterialApp(
      home: Scaffold(body: child),
    );
  }

  testWidgets('Privacy Policy dialog renders and closes cleanly', (WidgetTester tester) async {
    await tester.pumpWidget(createTestableWidget(
      Builder(
        builder: (context) => ElevatedButton(
          onPressed: () => LegalDialogs.showPrivacyPolicy(context),
          child: const Text('Open Privacy'),
        ),
      ),
    ));

    await tester.tap(find.text('Open Privacy'));
    await tester.pumpAndSettle();

    expect(find.text('Privacy Policy'), findsAtLeastNWidgets(1));
    expect(find.text('Contact: kevin@burke.land'), findsOneWidget);

    await tester.tap(find.text('Close'));
    await tester.pumpAndSettle();

    expect(find.text('Contact: kevin@burke.land'), findsNothing);
  });

  testWidgets('Terms of Service dialog renders and closes cleanly', (WidgetTester tester) async {
    await tester.pumpWidget(createTestableWidget(
      Builder(
        builder: (context) => ElevatedButton(
          onPressed: () => LegalDialogs.showTermsOfService(context),
          child: const Text('Open Terms'),
        ),
      ),
    ));

    await tester.tap(find.text('Open Terms'));
    await tester.pumpAndSettle();

    expect(find.text('Terms of Service'), findsAtLeastNWidgets(1));
    expect(find.text('1. Permitted Use: Granted personal, non-commercial license for TTRPG sessions.\n'
        '2. AS-IS Disclaimer: Provided "AS-IS" without warranties of uninterrupted service or stream sync latency protection.\n'
        '3. Limitation of Liability: Developers are not liable for loss of local preset data or game session disruption.\n'
        '4. DMCA & Contact: Contact kevin@burke.land for intellectual property notices.'), findsOneWidget);

    await tester.tap(find.text('Close'));
    await tester.pumpAndSettle();

    expect(find.text('1. Permitted Use: Granted personal, non-commercial license for TTRPG sessions.\n'
        '2. AS-IS Disclaimer: Provided "AS-IS" without warranties of uninterrupted service or stream sync latency protection.\n'
        '3. Limitation of Liability: Developers are not liable for loss of local preset data or game session disruption.\n'
        '4. DMCA & Contact: Contact kevin@burke.land for intellectual property notices.'), findsNothing);
  });

  testWidgets('Legal & SRD 5.1 Attribution dialog renders and closes cleanly', (WidgetTester tester) async {
    await tester.pumpWidget(createTestableWidget(
      Builder(
        builder: (context) => ElevatedButton(
          onPressed: () => LegalDialogs.showAttribution(context),
          child: const Text('Open Legal'),
        ),
      ),
    ));

    await tester.tap(find.text('Open Legal'));
    await tester.pumpAndSettle();

    expect(find.text('Legal & SRD 5.1 Attribution'), findsOneWidget);
    expect(find.text('Compatibility & Legal Disclaimer'), findsOneWidget);
    expect(find.text('System Reference Document 5.1 & 5.2 (SRD 5.1 & SRD 5.2) License'), findsOneWidget);

    await tester.tap(find.text('Close'));
    await tester.pumpAndSettle();

    expect(find.text('Compatibility & Legal Disclaimer'), findsNothing);
  });
}
