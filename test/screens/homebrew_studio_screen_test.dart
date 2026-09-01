import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/domain/core_types.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/domain/spell_monster_equipment.dart';
import 'package:dangerously_nerdy_5e_toolkit/screens/homebrew_studio_screen.dart';
import 'package:dangerously_nerdy_5e_toolkit/services/persistence/homebrew_persistence_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('HomebrewStudioScreen Widget Tests', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
      HomebrewPersistenceService().clearAllHomebrew();
    });

    testWidgets('renders Homebrew Studio tabs and empty states', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: HomebrewStudioScreen(),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Homebrew Studio'), findsOneWidget);
      expect(find.text('Spells (0)'), findsOneWidget);
      expect(find.text('Monsters (0)'), findsOneWidget);
      expect(find.text('Items (0)'), findsOneWidget);
      expect(find.text('No Custom Spells'), findsOneWidget);
      expect(find.byType(FloatingActionButton), findsOneWidget);
    });

    testWidgets('opens SpellBuilderDialog on New Spell tap and saves spell', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: HomebrewStudioScreen(),
        ),
      );
      await tester.pumpAndSettle();

      // Tap FloatingActionButton
      await tester.tap(find.byType(FloatingActionButton));
      await tester.pumpAndSettle();

      expect(find.text('Create Custom Spell'), findsOneWidget);
      expect(find.text('Spell Name'), findsOneWidget);

      // Enter spell name
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Spell Name'),
        'Solar Flare',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Spell Description (Markdown supported)'),
        'Blasts radiant solar light in a 30ft cone.',
      );
      await tester.pumpAndSettle();

      // Tap Save Spell
      await tester.tap(find.text('Save Spell'));
      await tester.pumpAndSettle();

      // Verify saved in list
      expect(find.text('Solar Flare'), findsOneWidget);
      expect(find.textContaining('Evocation'), findsOneWidget);

      // Verify stored in persistence
      final saved = await HomebrewPersistenceService().loadCustomSpells();
      expect(saved.length, equals(1));
      expect(saved.first.name, equals('Solar Flare'));
      expect(saved.first.slug, equals('solar-flare'));
    });

    testWidgets('opens HomebrewImportPreviewDialog and parses compendium JSON', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: HomebrewStudioScreen(),
        ),
      );
      await tester.pumpAndSettle();

      // Tap import icon button in AppBar
      await tester.tap(find.byIcon(Icons.file_download_outlined));
      await tester.pumpAndSettle();

      expect(find.text('Import Homebrew / Compendium JSON'), findsOneWidget);

      const jsonSnippet = '{"spell":[{"name":"Frost Nova","source":"HOMEBREW","level":3,"school":"V","time":[{"number":1,"unit":"action"}],"range":{"type":"point","distance":{"type":"feet","amount":30}},"components":{"v":true,"s":true},"duration":[{"type":"instant"}],"entries":["Freezes ground dealing {@damage 6d6|cold} damage."]}]}';

      await tester.enterText(find.byType(TextField), jsonSnippet);
      await tester.pumpAndSettle();

      // Tap Analyze Bundle button
      await tester.tap(find.text('Analyze Bundle'));
      await tester.pumpAndSettle();

      expect(find.text('1 New'), findsOneWidget);
      expect(find.text('Spells (1/1)'), findsOneWidget);
      expect(find.text('Frost Nova'), findsOneWidget);

      // Tap Confirm Import button
      await tester.tap(find.text('Confirm Import (1 items)'));
      await tester.pumpAndSettle();

      // Verify imported spell appears on screen
      expect(find.text('Frost Nova'), findsOneWidget);
    });

    testWidgets('imports multi-category bundle including classes, races, and feats with deduplication', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: HomebrewStudioScreen(),
        ),
      );
      await tester.pumpAndSettle();

      // Open import dialog
      await tester.tap(find.byIcon(Icons.file_download_outlined));
      await tester.pumpAndSettle();

      const multiBundle = '''
{
  "class": [{"name": "Blood Hunter", "hd": {"faces": 10}, "classFeatures": ["Crimson Rite: Enhance weapons"]}],
  "race": [{"name": "Genasi", "size": "Medium", "trait": ["Elemental Heritage: Innate power"]}],
  "feat": [{"name": "Fey Touched", "category": "General", "entries": ["Cast Misty Step once per long rest."]}]
}
''';

      await tester.enterText(find.byType(TextField), multiBundle);
      await tester.pumpAndSettle();

      // Tap Analyze Bundle
      await tester.tap(find.text('Analyze Bundle'));
      await tester.pumpAndSettle();

      expect(find.text('3 New'), findsOneWidget);
      expect(find.text('Classes (1/1)'), findsOneWidget);
      expect(find.text('Races & Species (1/1)'), findsOneWidget);
      expect(find.text('Feats (1/1)'), findsOneWidget);

      await tester.tap(find.text('Confirm Import (3 items)'));
      await tester.pumpAndSettle();

      expect(find.textContaining('Classes (1)'), findsOneWidget);
      expect(find.textContaining('Races (1)'), findsOneWidget);
      expect(find.textContaining('Feats (1)'), findsOneWidget);
    });

    testWidgets('opens HomebrewExportDialog and generates bundle JSON', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: HomebrewStudioScreen(),
        ),
      );
      await tester.pumpAndSettle();

      // Tap export icon button in AppBar
      await tester.tap(find.byIcon(Icons.file_upload_outlined));
      await tester.pumpAndSettle();

      expect(find.text('Export Homebrew Pack'), findsOneWidget);
      expect(find.text('Bundle Name'), findsOneWidget);
      expect(find.text('Include Categories:'), findsOneWidget);

      // Tap Generate Bundle
      await tester.tap(find.text('Generate Bundle'));
      await tester.pumpAndSettle();

      expect(find.text('Bundle Generated'), findsOneWidget);
      expect(find.text('Copy to Clipboard'), findsOneWidget);
    });

    testWidgets('opens HomebrewRefresherDialog and executes reparse', (tester) async {
      // Pre-populate with a custom spell having raw JSON
      final persistence = HomebrewPersistenceService();
      await persistence.saveCustomSpellsBatch(
        [],
      );

      await tester.pumpWidget(
        const MaterialApp(
          home: HomebrewStudioScreen(),
        ),
      );
      await tester.pumpAndSettle();

      // Tap JSON Refresher icon button in AppBar
      await tester.tap(find.byIcon(Icons.auto_fix_high));
      await tester.pumpAndSettle();

      expect(find.text('JSON Refresher & AST Upgrade'), findsOneWidget);
      expect(find.text('Storage Overview'), findsOneWidget);

      // Tap Cancel to close
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(find.text('JSON Refresher & AST Upgrade'), findsNothing);
    });

    testWidgets('opens HomebrewBulkDeleterDialog and executes category deletion', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: HomebrewStudioScreen(),
        ),
      );
      await tester.pumpAndSettle();

      // Tap Bulk Deleter icon button in AppBar
      await tester.tap(find.byIcon(Icons.delete_sweep_outlined));
      await tester.pumpAndSettle();

      expect(find.text('Bulk Homebrew Deleter'), findsOneWidget);
      expect(find.text('Spells & Cantrips'), findsOneWidget);
      expect(find.text('Monsters & NPCs'), findsOneWidget);

      // Tap Cancel to close
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(find.text('Bulk Homebrew Deleter'), findsNothing);
    });

    testWidgets('supports in-tab multi-select mode and batch item deletion', (tester) async {
      // Pre-populate 2 custom spells
      final persistence = HomebrewPersistenceService();
      await persistence.saveCustomSpellsBatch(
        [
          const Spell(
            id: EntityId(slug: 'spell-a', ruleset: RulesetVersion.homebrew),
            name: 'Spell Alpha',
            level: 1,
            school: 'Evocation',
            castingTime: CastingTime(cost: 1, actionType: ActionType.action),
            duration: SpellDuration(type: DurationType.instantaneous),
            range: '30 ft',
            components: SpellComponents(),
            descriptionMarkdown: 'Alpha',
          ),
          const Spell(
            id: EntityId(slug: 'spell-b', ruleset: RulesetVersion.homebrew),
            name: 'Spell Beta',
            level: 2,
            school: 'Abjuration',
            castingTime: CastingTime(cost: 1, actionType: ActionType.action),
            duration: SpellDuration(type: DurationType.instantaneous),
            range: '60 ft',
            components: SpellComponents(),
            descriptionMarkdown: 'Beta',
          ),
        ],
      );

      await tester.pumpWidget(
        const MaterialApp(
          home: HomebrewStudioScreen(),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Spell Alpha'), findsOneWidget);
      expect(find.text('Spell Beta'), findsOneWidget);

      // Enter Select Mode
      await tester.tap(find.text('Select Mode'));
      await tester.pumpAndSettle();

      expect(find.text('Selected: 0 / 2'), findsOneWidget);

      // Tap Spell Alpha to select it
      await tester.tap(find.text('Spell Alpha'));
      await tester.pumpAndSettle();

      expect(find.text('Selected: 1 / 2'), findsOneWidget);
      expect(find.text('Delete (1)'), findsOneWidget);

      // Tap Delete (1)
      await tester.tap(find.text('Delete (1)'));
      await tester.pumpAndSettle();

      expect(find.text('Delete Selected Items?'), findsOneWidget);

      // Confirm deletion
      await tester.tap(find.widgetWithText(FilledButton, 'Delete 1 Items'));
      await tester.pumpAndSettle();

      // Verify Spell Alpha was deleted and Spell Beta remains
      expect(find.text('Spell Alpha'), findsNothing);
      expect(find.text('Spell Beta'), findsOneWidget);
    });
  });
}
