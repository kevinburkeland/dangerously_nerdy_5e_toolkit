import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dangerously_nerdy_5e_toolkit/presentation/codex/codex.dart';

enum _TestMode { alpha, beta }
enum _TestCategory { martial, caster }

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('CodexAppBarTitle Tests', () {
    testWidgets('title, icon, and visible count render correctly',
        (tester) async {
      const config = CodexHeaderConfig(
        title: 'Synthetic Codex',
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

      expect(find.text('Synthetic Codex'), findsOneWidget);
      expect(find.byIcon(Icons.shield), findsOneWidget);
      expect(find.text('42'), findsOneWidget);

      final semanticsFinder = find.byWidgetPredicate(
        (w) =>
            w is Semantics &&
            w.properties.header == true &&
            w.properties.label == 'Synthetic Codex, 42 items',
      );
      expect(semanticsFinder, findsOneWidget);
    });

    testWidgets('custom iconWidget overrides icon', (tester) async {
      const config = CodexHeaderConfig(
        title: 'Custom Glyph Codex',
        iconWidget: KeyedSubtree(
          key: Key('custom-glyph'),
          child: Icon(Icons.flash_on),
        ),
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

      expect(find.byKey(const Key('custom-glyph')), findsOneWidget);
      expect(find.text('Custom Glyph Codex'), findsOneWidget);
    });

    testWidgets('semantic label matches custom semanticsLabel when provided',
        (tester) async {
      const config = CodexHeaderConfig(
        title: 'Short',
        semanticsLabel: 'Expanded Accessible Header Title',
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

      final semanticsFinder = find.byWidgetPredicate(
        (w) =>
            w is Semantics &&
            w.properties.header == true &&
            w.properties.label == 'Expanded Accessible Header Title',
      );
      expect(semanticsFinder, findsOneWidget);
    });

    testWidgets('text scaling up to 2.0x remains safe without overflow',
        (tester) async {
      const config = CodexHeaderConfig(
        title: 'A Very Long Screen Title Under Stress Scaling',
        icon: Icons.star,
        visibleCount: 1234,
      );

      await tester.pumpWidget(
        const MediaQuery(
          data: MediaQueryData(
            size: Size(320, 568),
            textScaler: TextScaler.linear(2.0),
          ),
          child: MaterialApp(
            home: Scaffold(
              appBar: PreferredSize(
                preferredSize: Size.fromHeight(56),
                child: SafeArea(child: CodexAppBarTitle(config: config)),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('1234'), findsOneWidget);
    });
  });

  group('CodexModeSelector Tests', () {
    testWidgets('chips style renders modes, shows counts, and reflects selection',
        (tester) async {
      _TestMode selected = _TestMode.alpha;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) {
                return CodexModeSelector<_TestMode>(
                  modes: const [
                    CodexViewMode(
                      key: _TestMode.alpha,
                      label: 'Alpha',
                      icon: Icons.looks_one,
                      count: 15,
                    ),
                    CodexViewMode(
                      key: _TestMode.beta,
                      label: 'Beta',
                      icon: Icons.looks_two,
                      count: 5,
                    ),
                  ],
                  selectedMode: selected,
                  style: CodexModeSelectorStyle.chips,
                  onModeSelected: (m) => setState(() => selected = m),
                );
              },
            ),
          ),
        ),
      );

      expect(find.text('Alpha'), findsOneWidget);
      expect(find.text('15'), findsOneWidget);
      expect(find.text('Beta'), findsOneWidget);
      expect(find.text('5'), findsOneWidget);

      // Verify semantics
      final alphaSemantics = find.byWidgetPredicate(
        (w) =>
            w is Semantics &&
            w.properties.button == true &&
            w.properties.selected == true &&
            w.properties.label == 'Alpha, 15 items',
      );
      expect(alphaSemantics, findsOneWidget);

      // Tap on Beta
      await tester.tap(find.text('Beta'));
      await tester.pumpAndSettle();

      expect(selected, equals(_TestMode.beta));
    });

    testWidgets('segmented style renders segments and fires onModeSelected',
        (tester) async {
      _TestMode selected = _TestMode.alpha;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) {
                return CodexModeSelector<_TestMode>(
                  modes: const [
                    CodexViewMode(
                      key: _TestMode.alpha,
                      label: 'Alpha',
                      icon: Icons.looks_one,
                    ),
                    CodexViewMode(
                      key: _TestMode.beta,
                      label: 'Beta',
                      icon: Icons.looks_two,
                    ),
                  ],
                  selectedMode: selected,
                  style: CodexModeSelectorStyle.segmented,
                  onModeSelected: (m) => setState(() => selected = m),
                );
              },
            ),
          ),
        ),
      );

      expect(find.byType(SegmentedButton<_TestMode>), findsOneWidget);

      await tester.tap(find.text('Beta'));
      await tester.pumpAndSettle();

      expect(selected, equals(_TestMode.beta));
    });
  });

  group('CodexFilterStrip Tests', () {
    testWidgets('renders options, icons, counts, and updates onSelected',
        (tester) async {
      _TestCategory selected = _TestCategory.martial;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) {
                return CodexFilterStrip<_TestCategory>(
                  options: const [
                    CodexFilterOption(
                      value: _TestCategory.martial,
                      label: 'Martial',
                      icon: Icons.fitness_center,
                    ),
                    CodexFilterOption(
                      value: _TestCategory.caster,
                      label: 'Caster',
                      icon: Icons.auto_fix_high,
                      count: 8,
                    ),
                  ],
                  selectedValue: selected,
                  onSelected: (val) => setState(() => selected = val),
                );
              },
            ),
          ),
        ),
      );

      expect(find.text('Martial'), findsOneWidget);
      expect(find.byIcon(Icons.fitness_center), findsOneWidget);
      expect(find.text('Caster'), findsOneWidget);
      expect(find.text('(8)'), findsOneWidget);

      // Verify semantics
      final casterSemantics = find.byWidgetPredicate(
        (w) =>
            w is Semantics &&
            w.properties.button == true &&
            w.properties.label == 'Caster, 8 available',
      );
      expect(casterSemantics, findsOneWidget);

      // Tap on Caster
      await tester.tap(find.text('Caster'));
      await tester.pumpAndSettle();

      expect(selected, equals(_TestCategory.caster));
    });

    testWidgets('deselection invokes onDeselected cleanly without unsafe casts',
        (tester) async {
      _TestCategory? selected = _TestCategory.martial;
      bool deselectedFired = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) {
                return CodexFilterStrip<_TestCategory>(
                  options: const [
                    CodexFilterOption(
                      value: _TestCategory.martial,
                      label: 'Martial',
                    ),
                    CodexFilterOption(
                      value: _TestCategory.caster,
                      label: 'Caster',
                    ),
                  ],
                  selectedValue: selected,
                  onSelected: (val) => setState(() => selected = val),
                  onDeselected: () {
                    deselectedFired = true;
                    setState(() => selected = null);
                  },
                );
              },
            ),
          ),
        ),
      );

      // Tap already selected Martial chip
      await tester.tap(find.text('Martial'));
      await tester.pumpAndSettle();

      expect(deselectedFired, isTrue);
      expect(selected, isNull);
    });

    testWidgets('CodexFilterStrip.optional factory deselects to null cleanly',
        (tester) async {
      String? selected = 'General';

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) {
                return CodexFilterStrip<String>.optional(
                  options: const [
                    CodexFilterOption(value: 'Origin', label: 'Origin'),
                    CodexFilterOption(value: 'General', label: 'General'),
                  ],
                  selectedValue: selected,
                  onSelected: (val) => setState(() => selected = val),
                );
              },
            ),
          ),
        ),
      );

      // Tap General to deselect it
      await tester.tap(find.text('General'));
      await tester.pumpAndSettle();

      expect(selected, isNull);

      // Tap Origin to select it
      await tester.tap(find.text('Origin'));
      await tester.pumpAndSettle();

      expect(selected, equals('Origin'));
    });
  });

  group('CodexPageShell Tests', () {
    testWidgets('renders all optional regions: context banner, header control, mode selector, filters',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: CodexPageShell(
            headerConfig: CodexHeaderConfig(
              title: 'Full Shell',
              icon: Icons.menu_book,
            ),
            headerControl: Text('Header Context Control'),
            sessionContextBanner: Text('Session Context Banner'),
            customBanner: Text('Custom Alert Banner'),
            searchHeader: Text('Search Bar Widget'),
            modeSelector: Text('View Mode Selector'),
            filterArea: Text('Primary Filter Strip'),
            secondaryFilterArea: Text('Secondary Filter Strip'),
            statusHeader: Text('Attribution Status Header'),
            content: Text('Content Grid Body'),
          ),
        ),
      );

      expect(find.text('Full Shell'), findsOneWidget);
      expect(find.text('Header Context Control'), findsOneWidget);
      expect(find.text('Session Context Banner'), findsOneWidget);
      expect(find.text('Custom Alert Banner'), findsOneWidget);
      expect(find.text('Search Bar Widget'), findsOneWidget);
      expect(find.text('View Mode Selector'), findsOneWidget);
      expect(find.text('Primary Filter Strip'), findsOneWidget);
      expect(find.text('Secondary Filter Strip'), findsOneWidget);
      expect(find.text('Attribution Status Header'), findsOneWidget);
      expect(find.text('Content Grid Body'), findsOneWidget);
    });

    testWidgets('works with only minimal required regions and no optionals',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: CodexPageShell(
            headerConfig: CodexHeaderConfig(title: 'Minimal Shell'),
            searchHeader: Text('Search Only'),
            content: Text('Content Only'),
          ),
        ),
      );

      expect(find.text('Minimal Shell'), findsOneWidget);
      expect(find.text('Search Only'), findsOneWidget);
      expect(find.text('Content Only'), findsOneWidget);
    });

    testWidgets('switches between content and empty state based on isEmpty',
        (tester) async {
      bool empty = false;

      await tester.pumpWidget(
        MaterialApp(
          home: StatefulBuilder(
            builder: (context, setState) {
              return CodexPageShell(
                headerConfig: const CodexHeaderConfig(title: 'Toggle Shell'),
                searchHeader: const Text('Search'),
                isEmpty: empty,
                emptyState: const Text('Empty State Card'),
                content: const Text('Main Content Grid'),
                floatingActionButton: FloatingActionButton(
                  onPressed: () => setState(() => empty = !empty),
                  child: const Icon(Icons.toggle_on),
                ),
              );
            },
          ),
        ),
      );

      expect(find.text('Main Content Grid'), findsOneWidget);
      expect(find.text('Empty State Card'), findsNothing);

      await tester.tap(find.byType(FloatingActionButton));
      await tester.pumpAndSettle();

      expect(find.text('Empty State Card'), findsOneWidget);
      expect(find.text('Main Content Grid'), findsNothing);
    });

    testWidgets('narrow layout (320dp) and 2.0x text scaling do not overflow',
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
                title: 'Extended Codex Title Under Scaled Viewport',
                icon: Icons.shield,
                visibleCount: 9999,
              ),
              headerControl: const Icon(Icons.tune),
              sessionContextBanner: const Text('Session Connected'),
              searchHeader: const TextField(
                decoration: InputDecoration(hintText: 'Search query...'),
              ),
              modeSelector: CodexModeSelector<String>(
                modes: const [
                  CodexViewMode(key: '1', label: 'Long Tab One', icon: Icons.star, count: 50),
                  CodexViewMode(key: '2', label: 'Long Tab Two', icon: Icons.star, count: 20),
                ],
                selectedMode: '1',
                onModeSelected: (_) {},
              ),
              filterArea: CodexFilterStrip<String>(
                options: const [
                  CodexFilterOption(value: 'a', label: 'Filter Alpha'),
                  CodexFilterOption(value: 'b', label: 'Filter Beta'),
                ],
                selectedValue: 'a',
                onSelected: (_) {},
              ),
              content: ListView(
                children: const [
                  ListTile(title: Text('Result 1')),
                  ListTile(title: Text('Result 2')),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.byType(CodexPageShell), findsOneWidget);
      expect(find.text('Result 1'), findsOneWidget);
    });
  });
}
