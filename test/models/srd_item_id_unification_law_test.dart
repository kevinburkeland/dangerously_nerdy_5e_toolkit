import 'dart:convert';
import 'dart:io';

import 'package:dangerously_nerdy_5e_toolkit/infrastructure/dtos/character_telemetry_dto.dart';
import 'package:dangerously_nerdy_5e_toolkit/infrastructure/resolvers/character_telemetry_resolver.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/characters/srd_equipment_library.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/domain/character_models.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/domain/core_types.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/magic_items/magic_item_library.dart';
import 'package:dangerously_nerdy_5e_toolkit/services/acl/srd_equivalence_index.dart';
import 'package:dangerously_nerdy_5e_toolkit/services/persistence/app_database_service.dart';
import 'package:dangerously_nerdy_5e_toolkit/services/persistence/homebrew_persistence_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../test_doubles/hive_test_harness.dart';

void main() {
  final hive = HiveTestHarness();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await hive.setUpInMemory();
    MagicItemLibrary.setHomebrewItems(const []);
  });

  tearDown(() async {
    MagicItemLibrary.setHomebrewItems(const []);
    await hive.tearDown();
  });

  group('Fix 3.1: One id per SRD bundled item', () {
    test(
        'Law (a): every bundled item id resolves across catalog, rules view, and equivalence index to the same item',
        () {
      final index = SrdEquivalenceIndex()..build();
      final catalogItems = MagicItemLibrary.baseItems;
      final rulesViewItems = SrdEquipmentLibrary.baseEquipmentItems;

      expect(rulesViewItems.length, equals(catalogItems.length));

      final mismatches = <String>[];
      for (var i = 0; i < catalogItems.length; i++) {
        final cat = catalogItems[i];
        final rulesItem = rulesViewItems[i];

        if (cat.id.slug.contains('-')) {
          mismatches.add('Bundled catalog item "${cat.id.slug}" contains hyphen');
        }
        if (rulesItem.id.slug != cat.id.slug) {
          mismatches.add(
            'Rules view id "${rulesItem.id.slug}" != catalog id "${cat.id.slug}"',
          );
        }

        final viaCatByRulesId = MagicItemLibrary.findById(rulesItem.id.slug);
        if (viaCatByRulesId == null) {
          mismatches.add(
            'MagicItemLibrary.findById("${rulesItem.id.slug}") returned null for "${cat.name}"',
          );
        } else if (viaCatByRulesId.id.slug != cat.id.slug ||
            viaCatByRulesId.name != cat.name) {
          mismatches.add(
            'MagicItemLibrary.findById("${rulesItem.id.slug}") resolved to "${viaCatByRulesId.id.slug}" instead of "${cat.id.slug}"',
          );
        }

        final viaCatByCatId = MagicItemLibrary.findById(cat.id.slug);
        if (viaCatByCatId == null || viaCatByCatId.id.slug != cat.id.slug) {
          mismatches.add(
            'MagicItemLibrary.findById("${cat.id.slug}") failed to resolve "${cat.name}"',
          );
        }

        final eqMatch = index.checkEntity(
          slug: cat.id.slug,
          name: cat.name,
          type: EntityType.equipment,
        );
        if (eqMatch != SrdMatchResult.exactSrdMatch) {
          mismatches.add(
            'SrdEquivalenceIndex failed for "${cat.id.slug}" (${cat.name}): $eqMatch',
          );
        }
      }

      // Spot check reviewer's canonical club case via all lookups:
      final clubCatalog = MagicItemLibrary.findById('weapon_club');
      final clubRules = SrdEquipmentLibrary.allEquipmentItems
          .where((e) => e.id.slug == 'weapon_club')
          .firstOrNull;
      if (clubCatalog == null || clubRules == null) {
        mismatches.add(
          'Canonical weapon_club missing in catalog (${clubCatalog != null}) or rules view (${clubRules != null})',
        );
      }

      expect(
        mismatches,
        isEmpty,
        reason: 'SRD item id unification mismatches (${mismatches.length}):\n'
            '${mismatches.take(15).join('\n')}',
      );
    });

    test(
        'Law (b): every item id in legacy and stored-format fixtures resolves consistently',
        () async {
      const expectedLegacyNames = <String, String>{
        'leather-armor': 'Leather Armor',
        'dagger': 'Dagger',
        'pearl-of-power': 'Pearl of Power',
        'breastplate': 'Breastplate',
        'shield': 'Shield',
        'boots-of-elvenkind': 'Boots of Elvenkind',
        'chain_mail': 'Chain Mail',
        'longsword': 'Longsword',
      };

      // 1. Standalone legacy_character_regression.json
      final regressionMap = jsonDecode(
        File('test/fixtures/legacy_character_regression.json').readAsStringSync(),
      ) as Map<String, dynamic>;
      final regressionChar = Character.fromMap(regressionMap);
      final regressionResolved = await CharacterTelemetryResolver.resolve(
        CharacterTelemetryDto(
          id: regressionChar.id.slug,
          name: regressionChar.name,
          speciesSlug: regressionChar.speciesRef.slug,
          equippedItemSlugs: regressionChar.inventory
              .where((i) => i.isEquipped)
              .map((i) => i.itemRef.slug)
              .toList(),
        ),
      );
      for (final item in regressionChar.inventory) {
        final exp = expectedLegacyNames[item.itemRef.slug];
        expect(exp, isNotNull, reason: 'Unexpected fixture slug ${item.itemRef.slug}');
        if (item.isEquipped) {
          expect(
            regressionResolved.equippedItemNames,
            contains(exp),
            reason: 'Regression fixture slug ${item.itemRef.slug} did not resolve to $exp',
          );
        }
      }

      // 2. Legacy storage E1..E9 characters
      for (var era = 1; era <= 9; era++) {
        final storageMap = jsonDecode(
          File('test/fixtures/legacy_storage/E$era/storage.json')
              .readAsStringSync(),
        ) as Map<String, dynamic>;
        final prefs = storageMap['prefs'] as Map<String, dynamic>? ?? const {};
        final rosterRaw = prefs['saved_characters_roster_v1']?.toString();
        if (rosterRaw == null || rosterRaw.isEmpty) continue;
        final roster = jsonDecode(rosterRaw) as List<dynamic>;
        for (final entry in roster.cast<Map<String, dynamic>>()) {
          final ch = Character.fromMap(entry);
          final resolved = await CharacterTelemetryResolver.resolve(
            CharacterTelemetryDto(
              id: ch.id.slug,
              name: ch.name,
              speciesSlug: ch.speciesRef.slug,
              equippedItemSlugs: ch.inventory
                  .where((i) => i.isEquipped)
                  .map((i) => i.itemRef.slug)
                  .toList(),
            ),
          );
          for (final item in ch.inventory) {
            final exp = expectedLegacyNames[item.itemRef.slug];
            expect(exp, isNotNull,
                reason: 'E$era unexpected fixture slug ${item.itemRef.slug}');
            if (item.isEquipped) {
              expect(
                resolved.equippedItemNames,
                contains(exp),
                reason: 'E$era slug ${item.itemRef.slug} did not resolve to $exp',
              );
            }
          }
        }
      }

      // 3. Stored-format homebrew items
      final itemsFixture = jsonDecode(
        File('test/fixtures/stored_formats/homebrew_items_stored.json')
            .readAsStringSync(),
      ) as Map<String, dynamic>;
      final db = AppDatabaseService();
      await db.put(
        AppDatabaseService.boxHomebrew,
        'dn_homebrew_items_v1',
        List<String>.from(itemsFixture['storedJsonList'] as List),
      );
      final hbSvc = HomebrewPersistenceService();
      await hbSvc.syncToLibraries();
      final loadedItems = await hbSvc.loadCustomItems();
      expect(loadedItems, isNotEmpty);
      for (final item in loadedItems) {
        final found = MagicItemLibrary.findById(item.id.slug);
        expect(found, isNotNull, reason: 'Stored item ${item.id.slug} missing');
        expect(found!.name, equals(item.name));
      }
    });

    test(
        'pre-Cleanup slice 18 load-time normalizer converts stored hyphenated bundled item ids to underscore',
        () {
      expect(
        SrdEquipmentLibrary.normalizeLegacyBundledItemId('weapon-club'),
        equals('weapon_club'),
      );
      expect(
        SrdEquipmentLibrary.normalizeLegacyBundledItemId('armor-plate'),
        equals('armor_plate'),
      );
      expect(
        SrdEquipmentLibrary.normalizeLegacyBundledItemId('item-flame-tongue'),
        equals('item_flame_tongue'),
      );
      // Legacy short aliases and custom homebrew ids remain untouched.
      expect(
        SrdEquipmentLibrary.normalizeLegacyBundledItemId('leather-armor'),
        equals('leather-armor'),
      );
      expect(
        SrdEquipmentLibrary.normalizeLegacyBundledItemId('hb-item-weapon'),
        equals('hb-item-weapon'),
      );

      final legacyChar = Character(
        id: const EntityId(slug: 'char-legacy-hyphen', ruleset: RulesetVersion.v2024),
        name: 'Legacy Hyphen Holder',
        speciesRef: const EntityReference<DomainEntity>.empty(
          refType: EntityType.species,
          slug: 'human',
          displayName: 'Human',
        ),
        progression: const CharacterProgression(classes: []),
        baseScores: const AbilityScores(),
        resources: const CharacterResourcePool(),
        inventory: [
          InventoryItemInstance(
            instanceId: 'inv-1',
            itemRef: EntityReference<DomainEntity>(
              refType: EntityType.equipment,
              slug: 'weapon-club',
              displayName: 'Club',
            ),
          ),
          InventoryItemInstance(
            instanceId: 'inv-2',
            itemRef: EntityReference<DomainEntity>(
              refType: EntityType.equipment,
              slug: 'leather-armor',
              displayName: 'Leather Armor',
            ),
          ),
        ],
      );

      final normalized = SrdEquipmentLibrary.normalizeCharacterItemIds(legacyChar);
      expect(normalized.inventory[0].itemRef.slug, equals('weapon_club'));
      expect(normalized.inventory[1].itemRef.slug, equals('leather-armor'));
      expect(MagicItemLibrary.findById(normalized.inventory[0].itemRef.slug), isNotNull);
    });
  });
}
