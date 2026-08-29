import 'package:flutter_test/flutter_test.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/domain/core_types.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/domain/entity_reference.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/domain/spell_monster_equipment.dart';
import 'package:dangerously_nerdy_5e_toolkit/services/repository/layered_priority_repository.dart';
import 'package:dangerously_nerdy_5e_toolkit/services/repository/reference_resolver.dart';

void main() {
  group('Layered Priority Repository & Resolver Tests', () {
    late LayeredPriorityRepository repository;
    late ReferenceResolver resolver;

    late Spell baseFireball2024;
    late Spell baseFireball2014;
    late Spell customFireballOverride;

    setUp(() {
      repository = LayeredPriorityRepository();
      resolver = ReferenceResolver(repository);

      baseFireball2024 = Spell(
        id: const EntityId(slug: 'fireball', ruleset: RulesetVersion.v2024),
        name: 'Fireball (2024)',
        level: 3,
        school: 'Evocation',
        castingTime: const CastingTime(cost: 1, actionType: ActionType.action),
        duration: const SpellDuration(type: DurationType.instantaneous),
        range: '150 feet',
        components: const SpellComponents(v: true, s: true, m: true),
        descriptionMarkdown: 'SRD 2024 Fireball description.',
        damageMath: const [EvaluationMath(diceFormula: '8d6', damageType: DamageType.fire)],
      );

      baseFireball2014 = Spell(
        id: const EntityId(slug: 'fireball', ruleset: RulesetVersion.v2014),
        name: 'Fireball (2014)',
        level: 3,
        school: 'Evocation',
        castingTime: const CastingTime(cost: 1, actionType: ActionType.action),
        duration: const SpellDuration(type: DurationType.instantaneous),
        range: '150 feet',
        components: const SpellComponents(v: true, s: true, m: true),
        descriptionMarkdown: 'SRD 2014 Fireball description.',
        damageMath: const [EvaluationMath(diceFormula: '8d6', damageType: DamageType.fire)],
      );

      customFireballOverride = Spell(
        id: const EntityId(slug: 'fireball', ruleset: RulesetVersion.homebrew),
        name: 'Custom Mega Fireball',
        level: 3,
        school: 'Evocation',
        castingTime: const CastingTime(cost: 1, actionType: ActionType.bonusAction),
        duration: const SpellDuration(type: DurationType.instantaneous),
        range: '300 feet',
        components: const SpellComponents(v: true),
        descriptionMarkdown: 'Overridden custom fireball in campaign.',
        damageMath: const [EvaluationMath(diceFormula: '10d6', damageType: DamageType.fire)],
      );
    });

    test('resolves from baseline layer when no overrides present', () {
      final baseLayer = PriorityLayer(
        layerId: 'base-srd-2024',
        name: 'SRD 2024',
        priority: LayerPriority.baseRuleset,
      )..registerEntity(baseFireball2024);

      repository.addLayer(baseLayer);

      const ref = EntityReference<Spell>(
        refType: EntityType.spell,
        slug: 'fireball',
        displayName: 'Fireball',
      );

      final result = resolver.resolveTyped(ref);
      expect(result.isResolved, isTrue);
      expect(result.entity!.name, equals('Fireball (2024)'));
      expect(result.entity!.ruleset, equals(RulesetVersion.v2024));
    });

    test('resolves specific ruleset version when multiple baselines exist', () {
      final layer2024 = PriorityLayer(
        layerId: 'base-srd-2024',
        name: 'SRD 2024',
        priority: LayerPriority.baseRuleset,
      )..registerEntity(baseFireball2024);

      final layer2014 = PriorityLayer(
        layerId: 'base-srd-2014',
        name: 'SRD 2014',
        priority: LayerPriority.baseRuleset,
      )..registerEntity(baseFireball2014);

      repository.addLayer(layer2024);
      repository.addLayer(layer2014);

      const ref2014 = EntityReference<Spell>(
        refType: EntityType.spell,
        slug: 'fireball',
        displayName: 'Fireball',
        rulesetPreferred: RulesetVersion.v2014,
      );

      final result = resolver.resolveTyped(ref2014);
      expect(result.isResolved, isTrue);
      expect(result.entity!.name, equals('Fireball (2014)'));
      expect(result.entity!.ruleset, equals(RulesetVersion.v2014));
    });

    test('campaign override layer takes top priority (Copy-on-Write clone)', () {
      final baseLayer = PriorityLayer(
        layerId: 'base-srd-2024',
        name: 'SRD 2024',
        priority: LayerPriority.baseRuleset,
      )..registerEntity(baseFireball2024);

      final campaignLayer = PriorityLayer(
        layerId: 'campaign-1',
        name: 'Campaign Layer',
        priority: LayerPriority.campaignOverrides,
      );

      repository.addLayer(baseLayer);
      repository.addLayer(campaignLayer);

      // Save full CoW clone in campaign layer
      repository.saveOverride('campaign-1', customFireballOverride);

      const ref = EntityReference<Spell>(
        refType: EntityType.spell,
        slug: 'fireball',
        displayName: 'Fireball',
      );

      final result = resolver.resolveTyped(ref);
      expect(result.isResolved, isTrue);
      expect(result.entity!.name, equals('Custom Mega Fireball'));
      expect(result.entity!.castingTime.actionType, equals(ActionType.bonusAction));
      expect(result.entity!.damageMath.first.diceFormula, equals('10d6'));
    });

    test('disabling top layer falls through cleanly to base ruleset', () {
      final baseLayer = PriorityLayer(
        layerId: 'base-srd-2024',
        name: 'SRD 2024',
        priority: LayerPriority.baseRuleset,
      )..registerEntity(baseFireball2024);

      final campaignLayer = PriorityLayer(
        layerId: 'campaign-1',
        name: 'Campaign Layer',
        priority: LayerPriority.campaignOverrides,
      )..registerEntity(customFireballOverride);

      repository.addLayer(baseLayer);
      repository.addLayer(campaignLayer);

      // Disable top layer
      repository.setLayerActive('campaign-1', false);

      const ref = EntityReference<Spell>(
        refType: EntityType.spell,
        slug: 'fireball',
        displayName: 'Fireball',
      );

      final result = resolver.resolveTyped(ref);
      expect(result.isResolved, isTrue);
      expect(result.entity!.name, equals('Fireball (2024)'));
    });

    test('returns UnresolvedReference Null-Object when entity does not exist', () {
      final baseLayer = PriorityLayer(
        layerId: 'base-srd-2024',
        name: 'SRD 2024',
        priority: LayerPriority.baseRuleset,
      )..registerEntity(baseFireball2024);

      repository.addLayer(baseLayer);

      const missingRef = EntityReference<Spell>(
        refType: EntityType.spell,
        slug: 'wish',
        displayName: 'Wish',
      );

      final result = resolver.resolve(missingRef);
      expect(result, isA<UnresolvedReference>());
      expect(result.name, equals('[Missing spell: wish]'));
      expect(result.slug, equals('wish'));

      final typedResult = resolver.resolveTyped(missingRef);
      expect(typedResult.isResolved, isFalse);
      expect(typedResult.displayName, equals('[Missing spell: wish]'));
    });
  });
}
