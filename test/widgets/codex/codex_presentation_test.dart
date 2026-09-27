import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dangerously_nerdy_5e_toolkit/presentation/codex/codex.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Codex Presentation Layer Tests', () {
    testWidgets('CodexAppBarTitle renders title, icon, and visible count badge',
        (tester) async {
      const config = CodexHeaderConfig(
        title: 'Test Codex',
        icon: Icons.shield,
        accentColor: Colors.deepOrange,
        visibleCount: 42,
      );

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            appBar: PreferredSize(
              preferredSize: Size.fromHeight(56),
              child: SafeArea(child: CodexAppBarTitle(config: config)),
            ),
          ),
        ),
      );

      expect(find.text('Test Codex'), findsOneWidget);
      expect(find.byIcon(Icons.shield), findsOneWidget);
      expect(find.text('42'), findsOneWidget);

      // Verify semantics header
      final semanticsFinder = find.byWidgetPredicate(
        (w) => w is Semantics && w.properties.header == true,
      );
      expect(semanticsFinder, findsOneWidget);
    });

    testWidgets('CodexModeSelector renders modes and fires onModeSelected with haptic',
        (tester) async {
      String selectedMode = 'all';

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) {
                return CodexModeSelector<String>(
                  modes: const [
                    CodexViewMode(key: 'all', label: 'All Items', icon: Icons.list, count: 10),
                    CodexViewMode(key: 'pinned', label: 'Bookmarks', icon: Icons.bookmark, count: 2),
                    CodexViewMode(key: 'diffs', label: '2024 Diffs', icon: Icons.auto_awesome),
                  ],
                  selectedMode: selectedMode,
                  onModeSelected: (newMode) {
                    setState(() => selectedMode = newMode);
                  },
                );
              },
            ),
          ),
        ),
      );

      expect(find.text('All Items'), findsOneWidget);
      expect(find.text('10'), findsOneWidget);
      expect(find.text('Bookmarks'), findsOneWidget);
      expect(find.text('2'), findsOneWidget);
      expect(find.text('2024 Diffs'), findsOneWidget);

      // Tap on Bookmarks
      await tester.tap(find.text('Bookmarks'));
      await tester.pumpAndSettle();

      expect(selectedMode, equals('pinned'));
    });

    testWidgets('CodexFilterStrip renders options and propagates selection',
        (tester) async {
      int selectedCategory = 1;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) {
                return CodexFilterStrip<int>(
                  options: const [
                    CodexFilterOption(value: 1, label: 'Martial'),
                    CodexFilterOption(value: 2, label: 'Caster'),
                    CodexFilterOption(value: 3, label: 'Specialist', count: 5),
                  ],
                  selectedValue: selectedCategory,
                  onSelected: (val) {
                    setState(() => selectedCategory = val);
                  },
                );
              },
            ),
          ),
        ),
      );

      expect(find.text('Martial'), findsOneWidget);
      expect(find.text('Caster'), findsOneWidget);
      expect(find.text('Specialist'), findsOneWidget);
      expect(find.text('(5)'), findsOneWidget);

      // Select Caster
      await tester.tap(find.text('Caster'));
      await tester.pumpAndSettle();

      expect(selectedCategory, equals(2));
    });

    testWidgets('CodexPageShell composes empty state and content switching',
        (tester) async {
      bool isEmpty = false;

      await tester.pumpWidget(
        MaterialApp(
          home: StatefulBuilder(
            builder: (context, setState) {
              return CodexPageShell(
                headerConfig: const CodexHeaderConfig(
                  title: 'Shell Test',
                  icon: Icons.book,
                ),
                showRoomBanner: false,
                searchHeader: const SizedBox(height: 40, child: Text('Search Header')),
                modeSelector: const SizedBox(height: 30, child: Text('Mode Selector')),
                filterArea: const SizedBox(height: 30, child: Text('Filter Area')),
                isEmpty: isEmpty,
                emptyState: const Text('Empty State Card'),
                content: const Text('Main Content Grid'),
                floatingActionButton: FloatingActionButton(
                  onPressed: () => setState(() => isEmpty = !isEmpty),
                  child: const Icon(Icons.swap_horiz),
                ),
              );
            },
          ),
        ),
      );

      expect(find.text('Shell Test'), findsOneWidget);
      expect(find.text('Search Header'), findsOneWidget);
      expect(find.text('Mode Selector'), findsOneWidget);
      expect(find.text('Filter Area'), findsOneWidget);
      expect(find.text('Main Content Grid'), findsOneWidget);
      expect(find.text('Empty State Card'), findsNothing);

      // Toggle to empty
      await tester.tap(find.byType(FloatingActionButton));
      await tester.pumpAndSettle();

      expect(find.text('Empty State Card'), findsOneWidget);
      expect(find.text('Main Content Grid'), findsNothing);
    });

    testWidgets('CodexPageShell renders cleanly under 2.0x text scaling and narrow mobile width without overflow',
        (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(
            size: Size(320, 640),
            textScaler: TextScaler.linear(2.0),
          ),
          child: MaterialApp(
            home: CodexPageShell(
              headerConfig: const CodexHeaderConfig(
                title: 'A Very Long Screen Title For A Comprehensive Codex',
                icon: Icons.shield,
                visibleCount: 999,
              ),
              showRoomBanner: false,
              searchHeader: const TextField(
                decoration: InputDecoration(hintText: 'Search...'),
              ),
              modeSelector: CodexModeSelector<String>(
                modes: const [
                  CodexViewMode(key: '1', label: 'Very Long Mode One', icon: Icons.star, count: 50),
                  CodexViewMode(key: '2', label: 'Very Long Mode Two', icon: Icons.star, count: 20),
                ],
                selectedMode: '1',
                onModeSelected: (_) {},
              ),
              filterArea: CodexFilterStrip<String>(
                options: const [
                  CodexFilterOption(value: 'a', label: 'Option Alpha'),
                  CodexFilterOption(value: 'b', label: 'Option Beta'),
                ],
                selectedValue: 'a',
                onSelected: (_) {},
              ),
              isEmpty: false,
              content: ListView(
                children: const [
                  ListTile(title: Text('Card 1')),
                  ListTile(title: Text('Card 2')),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Ensure no RenderFlex errors were thrown and key elements are rendered
      expect(tester.takeException(), isNull);
      expect(find.byType(CodexPageShell), findsOneWidget);
      expect(find.text('Card 1'), findsOneWidget);
    });
  });
}
