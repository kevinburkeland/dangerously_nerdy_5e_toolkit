import 'package:flutter_test/flutter_test.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/dm_screen_data.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/spellbook_data.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/domain/core_types.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/domain/entity_reference.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/domain/spell_monster_equipment.dart';
import 'package:dangerously_nerdy_5e_toolkit/services/repository/layered_priority_repository.dart';
import 'package:dangerously_nerdy_5e_toolkit/services/repository/reference_resolver.dart';

void main() {
  group('SRD Spells Conformance & Baseline Ingestion Tests', () {
    late LayeredPriorityRepository repository;
    late ReferenceResolver resolver;

    setUp(() {
      repository = LayeredPriorityRepository();
      resolver = ReferenceResolver(repository);
    });

    String slugify(String name) {
      return name
          .toLowerCase()
          .replaceAll(RegExp(r"['’]"), '')
          .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
          .replaceAll(RegExp(r'^-+|-+$'), '');
    }

    ActionType parseActionType(String castingTimeStr) {
      final lower = castingTimeStr.toLowerCase();
      if (lower.contains('bonus')) return ActionType.bonusAction;
      if (lower.contains('reaction')) return ActionType.reaction;
      if (lower.contains('minute')) return ActionType.minute;
      if (lower.contains('hour')) return ActionType.hour;
      return ActionType.action;
    }

    SpellComponents parseComponents(String compStr, SpellMaterialComponent? mat) {
      final v = compStr.contains('V');
      final s = compStr.contains('S');
      final m = compStr.contains('M');
      return SpellComponents(
        v: v,
        s: s,
        m: m,
        materialDescription: mat?.description,
        materialCostGp: mat?.costInGp ?? 0,
        consumesMaterial: mat?.isConsumed ?? false,
      );
    }

    DamageType parseDamageType(String? typeStr) {
      if (typeStr == null) return DamageType.untyped;
      final lower = typeStr.toLowerCase();
      return DamageType.values.firstWhere(
        (e) => e.name == lower,
        orElse: () => DamageType.untyped,
      );
    }

    Spell convertToDomainSpell(SpellItem item, DmRulesEdition edition) {
      final rules = item.getRules(edition);
      final ruleset =
          edition == DmRulesEdition.v2024 ? RulesetVersion.v2024 : RulesetVersion.v2014;
      final name = item.getName(edition);
      final slug = slugify(name);

      final damageList = <EvaluationMath>[];
      if (rules.rollFormula != null && rules.rollFormula!.isNotEmpty) {
        final scalingDesc = rules.scalingFormula != null
            ? '+${rules.scalingFormula!.dicePerSlotLevel}d${rules.scalingFormula!.diceSides}'
            : null;
        damageList.add(EvaluationMath(
          diceFormula: rules.rollFormula!,
          damageType: parseDamageType(rules.damageOrHealType),
          scalingFormula: scalingDesc,
        ));
      }

      return Spell(
        id: EntityId(slug: slug, ruleset: ruleset),
        name: name,
        level: item.level,
        school: item.getSchool(edition).label,
        castingTime: CastingTime(
          cost: 1,
          actionType: parseActionType(rules.castingTime),
          triggerCondition: rules.reactionTrigger,
        ),
        duration: SpellDuration(
          type: rules.duration.toLowerCase().contains('instant')
              ? DurationType.instantaneous
              : DurationType.timed,
          requiresConcentration: rules.concentration,
          rawText: rules.duration,
        ),
        range: rules.range,
        components: parseComponents(rules.components, rules.materialDetails),
        descriptionMarkdown: rules.description.join('\n\n'),
        higherLevelsMarkdown: rules.higherLevels,
        damageMath: damageList,
        customProperties: {
          'classes': rules.classes.map((c) => c.label).toList(),
          'ritual': rules.ritual,
          'savingThrow': rules.savingThrow,
          'legacyId': item.id,
        },
      );
    }

    test('validates total spell count in SRD library', () {
      const spells = SpellbookLibrary.allSpells;
      expect(spells, isNotEmpty);
      expect(spells.length, greaterThanOrEqualTo(100),
          reason: 'Expected comprehensive SRD spell library');
    });

    test('ingests all SRD spells into 2014 & 2024 baseline repository layers', () {
      final layer2014 = PriorityLayer(
        layerId: 'base-srd-2014',
        name: 'SRD 2014 Ruleset',
        priority: LayerPriority.baseRuleset,
      );

      final layer2024 = PriorityLayer(
        layerId: 'base-srd-2024',
        name: 'SRD 2024 Ruleset',
        priority: LayerPriority.baseRuleset,
      );

      for (final item in SpellbookLibrary.allSpells) {
        layer2014.registerEntity(convertToDomainSpell(item, DmRulesEdition.v2014));
        layer2024.registerEntity(convertToDomainSpell(item, DmRulesEdition.v2024));
      }

      repository.addLayer(layer2024);
      repository.addLayer(layer2014);

      expect(layer2014.getAll().length, equals(SpellbookLibrary.allSpells.length));
      expect(layer2024.getAll().length, equals(SpellbookLibrary.allSpells.length));
    });

    test('dynamically resolves 2014 vs 2024 ruleset differences for key SRD spells', () {
      final layer2014 = PriorityLayer(
        layerId: 'base-srd-2014',
        name: 'SRD 2014 Ruleset',
        priority: LayerPriority.baseRuleset,
      );

      final layer2024 = PriorityLayer(
        layerId: 'base-srd-2024',
        name: 'SRD 2024 Ruleset',
        priority: LayerPriority.baseRuleset,
      );

      for (final item in SpellbookLibrary.allSpells) {
        layer2014.registerEntity(convertToDomainSpell(item, DmRulesEdition.v2014));
        layer2024.registerEntity(convertToDomainSpell(item, DmRulesEdition.v2024));
      }

      repository.addLayer(layer2024);
      repository.addLayer(layer2014);

      // 1. True Strike: 2014 has concentration, 2024 does not
      const trueStrike2014Ref = EntityReference<Spell>(
        refType: EntityType.spell,
        slug: 'true-strike',
        displayName: 'True Strike',
        rulesetPreferred: RulesetVersion.v2014,
      );
      const trueStrike2024Ref = EntityReference<Spell>(
        refType: EntityType.spell,
        slug: 'true-strike',
        displayName: 'True Strike',
        rulesetPreferred: RulesetVersion.v2024,
      );

      final ts2014 = resolver.resolveTyped(trueStrike2014Ref);
      final ts2024 = resolver.resolveTyped(trueStrike2024Ref);

      expect(ts2014.isResolved, isTrue);
      expect(ts2024.isResolved, isTrue);
      expect(ts2014.entity!.duration.requiresConcentration, isTrue);
      expect(ts2024.entity!.duration.requiresConcentration, isFalse);

      // 2. Cure Wounds: 2014 (1d8) vs 2024 (2d8)
      const cureWounds2014Ref = EntityReference<Spell>(
        refType: EntityType.spell,
        slug: 'cure-wounds',
        displayName: 'Cure Wounds',
        rulesetPreferred: RulesetVersion.v2014,
      );
      const cureWounds2024Ref = EntityReference<Spell>(
        refType: EntityType.spell,
        slug: 'cure-wounds',
        displayName: 'Cure Wounds',
        rulesetPreferred: RulesetVersion.v2024,
      );

      final cw2014 = resolver.resolveTyped(cureWounds2014Ref);
      final cw2024 = resolver.resolveTyped(cureWounds2024Ref);

      expect(cw2014.entity!.damageMath.first.diceFormula, equals('1d8 + mod'));
      expect(cw2024.entity!.damageMath.first.diceFormula, equals('2d8 + mod'));
    });

    test('verifies all SRD spell components and costly materials conformance', () {
      for (final item in SpellbookLibrary.allSpells) {
        final spell2024 = convertToDomainSpell(item, DmRulesEdition.v2024);

        if (item.rules2024.materialDetails != null) {
          final mat = item.rules2024.materialDetails!;
          expect(spell2024.components.m, isTrue,
              reason: '${item.name} has material details but component M is false');
          if (mat.costInGp > 0) {
            expect(spell2024.components.materialCostGp, equals(mat.costInGp));
          }
          expect(spell2024.components.consumesMaterial, equals(mat.isConsumed));
        }
      }
    });
  });
}
