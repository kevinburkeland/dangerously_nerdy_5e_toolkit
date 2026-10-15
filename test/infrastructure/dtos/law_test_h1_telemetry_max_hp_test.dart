import 'dart:math';
import 'package:flutter_test/flutter_test.dart';
import 'package:vtt_ruleset_dnd5e/vtt_ruleset_dnd5e.dart';
import 'package:vtt_engine_core/vtt_engine_core.dart' hide Character, CharacterResourcePool, EntityType, InventoryItemInstance;
import 'package:dangerously_nerdy_5e_toolkit/infrastructure/dtos/character_telemetry_dto.dart';

void main() {
  group('Pass 6 Law Test: H1 Telemetry and Evaluation Engine Max HP Agreement', () {
    test('Over 250 seeded random characters, telemetry max HP equals CharacterEvaluationEngine.evaluate(c).maxHp', () {
      final rng = Random(1337);
      const classPool = [
        'fighter',
        'wizard',
        'cleric',
        'rogue',
        'barbarian',
        'paladin',
        'ranger',
        'bard',
        'druid',
        'monk',
        'sorcerer',
        'warlock',
      ];
      final hitDiceMap = {
        'barbarian': 'd12',
        'fighter': 'd10',
        'paladin': 'd10',
        'ranger': 'd10',
        'bard': 'd8',
        'cleric': 'd8',
        'druid': 'd8',
        'monk': 'd8',
        'rogue': 'd8',
        'warlock': 'd8',
        'sorcerer': 'd6',
        'wizard': 'd6',
      };

      const iterations = 250;
      for (int i = 0; i < iterations; i++) {
        final conScore = 3 + rng.nextInt(18); // 3 to 20
        final hasTough = rng.nextBool();
        final isHillDwarf = rng.nextBool();
        final hasHpOverride = (i % 2 == 1);
        final storedMaxHp = 1 + rng.nextInt(250);
        final overrideMaxHp = hasHpOverride ? (1 + rng.nextInt(300)) : null;

        final numClasses = 1 + rng.nextInt(3); // 1 to 3 classes
        final classList = <ClassLevelProgression>[];
        final pickedClasses = <String>{};

        for (int c = 0; c < numClasses; c++) {
          String classSlug;
          do {
            classSlug = classPool[rng.nextInt(classPool.length)];
          } while (pickedClasses.contains(classSlug));
          pickedClasses.add(classSlug);

          final classLevel = 1 + rng.nextInt(20);
          classList.add(
            ClassLevelProgression(
              classRef: EntityReference<DomainEntity>.empty(
                refType: EntityType.classDefinition,
                slug: classSlug,
                displayName: classSlug[0].toUpperCase() + classSlug.substring(1),
              ),
              level: classLevel,
              hitDie: hitDiceMap[classSlug] ?? 'd8',
            ),
          );
        }

        final feats = <EntityReference<DomainEntity>>[];
        if (hasTough) {
          feats.add(
            const EntityReference<DomainEntity>.empty(
              refType: EntityType.feat,
              slug: 'tough',
              displayName: 'Tough',
            ),
          );
        }

        final speciesSlug = isHillDwarf ? 'hill-dwarf' : 'human';
        final speciesName = isHillDwarf ? 'Hill Dwarf' : 'Human';

        final customProps = <String, dynamic>{};
        if (hasHpOverride) {
          customProps['maxHp'] = overrideMaxHp;
        }

        final character = Character(
          id: EntityId(slug: 'rand-char-$i', ruleset: RulesetVersion.v2024),
          name: 'Random Hero $i',
          speciesRef: EntityReference<DomainEntity>.empty(
            refType: EntityType.species,
            slug: speciesSlug,
            displayName: speciesName,
          ),
          baseScores: AbilityScores(constitution: conScore),
          resources: CharacterResourcePool(
            vitals: EntityVitals(currentHp: storedMaxHp, maxHp: storedMaxHp),
          ),
          progression: CharacterProgression(classes: classList),
          feats: feats,
          customProperties: customProps,
        );

        final evaluatedHp = CharacterEvaluationEngine.evaluate(character).maxHp;
        final telemetryHp = character.toTelemetryDto().maxHp;

        expect(
          telemetryHp,
          equals(evaluatedHp),
          reason: 'Iteration $i: Telemetry maxHp ($telemetryHp) must equal evaluated maxHp ($evaluatedHp)',
        );

        if (hasHpOverride) {
          expect(
            telemetryHp,
            equals(overrideMaxHp),
            reason: 'Iteration $i: Telemetry maxHp ($telemetryHp) must equal override ($overrideMaxHp)',
          );
          expect(
            evaluatedHp,
            equals(overrideMaxHp),
            reason: 'Iteration $i: Evaluated maxHp ($evaluatedHp) must equal override ($overrideMaxHp)',
          );
        }
      }
    });
  });
}
