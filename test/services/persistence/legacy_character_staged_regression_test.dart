// ignore_for_file: avoid_print
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dangerously_nerdy_5e_toolkit/screens/character_sheet_view.dart';
import 'package:dangerously_nerdy_5e_toolkit/screens/character_builder_screen.dart';
import 'package:dangerously_nerdy_5e_toolkit/services/persistence/character_persistence_service.dart';
import 'package:dangerously_nerdy_5e_toolkit/infrastructure/repositories/local_character_repository.dart';
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

    test('STAGE B: rigorous JSON round trip with canonical equippedSlot', () {
      print('Executing STAGE B: rigorous JSON round trip');
      final character = Character.fromMap(raw);

      // Verify deserialized runtime representation
      final equippedItems = character.inventory.where((i) => i.isEquipped).toList();
      expect(equippedItems, isNotEmpty);
      for (final item in equippedItems) {
        expect(item.equippedSlot, isA<EquipmentSlot>(),
            reason: 'Item ${item.instanceId} (${item.displayName}) must have EquipmentSlot runtime type');
      }

      // Verify specific known fixture slot values
      final pearl = character.inventory.firstWhere((i) => i.instanceId == 'item-3');
      expect(pearl.equippedSlot, equals(EquipmentSlot.wondrous));
      final breastplate = character.inventory.firstWhere((i) => i.instanceId == 'item-4');
      expect(breastplate.equippedSlot, equals(EquipmentSlot.armor));
      final shield = character.inventory.firstWhere((i) => i.instanceId == 'item-5');
      expect(shield.equippedSlot, equals(EquipmentSlot.shield));
      final boots = character.inventory.firstWhere((i) => i.instanceId == 'item-6');
      expect(boots.equippedSlot, equals(EquipmentSlot.boots));

      // 1. Serialization
      final serializedMap = character.toMap();
      final serializedInventory =
          (serializedMap['inventory'] as List).cast<Map<String, dynamic>>();

      for (final itemMap in serializedInventory) {
        final slot = itemMap['equippedSlot'];
        expect(slot == null || slot is String, isTrue,
            reason: 'Persisted equippedSlot must be a String or null, never an Enum object');
      }

      final pMap = serializedInventory.firstWhere((i) => i['instanceId'] == 'item-3');
      expect(pMap['equippedSlot'], equals('wondrous'));
      final bMap = serializedInventory.firstWhere((i) => i['instanceId'] == 'item-4');
      expect(bMap['equippedSlot'], equals('armor'));
      final sMap = serializedInventory.firstWhere((i) => i['instanceId'] == 'item-5');
      expect(sMap['equippedSlot'], equals('shield'));
      final btMap = serializedInventory.firstWhere((i) => i['instanceId'] == 'item-6');
      expect(btMap['equippedSlot'], equals('boots'));

      // 2. JSON Encoding must succeed without any enum conversion errors
      final jsonEncoded = jsonEncode(serializedMap);
      expect(jsonEncoded, isA<String>());
      expect(jsonEncoded, contains('"equippedSlot":"wondrous"'));
      expect(jsonEncoded, contains('"equippedSlot":"armor"'));
      expect(jsonEncoded, contains('"equippedSlot":"shield"'));
      expect(jsonEncoded, contains('"equippedSlot":"boots"'));

      // 3. JSON Decoding & Second Deserialization
      final decodedJson = jsonDecode(jsonEncoded) as Map<String, dynamic>;
      final restored = Character.fromMap(decodedJson);

      expect(restored.inventory.length, equals(character.inventory.length));
      for (var i = 0; i < character.inventory.length; i++) {
        final orig = character.inventory[i];
        final rest = restored.inventory[i];
        expect(rest.isEquipped, equals(orig.isEquipped));
        expect(rest.equippedSlot, equals(orig.equippedSlot));
      }

      final restoredPearl = restored.inventory.firstWhere((i) => i.instanceId == 'item-3');
      expect(restoredPearl.equippedSlot, equals(EquipmentSlot.wondrous));
      final restoredBreastplate = restored.inventory.firstWhere((i) => i.instanceId == 'item-4');
      expect(restoredBreastplate.equippedSlot, equals(EquipmentSlot.armor));
      final restoredShield = restored.inventory.firstWhere((i) => i.instanceId == 'item-5');
      expect(restoredShield.equippedSlot, equals(EquipmentSlot.shield));
      final restoredBoots = restored.inventory.firstWhere((i) => i.instanceId == 'item-6');
      expect(restoredBoots.equippedSlot, equals(EquipmentSlot.boots));

      print('STAGE B PASSED: Rigorous JSON round-trip validated');
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

      // Invariant assertion: all equipped items must be canonical EquipmentSlot
      for (final item in character.inventory.where((i) => i.isEquipped)) {
        expect(item.equippedSlot, isA<EquipmentSlot>());
      }

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
      // Invariant assertion: all equipped items must be canonical EquipmentSlot
      for (final item in character.inventory.where((i) => i.isEquipped)) {
        expect(item.equippedSlot, isA<EquipmentSlot>());
      }

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

    test('STAGE H: Failed-record preservation across unrelated writes (CharacterPersistenceService)',
        () async {
      print('Executing STAGE H: Failed-record preservation across unrelated writes');
      final healthy = Character.fromMap(raw);
      final corrupt = <String, dynamic>{
        'id': 'corrupt-character',
        'name': 'Corrupt One',
        'speciesRef': 'not-a-map-causing-exception',
      };

      // 1. Seed raw database roster with both healthy and corrupt records
      await AppDatabaseService.instance.put(
        AppDatabaseService.boxCharacters,
        'saved_characters_roster_v1',
        [healthy.toMap(), corrupt],
      );

      // 2. Verify loadCharacters loads the healthy record and safely skips corrupt record
      final loaded = await CharacterPersistenceService().loadCharacters();
      expect(loaded.length, equals(1));
      expect(loaded.first.id.slug, equals('legacy-adventurer'));

      // 3. Modify and save ONLY the healthy character
      final modifiedHealthy = healthy.copyWith(name: 'Renamed Adventurer');
      await CharacterPersistenceService().saveCharacter(modifiedHealthy);

      // 4. Inspect raw persisted database directly to verify malformed record is RETAINED
      final rawPersisted = AppDatabaseService.instance.get(
        AppDatabaseService.boxCharacters,
        'saved_characters_roster_v1',
      ) as List<dynamic>;

      expect(rawPersisted.length, equals(2),
          reason: 'Raw database must contain both the updated healthy character and the malformed record');

      final persistedHealthy = rawPersisted[0] as Map<dynamic, dynamic>;
      final persistedCorrupt = rawPersisted[1] as Map<dynamic, dynamic>;

      expect(persistedHealthy['name'], equals('Renamed Adventurer'));
      expect(persistedCorrupt['id'], equals('corrupt-character'));
      expect(persistedCorrupt['speciesRef'], equals('not-a-map-causing-exception'));

      // 5. Reload characters and verify application remains fully operational
      final reloaded = await CharacterPersistenceService().loadCharacters();
      expect(reloaded.length, equals(1));
      expect(reloaded.first.name, equals('Renamed Adventurer'));
      print('STAGE H PASSED: Corrupt record preserved across saveCharacter in CharacterPersistenceService!');
    });

    test('STAGE I: Failed-record preservation across unrelated writes (LocalCharacterRepository)',
        () async {
      print('Executing STAGE I: Failed-record preservation across unrelated writes in LocalCharacterRepository');
      final healthy = Character.fromMap(raw);
      final corrupt = <String, dynamic>{
        'id': 'corrupt-character-repo',
        'name': 'Corrupt Repo One',
        'speciesRef': 'invalid-type-triggering-failure',
      };

      final repo = LocalCharacterRepository();

      // Seed database with both
      await AppDatabaseService.instance.put(
        AppDatabaseService.boxCharacters,
        'saved_characters_roster_v1',
        [healthy.toMap(), corrupt],
      );

      // Load characters
      final loaded = await repo.loadCharacters();
      expect(loaded.length, equals(1));
      expect(loaded.first.id.slug, equals('legacy-adventurer'));

      // Modify and save ONLY healthy character
      final modified = healthy.copyWith(name: 'Renamed Adventurer Repo');
      await repo.saveCharacter(modified);

      // Inspect raw database directly
      final rawPersisted = AppDatabaseService.instance.get(
        AppDatabaseService.boxCharacters,
        'saved_characters_roster_v1',
      ) as List<dynamic>;

      expect(rawPersisted.length, equals(2));
      final persistedHealthy = rawPersisted[0] as Map<dynamic, dynamic>;
      final persistedCorrupt = rawPersisted[1] as Map<dynamic, dynamic>;

      expect(persistedHealthy['name'], equals('Renamed Adventurer Repo'));
      expect(persistedCorrupt['id'], equals('corrupt-character-repo'));

      final reloaded = await repo.loadCharacters();
      expect(reloaded.length, equals(1));
      expect(reloaded.first.name, equals('Renamed Adventurer Repo'));
      print('STAGE I PASSED: Corrupt record preserved in LocalCharacterRepository!');
    });
  });
}
