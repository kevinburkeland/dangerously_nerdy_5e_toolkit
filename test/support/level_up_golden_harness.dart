import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vtt_ruleset_dnd5e/vtt_ruleset_dnd5e.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/characters/srd_classes_library.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/domain/character_models.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/domain/core_types.dart';
import 'package:dangerously_nerdy_5e_toolkit/widgets/character_builder/level_up_wizard_dialog.dart';
import 'step6_normalizer.dart';

class LevelUpGoldenSpec {
  final String caseKey;
  final RulesetVersion ruleset;
  final String classSlug;
  final int fromLevel;
  final int toLevel;

  const LevelUpGoldenSpec({
    required this.caseKey,
    required this.ruleset,
    required this.classSlug,
    required this.fromLevel,
    required this.toLevel,
  });
}

List<LevelUpGoldenSpec> buildAllLevelUpGoldenSpecs() {
  final specs = <LevelUpGoldenSpec>[];
  for (final ruleset in const [RulesetVersion.v2014, RulesetVersion.v2024]) {
    final ed = ruleset == RulesetVersion.v2014 ? '2014' : '2024';
    final classes = SrdClassesLibrary.baseClasses;
    for (final cls in classes) {
      for (var fromLevel = 1; fromLevel <= 4; fromLevel++) {
        specs.add(LevelUpGoldenSpec(
          caseKey: '${ed}_${cls.id.slug}_L${fromLevel}_to_L${fromLevel + 1}',
          ruleset: ruleset,
          classSlug: cls.id.slug,
          fromLevel: fromLevel,
          toLevel: fromLevel + 1,
        ));
      }
    }
  }
  return specs;
}

AbilityType? _parseCastingAbility(String? raw) {
  if (raw == null || raw.trim().isEmpty) return null;
  final lower = raw.toLowerCase().trim();
  for (final ab in AbilityType.values) {
    if (ab.name.toLowerCase() == lower || ab.shortName.toLowerCase() == lower) {
      return ab;
    }
  }
  return null;
}

int _hitDieSides(String hitDie) {
  return int.tryParse(hitDie.toLowerCase().replaceAll('d', '')) ?? 8;
}

/// Builds a deterministic single-class Character at [spec.fromLevel]:
/// - Standard array (15, 14, 13, 12, 10, 8)
/// - CON = 14 (+2)
/// - Casting ability (from SrdClassesLibrary) = 15 (+2), or STR = 15 for non-casters
/// - Remaining abilities assigned [13, 12, 10, 8] in AbilityType.values order
/// - First SRD subclass pre-attached when fromLevel >= subclassLevel
Character buildDeterministicCharacterForLevelUp(LevelUpGoldenSpec spec) {
  final cls = SrdClassesLibrary.findBySlug(spec.classSlug, ruleset: spec.ruleset)!;
  final castingAb = _parseCastingAbility(cls.spellcastingAbility) ?? AbilityType.strength;

  final scores = <AbilityType, int>{
    AbilityType.constitution: 14,
    castingAb: 15,
  };
  final remaining = [13, 12, 10, 8];
  var remIdx = 0;
  for (final ab in AbilityType.values) {
    if (!scores.containsKey(ab)) {
      scores[ab] = remaining[remIdx++];
    }
  }

  final subLevel = cls.getSubclassLevel(spec.ruleset);
  EntityReference<DomainEntity>? existingSub;
  if (spec.fromLevel >= subLevel && cls.subclasses.isNotEmpty) {
    final firstSub = cls.subclasses.first;
    existingSub = EntityReference<DomainEntity>.empty(
      refType: EntityType.subclass,
      slug: firstSub.id.slug,
      displayName: firstSub.name,
    );
  }

  final sides = _hitDieSides(cls.hitDie);
  final fixedAvg = (sides ~/ 2) + 1;
  final startHp = sides + 2 + (spec.fromLevel - 1) * (fixedAvg + 2);

  return Character(
    id: EntityId(slug: 'lvlup_${spec.caseKey}', ruleset: spec.ruleset),
    name: 'Hero ${spec.caseKey}',
    speciesRef: const EntityReference<DomainEntity>.empty(
      refType: EntityType.species,
      slug: 'human',
      displayName: 'Human',
    ),
    progression: CharacterProgression(
      classes: [
        ClassLevelProgression(
          classRef: EntityReference<DomainEntity>.empty(
            refType: EntityType.classDefinition,
            slug: cls.id.slug,
            displayName: cls.name,
          ),
          subclassRef: existingSub,
          level: spec.fromLevel,
          hitDie: cls.hitDie,
          isStartingClass: true,
        ),
      ],
    ),
    baseScores: AbilityScores(
      strength: scores[AbilityType.strength]!,
      dexterity: scores[AbilityType.dexterity]!,
      constitution: scores[AbilityType.constitution]!,
      intelligence: scores[AbilityType.intelligence]!,
      wisdom: scores[AbilityType.wisdom]!,
      charisma: scores[AbilityType.charisma]!,
    ),
    resources: CharacterResourcePool(
      currentHp: startHp,
      currentHitDice: {cls.hitDie: spec.fromLevel},
    ),
  );
}

String _extractTextFromWidget(Widget widget) {
  if (widget is Text) return widget.data ?? '';
  if (widget is Row) {
    for (final child in widget.children) {
      final t = _extractTextFromWidget(child);
      if (t.isNotEmpty) return t;
    }
  }
  if (widget is Expanded) return _extractTextFromWidget(widget.child);
  if (widget is Padding && widget.child != null) {
    return _extractTextFromWidget(widget.child!);
  }
  return '';
}

String _currentStepHeader(WidgetTester tester) {
  for (final t in tester.widgetList<Text>(find.byType(Text))) {
    final data = t.data;
    if (data != null && data.startsWith('Step ') && data.contains(' of 6:')) {
      return data;
    }
  }
  throw StateError('Could not find LevelUpWizardDialog step header');
}

int _readShownHpGain(WidgetTester tester) {
  final re = RegExp(r'^\+(\d+) HP$');
  for (final t in tester.widgetList<Text>(find.byType(Text))) {
    final data = t.data;
    if (data != null) {
      final m = re.firstMatch(data.trim());
      if (m != null) return int.parse(m.group(1)!);
    }
  }
  throw StateError('Could not find +<N> HP text on Step 2');
}

({int highestSpellLevel, String? spellQuotaText}) _readStep5SpellInfo(
    WidgetTester tester) {
  final maxRe = RegExp(r'Max Spell Level:\s*(\d+)');
  int maxLvl = 0;
  String? quota;
  for (final t in tester.widgetList<Text>(find.byType(Text))) {
    final data = t.data;
    if (data == null) continue;
    final m = maxRe.firstMatch(data);
    if (m != null) {
      maxLvl = int.parse(m.group(1)!);
    }
    if (data.startsWith('Quota for Level ')) {
      quota = data;
    }
  }
  return (highestSpellLevel: maxLvl, spellQuotaText: quota);
}

/// Drives [LevelUpWizardDialog.show] at 1280x800 for [spec] and returns the
/// full characterization record plus preview-vs-confirm comparison data.
Future<Map<String, dynamic>> runLevelUpGoldenSpec(
  WidgetTester tester,
  LevelUpGoldenSpec spec,
) async {
  tester.view.physicalSize = const Size(1280, 800);
  tester.view.devicePixelRatio = 1.0;

  final baseChar = buildDeterministicCharacterForLevelUp(spec);
  Character? confirmedChar;

  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) => ElevatedButton(
            onPressed: () {
              LevelUpWizardDialog.show(
                context,
                character: baseChar,
                onLevelUpApplied: (upgraded) {
                  confirmedChar = upgraded;
                },
              );
            },
            child: const Text('Open Wizard'),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();

  await tester.tap(find.text('Open Wizard'));
  await tester.pumpAndSettle();

  final stepsShown = <String>[];

  // Step 1: Target Class
  stepsShown.add(_currentStepHeader(tester));
  final classDd = tester.widget<DropdownButton<String>>(
    find.descendant(
      of: find.byType(DropdownButtonFormField<String>).first,
      matching: find.byType(DropdownButton<String>),
    ),
  );
  final classesOffered = (classDd.items ?? const <DropdownMenuItem<String>>[])
      .map((item) => {
            'slug': item.value ?? '',
            'label': _extractTextFromWidget(item.child),
          })
      .toList();

  await tester.tap(find.text('Next Step'));
  await tester.pumpAndSettle();

  // Step 2: Hit Points
  stepsShown.add(_currentStepHeader(tester));
  final fixedAverageHpGainShown = _readShownHpGain(tester);

  await tester.tap(find.text('Next Step'));
  await tester.pumpAndSettle();

  // Step 3: Subclass & Features
  stepsShown.add(_currentStepHeader(tester));
  var subclassesOffered = <Map<String, String>>[];
  final subDdFinder = find.byType(DropdownButtonFormField<String>);
  if (subDdFinder.evaluate().isNotEmpty) {
    final subDd = tester.widget<DropdownButton<String>>(
      find.descendant(
        of: subDdFinder.first,
        matching: find.byType(DropdownButton<String>),
      ),
    );
    subclassesOffered = (subDd.items ?? const <DropdownMenuItem<String>>[])
        .map((item) => {
              'slug': item.value ?? '',
              'label': _extractTextFromWidget(item.child),
            })
        .toList();
    if (subclassesOffered.isNotEmpty) {
      await tester.tap(subDdFinder.first);
      await tester.pumpAndSettle();
      await tester.tap(find.text(subclassesOffered.first['label']!).last);
      await tester.pumpAndSettle();
    }
  }

  await tester.tap(find.text('Next Step'));
  await tester.pumpAndSettle();

  // Step 4: ASI / Feat
  stepsShown.add(_currentStepHeader(tester));
  int? conPlusTwoHpGainShown;
  if (spec.toLevel == 4) {
    // Pick +2 CONSTITUTION and check Step 2's shown HP gain, then restore to STRENGTH
    final asiDdFinder = find.byType(DropdownButtonFormField<AbilityType>);
    if (asiDdFinder.evaluate().isNotEmpty) {
      await tester.tap(asiDdFinder.first);
      await tester.pumpAndSettle();
      await tester.tap(find.textContaining('CONSTITUTION').last);
      await tester.pumpAndSettle();

      // Go back 2 steps (Step 4 -> Step 3 -> Step 2) to read HP gain shown
      await tester.tap(find.text('Back'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Back'));
      await tester.pumpAndSettle();
      conPlusTwoHpGainShown = _readShownHpGain(tester);

      // Return to Step 4 (Step 2 -> Step 3 -> Step 4) and restore default STRENGTH
      await tester.tap(find.text('Next Step'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Next Step'));
      await tester.pumpAndSettle();

      await tester.tap(find.byType(DropdownButtonFormField<AbilityType>).first);
      await tester.pumpAndSettle();
      await tester.tap(find.textContaining('STRENGTH').last);
      await tester.pumpAndSettle();
    }
  }

  await tester.tap(find.text('Next Step'));
  await tester.pumpAndSettle();

  // Step 5: Spells
  stepsShown.add(_currentStepHeader(tester));
  final spellInfo = _readStep5SpellInfo(tester);

  await tester.tap(find.text('Next Step'));
  await tester.pumpAndSettle();

  // Step 6: Review & Confirm
  stepsShown.add(_currentStepHeader(tester));
  await tester.tap(find.text('CONFIRM LEVEL UP'));
  await tester.pumpAndSettle();

  expect(confirmedChar, isNotNull,
      reason: 'CONFIRM LEVEL UP must invoke onLevelUpApplied for ${spec.caseKey}');

  final confirmed = confirmedChar!;
  final hpGainAfterConfirm =
      confirmed.resources.currentHp - baseChar.resources.currentHp;

  final eval = CharacterEvaluationEngine.evaluate(confirmed);
  final int? impliedCastingModFromDc = eval.spellSaveDcs.isNotEmpty
      ? eval.spellSaveDcs.values.first - 8 - eval.proficiencyBonus
      : null;

  // Compute casting modifier the wizard used from the character's casting ability + pending ASI
  final cls = SrdClassesLibrary.findBySlug(spec.classSlug, ruleset: spec.ruleset)!;
  final castingAb = _parseCastingAbility(cls.spellcastingAbility);
  int? wizardCastingMod;
  if (spellInfo.highestSpellLevel > 0) {
    final ab = castingAb ?? AbilityType.intelligence;
    var score = baseChar.baseScores.getScore(ab) + baseChar.bonusScores.getScore(ab);
    if (spec.toLevel == 4 && ab == AbilityType.strength) {
      score += 2;
    }
    wizardCastingMod = score.dndModifier;
  }

  return {
    'caseKey': spec.caseKey,
    'classSlug': spec.classSlug,
    'edition': spec.ruleset == RulesetVersion.v2014 ? 'v2014' : 'v2024',
    'fromLevel': spec.fromLevel,
    'toLevel': spec.toLevel,
    'classesOffered': classesOffered,
    'subclassesOffered': subclassesOffered,
    'stepsShown': stepsShown,
    'fixedAverageHpGainShown': fixedAverageHpGainShown,
    'conPlusTwoHpGainShown': conPlusTwoHpGainShown,
    'hpGainAfterConfirm': hpGainAfterConfirm,
    'highestSpellLevelShown': spellInfo.highestSpellLevel,
    'spellQuotaText': spellInfo.spellQuotaText,
    'castingModifierShown': wizardCastingMod,
    'castingModifierImpliedByConfirmedDc': impliedCastingModFromDc,
    'characterAfterConfirm': normalizeCharacterMap(confirmed.toMap()),
  };
}
