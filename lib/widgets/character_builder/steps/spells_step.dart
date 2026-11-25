import 'package:material_ui/material_ui.dart';
import '../../../models/characters/srd_backgrounds_library.dart';
import '../../../models/characters/srd_species_library.dart';
import '../../../models/characters/subclass_spells_library.dart';
import '../../../models/domain/homebrew_extended_entities.dart';
import '../../../models/dm_screen_data.dart' show DmRulesEdition;
import '../../../models/spellbook_data.dart';
import '../../../services/haptic_service.dart';
import '../../glyphs/dnd_glyph.dart';
import 'builder_step_order.dart';

class BuilderSpellsStep extends StatelessWidget {
  final CharacterClass curClass;
  final RulesetVersion selectedRuleset;
  final String? selectedSpecies;
  final String? selectedSubrace;
  final String? selectedBackground;
  final String? wizardSelectedSubclass;
  final int stepNumber;
  final AbilityScores wizardBaseScores;
  final AbilityScores Function(Race? curSpecies, Background? curBackground,
      RulesetVersion ruleset, {Subrace? curSubrace}) calculateBonusScores;
  final Set<String> selectedWizardCantrips;
  final Set<String> selectedWizardSpells;
  final String spellSearchQuery;
  final ValueChanged<String> onSpellSearchQueryChanged;
  final ValueChanged<VoidCallback> onMutateState;

  const BuilderSpellsStep({
    super.key,
    required this.curClass,
    required this.selectedRuleset,
    required this.selectedSpecies,
    required this.selectedSubrace,
    required this.selectedBackground,
    required this.wizardSelectedSubclass,
    required this.stepNumber,
    required this.wizardBaseScores,
    required this.calculateBonusScores,
    required this.selectedWizardCantrips,
    required this.selectedWizardSpells,
    required this.spellSearchQuery,
    required this.onSpellSearchQueryChanged,
    required this.onMutateState,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final edition = selectedRuleset == RulesetVersion.v2024
        ? DmRulesEdition.v2024
        : DmRulesEdition.v2014;
    final casterProfile =
        resolveBuilderCasterProfile(curClass.id.slug, selectedRuleset);
    final spellClass = casterProfile.spellList;
    final curSpecies = selectedSpecies != null
        ? SrdSpeciesLibrary.findBySlug(selectedSpecies!)
        : null;
    final curSub = selectedSubrace != null
        ? SrdSpeciesLibrary.findSubraceBySlug(selectedSubrace!)
        : null;

    final speciesBonusSpells = <String>{};
    if (curSub != null) {
      speciesBonusSpells.addAll(curSub.grants
          .where((g) => g.type == GrantType.bonusSpell)
          .map((g) => g.payload['slug']?.toString().toLowerCase() ?? ''));
      final addSpells = curSub.customProperties['additionalSpells'];
      if (addSpells != null) {
        speciesBonusSpells.addAll(FeatureGrant.extractSpellNames(addSpells).map(
            (n) => n.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '-')));
      }
    }
    if (curSpecies != null) {
      speciesBonusSpells.addAll(curSpecies.grants
          .where((g) => g.type == GrantType.bonusSpell)
          .map((g) => g.payload['slug']?.toString().toLowerCase() ?? ''));
      final addSpells = curSpecies.customProperties['additionalSpells'];
      if (addSpells != null) {
        speciesBonusSpells.addAll(FeatureGrant.extractSpellNames(addSpells).map(
            (n) => n.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '-')));
      }
    }

    final allClassSpells = SpellbookLibrary.allSpells.where((s) {
      if (s.level > 1) return false;
      if (spellClass == null) return s.level <= 1;
      final rules = s.getRules(edition);
      final isClassSpell = rules.classes.contains(spellClass);
      final isExpanded = SubclassSpellsLibrary.isExpandedSpell(
              curClass.id.slug, wizardSelectedSubclass, s, edition) ||
          speciesBonusSpells.contains(s.id.toLowerCase());
      return isClassSpell || isExpanded;
    }).toList();

    final cantrips = allClassSpells.where((s) => s.level == 0).toList();
    final level1Spells = allClassSpells.where((s) => s.level == 1).toList();
    

    // Calculate dynamic spell limits based on class, level, ability score modifier, and edition
    final castingAbility =
        casterProfile.castingAbility ?? AbilityType.charisma;
    final curBackground = selectedBackground != null
        ? SrdBackgroundsLibrary.findBySlug(selectedBackground!)
        : null;
    final calculatedBonuses = calculateBonusScores(
        curSpecies, curBackground, selectedRuleset,
        curSubrace: curSub);
    final effectiveScores = wizardBaseScores.withBonus(calculatedBonuses);
    final castingMod = effectiveScores.getModifier(castingAbility);

    final limits = SpellAllocationValidator.getLimitsForClass(
      classSlug: curClass.id.slug,
      classLevel: 1,
      abilityModifier: castingMod,
      edition: edition,
    );

    final maxCantrips = limits.maxCantrips;
    final isWizard = curClass.id.slug.toLowerCase() == 'wizard';
    final maxSpells = (isWizard && limits.maxSpellbookInitialScribe > 0)
        ? limits.maxSpellbookInitialScribe // 6 for Wizard spellbook
        : (limits.maxSpellsPrepared > 0
            ? limits.maxSpellsPrepared
            : limits.maxSpellsKnown);

    final spellsSectionTitle = isWizard
        ? 'SPELLBOOK (1ST-LEVEL SPELLS)'
        : (limits.maxSpellsPrepared > 0
            ? 'PREPARED 1ST-LEVEL SPELLS'
            : '1ST-LEVEL SPELLS KNOWN');

    final spellsSubtitle = isWizard
        ? 'A Level 1 Wizard must choose exactly 6 1st-level spells to scribe into their spellbook.'
        : (limits.maxSpellsPrepared > 0
            ? 'Prepared limit: Level 1 + ${castingAbility.shortName} mod (${castingMod >= 0 ? "+$castingMod" : "$castingMod"}) = $maxSpells spells.'
            : 'Spells known limit: $maxSpells spells.');

    final alwaysPreparedSpells =
        SubclassSpellsLibrary.getAlwaysPreparedSpellsForLevel(
      classSlug: curClass.id.slug,
      subclassSlug: wizardSelectedSubclass,
      classLevel: 1,
      edition: edition,
    );

    final filteredCantrips = cantrips.where((c) {
      if (spellSearchQuery.isEmpty) return true;
      final q = spellSearchQuery.toLowerCase();
      final nameMatches = c.getName(edition).toLowerCase().contains(q);
      final idMatches = c.id.toLowerCase().contains(q);
      final schoolMatches = c.school.name.toLowerCase().contains(q);
      final tagsMatch = c.tags.any((t) => t.toLowerCase().contains(q));
      final summaryMatch = c.diffSummary?.toLowerCase().contains(q) ?? false;
      return nameMatches ||
          idMatches ||
          schoolMatches ||
          tagsMatch ||
          summaryMatch;
    }).toList();

    final filteredLevel1Spells = level1Spells.where((s) {
      if (spellSearchQuery.isEmpty) return true;
      final q = spellSearchQuery.toLowerCase();
      final nameMatches = s.getName(edition).toLowerCase().contains(q);
      final idMatches = s.id.toLowerCase().contains(q);
      final schoolMatches = s.school.name.toLowerCase().contains(q);
      final tagsMatch = s.tags.any((t) => t.toLowerCase().contains(q));
      final summaryMatch = s.diffSummary?.toLowerCase().contains(q) ?? false;
      return nameMatches ||
          idMatches ||
          schoolMatches ||
          tagsMatch ||
          summaryMatch;
    }).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Step $stepNumber: Spells & Cantrips',
            style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold, color: Colors.purpleAccent)),
        const SizedBox(height: 6),
        Text(
            'Select starting cantrips and 1st-level spells for ${curClass.name} (${castingAbility.shortName} mod: ${castingMod >= 0 ? "+$castingMod" : "$castingMod"}).',
            style: const TextStyle(fontSize: 12, color: Colors.white70)),
        const SizedBox(height: 12),

        // Subclass Always-Prepared Spells Alert Card
        if (alwaysPreparedSpells.isNotEmpty) ...[
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.teal.shade900.withValues(alpha: 0.25),
              borderRadius: BorderRadius.circular(10),
              border:
                  Border.all(color: Colors.tealAccent.withValues(alpha: 0.4)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.verified,
                        size: 14, color: Colors.tealAccent),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'Subclass Granted Spells (Always Prepared, Free Quota):',
                        style: theme.textTheme.labelSmall?.copyWith(
                            color: Colors.tealAccent,
                            fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: alwaysPreparedSpells.map((s) {
                    return Chip(
                      visualDensity: VisualDensity.compact,
                      avatar: DndGlyph.spell(
                        school: s.school,
                        level: s.level,
                        size: 16,
                        isDarkMode: true,
                      ),
                      label: Text('${s.getName(edition)} (L${s.level})',
                          style: const TextStyle(fontSize: 11)),
                      backgroundColor:
                          Colors.teal.shade800.withValues(alpha: 0.4),
                      side: BorderSide(
                          color: Colors.tealAccent.withValues(alpha: 0.3)),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
        ],

        // Quick Auto-Fill Recommended Spells
        Align(
          alignment: Alignment.centerRight,
          child: TextButton.icon(
            icon: const Icon(Icons.auto_fix_high, size: 16),
            label: const Text('Select Recommended Spells',
                style: TextStyle(fontSize: 12)),
            onPressed: () {
              HapticService.selectionTick(context);
              onMutateState(() {
                selectedWizardCantrips.clear();
                selectedWizardSpells.clear();
                if (cantrips.isNotEmpty && maxCantrips > 0) {
                  selectedWizardCantrips
                      .addAll(cantrips.take(maxCantrips).map((c) => c.id));
                }
                if (level1Spells.isNotEmpty && maxSpells > 0) {
                  selectedWizardSpells
                      .addAll(level1Spells.take(maxSpells).map((s) => s.id));
                }
              });
            },
          ),
        ),

        // Search Bar
        TextField(
          decoration: InputDecoration(
            labelText: 'Search Cantrips & Spells',
            hintText: 'Filter by spell name, school, or keywords...',
            prefixIcon: const Icon(Icons.search, size: 20),
            suffixIcon: spellSearchQuery.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.clear, size: 18),
                    onPressed: () => onSpellSearchQueryChanged(''),
                  )
                : null,
            border: const OutlineInputBorder(),
            isDense: true,
          ),
          onChanged: (val) => onSpellSearchQueryChanged(val.trim()),
        ),
        const SizedBox(height: 12),

        if (filteredCantrips.isEmpty &&
            filteredLevel1Spells.isEmpty &&
            spellSearchQuery.isNotEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 24),
            child: Center(
              child: Text(
                'No cantrips or spells found matching "$spellSearchQuery"',
                style: const TextStyle(
                    color: Colors.white54, fontStyle: FontStyle.italic),
              ),
            ),
          )
        else ...[
          // Section 1: Cantrips
          if (maxCantrips > 0 || filteredCantrips.isNotEmpty)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.purple.shade900.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                    color: Colors.purpleAccent.withValues(alpha: 0.3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('CANTRIPS (Level 0)',
                          style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.purpleAccent)),
                      Text(
                        '${selectedWizardCantrips.length} / $maxCantrips selected',
                        style: TextStyle(
                          fontSize: 12,
                          color: selectedWizardCantrips.length == maxCantrips
                              ? Colors.greenAccent
                              : Colors.amberAccent,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  if (filteredCantrips.isEmpty)
                    Text(
                        spellSearchQuery.isNotEmpty
                            ? 'No cantrips match search.'
                            : 'No class-specific cantrips found.',
                        style: const TextStyle(
                            fontSize: 12, color: Colors.white54))
                  else
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: filteredCantrips.map((c) {
                        final isSelected =
                            selectedWizardCantrips.contains(c.id);
                        return FilterChip(
                          selected: isSelected,
                          selectedColor:
                              Colors.purpleAccent.withValues(alpha: 0.3),
                          label: Text(c.getName(edition)),
                          avatar: DndGlyph.spell(
                            school: c.school,
                            level: 0,
                            size: 16,
                            isDarkMode: true,
                          ),
                          onSelected: (selected) {
                            HapticService.selectionTick(context);
                            onMutateState(() {
                              if (selected) {
                                if (selectedWizardCantrips.length <
                                    maxCantrips) {
                                  selectedWizardCantrips.add(c.id);
                                } else {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                          'Cannot select more than $maxCantrips cantrips for Level 1 ${curClass.name}.'),
                                      duration: const Duration(seconds: 2),
                                    ),
                                  );
                                }
                              } else {
                                selectedWizardCantrips.remove(c.id);
                              }
                            });
                          },
                        );
                      }).toList(),
                    ),
                ],
              ),
            ),

          const SizedBox(height: 16),

          // Section 2: 1st-Level Spells
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.cyan.shade900.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(10),
              border:
                  Border.all(color: Colors.cyanAccent.withValues(alpha: 0.3)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(spellsSectionTitle,
                        style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.cyanAccent)),
                    Text(
                      '${selectedWizardSpells.length} / $maxSpells selected',
                      style: TextStyle(
                        fontSize: 12,
                        color: selectedWizardSpells.length == maxSpells
                            ? Colors.greenAccent
                            : Colors.amberAccent,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(spellsSubtitle,
                    style: const TextStyle(
                        fontSize: 11,
                        color: Colors.white60,
                        fontStyle: FontStyle.italic)),
                const SizedBox(height: 8),
                if (filteredLevel1Spells.isEmpty)
                  Text(
                      spellSearchQuery.isNotEmpty
                          ? 'No 1st-level spells match search.'
                          : 'No class-specific 1st-level spells found.',
                      style:
                          const TextStyle(fontSize: 12, color: Colors.white54))
                else
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: filteredLevel1Spells.map((s) {
                      final isSelected = selectedWizardSpells.contains(s.id);
                      return FilterChip(
                        selected: isSelected,
                        selectedColor: Colors.cyanAccent.withValues(alpha: 0.3),
                        label: Text(s.getName(edition)),
                        avatar: DndGlyph.spell(
                          school: s.school,
                          level: 1,
                          size: 16,
                          isDarkMode: true,
                        ),
                        onSelected: (selected) {
                          HapticService.selectionTick(context);
                          onMutateState(() {
                            if (selected) {
                              if (selectedWizardSpells.length < maxSpells) {
                                selectedWizardSpells.add(s.id);
                              } else {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                        'Cannot select more than $maxSpells spells for Level 1 ${curClass.name}.'),
                                    duration: const Duration(seconds: 2),
                                  ),
                                );
                              }
                            } else {
                              selectedWizardSpells.remove(s.id);
                            }
                          });
                        },
                      );
                    }).toList(),
                  ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}
