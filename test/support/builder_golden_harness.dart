import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/characters/srd_backgrounds_library.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/characters/srd_classes_library.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/characters/srd_feats_library.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/characters/srd_species_library.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/domain/core_types.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/domain/homebrew_extended_entities.dart';
import 'package:dangerously_nerdy_5e_toolkit/screens/character_builder_screen.dart';
import 'package:dangerously_nerdy_5e_toolkit/widgets/character_sheet/character_header_banner.dart';
import 'step6_normalizer.dart';

class BuilderGoldenSpec {
  final String buildKey;
  final RulesetVersion ruleset;
  final String classSlug;
  final String speciesSlug;
  final String? subraceSlug;
  final String backgroundSlug;
  final bool useFlexibleOrigin2014;
  final AbilityType? backgroundPrimaryBonus2024;
  final AbilityType? backgroundSecondaryBonus2024;

  const BuilderGoldenSpec({
    required this.buildKey,
    required this.ruleset,
    required this.classSlug,
    required this.speciesSlug,
    this.subraceSlug,
    required this.backgroundSlug,
    this.useFlexibleOrigin2014 = false,
    this.backgroundPrimaryBonus2024,
    this.backgroundSecondaryBonus2024,
  });
}

/// Builds the deterministic list of Step 6.1 builder golden specs:
/// - Every SRD class in both editions, using:
///   - Fixed species rule: first species in SrdSpeciesLibrary.getSpeciesForRuleset(ruleset)
///     with subraces.isEmpty and flexibleAbilityChoiceCount == 0.
///   - Fixed background rule: first background in SrdBackgroundsLibrary.getBackgroundsForRuleset(ruleset).
/// - Plus 1 flexible origin build per edition:
///   - 2014: first species with flexibleAbilityChoiceCount > 0 (or first subrace with it).
///   - 2024: +2 Charisma / +1 Wisdom background bonuses on the first class/species/background.
List<BuilderGoldenSpec> buildAllBuilderGoldenSpecs() {
  final specs = <BuilderGoldenSpec>[];

  for (final ruleset in const [RulesetVersion.v2014, RulesetVersion.v2024]) {
    final editionTag = ruleset == RulesetVersion.v2014 ? '2014' : '2024';
    final classes = SrdClassesLibrary.baseClasses;
    final speciesList = SrdSpeciesLibrary.getSpeciesForRuleset(ruleset);
    final backgrounds = SrdBackgroundsLibrary.baseBackgrounds;

    final fixedSpecies = speciesList.firstWhere(
      (s) => s.subraces.isEmpty && s.flexibleAbilityChoiceCount == 0,
    );
    final fixedBackground = backgrounds.first;

    for (final cls in classes) {
      specs.add(BuilderGoldenSpec(
        buildKey: '${editionTag}_${cls.id.slug}',
        ruleset: ruleset,
        classSlug: cls.id.slug,
        speciesSlug: fixedSpecies.id.slug,
        backgroundSlug: fixedBackground.id.slug,
      ));
    }

    if (ruleset == RulesetVersion.v2014) {
      Race? flexSpecies;
      Subrace? flexSubrace;
      for (final sp in speciesList) {
        if (sp.flexibleAbilityChoiceCount > 0 && sp.subraces.isEmpty) {
          flexSpecies = sp;
          break;
        }
        for (final sub in sp.subraces) {
          if (sub.flexibleAbilityChoiceCount > 0) {
            flexSpecies = sp;
            flexSubrace = sub;
            break;
          }
        }
        if (flexSpecies != null) break;
      }
      specs.add(BuilderGoldenSpec(
        buildKey: '2014_flexible_origin',
        ruleset: RulesetVersion.v2014,
        classSlug: classes.first.id.slug,
        speciesSlug: flexSpecies!.id.slug,
        subraceSlug: flexSubrace?.id.slug,
        backgroundSlug: fixedBackground.id.slug,
        useFlexibleOrigin2014: true,
      ));
    } else {
      specs.add(BuilderGoldenSpec(
        buildKey: '2024_flexible_origin',
        ruleset: RulesetVersion.v2024,
        classSlug: classes.first.id.slug,
        speciesSlug: fixedSpecies.id.slug,
        backgroundSlug: fixedBackground.id.slug,
        backgroundPrimaryBonus2024: AbilityType.charisma,
        backgroundSecondaryBonus2024: AbilityType.wisdom,
      ));
    }
  }

  return specs;
}

({String key, String title}) _detectCurrentBuilderStep(WidgetTester tester) {
  String? firstMatchingText(bool Function(String) predicate) {
    for (final widget in tester.widgetList<Text>(find.byType(Text))) {
      final data = widget.data;
      if (data != null && predicate(data)) return data;
    }
    return null;
  }

  final tBasics = firstMatchingText(
      (s) => s.startsWith('Step 1: Character Identity & Edition'));
  if (tBasics != null) return (key: 'basics', title: tBasics);

  final tSpecies =
      firstMatchingText((s) => s.startsWith('Step 2: Choose Species'));
  if (tSpecies != null) return (key: 'species', title: tSpecies);

  final tClass = firstMatchingText(
      (s) => s.startsWith('Step 3: Choose Class & Starting Skills'));
  if (tClass != null) return (key: 'class', title: tClass);

  final tSubclass = firstMatchingText(
      (s) => s.startsWith('Choose ') && s.endsWith('Subclass / Archetype'));
  if (tSubclass != null) return (key: 'subclass', title: tSubclass);

  final tDecisions =
      firstMatchingText((s) => s.endsWith('Decisions & Specializations'));
  if (tDecisions != null) return (key: 'class_decisions', title: tDecisions);

  final tBg = firstMatchingText(
      (s) => s.startsWith('Step 4: Choose Background'));
  if (tBg != null) return (key: 'background', title: tBg);

  final tScores = firstMatchingText(
      (s) => s.startsWith('Step 5: Ability Score Allocation'));
  if (tScores != null) return (key: 'scores', title: tScores);

  final tFeats = firstMatchingText((s) =>
      s.startsWith('Step 6: Origin Feat') ||
      (s.startsWith('Step 6: ') && s.endsWith('Bonus Feat')));
  if (tFeats != null) return (key: 'feats', title: tFeats);

  final tSpells =
      firstMatchingText((s) => s.contains('Spells & Cantrips'));
  if (tSpells != null) return (key: 'spells', title: tSpells);

  final tEquip = firstMatchingText(
      (s) => s.contains('Starting Equipment & Inventory'));
  if (tEquip != null) return (key: 'equipment', title: tEquip);

  final tReview = firstMatchingText(
      (s) => s.contains('Review & Finalize') || s.contains('Character Summary'));
  if (tReview != null) return (key: 'review', title: tReview);

  // Fallback: check for CREATE & LAUNCH SHEET button
  if (tester.any(find.text('CREATE & LAUNCH SHEET'))) {
    return (key: 'review', title: 'Review & Finalize');
  }
  final visible = tester
      .widgetList<Text>(find.byType(Text))
      .map((t) => t.data)
      .whereType<String>()
      .take(25)
      .join(' | ');
  throw StateError('Unable to detect current builder step. Visible: $visible');
}

Future<void> _scrollAndTap(WidgetTester tester, Finder finder) async {
  for (var i = 0; i < 20 && finder.evaluate().isEmpty; i++) {
    final lists = find.byType(ListView);
    if (lists.evaluate().isEmpty) break;
    await tester.drag(lists.last, const Offset(0, -600));
    await tester.pumpAndSettle();
  }
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder, warnIfMissed: false);
  await tester.pumpAndSettle();
}

/// Drives [CharacterBuilderScreen] from step 0 through CREATE & LAUNCH SHEET
/// at 1280x800 and returns the golden record for [spec].
Future<Map<String, dynamic>> runBuilderGoldenSpec(
  WidgetTester tester,
  BuilderGoldenSpec spec,
) async {
  SharedPreferences.setMockInitialValues({});
  tester.view.physicalSize = const Size(1280, 800);
  tester.view.devicePixelRatio = 1.0;

  await tester.pumpWidget(
    MaterialApp(
      home: CharacterBuilderScreen(key: ValueKey(spec.buildKey)),
    ),
  );
  await tester.pumpAndSettle();

  // Switch to Guided Builder tab
  await tester.tap(find.text('Guided Builder'));
  await tester.pumpAndSettle();

  final species = SrdSpeciesLibrary.findBySlug(spec.speciesSlug)!;
  final cls = SrdClassesLibrary.findBySlug(spec.classSlug, ruleset: spec.ruleset)!;
  final bg = SrdBackgroundsLibrary.findBySlug(spec.backgroundSlug)!;

  final guidedSteps = <String>[];
  final visibleStepTitles = <String>[];
  String? spellsSubtitle;

  for (var guard = 0; guard < 15; guard++) {
    final step = _detectCurrentBuilderStep(tester);
    guidedSteps.add(step.key);
    visibleStepTitles.add(step.title);

    switch (step.key) {
      case 'basics':
        // Enter deterministic character name
        await tester.enterText(
            find.byType(TextField).first, 'Golden ${spec.buildKey}');
        await tester.pumpAndSettle();
        // Select edition
        final edLabel = spec.ruleset == RulesetVersion.v2014
            ? '2014 SRD (5.1 Classic)'
            : '2024 SRD (5.2 Revised)';
        await _scrollAndTap(tester, find.text(edLabel));

      case 'species':
        await _scrollAndTap(tester, find.text(species.name).first);
        if (spec.subraceSlug != null) {
          final sub = species.subraces
              .firstWhere((s) => s.id.slug == spec.subraceSlug);
          await _scrollAndTap(tester, find.text(sub.name).first);
        }

      case 'class':
        final dd = find.byType(DropdownButtonFormField<String>).first;
        await _scrollAndTap(tester, dd);
        await tester.tap(find.textContaining('${cls.name} (').last);
        await tester.pumpAndSettle();

      case 'subclass':
        // First offered subclass is auto-selected by default.
        break;

      case 'class_decisions':
        // Select first offered option for each decision if any FilterChip/ChoiceChip is unselected.
        break;

      case 'background':
        await _scrollAndTap(tester, find.text(bg.name).first);
        // If background skills overlap class skills, pick the first offered compensatory skill chips.
        for (var pick = 0; pick < 4; pick++) {
          final chips = find.byWidgetPredicate(
            (w) =>
                (w is ActionChip && w.onPressed != null) ||
                (w is FilterChip && w.onSelected != null && !w.selected),
          );
          if (chips.evaluate().isEmpty) break;
          await _scrollAndTap(tester, chips.first);
        }

      case 'scores':
        if (tester.any(find.text('Auto-Assign'))) {
          await _scrollAndTap(tester, find.text('Auto-Assign'));
        }
        if (spec.useFlexibleOrigin2014) {
          // Tap first flexible bonus chips until required count is selected.
          final chips = find.byWidgetPredicate(
            (w) =>
                w is FilterChip &&
                w.onSelected != null &&
                !w.selected,
          );
          final count = chips.evaluate().length;
          final picks = count >= 2 ? 2 : count;
          for (var i = 0; i < picks; i++) {
            final nextChip = find.byWidgetPredicate(
              (w) =>
                  w is FilterChip &&
                  w.onSelected != null &&
                  !w.selected,
            );
            if (nextChip.evaluate().isEmpty) break;
            await _scrollAndTap(tester, nextChip.first);
          }
        }
        if (spec.backgroundPrimaryBonus2024 != null) {
          final primaryDd = find.byType(DropdownButtonFormField<AbilityType>).first;
          await _scrollAndTap(tester, primaryDd);
          final pName = spec.backgroundPrimaryBonus2024!.name.toUpperCase();
          await tester.tap(find.text('$pName (+2)').last);
          await tester.pumpAndSettle();
        }
        if (spec.backgroundSecondaryBonus2024 != null) {
          final secondaryDd = find.byType(DropdownButtonFormField<AbilityType>).at(1);
          await _scrollAndTap(tester, secondaryDd);
          final sName = spec.backgroundSecondaryBonus2024!.name.toUpperCase();
          await tester.tap(find.text('$sName (+1)').last);
          await tester.pumpAndSettle();
        }

      case 'feats':
        // Select first offered feat
        final is2024 = spec.ruleset == RulesetVersion.v2024;
        final eligible = is2024
            ? SrdFeatsLibrary.getOriginFeats()
            : SrdFeatsLibrary.getFeatsForRuleset(spec.ruleset);
        if (eligible.isNotEmpty) {
          await _scrollAndTap(tester, find.text(eligible.first.name).first);
        }

      case 'spells':
        // Record the displayed casting-ability/prepared-limit subtitle so casting-ability regressions are caught.
        for (final el in find.byType(Text).evaluate()) {
          final data = (el.widget as Text).data;
          if (data != null &&
              (data.startsWith('Prepared limit:') ||
                  data.startsWith('Spells known limit:') ||
                  data.startsWith('A Level 1 Wizard must choose'))) {
            spellsSubtitle = data;
            break;
          }
        }

      case 'equipment':
        // First equipment package is auto-selected by default.
        break;

      case 'review':
        final createBtn = find.text('CREATE & LAUNCH SHEET');
        await _scrollAndTap(tester, createBtn);
        // Allow async saveCharacter + loadCharacters microtasks to complete
        await tester.pump(const Duration(milliseconds: 100));
        await tester.pumpAndSettle();

        final bannerFinder = find.byType(CharacterHeaderBanner);
        expect(bannerFinder, findsOneWidget,
            reason: 'Sheet should open after creating ${spec.buildKey}');
        final created = tester
            .widget<CharacterHeaderBanner>(bannerFinder)
            .controller
            .character;

        return {
          'buildKey': spec.buildKey,
          'classSlug': spec.classSlug,
          'edition': spec.ruleset == RulesetVersion.v2014 ? 'v2014' : 'v2024',
          'speciesSlug': spec.speciesSlug,
          'subraceSlug': spec.subraceSlug,
          'backgroundSlug': spec.backgroundSlug,
          'guidedSteps': guidedSteps,
          'visibleStepTitles': visibleStepTitles,
          'spellsSubtitle': ?spellsSubtitle,
          'character': normalizeCharacterMap(created.toMap()),
        };
    }

    // Advance to next step and scroll back to top so the next step title is visible
    final nextBtn = find.text('Next Step');
    await _scrollAndTap(tester, nextBtn);
    final lists = find.byType(ListView);
    if (lists.evaluate().isNotEmpty) {
      await tester.drag(lists.last, const Offset(0, 3000));
      await tester.pumpAndSettle();
    }
  }

  throw StateError(
      'Builder did not reach review step for ${spec.buildKey}; visited=$guidedSteps');
}
