import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:url_launcher_platform_interface/url_launcher_platform_interface.dart';
import 'package:url_launcher_platform_interface/link.dart';
import 'package:dangerously_nerdy_5e_toolkit/presentation/common/site_footer.dart';

class FakeUrlLauncherPlatform extends UrlLauncherPlatform
    with MockPlatformInterfaceMixin {
  String? launchedUrl;
  PreferredLaunchMode? launchMode;

  @override
  LinkDelegate? get linkDelegate => null;

  @override
  Future<bool> canLaunch(String url) async => true;

  @override
  Future<bool> launchUrl(String url, LaunchOptions options) async {
    launchedUrl = url;
    launchMode = options.mode;
    return true;
  }
}

void main() {
  group('Repository Governance & Licensing Verification', () {
    test('LICENSE file contains full AGPL-3.0 text and SRD attribution', () {
      final licenseFile = File('LICENSE');
      expect(licenseFile.existsSync(), isTrue);
      final content = licenseFile.readAsStringSync();
      expect(content, contains('GNU AFFERO GENERAL PUBLIC LICENSE'));
      expect(content, contains('Version 3, 19 November 2007'));
      expect(content, contains('System Reference Document 5.1 & 5.2'));
    });

    test('CONTRIBUTING.md explicitly rejects CLA in favor of DCO and requires git commit -s', () {
      final contributingFile = File('CONTRIBUTING.md');
      expect(contributingFile.existsSync(), isTrue);
      final content = contributingFile.readAsStringSync();
      expect(content, contains('Developer Certificate of Origin'));
      expect(content, contains('we deliberately do not use a Contributor License Agreement (CLA)'));
      expect(content, contains('git commit -s'));
      expect(content, contains('inbound = outbound'));
    });

    test('README.md includes AGPLv3 badge and DCO inbound=outbound governance notice', () {
      final readmeFile = File('README.md');
      expect(readmeFile.existsSync(), isTrue);
      final content = readmeFile.readAsStringSync();
      expect(content, contains('License-AGPL%20v3-blue.svg'));
      expect(content, contains('GNU Affero General Public License v3.0 (AGPL-3.0)'));
      expect(content, contains('Developer Certificate of Origin (DCO)'));
    });
  });

  group('SiteFooter Widget Verification', () {
    late FakeUrlLauncherPlatform fakeUrlLauncher;

    setUp(() {
      fakeUrlLauncher = FakeUrlLauncherPlatform();
      UrlLauncherPlatform.instance = fakeUrlLauncher;
    });

    testWidgets('renders copyright, AGPLv3 button, and GitHub source button', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SiteFooter(),
          ),
        ),
      );

      final currentYear = DateTime.now().year.toString();
      expect(find.textContaining('© $currentYear Dangerously Nerdy'), findsOneWidget);
      expect(find.text('Licensed under AGPLv3'), findsOneWidget);
      expect(find.text('GitHub Source'), findsOneWidget);
      expect(find.byIcon(Icons.code), findsOneWidget);
    });

    testWidgets('enforces strict 48x48dp minimum touch targets on interactive buttons', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SiteFooter(),
          ),
        ),
      );

      final buttons = find.byType(TextButton);
      expect(buttons, findsNWidgets(2));

      for (final btn in buttons.evaluate()) {
        final box = btn.renderObject as RenderBox?;
        expect(box, isNotNull);
        expect(box!.size.width, greaterThanOrEqualTo(48.0));
        expect(box.size.height, greaterThanOrEqualTo(48.0));
      }
    });

    testWidgets('Semantics wrappers announce external links with full descriptive targets', (tester) async {
      final handle = tester.ensureSemantics();

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SiteFooter(),
          ),
        ),
      );

      expect(
        tester.getSemantics(find.bySemanticsLabel('External Link: View AGPLv3 License details')),
        matchesSemantics(
          label: 'External Link: View AGPLv3 License details',
          isLink: true,
        ),
      );

      expect(
        tester.getSemantics(find.bySemanticsLabel('External Link: Dangerously Nerdy 5e Toolkit GitHub Repository')),
        matchesSemantics(
          label: 'External Link: Dangerously Nerdy 5e Toolkit GitHub Repository',
          isLink: true,
        ),
      );

      handle.dispose();
    });

    testWidgets('tapping buttons triggers url_launcher with external application mode', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SiteFooter(),
          ),
        ),
      );

      // Tap AGPL license button
      await tester.tap(find.text('Licensed under AGPLv3'));
      await tester.pumpAndSettle();
      expect(fakeUrlLauncher.launchedUrl, 'https://www.gnu.org/licenses/agpl-3.0.html');
      expect(fakeUrlLauncher.launchMode, PreferredLaunchMode.externalApplication);

      // Tap GitHub source button
      await tester.tap(find.text('GitHub Source'));
      await tester.pumpAndSettle();
      expect(
        fakeUrlLauncher.launchedUrl,
        'https://github.com/kevinburkeland/dangerously_nerdy_5e_toolkit',
      );
      expect(fakeUrlLauncher.launchMode, PreferredLaunchMode.externalApplication);
    });

    testWidgets('renders without layout overflow under TextScaler.linear(2.0) across viewport widths', (tester) async {
      tester.view.physicalSize = const Size(360 * 2, 640 * 2);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        const MaterialApp(
          home: MediaQuery(
            data: MediaQueryData(
              size: Size(360, 640),
              textScaler: TextScaler.linear(2.0),
            ),
            child: Scaffold(
              body: SingleChildScrollView(
                child: SiteFooter(),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
    });
  });
}
