// ignore_for_file: avoid_print
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dangerously_nerdy_5e_toolkit/screens/character_sheet_view.dart';
import 'package:dangerously_nerdy_5e_toolkit/screens/character_builder_screen.dart';
import 'package:dangerously_nerdy_5e_toolkit/services/persistence/character_persistence_service.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/domain/character_models.dart';
import 'package:dangerously_nerdy_5e_toolkit/infrastructure/dtos/character_dto.dart';
import 'package:dangerously_nerdy_5e_toolkit/providers/character_sheet_controller.dart';
import 'package:dangerously_nerdy_5e_toolkit/services/rules/character_actions_resolver.dart';
import 'package:dangerously_nerdy_5e_toolkit/services/rules/character_evaluation_engine.dart';
import 'package:vtt_engine_core/crdt/replica_id.dart';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:dangerously_nerdy_5e_toolkit/services/persistence/app_database_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Legacy Character Regression Staged Diagnosis', () {
    late Map<String, dynamic> raw;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      await AppDatabaseService.instance.resetForTesting();
    });

    setUpAll(() {
      final file = File('test/fixtures/legacy_character_regression.json');
      raw = json.decode(file.readAsStringSync()) as Map<String, dynamic>;
    });

    test('STAGE A: raw DTO and domain deserialization', () {
      print('Executing STAGE A: raw DTO/domain deserialization');
      // 1. DTO deserialization
      final dto = CharacterDto.fromMap(raw);
      expect(dto.name, equals('Legacy Adventurer'));
      final fromDto = dto.toDomain();
      expect(fromDto.name, equals('Legacy Adventurer'));

      // 2. Production Character.fromMap route
      final character = Character.fromMap(raw);
      expect(character.name, equals('Legacy Adventurer'));
      print('STAGE A PASSED');
    });

    test('STAGE B: serialization round trip', () {
      print('Executing STAGE B: serialization round trip');
      final character = Character.fromMap(raw);
      final serialized = character.toMap();
      expect(serialized, isNotNull);
      print('STAGE B PASSED');
    });

    test('STAGE C: character evaluation', () {
      print('Executing STAGE C: CharacterEvaluationEngine.evaluate');
      final character = Character.fromMap(raw);
      final stats = CharacterEvaluationEngine.evaluate(character);
      expect(stats, isNotNull);
      print('STAGE C PASSED: AC=${stats.armorClass}, HP=${stats.maxHp}');
    });

    test('STAGE D: CharacterSheetController construction', () {
      print('Executing STAGE D: CharacterSheetController construction');
      final character = Character.fromMap(raw);
      final controller = CharacterSheetController(
        character: character,
        replicaId: ReplicaId('test_stage_d_replica'),
      );
      expect(controller.character.name, equals('Legacy Adventurer'));
      print('STAGE D PASSED');
    });

    test('STAGE E: character-sheet dependent resolvers', () {
      print('Executing STAGE E: character-sheet dependent resolvers');
      final character = Character.fromMap(raw);
      final controller = CharacterSheetController(
        character: character,
        replicaId: ReplicaId('test_stage_e_replica'),
      );

      print('Testing CharacterActionsResolver.resolve...');
      final actions = CharacterActionsResolver.resolve(
        character: character,
        stats: controller.stats,
        controller: controller,
      );
      expect(actions, isNotNull);
      print('CharacterActionsResolver passed: ${actions.allActions.length} actions');

      print('STAGE E PASSED');
    });

    testWidgets('STAGE F: Pumping CharacterSheetView with legacy character and switching tabs',
        (tester) async {
      print('Executing STAGE F: Pumping CharacterSheetView and switching tabs');
      tester.view.physicalSize = const Size(1200, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final character = Character.fromMap(raw);
      final controller = CharacterSheetController(
        character: character,
        replicaId: ReplicaId('test_stage_f_replica'),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: CharacterSheetView(
            character: character,
            controller: controller,
          ),
        ),
      );
      await tester.pumpAndSettle();
      print('Tab 1 (Actions) rendered');

      // Click Spells tab
      await tester.tap(find.text('Spells'));
      await tester.pumpAndSettle();
      print('Tab 2 (Spells) rendered');

      // Click Skills tab
      await tester.tap(find.text('Skills'));
      await tester.pumpAndSettle();
      print('Tab 3 (Skills) rendered');

      // Click Traits tab
      await tester.tap(find.text('Traits'));
      await tester.pumpAndSettle();
      print('Tab 4 (Traits) rendered');

      // Click Inventory tab
      await tester.tap(find.text('Inventory'));
      await tester.pumpAndSettle();
      print('Tab 5 (Inventory) rendered');
    });

    testWidgets(
        'STAGE G: Pumping CharacterBuilderScreen with persisted legacy roster',
        (tester) async {
      print('Executing STAGE G: Pumping CharacterBuilderScreen');
      tester.view.physicalSize = const Size(1200, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final character = Character.fromMap(raw);
      await CharacterPersistenceService().saveRoster([character]);
      await CharacterPersistenceService().saveActiveCharacterId('legacy-adventurer');

      await tester.pumpWidget(
        const MaterialApp(
          home: CharacterBuilderScreen(),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      print('CharacterBuilderScreen pumped');
      // If in selector view, tap Open Sheet on legacy-adventurer
      final openBtn = find.byKey(const ValueKey('open_sheet_legacy-adventurer'));
      if (openBtn.evaluate().isNotEmpty) {
        print('Found open_sheet_legacy-adventurer, tapping it...');
        await tester.tap(openBtn);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 200));
      }

      print('STAGE G complete. Testing elements...');
      expect(find.text('Legacy Adventurer'), findsWidgets);
    });

    test('STAGE H: One corrupt record does NOT erase healthy roster records',
        () async {
      print('Executing STAGE H: Roster failure isolation');
      final healthy = Character.fromMap(raw);
      final corrupt = <String, dynamic>{
        'id': 'corrupt-character',
        'name': 'Corrupt One',
        'speciesRef': 'not-a-map-causing-exception',
      };

      // Save raw database roster with both
      await AppDatabaseService.instance.put(
        AppDatabaseService.boxCharacters,
        'saved_characters_roster_v1',
        [healthy.toMap(), corrupt],
      );

      final loaded = await CharacterPersistenceService().loadCharacters();
      expect(loaded.length, equals(1));
      expect(loaded.first.id.slug, equals('legacy-adventurer'));
      expect(loaded.first.name, equals('Legacy Adventurer'));
      print('STAGE H PASSED: Healthy character preserved despite corrupt entry!');
    });
  });
}
