import 'package:material_ui/material_ui.dart';
import '../../../models/domain/character_models.dart';
import '../../../models/domain/core_types.dart';
import '../../../models/domain/homebrew_extended_entities.dart';
import '../../../providers/character_builder_controller.dart';
import '../../../services/haptic_service.dart';

class BuilderSpeciesBonusesAndTraitsSection extends StatelessWidget {
  final Race species;
  final Subrace? selectedSubraceObj;
  final Background? curBackground;
  final RulesetVersion selectedRuleset;
  final CharacterBuilderController abilityScoreController;
  final AbilityScores wizardBaseScores;
  final int flexibleCount;
  final int flexibleBonusValue;
  final Map<String, int> fixedBonuses;
  final List<String>? flexiblePool;
  final Set<AbilityType> variantHumanBonuses;
  final int speciesBonusSkillCount;
  final List<SkillType> eligibleBonusSkills;
  final Set<SkillType> speciesBonusSkillPicks;
  final String? dwarfToolChoice;
  final Set<String> speciesBonusLanguages;
  final AbilityScores bonusScores;
  final void Function(AbilityType ab, bool selected, int flexibleCount)
      onToggleFlexibleAbility;
  final void Function(SkillType skill, bool selected, int maxCount)
      onToggleSpeciesBonusSkill;
  final ValueChanged<String> onDwarfToolChanged;
  final void Function(String lang, bool selected) onToggleSpeciesBonusLanguage;

  const BuilderSpeciesBonusesAndTraitsSection({
    super.key,
    required this.species,
    required this.selectedSubraceObj,
    required this.curBackground,
    required this.selectedRuleset,
    required this.abilityScoreController,
    required this.wizardBaseScores,
    required this.flexibleCount,
    required this.flexibleBonusValue,
    required this.fixedBonuses,
    required this.flexiblePool,
    required this.variantHumanBonuses,
    required this.speciesBonusSkillCount,
    required this.eligibleBonusSkills,
    required this.speciesBonusSkillPicks,
    required this.dwarfToolChoice,
    required this.speciesBonusLanguages,
    required this.bonusScores,
    required this.onToggleFlexibleAbility,
    required this.onToggleSpeciesBonusSkill,
    required this.onDwarfToolChanged,
    required this.onToggleSpeciesBonusLanguage,
  });

  @override
  Widget build(BuildContext context) {
    final sp = species;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // 2014 Racial Attributes & Lineage Flexible Choices
        if (selectedRuleset == RulesetVersion.v2014 && flexibleCount > 0) ...[
          const Divider(height: 1, color: Colors.cyanAccent),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.cyan.shade900.withValues(alpha: 0.25),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: variantHumanBonuses.length == flexibleCount
                      ? Colors.greenAccent
                      : Colors.cyanAccent.withValues(alpha: 0.5),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          '${sp.name}${selectedSubraceObj != null ? " (${selectedSubraceObj!.name})" : ""} Lineage Ability Choices (+$flexibleBonusValue):',
                          style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.cyanAccent,
                              fontSize: 13),
                        ),
                      ),
                      Text(
                        '${variantHumanBonuses.length} / $flexibleCount selected',
                        style: TextStyle(
                          fontSize: 12,
                          color: variantHumanBonuses.length == flexibleCount
                              ? Colors.greenAccent
                              : Colors.amberAccent,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Select $flexibleCount different ability score${flexibleCount > 1 ? 's' : ''} to receive a +$flexibleBonusValue bonus:',
                    style:
                        const TextStyle(fontSize: 12, color: Colors.white70),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    children: AbilityType.values.map((ab) {
                      final isFixed =
                          fixedBonuses.containsKey(ab.name.toLowerCase());
                      final inPool = flexiblePool == null ||
                          flexiblePool!.isEmpty ||
                          flexiblePool!.any((p) {
                            final pStr = p.toLowerCase().trim();
                            final prefix =
                                pStr.length > 3 ? pStr.substring(0, 3) : pStr;
                            return ab.name.toLowerCase().startsWith(prefix);
                          });
                      if (!isFixed && !inPool) {
                        return const SizedBox.shrink();
                      }

                      final isChosen = variantHumanBonuses.contains(ab);
                      return FilterChip(
                        label: Text(isFixed
                            ? '${ab.name.toUpperCase()} (+${fixedBonuses[ab.name.toLowerCase()]} Fixed)'
                            : '${ab.name.toUpperCase()} (+$flexibleBonusValue Bonus)'),
                        selected: isChosen,
                        selectedColor:
                            Colors.cyanAccent.withValues(alpha: 0.3),
                        checkmarkColor: Colors.cyanAccent,
                        onSelected: isFixed
                            ? null
                            : (selected) {
                                HapticService.selectionTick(context);
                                onToggleFlexibleAbility(
                                    ab, selected, flexibleCount);
                              },
                      );
                    }).toList(),
                  ),
                  if (wizardBaseScores.strength > 0) ...[
                    const SizedBox(height: 10),
                    const Text(
                      'Current Ability Totals (allocated base + lineage bonuses):',
                      style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: Colors.white70),
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: AbilityType.values.map((ab) {
                        final base = wizardBaseScores.getScore(ab);
                        final fixedAmt =
                            fixedBonuses[ab.name.toLowerCase()] ?? 0;
                        final flexAmt = variantHumanBonuses.contains(ab)
                            ? flexibleBonusValue
                            : 0;
                        final bonusAmt = fixedAmt + flexAmt;
                        final total = base + bonusAmt;
                        final mod = Dnd5eScoreMath.scoreToModifier(total);
                        final modStr = mod >= 0 ? '+$mod' : '$mod';
                        return Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: bonusAmt > 0
                                ? Colors.cyan.shade900.withValues(alpha: 0.4)
                                : Colors.black26,
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(
                                color: bonusAmt > 0
                                    ? Colors.cyanAccent.withValues(alpha: 0.5)
                                    : Colors.white12),
                          ),
                          child: Text(
                            '${ab.name.substring(0, 3).toUpperCase()}: $total ($modStr)${bonusAmt > 0 ? ' [+$bonusAmt]' : ''}',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: bonusAmt > 0
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                              color: bonusAmt > 0
                                  ? Colors.cyanAccent
                                  : Colors.white70,
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
        // Species Flexible Bonus Skills (e.g. 2024 Human Skillful, 2014 Variant Human, Half-Elf Skill Versatility)
        if (speciesBonusSkillCount > 0) ...[
          const Divider(height: 1, color: Colors.tealAccent),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.tealAccent.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: speciesBonusSkillPicks.length == speciesBonusSkillCount
                      ? Colors.greenAccent
                      : Colors.tealAccent.withValues(alpha: 0.5),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Species Bonus Skills (${sp.name}):',
                        style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                            color: Colors.tealAccent),
                      ),
                      Text(
                        '${speciesBonusSkillPicks.length} / $speciesBonusSkillCount selected',
                        style: TextStyle(
                          fontSize: 12,
                          color: speciesBonusSkillPicks.length ==
                                  speciesBonusSkillCount
                              ? Colors.greenAccent
                              : Colors.amberAccent,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Your lineage grants $speciesBonusSkillCount skill proficiency choice${speciesBonusSkillCount > 1 ? 's' : ''}:',
                    style:
                        const TextStyle(fontSize: 12, color: Colors.white70),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: eligibleBonusSkills.map((sk) {
                      final isChosen = speciesBonusSkillPicks.contains(sk);
                      return FilterChip(
                        label: Text(sk.displayName,
                            style: const TextStyle(fontSize: 12)),
                        selected: isChosen,
                        selectedColor:
                            Colors.tealAccent.withValues(alpha: 0.3),
                        onSelected: (selected) {
                          HapticService.selectionTick(context);
                          onToggleSpeciesBonusSkill(
                              sk, selected, speciesBonusSkillCount);
                        },
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
          ),
        ],
        // Dwarf Tools / Bonus Languages
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: _buildSpeciesProficienciesPrompt(context, sp),
        ),
        const SizedBox(height: 8),
        // Species Racial Bonus Summary
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: _buildSpeciesRacialBonusSummary(sp),
        ),
      ],
    );
  }

  Widget _buildSpeciesProficienciesPrompt(BuildContext context, Race sp) {
    final spSlug = sp.id.slug.toLowerCase();
    final is2014 = selectedRuleset == RulesetVersion.v2014;
    final isDwarf = spSlug.contains('dwarf');
    final hasBonusLang = is2014 &&
        (spSlug == 'human' ||
            spSlug == 'human-variant' ||
            spSlug.contains('half-elf'));

    if (!isDwarf && !hasBonusLang) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.only(top: 14),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (isDwarf) ...[
            const Row(
              children: [
                Icon(Icons.handyman, size: 16, color: Colors.amberAccent),
                SizedBox(width: 6),
                Text('Dwarf Tool Proficiency:',
                    style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                        color: Colors.amberAccent)),
              ],
            ),
            const SizedBox(height: 4),
            const Text(
                'Gain proficiency with the artisan\'s tools of your choice: Smith\'s Tools, Brewer\'s Supplies, or Mason\'s Tools.',
                style: TextStyle(fontSize: 11.5, color: Colors.white70)),
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              children: [
                'Smith\'s Tools',
                'Brewer\'s Supplies',
                'Mason\'s Tools'
              ].map((tool) {
                final isChosen = (dwarfToolChoice ?? 'Smith\'s Tools') == tool;
                return ChoiceChip(
                  label: Text(tool, style: const TextStyle(fontSize: 11)),
                  selected: isChosen,
                  selectedColor: Colors.amberAccent.withValues(alpha: 0.3),
                  onSelected: (selected) {
                    if (selected) {
                      HapticService.selectionTick(context);
                      onDwarfToolChanged(tool);
                    }
                  },
                );
              }).toList(),
            ),
            if (hasBonusLang) const Divider(height: 16),
          ],
          if (hasBonusLang) ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Row(
                  children: [
                    Icon(Icons.translate, size: 16, color: Colors.cyanAccent),
                    SizedBox(width: 6),
                    Text('Species Bonus Language:',
                        style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                            color: Colors.cyanAccent)),
                  ],
                ),
                Text(
                  '${speciesBonusLanguages.length} / 1 languages selected',
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.bold,
                    color: speciesBonusLanguages.isNotEmpty
                        ? Colors.greenAccent
                        : Colors.amberAccent,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            const Text('Select 1 additional language granted by your lineage:',
                style: TextStyle(fontSize: 11.5, color: Colors.white70)),
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: [
                'Elvish',
                'Dwarvish',
                'Giant',
                'Gnomish',
                'Goblin',
                'Halfling',
                'Orc',
                'Draconic',
                'Celestial',
                'Undercommon',
              ].map((lang) {
                final isChosen = speciesBonusLanguages.contains(lang);
                return FilterChip(
                  label: Text(lang, style: const TextStyle(fontSize: 11)),
                  selected: isChosen,
                  selectedColor: Colors.cyanAccent.withValues(alpha: 0.3),
                  onSelected: (selected) {
                    HapticService.selectionTick(context);
                    onToggleSpeciesBonusLanguage(lang, selected);
                  },
                );
              }).toList(),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSpeciesRacialBonusSummary(Race sp) {
    final bonuses = bonusScores;
    final hasBaseScores = abilityScoreController.isAbilityAllocationComplete ||
        abilityScoreController.hasValidScores;
    final baseScores = wizardBaseScores;

    final bonusEntries = <String>[];
    if (bonuses.strength > 0) bonusEntries.add('+${bonuses.strength} STR');
    if (bonuses.dexterity > 0) bonusEntries.add('+${bonuses.dexterity} DEX');
    if (bonuses.constitution > 0) {
      bonusEntries.add('+${bonuses.constitution} CON');
    }
    if (bonuses.intelligence > 0) {
      bonusEntries.add('+${bonuses.intelligence} INT');
    }
    if (bonuses.wisdom > 0) bonusEntries.add('+${bonuses.wisdom} WIS');
    if (bonuses.charisma > 0) bonusEntries.add('+${bonuses.charisma} CHA');

    final bonusSummaryText =
        bonusEntries.isNotEmpty ? bonusEntries.join(', ') : 'None';

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white10,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.fitness_center,
                  color: Colors.cyanAccent, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Racial Attribute Modifiers (${sp.name}): $bonusSummaryText',
                  style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                      color: Colors.cyanAccent),
                ),
              ),
            ],
          ),
          if (hasBaseScores) ...[
            const SizedBox(height: 8),
            const Text(
              'Base Scores + Racial Bonuses = Resulting Attributes:',
              style: TextStyle(fontSize: 11.5, color: Colors.white70),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: AbilityType.values.map((ab) {
                final base = baseScores.getScore(ab);
                final bonus = bonuses.getScore(ab);
                final total = base + bonus;
                final mod = Dnd5eScoreMath.scoreToModifier(total);
                final modStr = mod >= 0 ? '+$mod' : '$mod';
                return Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: bonus > 0
                        ? Colors.cyan.shade900.withValues(alpha: 0.3)
                        : Colors.black26,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                        color: bonus > 0
                            ? Colors.cyanAccent.withValues(alpha: 0.5)
                            : Colors.white12),
                  ),
                  child: Text(
                    '${ab.name.substring(0, 3).toUpperCase()}: $total ($modStr)${bonus > 0 ? ' [+$bonus]' : ''}',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight:
                          bonus > 0 ? FontWeight.bold : FontWeight.normal,
                      color: bonus > 0 ? Colors.cyanAccent : Colors.white70,
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        ],
      ),
    );
  }
}
