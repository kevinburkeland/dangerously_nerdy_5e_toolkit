import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/domain/core_types.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/domain/homebrew_extended_entities.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/domain/spell_monster_equipment.dart';
import 'package:dangerously_nerdy_5e_toolkit/services/acl/homebrew_merge_resolver.dart';
import 'package:dangerously_nerdy_5e_toolkit/services/persistence/homebrew_persistence_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Homebrew Ingestion & Batch Performance Tests', () {
    late HomebrewPersistenceService persistence;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      persistence = HomebrewPersistenceService();
    });

    test('saveCustomSpellsBatch merges into existing spells with O(1) lookup and batch raw payloads', () async {
      // 1. Seed 10 existing spells
      final existingSpells = List<Spell>.generate(
        10,
        (i) => Spell(
          id: EntityId(slug: 'existing-spell-$i', ruleset: RulesetVersion.homebrew),
          name: 'Existing Spell $i',
          level: 1,
          school: 'Evocation',
          castingTime: const CastingTime(cost: 1, actionType: ActionType.action),
          duration: const SpellDuration(type: DurationType.instantaneous),
          range: '60 ft',
          components: const SpellComponents(v: true),
          descriptionMarkdown: 'Initial spell $i',
        ),
      );
      await persistence.saveCustomSpellsBatch(existingSpells);
      expect((await persistence.loadCustomSpells()).length, equals(10));

      // 2. Incoming batch of 20 spells (5 updates to existing, 15 new ones)
      final incomingSpells = <Spell>[
        // 5 updates
        for (int i = 0; i < 5; i++)
          Spell(
            id: EntityId(slug: 'existing-spell-$i', ruleset: RulesetVersion.homebrew),
            name: 'Updated Spell $i',
            level: 2,
            school: 'Abjuration',
            castingTime: const CastingTime(cost: 1, actionType: ActionType.action),
            duration: const SpellDuration(type: DurationType.instantaneous),
            range: '90 ft',
            components: const SpellComponents(v: true),
            descriptionMarkdown: 'Updated description $i',
          ),
        // 15 new spells
        for (int i = 10; i < 25; i++)
          Spell(
            id: EntityId(slug: 'new-spell-$i', ruleset: RulesetVersion.homebrew),
            name: 'New Spell $i',
            level: 3,
            school: 'Transmutation',
            castingTime: const CastingTime(cost: 1, actionType: ActionType.action),
            duration: const SpellDuration(type: DurationType.instantaneous),
            range: '30 ft',
            components: const SpellComponents(v: true, s: true),
            descriptionMarkdown: 'Brand new spell $i',
          ),
      ];

      final rawPayloads = [
        for (final s in incomingSpells) {'name': s.name, 'slug': s.id.slug, 'source': 'HB'},
      ];

      await persistence.saveCustomSpellsBatch(incomingSpells, rawPayloads: rawPayloads);

      final result = await persistence.loadCustomSpells();
      expect(result.length, equals(25)); // 10 original - 5 updated + 15 new + 5 kept = 25 total

      final updatedZero = result.firstWhere((s) => s.id.slug == 'existing-spell-0');
      expect(updatedZero.name, equals('Updated Spell 0'));
      expect(updatedZero.level, equals(2));

      final keptNine = result.firstWhere((s) => s.id.slug == 'existing-spell-9');
      expect(keptNine.name, equals('Existing Spell 9'));
      expect(keptNine.level, equals(1));

      final newSpellTen = result.firstWhere((s) => s.id.slug == 'new-spell-10');
      expect(newSpellTen.name, equals('New Spell 10'));
      expect(newSpellTen.level, equals(3));
    });

    test('saveCustomOtherEntriesBatch saves generic entries and updates invocations', () async {
      final entries = [
        const HomebrewCompendiumEntry(
          id: EntityId(slug: 'hb-eldritch-sight-extra', ruleset: RulesetVersion.homebrew),
          name: 'Eldritch Sight Extra',
          category: 'Eldritch Invocation',
          descriptionMarkdown: 'You can cast detect magic at will without expending a spell slot.',
        ),
        const HomebrewCompendiumEntry(
          id: EntityId(slug: 'hb-critical-fumble-table', ruleset: RulesetVersion.homebrew),
          name: 'Critical Fumble Table',
          category: 'Rule Tables',
          descriptionMarkdown: '| Roll | Effect |',
        ),
      ];

      await persistence.saveCustomOtherEntriesBatch(entries);

      final loaded = await persistence.loadCustomOtherEntries();
      expect(loaded.length, equals(2));
      expect(loaded.any((e) => e.name == 'Eldritch Sight Extra'), isTrue);
      expect(loaded.any((e) => e.name == 'Critical Fumble Table'), isTrue);
    });

    test('importResolvedBundle processes categories in-memory with single disk transaction and progress ticks', () async {
      // Pre-seed database with 5 existing items
      final preExistingItems = List<EquipmentItem>.generate(
        5,
        (i) => EquipmentItem(
          id: EntityId(slug: 'item-$i', ruleset: RulesetVersion.homebrew),
          name: 'Pre-existing Item $i',
          itemType: 'Weapon',
          rarity: 'Common',
          requiresAttunement: false,
          descriptionMarkdown: 'Description $i',
        ),
      );
      await persistence.saveCustomItemsBatch(preExistingItems);

      // Create import items: 1 keepLocal, 1 duplicateRename, 3 new additions
      final incoming = [
        // 1 collided keepLocal (should NOT overwrite or be added)
        ImportAnalysisItem<EquipmentItem>(
          incomingEntity: const EquipmentItem(
            id: EntityId(slug: 'item-0', ruleset: RulesetVersion.homebrew),
            name: 'Incoming Item 0 Should Be Ignored',
            itemType: 'Weapon',
            rarity: 'Common',
            requiresAttunement: false,
            descriptionMarkdown: 'Ignored description',
          ),
          disposition: ImportDisposition.collision,
          resolution: CollisionResolution.keepLocal,
          isSelected: true,
        ),
        // 1 collided duplicateRename (should be renamed to Copy)
        ImportAnalysisItem<EquipmentItem>(
          incomingEntity: const EquipmentItem(
            id: EntityId(slug: 'item-1', ruleset: RulesetVersion.homebrew),
            name: 'Incoming Item 1',
            itemType: 'Weapon',
            rarity: 'Common',
            requiresAttunement: false,
            descriptionMarkdown: 'Renamed description',
          ),
          disposition: ImportDisposition.collision,
          resolution: CollisionResolution.duplicateRename,
          isSelected: true,
        ),
        // 3 new additions
        for (int i = 10; i < 13; i++)
          ImportAnalysisItem<EquipmentItem>(
            incomingEntity: EquipmentItem(
              id: EntityId(slug: 'item-$i', ruleset: RulesetVersion.homebrew),
              name: 'New Item $i',
              itemType: 'Armor',
              rarity: 'Uncommon',
              requiresAttunement: false,
              descriptionMarkdown: 'New armor $i',
            ),
            disposition: ImportDisposition.novel,
            resolution: CollisionResolution.overwrite,
            isSelected: true,
          ),
      ];

      final resolution = ImportAnalysisResult(
        items: incoming,
      );

      final progressTicks = <int>[];
      await persistence.importResolvedBundle(
        resolution,
        onProgress: (saved, total, phase) {
          progressTicks.add(saved);
        },
      );

      // Verify progress ticks fired for the items that were processed (4 items: 1 rename + 3 new)
      expect(progressTicks.isNotEmpty, isTrue);

      final savedItems = await persistence.loadCustomItems();
      // 5 pre-existing + 1 renamed copy + 3 new = 9 total
      expect(savedItems.length, equals(9));

      // Item 0 was keepLocal, so original name is preserved
      final itemZero = savedItems.firstWhere((i) => i.id.slug == 'item-0');
      expect(itemZero.name, equals('Pre-existing Item 0'));

      // Item 1 copy was created with unique slug
      final renamedItem = savedItems.firstWhere((i) => i.id.slug == 'item-1-copy');
      expect(renamedItem.name, equals('Incoming Item 1 (Copy)'));

      // New items exist
      expect(savedItems.any((i) => i.id.slug == 'item-10'), isTrue);
      expect(savedItems.any((i) => i.id.slug == 'item-11'), isTrue);
      expect(savedItems.any((i) => i.id.slug == 'item-12'), isTrue);
    });
  });
}
