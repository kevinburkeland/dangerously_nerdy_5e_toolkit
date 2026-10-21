import 'dart:convert';
import 'dart:math';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vtt_engine_core/vtt_engine_core.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/campaign_profile.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/custom_preset.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/domain/core_types.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/domain/dm_backup_models.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/domain/homebrew_extended_entities.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/domain/spell_monster_equipment.dart';
import 'package:dangerously_nerdy_5e_toolkit/infrastructure/di/injection_container.dart';
import 'package:dangerously_nerdy_5e_toolkit/infrastructure/dtos/campaign_profile_dto.dart';
import 'package:dangerously_nerdy_5e_toolkit/services/persistence/app_backup_service.dart';
import 'package:dangerously_nerdy_5e_toolkit/services/persistence/campaign_profile_service.dart';
import 'package:dangerously_nerdy_5e_toolkit/services/persistence/dm_backup_service.dart';
import 'package:dangerously_nerdy_5e_toolkit/services/persistence/homebrew_persistence_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Cold Iron Pass 9 — R4: Persistence and Import Boundaries', () {
    late StatefulHlcClock clock;
    late CampaignProfileService campaignService;
    late HomebrewPersistenceService homebrewService;
    late DmBackupService dmBackupService;
    late AppBackupService appBackupService;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      await initServiceLocator();
      clock = sl<StatefulHlcClock>();
      campaignService = CampaignProfileService();
      campaignService.clearCacheForTesting();
      homebrewService = HomebrewPersistenceService();
      await homebrewService.clearAllHomebrew();
      dmBackupService = DmBackupService(clock: clock);
      appBackupService = AppBackupService();
    });

    tearDown(() {
      sl.reset();
    });

    test('1. The 2100 example: validateAndImportProfile returns null, nothing stored, clock unchanged; control imports', () async {
      final initialClock = clock.latest;
      final year2100Ms = DateTime.utc(2100, 1, 1).millisecondsSinceEpoch;

      final baseProfile = CampaignProfile.defaultProfile(
        nodeId: clock.replicaId.value,
        clock: clock,
        name: 'Poisoned Campaign',
      );

      final poisonedProfile = baseProfile.copyWith(
        id: 'camp-2100',
        notesRegister: CrdtLwwRegister(
          value: 'Notes from the far future',
          timestamp: HybridLogicalClock(
            physicalTime: year2100Ms,
            logicalCounter: 0,
            nodeId: 'remote-future',
          ),
        ),
      );

      final poisonedJson = json.encode({
        'schemaVersion': DmBackupService.currentSchemaVersion,
        'appVersion': '1.0.0',
        'type': 'campaign_profile',
        'campaign': CampaignProfileDto.fromDomain(poisonedProfile).toMap(),
      });

      final clockBeforeImport = clock.latest;
      final imported = await dmBackupService.validateAndImportProfile(poisonedJson);
      expect(imported, isNull, reason: 'Profile with year 2100 notes must be rejected');
      expect(clock.latest, equals(clockBeforeImport), reason: 'Local clock must not advance on rejected import');

      final loadedProfiles = await campaignService.loadAllProfiles();
      expect(loadedProfiles.any((p) => p.name == 'Poisoned Campaign'), isFalse,
          reason: 'Poisoned profile must never be stored');

      // Control: Profile stamped one minute ago imports successfully
      final oneMinuteAgoMs = DateTime.now().toUtc().millisecondsSinceEpoch - 60000;
      final controlProfile = CampaignProfile.defaultProfile(
        nodeId: clock.replicaId.value,
        clock: clock,
        name: 'Control Campaign',
      ).copyWith(
        id: 'camp-valid-control',
        notesRegister: CrdtLwwRegister(
          value: 'Notes from one minute ago',
          timestamp: HybridLogicalClock(
            physicalTime: oneMinuteAgoMs,
            logicalCounter: 0,
            nodeId: 'remote-past',
          ),
        ),
      );

      final controlJson = json.encode({
        'schemaVersion': DmBackupService.currentSchemaVersion,
        'appVersion': '1.0.0',
        'type': 'campaign_profile',
        'campaign': CampaignProfileDto.fromDomain(controlProfile).toMap(),
      });

      final controlImported = await dmBackupService.validateAndImportProfile(controlJson);
      expect(controlImported, isNotNull, reason: 'Profile from one minute ago must import');
      final afterControlProfiles = await campaignService.loadAllProfiles();
      expect(afterControlProfiles.any((p) => p.name == 'Control Campaign'), isTrue);
    });

    test('2. restoreFullSystemSnapshot: far-future campaign skipped, good stored, returns false', () async {
      final nowMs = DateTime.now().toUtc().millisecondsSinceEpoch;
      final year2100Ms = DateTime.utc(2100, 1, 1).millisecondsSinceEpoch;

      final goodProfile = CampaignProfile.defaultProfile(
        nodeId: clock.replicaId.value,
        clock: clock,
        name: 'Good Campaign',
      ).copyWith(
        id: 'camp-good',
        notesRegister: CrdtLwwRegister(
          value: 'Good notes',
          timestamp: HybridLogicalClock(
            physicalTime: nowMs - 1000,
            logicalCounter: 0,
            nodeId: 'remote-node',
          ),
        ),
      );

      final futureProfile = CampaignProfile.defaultProfile(
        nodeId: clock.replicaId.value,
        clock: clock,
        name: 'Future 2100 Campaign',
      ).copyWith(
        id: 'camp-future-2100',
        notesRegister: CrdtLwwRegister(
          value: 'Far future notes',
          timestamp: HybridLogicalClock(
            physicalTime: year2100Ms,
            logicalCounter: 0,
            nodeId: 'remote-node',
          ),
        ),
      );

      final fullSnapshotJson = json.encode({
        'schemaVersion': DmBackupService.currentSchemaVersion,
        'appVersion': '1.0.0',
        'type': 'full_system_snapshot',
        'campaignProfiles': [
          CampaignProfileDto.fromDomain(goodProfile).toMap(),
          CampaignProfileDto.fromDomain(futureProfile).toMap(),
        ],
      });

      final success = await dmBackupService.restoreFullSystemSnapshot(fullSnapshotJson);
      expect(success, isFalse, reason: 'Must return false when any campaign fails/is skipped');

      final loaded = await campaignService.loadAllProfiles();
      expect(loaded.any((p) => p.name == 'Good Campaign'), isTrue,
          reason: 'Good campaign must be restored');
      expect(loaded.any((p) => p.name == 'Future 2100 Campaign'), isFalse,
          reason: 'Far-future campaign must be skipped and not stored');
    });

    test('3. Boundary: stamp at exactly now + maxFutureDrift is accepted; +1ms is refused', () {
      final nowMs = DateTime.now().toUtc().millisecondsSinceEpoch;
      const drift = Duration(minutes: 1); // 60,000ms
      final exactBoundMs = nowMs + 60000;
      final violationMs = exactBoundMs + 1;

      final baseProfile = CampaignProfile.defaultProfile(
        nodeId: clock.replicaId.value,
        clock: clock,
        name: 'Exact Bound',
      );

      final exactBoundProfile = baseProfile.copyWith(
        id: 'c-exact',
        notesRegister: CrdtLwwRegister(
          value: 'Exact notes',
          timestamp: HybridLogicalClock(
            physicalTime: exactBoundMs,
            logicalCounter: 0,
            nodeId: 'node-b',
          ),
        ),
      );

      final exactViolations = futureTimestampViolations(exactBoundProfile, nowMs, drift);
      expect(exactViolations, isEmpty, reason: 'Exact bound must be accepted');

      final overBoundProfile = baseProfile.copyWith(
        id: 'c-over',
        notesRegister: CrdtLwwRegister(
          value: 'Over bound notes',
          timestamp: HybridLogicalClock(
            physicalTime: violationMs,
            logicalCounter: 0,
            nodeId: 'node-b',
          ),
        ),
      );

      final overViolations = futureTimestampViolations(overBoundProfile, nowMs, drift);
      expect(overViolations, contains('notesRegister'), reason: 'now + drift + 1ms must be refused');
    });

    test('4. schemaVersion: current imports; current + 1 is refused for both services', () async {
      // DmBackupService
      final currentDmPayload = json.encode({
        'schemaVersion': DmBackupService.currentSchemaVersion,
        'appVersion': '1.0.0',
        'type': 'campaign_profile',
        'campaign': {
          'id': 'c-current',
          'name': 'Current Schema Campaign',
        },
      });
      final dmReportCurrent = dmBackupService.validatePayload(currentDmPayload);
      expect(dmReportCurrent.isValid, isTrue);

      final nextDmPayload = json.encode({
        'schemaVersion': DmBackupService.currentSchemaVersion + 1,
        'appVersion': '2.0.0',
        'type': 'campaign_profile',
        'campaign': {
          'id': 'c-future',
          'name': 'Future Schema Campaign',
        },
      });
      final dmReportNext = dmBackupService.validatePayload(nextDmPayload);
      expect(dmReportNext.isValid, isFalse);
      expect(dmReportNext.status, equals(ImportValidationStatus.incompatibleVersion));
      expect(
        dmReportNext.errors.first,
        contains(
            'Payload schema version (${DmBackupService.currentSchemaVersion + 1}) is newer than current (${DmBackupService.currentSchemaVersion})'),
      );
      final dmImportNext = await dmBackupService.validateAndImportProfile(nextDmPayload);
      expect(dmImportNext, isNull);

      // AppBackupService
      final currentAppPayload = json.encode({
        'schemaVersion': AppBackupService.currentSchemaVersion,
        'exportedAt': DateTime.now().toIso8601String(),
        'settings': {},
        'dicePresets': [],
        'dprProfiles': [],
      });
      final appResultCurrent = await appBackupService.importFullBackupJson(currentAppPayload);
      expect(appResultCurrent.success, isTrue);

      final nextAppPayload = json.encode({
        'schemaVersion': AppBackupService.currentSchemaVersion + 1,
        'exportedAt': DateTime.now().toIso8601String(),
        'settings': {},
        'dicePresets': [],
        'dprProfiles': [],
      });
      final appResultNext = await appBackupService.importFullBackupJson(nextAppPayload);
      expect(appResultNext.success, isFalse);
      expect(
        appResultNext.errorMessage,
        contains(
            'Backup schema version ${AppBackupService.currentSchemaVersion + 1} is newer than current supported version ${AppBackupService.currentSchemaVersion}'),
      );
    });

    test('5. Malformed record skip: one malformed spell and one good spell', () async {
      final validSpellMap = const Spell(
        id: EntityId(slug: 'good-spark', ruleset: RulesetVersion.v2024),
        name: 'Good Spark',
        level: 0,
        school: 'Evocation',
        castingTime: CastingTime(cost: 1, actionType: ActionType.action),
        duration: SpellDuration(type: DurationType.instantaneous),
        range: 'Touch',
        components: SpellComponents(v: true, s: true),
        descriptionMarkdown: 'Creates small sparks.',
      ).toMap();

      final payload = json.encode({
        'schemaVersion': AppBackupService.currentSchemaVersion,
        'exportedAt': DateTime.now().toIso8601String(),
        'settings': {},
        'dicePresets': [],
        'dprProfiles': [],
        'customSpells': [
          {'invalid': 'this spell has bad types', 'level': 'not_a_number'}, // index 0 (malformed)
          validSpellMap, // index 1 (good)
        ],
      });

      final result = await appBackupService.importFullBackupJson(payload);
      expect(result.success, isTrue, reason: 'Partial skips must still have success == true');
      expect(result.restoredHomebrewSpellsCount, equals(1));
      expect(result.skippedCount, equals(1));
      expect(result.skipReasons.length, equals(1));
      expect(result.skipReasons.first, startsWith('customSpells[0]:'));
    });

    test('6. Law: at least 200 seeded random backups restore + skipped equals total per section', () async {
      const int caseCount = 200;
      final validSpell = const Spell(
        id: EntityId(slug: 'spark', ruleset: RulesetVersion.v2024),
        name: 'Spark',
        level: 0,
        school: 'Evocation',
        castingTime: CastingTime(cost: 1, actionType: ActionType.action),
        duration: SpellDuration(type: DurationType.instantaneous),
        range: 'Touch',
        components: SpellComponents(v: true, s: true),
        descriptionMarkdown: 'Creates small sparks.',
      ).toMap();

      final validMonster = const Monster(
        id: EntityId(slug: 'kobold-guard', ruleset: RulesetVersion.v2024),
        name: 'Kobold Guard',
        size: 'Small',
        monsterType: 'Humanoid',
        alignment: 'Lawful Evil',
        challengeRating: '1/8',
        armorClass: 12,
        hitPoints: 5,
        hitDieFormula: '2d6 - 2',
        actionsMarkdown: 'Attacks with dagger.',
      ).toMap();

      final validItem = const EquipmentItem(
        id: EntityId(slug: 'wooden-club', ruleset: RulesetVersion.v2024),
        name: 'Wooden Club',
        itemType: 'weapon',
        rarity: 'Common',
        requiresAttunement: false,
        descriptionMarkdown: 'Simple wooden club.',
      ).toMap();

      final validClass = const CharacterClass(
        id: EntityId(slug: 'scout', ruleset: RulesetVersion.v2024),
        name: 'Scout',
        hitDie: 'd8',
        featuresMarkdown: 'Wilderness tracking',
      ).toMap();

      final validSubclass = const Subclass(
        id: EntityId(slug: 'stalker', ruleset: RulesetVersion.v2024),
        name: 'Stalker',
        classSlug: 'scout',
        featuresMarkdown: 'Stalking prey',
      ).toMap();

      final validRace = Race(
        id: const EntityId(slug: 'elfling', ruleset: RulesetVersion.v2024),
        name: 'Elfling',
        traitsMarkdown: 'Nimble and perceptive',
      ).toMap();

      final validFeat = const Feat(
        id: EntityId(slug: 'fleet-footed', ruleset: RulesetVersion.v2024),
        name: 'Fleet Footed',
        descriptionMarkdown: 'Move faster',
      ).toMap();

      final validBg = const Background(
        id: EntityId(slug: 'forager', ruleset: RulesetVersion.v2024),
        name: 'Forager',
        descriptionMarkdown: 'Find food in the wild',
      ).toMap();

      final validOther = const HomebrewCompendiumEntry(
        id: EntityId(slug: 'encounter-table', ruleset: RulesetVersion.v2024),
        name: 'Encounter Table',
        category: 'tables',
        descriptionMarkdown: 'Random table',
      ).toMap();

      final validPreset = CustomPreset(
        id: 'p1',
        name: 'Preset 1',
        modifier: 5,
      ).toMap();

      for (int seed = 1000; seed < 1000 + caseCount; seed++) {
        final rng = Random(seed);

        // Build random mix of good and malformed records for 10 chosen sections
        List<Map<String, dynamic>> buildSection(
          Map<String, dynamic> goodTemplate,
          int count,
        ) {
          final list = <Map<String, dynamic>>[];
          for (int i = 0; i < count; i++) {
            if (rng.nextBool()) {
              list.add(Map<String, dynamic>.from(goodTemplate));
            } else {
              // Malformed: missing id or bad types
              list.add({'badField_$i': 'corrupted_$seed'});
            }
          }
          return list;
        }

        final presets = buildSection(validPreset, rng.nextInt(4));
        final spells = buildSection(validSpell, rng.nextInt(4));
        final monsters = buildSection(validMonster, rng.nextInt(4));
        final items = buildSection(validItem, rng.nextInt(4));
        final classes = buildSection(validClass, rng.nextInt(4));
        final subclasses = buildSection(validSubclass, rng.nextInt(4));
        final races = buildSection(validRace, rng.nextInt(4));
        final feats = buildSection(validFeat, rng.nextInt(4));
        final backgrounds = buildSection(validBg, rng.nextInt(4));
        final others = buildSection(validOther, rng.nextInt(4));

        final backupPayload = json.encode({
          'schemaVersion': AppBackupService.currentSchemaVersion,
          'exportedAt': DateTime.now().toIso8601String(),
          'settings': {},
          'dicePresets': presets,
          'dprProfiles': [],
          'customSpells': spells,
          'customMonsters': monsters,
          'customItems': items,
          'customClasses': classes,
          'customSubclasses': subclasses,
          'customRaces': races,
          'customFeats': feats,
          'customBackgrounds': backgrounds,
          'customOtherEntries': others,
        });

        final result = await appBackupService.importFullBackupJson(backupPayload);
        if (!result.success) {
          fail('Seed $seed failed with error: ${result.errorMessage}');
        }

        int skippedFor(String section) {
          return result.skipReasons.where((r) => r.startsWith('$section[')).length;
        }

        // Verify restored + skipped == total for each section
        expect(
          result.restoredPresetsCount + skippedFor('dicePresets'),
          equals(presets.length),
          reason: 'Seed $seed: presets restored + skipped must equal total',
        );
        expect(
          result.restoredHomebrewSpellsCount + skippedFor('customSpells'),
          equals(spells.length),
          reason: 'Seed $seed: spells restored + skipped must equal total',
        );
        expect(
          result.restoredHomebrewMonstersCount + skippedFor('customMonsters'),
          equals(monsters.length),
          reason: 'Seed $seed: monsters restored + skipped must equal total',
        );
        expect(
          result.restoredHomebrewItemsCount + skippedFor('customItems'),
          equals(items.length),
          reason: 'Seed $seed: items restored + skipped must equal total',
        );
        expect(
          result.restoredHomebrewClassesCount + skippedFor('customClasses'),
          equals(classes.length),
          reason: 'Seed $seed: classes restored + skipped must equal total',
        );
        expect(
          result.restoredHomebrewSubclassesCount + skippedFor('customSubclasses'),
          equals(subclasses.length),
          reason: 'Seed $seed: subclasses restored + skipped must equal total',
        );
        expect(
          result.restoredHomebrewRacesCount + skippedFor('customRaces'),
          equals(races.length),
          reason: 'Seed $seed: races restored + skipped must equal total',
        );
        expect(
          result.restoredHomebrewFeatsCount + skippedFor('customFeats'),
          equals(feats.length),
          reason: 'Seed $seed: feats restored + skipped must equal total',
        );
        expect(
          result.restoredHomebrewBackgroundsCount + skippedFor('customBackgrounds'),
          equals(backgrounds.length),
          reason: 'Seed $seed: backgrounds restored + skipped must equal total',
        );
        expect(
          result.restoredHomebrewOtherCount + skippedFor('customOtherEntries'),
          equals(others.length),
          reason: 'Seed $seed: other entries restored + skipped must equal total',
        );

        // Verify each skipReason names a real index
        final indexPattern = RegExp(r'^(\w+)\[(\d+)\]:');
        for (final reason in result.skipReasons) {
          final match = indexPattern.firstMatch(reason);
          expect(match, isNotNull, reason: 'Seed $seed: reason must match section[index] pattern ($reason)');
          final section = match!.group(1)!;
          final idx = int.parse(match.group(2)!);
          List<Map<String, dynamic>> targetList;
          switch (section) {
            case 'dicePresets':
              targetList = presets;
              break;
            case 'customSpells':
              targetList = spells;
              break;
            case 'customMonsters':
              targetList = monsters;
              break;
            case 'customItems':
              targetList = items;
              break;
            case 'customClasses':
              targetList = classes;
              break;
            case 'customSubclasses':
              targetList = subclasses;
              break;
            case 'customRaces':
              targetList = races;
              break;
            case 'customFeats':
              targetList = feats;
              break;
            case 'customBackgrounds':
              targetList = backgrounds;
              break;
            case 'customOtherEntries':
              targetList = others;
              break;
            default:
              targetList = [];
          }
          expect(idx < targetList.length, isTrue,
              reason: 'Seed $seed: index $idx must be within $section length (${targetList.length})');
        }
      }
    });
  });
}
