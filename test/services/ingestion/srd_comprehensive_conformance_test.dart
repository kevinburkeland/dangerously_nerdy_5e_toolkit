import 'package:flutter_test/flutter_test.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/dm_screen_data.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/spellbook_data.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/magic_items/magic_item_library.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/monster_codex_data.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/srd_summons/srd_summons_library.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/domain/core_types.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/domain/entity_reference.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/domain/spell_monster_equipment.dart';
import 'package:dangerously_nerdy_5e_toolkit/services/repository/layered_priority_repository.dart';
import 'package:dangerously_nerdy_5e_toolkit/services/repository/reference_resolver.dart';

void main() {
  group('Comprehensive SRD Ecosystem Conformance & Repository Stack Tests', () {
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

    DamageType parseDamageType(String? typeStr) {
      if (typeStr == null) return DamageType.untyped;
      final lower = typeStr.toLowerCase();
      return DamageType.values.firstWhere(
        (e) => e.name == lower,
        orElse: () => DamageType.untyped,
      );
    }

    // =========================================================================
    // 1. DOMAIN ADAPTERS FOR SRD ENTITIES
    // =========================================================================

    Spell convertSpell(SpellItem item, DmRulesEdition edition) {
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
          actionType: rules.castingTime.toLowerCase().contains('bonus')
              ? ActionType.bonusAction
              : (rules.castingTime.toLowerCase().contains('reaction')
                  ? ActionType.reaction
                  : ActionType.action),
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
        components: SpellComponents(
          v: rules.components.contains('V'),
          s: rules.components.contains('S'),
          m: rules.components.contains('M'),
          materialDescription: rules.materialDetails?.description,
          materialCostGp: rules.materialDetails?.costInGp ?? 0,
          consumesMaterial: rules.materialDetails?.isConsumed ?? false,
        ),
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

    EquipmentItem convertItem(MagicItem item, DmRulesEdition edition) {
      final ruleset =
          edition == DmRulesEdition.v2024 ? RulesetVersion.v2024 : RulesetVersion.v2014;
      final name = item.getName(edition);
      final rules = edition == DmRulesEdition.v2024 ? item.rules2024 : item.rules2014;

      return EquipmentItem(
        id: EntityId(slug: slugify(name), ruleset: ruleset),
        name: name,
        itemType: item.category.label,
        rarity: item.rarity.name,
        requiresAttunement: item.requiresAttunement,
        descriptionMarkdown: rules.description,
        customProperties: {
          'legacyId': item.id,
          'category': item.category.label,
          'isChangedIn2024': item.isChangedIn2024,
        },
      );
    }

    Monster convertMonster(MonsterItem item, DmRulesEdition edition) {
      final ruleset =
          edition == DmRulesEdition.v2024 ? RulesetVersion.v2024 : RulesetVersion.v2014;
      final statBlock =
          edition == DmRulesEdition.v2024 ? item.statBlock2024 : item.statBlock2014;
      final name = item.getName(edition);

      final innateSpells = <EntityReference<Spell>>[];
      if (item.sourceSpellId != null && item.sourceSpellId!.isNotEmpty) {
        final spell = SpellbookLibrary.getSpellById(item.sourceSpellId!);
        if (spell != null) {
          innateSpells.add(EntityReference<Spell>(
            refType: EntityType.spell,
            slug: slugify(spell.name),
            displayName: spell.name,
            rulesetPreferred: ruleset,
          ));
        }
      }

      return Monster(
        id: EntityId(slug: slugify(name), ruleset: ruleset),
        name: name,
        size: statBlock.sizeDisplay,
        monsterType: statBlock.typeDisplay,
        alignment: statBlock.alignment,
        armorClass: statBlock.ac,
        hitPoints: statBlock.maxHp,
        hitDieFormula: statBlock.hitDice ?? '',
        challengeRating: statBlock.crDisplay,
        actionsMarkdown: statBlock.actions.map((a) => '**${a.name}**: ${a.description}').join('\n\n'),
        innateSpells: innateSpells,
        customProperties: {
          'sourceCategory': item.sourceCategory.name,
          'sourcePresetId': item.sourcePresetId,
          'legacyId': item.id,
        },
      );
    }

    // =========================================================================
    // 2. TESTS ACROSS THE ENTIRE SRD
    // =========================================================================

    test('validates inventory size across all SRD datasets in codebase', () {
      expect(SpellbookLibrary.allSpells.length, greaterThanOrEqualTo(100),
          reason: 'Comprehensive spells library');
      expect(MagicItemLibrary.allItems.length, greaterThanOrEqualTo(50),
          reason: 'Comprehensive magic items library');
      expect(MonsterCodexLibrary.allMonsters.length, greaterThanOrEqualTo(40),
          reason: 'Comprehensive bestiary / monster codex library');
      expect(DmScreenLibrary.allItems.length, greaterThanOrEqualTo(30),
          reason: 'Comprehensive DM reference rules library');
      expect(SrdSummonsLibrary.allPresets.length, greaterThanOrEqualTo(15),
          reason: 'Comprehensive SRD summons library');
    });

    test('ingests entire SRD corpus into 2014 & 2024 baseline repository layers', () {
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

      // Ingest Spells
      for (final spell in SpellbookLibrary.allSpells) {
        layer2014.registerEntity(convertSpell(spell, DmRulesEdition.v2014));
        layer2024.registerEntity(convertSpell(spell, DmRulesEdition.v2024));
      }

      // Ingest Magic Items & Equipment
      for (final item in MagicItemLibrary.allItems) {
        layer2014.registerEntity(convertItem(item, DmRulesEdition.v2014));
        layer2024.registerEntity(convertItem(item, DmRulesEdition.v2024));
      }

      // Ingest Monsters
      for (final monster in MonsterCodexLibrary.allMonsters) {
        layer2014.registerEntity(convertMonster(monster, DmRulesEdition.v2014));
        layer2024.registerEntity(convertMonster(monster, DmRulesEdition.v2024));
      }

      repository.addLayer(layer2024);
      repository.addLayer(layer2014);

      expect(layer2014.getAll().length,
          equals(SpellbookLibrary.allSpells.length +
              MagicItemLibrary.allItems.length +
              MonsterCodexLibrary.allMonsters.length));

      expect(layer2024.getAll().length,
          equals(SpellbookLibrary.allSpells.length +
              MagicItemLibrary.allItems.length +
              MonsterCodexLibrary.allMonsters.length));
    });

    test('resolves cross-entity pointers from monsters to spells dynamically', () {
      final layer2024 = PriorityLayer(
        layerId: 'base-srd-2024',
        name: 'SRD 2024 Ruleset',
        priority: LayerPriority.baseRuleset,
      );

      for (final spell in SpellbookLibrary.allSpells) {
        layer2024.registerEntity(convertSpell(spell, DmRulesEdition.v2024));
      }
      for (final monster in MonsterCodexLibrary.allMonsters) {
        layer2024.registerEntity(convertMonster(monster, DmRulesEdition.v2024));
      }
      repository.addLayer(layer2024);

      // Look up monsters that have linked source spells
      final monstersWithSpells = MonsterCodexLibrary.allMonsters
          .where((m) => m.sourceSpellId != null && m.sourceSpellId!.isNotEmpty);

      expect(monstersWithSpells, isNotEmpty);

      for (final monsterItem in monstersWithSpells) {
        final domainMonster = convertMonster(monsterItem, DmRulesEdition.v2024);
        for (final spellRef in domainMonster.innateSpells) {
          final resolvedSpellResult = resolver.resolveTyped<Spell>(spellRef);
          expect(
            resolvedSpellResult.isResolved,
            isTrue,
            reason: 'Monster "${domainMonster.name}" failed to resolve spell "${spellRef.slug}"',
          );
          expect(resolvedSpellResult.entity!.slug, equals(spellRef.slug));
        }
      }
    });

    test('verifies live campaign overrides across Spells, Monsters, and Items simultaneously', () {
      final layer2024 = PriorityLayer(
        layerId: 'base-srd-2024',
        name: 'SRD 2024 Ruleset',
        priority: LayerPriority.baseRuleset,
      );

      for (final spell in SpellbookLibrary.allSpells) {
        layer2024.registerEntity(convertSpell(spell, DmRulesEdition.v2024));
      }
      for (final item in MagicItemLibrary.allItems) {
        layer2024.registerEntity(convertItem(item, DmRulesEdition.v2024));
      }
      for (final monster in MonsterCodexLibrary.allMonsters) {
        layer2024.registerEntity(convertMonster(monster, DmRulesEdition.v2024));
      }
      repository.addLayer(layer2024);

      // Create Campaign Override Layer
      final campaignLayer = PriorityLayer(
        layerId: 'campaign-overrides',
        name: 'Campaign Overrides',
        priority: LayerPriority.campaignOverrides,
      );
      repository.addLayer(campaignLayer);

      // 1. Override Fireball
      final baseFireball = repository.lookup<Spell>('fireball')!;
      final customFireball = baseFireball.copyWith(
        name: 'Dragon Flame Fireball',
        damageMath: [const EvaluationMath(diceFormula: '12d6', damageType: DamageType.fire)],
      );
      repository.saveOverride('campaign-overrides', customFireball);

      // 2. Override Potion of Healing
      final basePotion = repository.lookup<EquipmentItem>('potion-of-healing')!;
      final customPotion = basePotion.copyWith(
        name: 'Greater Potion of Quick Healing',
        descriptionMarkdown: 'Heals 4d4 + 4 HP as a bonus action.',
      );
      repository.saveOverride('campaign-overrides', customPotion);

      // 3. Override Goblin
      final baseGoblin = repository.lookup<Monster>('goblin')!;
      final customGoblin = baseGoblin.copyWith(
        name: 'Armored Goblin Chieftain',
        armorClass: 18,
        hitPoints: 35,
      );
      repository.saveOverride('campaign-overrides', customGoblin);

      // Verify Campaign Overrides Resolve First
      const fireballRef = EntityReference<Spell>(
        refType: EntityType.spell,
        slug: 'fireball',
        displayName: 'Fireball',
      );
      const potionRef = EntityReference<EquipmentItem>(
        refType: EntityType.equipment,
        slug: 'potion-of-healing',
        displayName: 'Potion of Healing',
      );
      const goblinRef = EntityReference<Monster>(
        refType: EntityType.monster,
        slug: 'goblin',
        displayName: 'Goblin',
      );

      expect(resolver.resolveTyped(fireballRef).entity!.name, equals('Dragon Flame Fireball'));
      expect(resolver.resolveTyped(potionRef).entity!.name, equals('Greater Potion of Quick Healing'));
      expect(resolver.resolveTyped(goblinRef).entity!.name, equals('Armored Goblin Chieftain'));

      // Disable Campaign Layer -> Fall through to base SRD
      repository.setLayerActive('campaign-overrides', false);

      expect(resolver.resolveTyped(fireballRef).entity!.name, equals(baseFireball.name));
      expect(resolver.resolveTyped(potionRef).entity!.name, equals(basePotion.name));
      expect(resolver.resolveTyped(goblinRef).entity!.name, equals(baseGoblin.name));
    });

    test('verifies DM Reference Screen rules and conditions integrity', () {
      final conditions = DmScreenLibrary.allItems
          .where((i) => i.category == DmCategory.conditions)
          .toList();
      expect(conditions, isNotEmpty);

      // Check essential 5e conditions
      final conditionTitles = conditions.map((c) => c.title.toLowerCase()).toList();
      expect(conditionTitles.any((t) => t.contains('blinded')), isTrue);
      expect(conditionTitles.any((t) => t.contains('charmed')), isTrue);
      expect(conditionTitles.any((t) => t.contains('frightened')), isTrue);
      expect(conditionTitles.any((t) => t.contains('grappled')), isTrue);
      expect(conditionTitles.any((t) => t.contains('incapacitated')), isTrue);
      expect(conditionTitles.any((t) => t.contains('invisible')), isTrue);
      expect(conditionTitles.any((t) => t.contains('paralyzed')), isTrue);
      expect(conditionTitles.any((t) => t.contains('petrified')), isTrue);
      expect(conditionTitles.any((t) => t.contains('poisoned')), isTrue);
      expect(conditionTitles.any((t) => t.contains('prone')), isTrue);
      expect(conditionTitles.any((t) => t.contains('restrained')), isTrue);
      expect(conditionTitles.any((t) => t.contains('stunned')), isTrue);
      expect(conditionTitles.any((t) => t.contains('unconscious')), isTrue);
      expect(conditionTitles.any((t) => t.contains('exhaustion')), isTrue);
    });
  });
}
