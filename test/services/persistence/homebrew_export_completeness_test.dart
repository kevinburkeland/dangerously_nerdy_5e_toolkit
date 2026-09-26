import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/app_settings.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/characters/srd_backgrounds_library.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/characters/srd_classes_library.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/characters/srd_feats_library.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/characters/srd_species_library.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/domain/core_types.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/domain/homebrew_bundle.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/domain/homebrew_extended_entities.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/domain/spell_monster_equipment.dart';
import 'package:dangerously_nerdy_5e_toolkit/services/acl/homebrew_merge_resolver.dart';
import 'package:dangerously_nerdy_5e_toolkit/services/fluff/entity_fluff_service.dart';
import 'package:dangerously_nerdy_5e_toolkit/services/importers/community_compendium_importer_service.dart';
import 'package:dangerously_nerdy_5e_toolkit/services/persistence/app_backup_service.dart';
import 'package:dangerously_nerdy_5e_toolkit/services/persistence/dm_backup_service.dart';
import 'package:dangerously_nerdy_5e_toolkit/services/persistence/homebrew_persistence_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Homebrew Export & Import Completeness Test Suite', () {
    late HomebrewPersistenceService persistence;

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      persistence = HomebrewPersistenceService();
      SrdSpeciesLibrary.setCustomSpecies([]);
      SrdSpeciesLibrary.setCustomSubraces([]);
      SrdClassesLibrary.setCustomClasses([]);
      SrdClassesLibrary.setCustomSubclasses([]);
      SrdFeatsLibrary.setCustomFeats([]);
      SrdBackgroundsLibrary.setCustomBackgrounds([]);
      EntityFluffService().clear();
    });

    test(
        'exportHomebrewBundle captures all 11 categories including attached and standalone sub-entities',
        () async {
      // 1. Spell
      const spell = Spell(
        id: EntityId(slug: 'prismatic-flare', ruleset: RulesetVersion.homebrew),
        name: 'Prismatic Flare',
        level: 1,
        school: 'Evocation',
        castingTime: CastingTime(cost: 1, actionType: ActionType.action),
        duration: SpellDuration(type: DurationType.instantaneous),
        range: '60 feet',
        components: SpellComponents(v: true, s: true),
        descriptionMarkdown: 'Fires a beam of prismatic light.',
      );
      await persistence.saveCustomSpell(spell);

      // 2. Monster
      const monster = Monster(
        id: EntityId(slug: 'cinder-drake', ruleset: RulesetVersion.homebrew),
        name: 'Cinder Drake',
        size: 'Large',
        monsterType: 'Dragon',
        alignment: 'Chaotic Neutral',
        armorClass: 15,
        hitPoints: 60,
        hitDieFormula: '8d10 + 16',
        challengeRating: '3',
        actionsMarkdown: 'Breathes searing cinders.',
      );
      await persistence.saveCustomMonster(monster);

      // 3. Equipment Item
      const item = EquipmentItem(
        id: EntityId(
            slug: 'aegis-of-the-dawn', ruleset: RulesetVersion.homebrew),
        name: 'Aegis of the Dawn',
        itemType: 'shield',
        rarity: 'Rare',
        requiresAttunement: true,
        descriptionMarkdown: 'A gilded shield inscribed with radiant runes.',
      );
      await persistence.saveCustomItem(item);

      // 4. Class with attached Subclass
      const attachedSubclass = Subclass(
        id: EntityId(slug: 'dawn-blade', ruleset: RulesetVersion.homebrew),
        name: 'Dawn Blade',
        classSlug: 'solar-vanguard',
        featuresMarkdown: 'Channels solar energy into weapon strikes.',
      );
      const charClass = CharacterClass(
        id: EntityId(slug: 'solar-vanguard', ruleset: RulesetVersion.homebrew),
        name: 'Solar Vanguard',
        hitDie: 'd10',
        primaryAbility: 'Strength',
        featuresMarkdown: 'Champions of celestial radiance.',
        subclasses: [attachedSubclass],
      );
      await persistence.saveCustomClass(charClass);

      // 5. Standalone Subclass
      const standaloneSubclass = Subclass(
        id: EntityId(slug: 'dusk-warden', ruleset: RulesetVersion.homebrew),
        name: 'Dusk Warden',
        classSlug: 'fighter',
        featuresMarkdown: 'Protects the realm under twilight shadow.',
      );
      await persistence.saveCustomSubclass(standaloneSubclass);

      // 6. Race with attached Subrace
      const attachedSubrace = Subrace(
        id: EntityId(
            slug: 'starlight-lineage', ruleset: RulesetVersion.homebrew),
        name: 'Starlight Lineage',
        raceSlug: 'astral-born',
        traitsMarkdown: 'Glows with celestial luminescence.',
      );
      final race = Race(
        id: const EntityId(
            slug: 'astral-born', ruleset: RulesetVersion.homebrew),
        name: 'Astral Born',
        size: 'Medium',
        speed: '30 ft.',
        traitsMarkdown: 'Travelers from the Astral Sea.',
        subraces: const [attachedSubrace],
      );
      await persistence.saveCustomRace(race);

      // 7. Standalone Subrace
      const standaloneSubrace = Subrace(
        id: EntityId(slug: 'void-walker', ruleset: RulesetVersion.homebrew),
        name: 'Void Walker',
        raceSlug: 'astral-born',
        traitsMarkdown: 'Steps through planar rifts.',
      );
      await persistence.saveCustomSubrace(standaloneSubrace);

      // 8. Feat
      const feat = Feat(
        id: EntityId(
            slug: 'harmonic-resonance', ruleset: RulesetVersion.homebrew),
        name: 'Harmonic Resonance',
        category: 'General',
        descriptionMarkdown: 'Harmonize with magical vibrations.',
      );
      await persistence.saveCustomFeat(feat);

      // 9. Background
      const background = Background(
        id: EntityId(
            slug: 'wandering-astrologer', ruleset: RulesetVersion.homebrew),
        name: 'Wandering Astrologer',
        descriptionMarkdown: 'Reads destinies in star alignments.',
      );
      await persistence.saveCustomBackground(background);

      // 10. Other Entry (Table)
      const otherEntry = HomebrewCompendiumEntry(
        id: EntityId(
            slug: 'planar-portals-table', ruleset: RulesetVersion.homebrew),
        name: 'Planar Portals Table',
        category: 'tables',
        descriptionMarkdown: '| d6 | Plane |\n|---|---|\n| 1 | Astral |',
      );
      await persistence.saveCustomOtherEntry(otherEntry);

      // 11. Lore / Fluff
      const fluff = EntityFluff(
        entityType: 'monster',
        slug: 'cinder-drake',
        loreMarkdown: 'Cinder Drakes make nests in volcanic craters.',
      );
      await persistence.saveCustomFluffBatch([fluff]);
      EntityFluffService().batchRegisterFluff([fluff]);

      // Execute exportHomebrewBundle
      final bundle = await persistence.exportHomebrewBundle(
        bundleName: 'Complete Astral Expansion',
        author: 'Grand Cartographer',
        description: 'Comprehensive bundle with all homebrew data.',
      );

      // Verify all 11 categories
      expect(bundle.spells.map((s) => s.id.slug), contains('prismatic-flare'));
      expect(bundle.monsters.map((m) => m.id.slug), contains('cinder-drake'));
      expect(bundle.items.map((i) => i.id.slug), contains('aegis-of-the-dawn'));
      expect(bundle.classes.map((c) => c.id.slug), contains('solar-vanguard'));

      // Subclasses: both attached and standalone must be present
      final subclassSlugs = bundle.subclasses.map((s) => s.id.slug).toSet();
      expect(subclassSlugs, contains('dawn-blade'),
          reason: 'Attached subclass must be included');
      expect(subclassSlugs, contains('dusk-warden'),
          reason: 'Standalone subclass must be included');

      // Races and Subraces: both attached and standalone must be present
      expect(bundle.races.map((r) => r.id.slug), contains('astral-born'));
      final subraceSlugs = bundle.subraces.map((s) => s.id.slug).toSet();
      expect(subraceSlugs, contains('starlight-lineage'),
          reason: 'Attached subrace must be included');
      expect(subraceSlugs, contains('void-walker'),
          reason: 'Standalone subrace must be included');

      expect(
          bundle.feats.map((f) => f.id.slug), contains('harmonic-resonance'));
      expect(bundle.backgrounds.map((b) => b.id.slug),
          contains('wandering-astrologer'));
      expect(bundle.otherEntries.map((o) => o.id.slug),
          contains('planar-portals-table'));
      expect(bundle.fluff.map((f) => f.slug), contains('cinder-drake'));

      // Verify exportBundle dictionary representation
      final bundleMap = await persistence.exportBundle();
      expect((bundleMap['subclasses'] as List).length, greaterThanOrEqualTo(2));
      expect((bundleMap['subraces'] as List).length, greaterThanOrEqualTo(2));
      expect((bundleMap['classes'] as List).length, equals(1));
      expect((bundleMap['races'] as List).length, equals(1));
      expect((bundleMap['fluff'] as List).length, equals(1));
    });

    test(
        'DmBackupService export and restore preserves all 11 homebrew categories',
        () async {
      // Seed class with attached subclass
      const attachedSubclass = Subclass(
        id: EntityId(slug: 'radiant-blade', ruleset: RulesetVersion.homebrew),
        name: 'Radiant Blade',
        classSlug: 'sun-knight',
        featuresMarkdown: 'Empowered blade attacks.',
      );
      const charClass = CharacterClass(
        id: EntityId(slug: 'sun-knight', ruleset: RulesetVersion.homebrew),
        name: 'Sun Knight',
        hitDie: 'd10',
        primaryAbility: 'Strength',
        featuresMarkdown: 'Solar warriors.',
        subclasses: [attachedSubclass],
      );
      await persistence.saveCustomClass(charClass);

      // Seed race with attached subrace and standalone subrace
      final race = Race(
        id: const EntityId(
            slug: 'crystal-folk', ruleset: RulesetVersion.homebrew),
        name: 'Crystal Folk',
        size: 'Medium',
        speed: '30 ft.',
        traitsMarkdown: 'Crystalline humanoids.',
        subraces: const [
          Subrace(
            id: EntityId(
                slug: 'amethyst-lineage', ruleset: RulesetVersion.homebrew),
            name: 'Amethyst Lineage',
            raceSlug: 'crystal-folk',
            traitsMarkdown: 'Psychic resonance.',
          ),
        ],
      );
      await persistence.saveCustomRace(race);
      const standaloneSub = Subrace(
        id: EntityId(slug: 'quartz-lineage', ruleset: RulesetVersion.homebrew),
        name: 'Quartz Lineage',
        raceSlug: 'crystal-folk',
        traitsMarkdown: 'Radiant refraction.',
      );
      await persistence.saveCustomSubrace(standaloneSub);

      // Seed fluff
      const fluff = EntityFluff(
        entityType: 'race',
        slug: 'crystal-folk',
        loreMarkdown: 'Ancient legends describe crystal origins.',
      );
      await persistence.saveCustomFluffBatch([fluff]);
      EntityFluffService().batchRegisterFluff([fluff]);

      // Export full system snapshot
      final dmService = DmBackupService();
      final snapshotJson = await dmService.exportFullSystemSnapshot();
      final decoded = json.decode(snapshotJson) as Map<String, dynamic>;

      expect(decoded['customSubclasses'], isA<List>());
      final exportedSubSlugs = (decoded['customSubclasses'] as List)
          .map((s) => s['id']['slug'])
          .toSet();
      expect(exportedSubSlugs, contains('radiant-blade'));

      expect(decoded['customSubraces'], isA<List>());
      final exportedSubraceSlugs = (decoded['customSubraces'] as List)
          .map((s) => s['id']['slug'])
          .toSet();
      expect(exportedSubraceSlugs, contains('amethyst-lineage'));
      expect(exportedSubraceSlugs, contains('quartz-lineage'));

      expect(decoded['customFluff'], isA<List>());
      expect((decoded['customFluff'] as List).first['slug'],
          equals('crystal-folk'));

      // Clear storage and restore from snapshot
      SharedPreferences.setMockInitialValues({});
      SrdSpeciesLibrary.setCustomSpecies([]);
      SrdSpeciesLibrary.setCustomSubraces([]);
      SrdClassesLibrary.setCustomClasses([]);
      SrdClassesLibrary.setCustomSubclasses([]);

      final restored = await dmService.restoreFullSystemSnapshot(snapshotJson);
      expect(restored, isTrue);

      final restoredSubs = await persistence.loadCustomSubraces();
      expect(restoredSubs.map((s) => s.id.slug), contains('amethyst-lineage'));
      expect(restoredSubs.map((s) => s.id.slug), contains('quartz-lineage'));

      final restoredFluff = await persistence.loadCustomFluff();
      expect(restoredFluff.map((f) => f.slug), contains('crystal-folk'));
    });

    test(
        'AppBackupService export and restore preserves attached and standalone sub-entities',
        () async {
      final race = Race(
        id: const EntityId(
            slug: 'aether-folk', ruleset: RulesetVersion.homebrew),
        name: 'Aether Folk',
        size: 'Medium',
        speed: '30 ft.',
        traitsMarkdown: 'Beings of pure aether.',
        subraces: const [
          Subrace(
            id: EntityId(
                slug: 'luminary-lineage', ruleset: RulesetVersion.homebrew),
            name: 'Luminary Lineage',
            raceSlug: 'aether-folk',
            traitsMarkdown: 'Innate light.',
          ),
        ],
      );
      await persistence.saveCustomRace(race);

      const standaloneSub = Subrace(
        id: EntityId(slug: 'shadow-lineage', ruleset: RulesetVersion.homebrew),
        name: 'Shadow Lineage',
        raceSlug: 'aether-folk',
        traitsMarkdown: 'Shadow weaving.',
      );
      await persistence.saveCustomSubrace(standaloneSub);

      final appBackup = AppBackupService();
      final backupJson =
          await appBackup.exportFullBackupJson(const AppSettings());
      final decoded = json.decode(backupJson) as Map<String, dynamic>;

      final subracesList = decoded['customSubraces'] as List;
      final slugs = subracesList.map((s) => s['id']['slug']).toSet();
      expect(slugs, contains('luminary-lineage'));
      expect(slugs, contains('shadow-lineage'));

      // Test restore
      SharedPreferences.setMockInitialValues({});
      final restoreResult = await appBackup.importFullBackupJson(backupJson);
      expect(restoreResult.success, isTrue);

      final restoredSubs = await persistence.loadCustomSubraces();
      expect(restoredSubs.map((s) => s.id.slug), contains('luminary-lineage'));
      expect(restoredSubs.map((s) => s.id.slug), contains('shadow-lineage'));
    });

    test('HomebrewMergeResolver analyzes and preserves incoming subraces', () {
      const resolver = HomebrewMergeResolver();
      const bundle = HomebrewBundle(
        appVersion: '1.0.0',
        exportedAt: _TestEpochDateTime(),
        subraces: [
          Subrace(
            id: EntityId(
                slug: 'novel-subrace', ruleset: RulesetVersion.homebrew),
            name: 'Novel Subrace',
            raceSlug: 'custom-race',
            traitsMarkdown: 'Custom trait.',
          ),
        ],
      );

      final analysis = resolver.analyzeBundle(incomingBundle: bundle);
      expect(analysis.subraces.length, equals(1));
      expect(
          analysis.subraces.first.incomingEntity.name, equals('Novel Subrace'));
      expect(
          analysis.subraces.first.disposition, equals(ImportDisposition.novel));
      expect(analysis.totalIncoming, equals(1));
    });

    test('CommunityCompendiumImporterService parses and persists subraces',
        () async {
      final importer = CommunityCompendiumImporterService();
      final payload = {
        'race': [
          {
            'name': 'Gryphon Born',
            'size': 'Medium',
            'speed': 30,
          }
        ],
        'subrace': [
          {
            'name': 'Sky Hunter',
            'raceName': 'Gryphon Born',
            'race': 'gryphon-born',
          }
        ]
      };

      final result = await importer.importJsonString(json.encode(payload),
          persistAndSync: true);
      expect(result.errors, isEmpty);
      expect(result.races.length, equals(1));
      expect(result.races.first.subraces.length, equals(1));
      expect(result.races.first.subraces.first.name, equals('Sky Hunter'));

      final storedSubs = await persistence.loadCustomSubraces();
      expect(storedSubs.any((s) => s.name == 'Sky Hunter'), isTrue);
    });
  });
}

class _TestEpochDateTime implements DateTime {
  const _TestEpochDateTime();

  @override
  String toIso8601String() => '1970-01-01T00:00:00.000Z';

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
