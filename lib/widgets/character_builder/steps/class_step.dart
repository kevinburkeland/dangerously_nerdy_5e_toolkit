import 'package:material_ui/material_ui.dart';
import '../../../models/domain/character_models.dart';
import '../../../models/domain/core_types.dart';
import '../../../models/dm_screen_data.dart' show DmRulesEdition;
import '../../../models/characters/srd_classes_library.dart';
import '../../../models/characters/srd_proficiencies_library.dart';
import '../../../models/characters/srd_species_library.dart';
import '../../../models/domain/homebrew_extended_entities.dart';
import '../../../services/haptic_service.dart';
import '../../../services/rules/skill_trait_resolver.dart';
import '../../glyphs/dnd_glyph.dart';
import 'builder_step_order.dart';

class BuilderClassStep extends StatelessWidget {
  final CharacterClass? curClass;
  final List<SkillType> allowedSkills;
  final int allowedCount;
  final String? selectedClass;
  final String? selectedSpecies;
  final String? selectedSubrace;
  final String? selectedBackground;
  final RulesetVersion selectedRuleset;
  final Set<SkillType> wizardSelectedSkills;
  final Set<SkillType> compensatorySkillPicks;
  final Set<SkillType> speciesBonusSkillPicks;
  final Set<String> classBonusTools;
  final ValueChanged<String> onSelectClass;
  final void Function(SkillType sk, bool selected, int allowedCount,
      String className) onToggleClassSkill;
  final void Function(SkillType sk, bool selected, int maxCount)
      onToggleCompensatorySkill;
  final void Function(SkillType sk, bool selected, int maxCount)
      onToggleSpeciesBonusSkill;
  final void Function(String tool, bool selected, bool singleSelect)
      onToggleClassBonusTool;

  const BuilderClassStep({
    super.key,
    required this.curClass,
    required this.allowedSkills,
    required this.allowedCount,
    required this.selectedClass,
    required this.selectedSpecies,
    required this.selectedSubrace,
    required this.selectedBackground,
    required this.selectedRuleset,
    required this.wizardSelectedSkills,
    required this.compensatorySkillPicks,
    required this.speciesBonusSkillPicks,
    required this.classBonusTools,
    required this.onSelectClass,
    required this.onToggleClassSkill,
    required this.onToggleCompensatorySkill,
    required this.onToggleSpeciesBonusSkill,
    required this.onToggleClassBonusTool,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final curClassType = findBuilderClassType(selectedClass);
    final edition = selectedRuleset == RulesetVersion.v2024
        ? DmRulesEdition.v2024
        : DmRulesEdition.v2014;

    final skillReport = curClass != null
        ? SkillTraitResolver.resolveSkills(
            speciesSlug: selectedSpecies,
            subraceSlug: selectedSubrace,
            backgroundSlug: selectedBackground,
            classSlug: curClass!.id.slug,
            requestedClassSkills: wizardSelectedSkills,
            compensatoryPicks: compensatorySkillPicks,
            speciesBonusSkills: speciesBonusSkillPicks,
            edition: edition,
          )
        : null;

    final speciesBonusSkillCount =
        SkillTraitResolver.getSpeciesBonusSkillCount(selectedSpecies, edition);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Step 3: Choose Class & Starting Skills',
            style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold, color: Colors.cyanAccent)),
        const SizedBox(height: 6),
        const Text(
            'Select your core adventurer class and starting skill proficiencies.',
            style: TextStyle(fontSize: 12, color: Colors.white70)),
        const SizedBox(height: 12),
        if (curClassType != null)
          Container(
            padding: const EdgeInsets.all(12),
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: Colors.cyan.shade900.withValues(alpha: 0.25),
              borderRadius: BorderRadius.circular(10),
              border:
                  Border.all(color: Colors.cyanAccent.withValues(alpha: 0.4)),
            ),
            child: Row(
              children: [
                RepaintBoundary(
                  child: SizedBox(
                    width: 48,
                    height: 48,
                    child: FittedBox(
                      fit: BoxFit.contain,
                      child: DndGlyph.classFeature(
                        classType: curClassType,
                        size: 48,
                        isDarkMode: true,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        curClassType.displayName.toUpperCase(),
                        style: const TextStyle(
                          color: Colors.cyanAccent,
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                      ),
                      Text(
                        'd${curClassType.hitDieSides} Hit Die • Resource: ${curClassType.primaryResource}',
                        style: const TextStyle(
                            fontSize: 11.5, color: Colors.white70),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          )
        else
          Container(
            padding: const EdgeInsets.all(12),
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: Colors.white10,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.white24),
            ),
            child: const Row(
              children: [
                Icon(Icons.shield_outlined, color: Colors.cyanAccent, size: 36),
                SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'NO CLASS SELECTED',
                        style: TextStyle(
                          color: Colors.cyanAccent,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      Text(
                        'Select a class below to allocate skills and hit dice.',
                        style: TextStyle(fontSize: 11.5, color: Colors.white70),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        DropdownButtonFormField<String>(
          initialValue: selectedClass,
          hint: const Text('Select Starting Class...'),
          decoration: const InputDecoration(
              labelText: 'Starting Class', border: OutlineInputBorder()),
          items: SrdClassesLibrary.allClasses
              .map((c) => DropdownMenuItem(
                  value: c.id.slug,
                  child: Text(
                      '${c.name} (${c.hitDie} • Primary: ${c.primaryAbility})')))
              .toList(),
          onChanged: (v) {
            if (v == null) return;
            HapticService.selectionTick(context);
            onSelectClass(v);
          },
        ),
        if (curClass != null && skillReport != null) ...[
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Class Skills (Pick $allowedCount):',
                  style: const TextStyle(fontWeight: FontWeight.bold)),
              Text('${wizardSelectedSkills.length} / $allowedCount selected',
                  style: TextStyle(
                    fontSize: 12,
                    color: wizardSelectedSkills.length == allowedCount
                        ? Colors.greenAccent
                        : Colors.amberAccent,
                    fontWeight: FontWeight.bold,
                  )),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: allowedSkills.map((sk) {
              final isChosen = wizardSelectedSkills.contains(sk);
              final source = skillReport.grantedSkills[sk];
              final isGrantedByOther =
                  source != null && !source.startsWith('Class:');

              return FilterChip(
                label: Text(isGrantedByOther
                    ? '${sk.displayName} ($source)'
                    : sk.displayName),
                selected: isChosen,
                avatar: isGrantedByOther
                    ? const Icon(Icons.info_outline,
                        size: 14, color: Colors.amberAccent)
                    : null,
                onSelected: (selected) {
                  HapticService.selectionTick(context);
                  onToggleClassSkill(sk, selected, allowedCount, curClass!.name);
                },
              );
            }).toList(),
          ),

          // Collision & Compensatory Picks Section
          if (skillReport.collidingSkills.isNotEmpty) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.amberAccent.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                    color: Colors.amberAccent.withValues(alpha: 0.4)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.warning_amber_rounded,
                          color: Colors.amberAccent, size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Skill Collision Detected: ${skillReport.collidingSkills.map((s) => s.displayName).join(", ")} is already granted by your background/species.',
                          style: const TextStyle(
                              color: Colors.amberAccent,
                              fontWeight: FontWeight.bold,
                              fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Per RAW rules, you receive ${skillReport.compensatoryPicksEarned} compensatory choice(s) from any remaining unselected skill.',
                    style:
                        const TextStyle(fontSize: 11.5, color: Colors.white70),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Compensatory Pick(s):',
                          style: TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 12)),
                      Text(
                        '${compensatorySkillPicks.length} / ${skillReport.compensatoryPicksEarned} selected',
                        style: TextStyle(
                          fontSize: 12,
                          color: compensatorySkillPicks.length ==
                                  skillReport.compensatoryPicksEarned
                              ? Colors.greenAccent
                              : Colors.amberAccent,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: SkillType.values.where((sk) {
                      return skillReport.availableSkillPool.contains(sk) ||
                          compensatorySkillPicks.contains(sk);
                    }).map((sk) {
                      final isChosen = compensatorySkillPicks.contains(sk);
                      return FilterChip(
                        label: Text(sk.displayName,
                            style: const TextStyle(fontSize: 12)),
                        selected: isChosen,
                        selectedColor:
                            Colors.amberAccent.withValues(alpha: 0.3),
                        onSelected: (selected) {
                          HapticService.selectionTick(context);
                          onToggleCompensatorySkill(
                              sk, selected, skillReport.compensatoryPicksEarned);
                        },
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
          ],
        ],

        // Species Flexible Bonus Skills (e.g. Human Skillful, Half-Elf Skill Versatility)
        if (speciesBonusSkillCount > 0 && skillReport != null) ...[
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.tealAccent.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(10),
              border:
                  Border.all(color: Colors.tealAccent.withValues(alpha: 0.3)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                        'Species Bonus Skill (${selectedSpecies != null ? SrdSpeciesLibrary.findBySlug(selectedSpecies!)?.name ?? "Species" : "Species"}):',
                        style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                            color: Colors.tealAccent)),
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
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: SkillType.values.where((sk) {
                    return !skillReport.resolvedProficiencies.containsKey(sk) ||
                        speciesBonusSkillPicks.contains(sk);
                  }).map((sk) {
                    final isChosen = speciesBonusSkillPicks.contains(sk);
                    return FilterChip(
                      label: Text(sk.displayName,
                          style: const TextStyle(fontSize: 12)),
                      selected: isChosen,
                      selectedColor: Colors.tealAccent.withValues(alpha: 0.3),
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
        ],

        if (curClass != null) ...[
          const SizedBox(height: 16),
          _buildClassToolsPrompt(context, curClass!),
        ],
      ],
    );
  }

  Widget _buildClassToolsPrompt(BuildContext context, CharacterClass cls) {
    final clSlug = cls.id.slug.toLowerCase();
    final isBard = clSlug == 'bard';
    final isMonk = clSlug == 'monk';

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.amber.shade900.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.amberAccent.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.construction,
                  size: 16, color: Colors.amberAccent),
              const SizedBox(width: 6),
              Text(
                isBard
                    ? 'Bard Musical Instruments (Select 3):'
                    : (isMonk
                        ? 'Monk Tool / Instrument (Select 1):'
                        : 'Class Tools & Dialects:'),
                style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                    color: Colors.amberAccent),
              ),
            ],
          ),
          const SizedBox(height: 4),
          if (isBard) ...[
            const Text('Choose three musical instruments of your choice:',
                style: TextStyle(fontSize: 11.5, color: Colors.white70)),
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: SrdProficienciesLibrary.musicalInstruments.map((inst) {
                final isChosen = classBonusTools.contains(inst);
                return FilterChip(
                  label: Text(inst, style: const TextStyle(fontSize: 11)),
                  selected: isChosen,
                  selectedColor: Colors.amberAccent.withValues(alpha: 0.3),
                  onSelected: (selected) {
                    HapticService.selectionTick(context);
                    onToggleClassBonusTool(inst, selected, false);
                  },
                );
              }).toList(),
            ),
          ] else if (isMonk) ...[
            const Text('Choose one artisan\'s tool or musical instrument:',
                style: TextStyle(fontSize: 11.5, color: Colors.white70)),
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: [
                ...SrdProficienciesLibrary.artisansTools.take(6),
                ...SrdProficienciesLibrary.musicalInstruments.take(4),
              ].map((tool) {
                final isChosen = classBonusTools.contains(tool);
                return FilterChip(
                  label: Text(tool, style: const TextStyle(fontSize: 11)),
                  selected: isChosen,
                  selectedColor: Colors.amberAccent.withValues(alpha: 0.3),
                  onSelected: (selected) {
                    HapticService.selectionTick(context);
                    onToggleClassBonusTool(tool, selected, true);
                  },
                );
              }).toList(),
            ),
          ] else if (clSlug == 'rogue') ...[
            const Text(
                'Granted: Thieves\' Tools & Thieves\' Cant (Secret Dialect)',
                style: TextStyle(fontSize: 12, color: Colors.white70)),
          ] else if (clSlug == 'druid') ...[
            const Text('Granted: Herbalism Kit & Druidic (Secret Dialect)',
                style: TextStyle(fontSize: 12, color: Colors.white70)),
          ],
        ],
      ),
    );
  }
}
