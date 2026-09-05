import 'package:flutter/material.dart';
import '../../models/domain/character_models.dart';
import '../../models/domain/core_types.dart';
import '../../models/domain/homebrew_extended_entities.dart';
import '../../providers/character_builder_controller.dart';
import '../../services/a11y_service.dart';
import '../../services/haptic_service.dart';
import '../../services/rules/dnd_5e_rules_engine.dart';

/// Step 5: Ability Score Allocation widget supporting Consumable Resource Pools,
/// standard array, point buy, rolled stats, and manual entry with 100% accessible touch targets.
class AbilityScoreStep extends StatelessWidget {
  final CharacterBuilderController controller;
  final Race? curSpecies;
  final Background? curBackground;
  final RulesetVersion selectedRuleset;
  final Set<AbilityType> variantHumanBonuses;
  final ValueChanged<Set<AbilityType>> onVariantHumanBonusesChanged;
  final AbilityType backgroundPrimaryBonus;
  final ValueChanged<AbilityType> onBackgroundPrimaryBonusChanged;
  final AbilityType backgroundSecondaryBonus;
  final ValueChanged<AbilityType> onBackgroundSecondaryBonusChanged;
  final AbilityScores bonusScores;

  const AbilityScoreStep({
    super.key,
    required this.controller,
    this.curSpecies,
    this.curBackground,
    required this.selectedRuleset,
    required this.variantHumanBonuses,
    required this.onVariantHumanBonusesChanged,
    required this.backgroundPrimaryBonus,
    required this.onBackgroundPrimaryBonusChanged,
    required this.backgroundSecondaryBonus,
    required this.onBackgroundSecondaryBonusChanged,
    required this.bonusScores,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final is2014 = selectedRuleset == RulesetVersion.v2014;
    final flexibleCount = curSpecies?.flexibleAbilityChoiceCount ?? 0;
    final flexibleBonusValue = curSpecies?.flexibleAbilityBonusValue ?? 0;
    final hasFlexibleLineageBonus = is2014 && flexibleCount > 0 && curSpecies != null;

    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Step 5: Ability Score Allocation',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: Colors.cyanAccent,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Choose your attribute generation method (Standard Array, Point Buy, Dice Roll, or Manual Entry) and assign your consumable scores and lineage bonuses.',
              style: TextStyle(fontSize: 12, color: Colors.white70),
            ),
            const SizedBox(height: 12),

            // Method Selector
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(
                  value: 'standard',
                  label: Text('Standard Array', style: TextStyle(fontSize: 10.5)),
                ),
                ButtonSegment(
                  value: 'pointBuy',
                  label: Text('Point Buy', style: TextStyle(fontSize: 10.5)),
                ),
                ButtonSegment(
                  value: 'rolled',
                  label: Text('Dice Roll', style: TextStyle(fontSize: 10.5)),
                ),
                ButtonSegment(
                  value: 'manual',
                  label: Text('Enter Own', style: TextStyle(fontSize: 10.5)),
                ),
              ],
              selected: {controller.abilityScoreMode},
              onSelectionChanged: (set) {
                HapticService.selectionTick(context);
                controller.setMode(set.first);
              },
            ),
            const SizedBox(height: 16),

            // Allocation Status Banner
            _buildAllocationStatusBanner(context),
            const SizedBox(height: 14),

            // METHOD 1: POINT BUY
            if (controller.abilityScoreMode == 'pointBuy') ...[
              _buildPointBuySection(context),
            ]

            // METHOD 2: DICE ROLL
            else if (controller.abilityScoreMode == 'rolled') ...[
              _buildDiceRollSection(context),
            ]

            // METHOD 3: MANUAL ENTRY
            else if (controller.abilityScoreMode == 'manual') ...[
              _buildManualEntrySection(context),
            ]

            // METHOD 4: STANDARD ARRAY
            else ...[
              _buildStandardArraySection(context),
            ],

            const SizedBox(height: 16),

            // LINEAGE & BACKGROUND BONUSES
            _buildLineageAndBackgroundSection(
              context,
              hasFlexibleLineageBonus: hasFlexibleLineageBonus,
              flexibleCount: flexibleCount,
              flexibleBonusValue: flexibleBonusValue,
              is2014: is2014,
            ),

            const SizedBox(height: 16),

            // FINAL COMPUTED ATTRIBUTES PREVIEW
            _buildFinalPreviewCard(context),
          ],
        );
      },
    );
  }

  // ==========================================
  // STATUS BANNER
  // ==========================================
  Widget _buildAllocationStatusBanner(BuildContext context) {
    final isComplete = controller.isAbilityAllocationComplete;
    final mode = controller.abilityScoreMode;

    if (mode == 'pointBuy') {
      final remaining = controller.pointBuyPointsRemaining;
      final isOver = remaining < 0;
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isOver ? Colors.red.shade900.withValues(alpha: 0.25) : Colors.green.shade900.withValues(alpha: 0.25),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isOver ? Colors.redAccent : Colors.greenAccent,
            width: 0.8,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Point Buy Pool (Cost: 8=0, 9=1, ..., 15=9):',
              style: TextStyle(fontSize: 12, color: Colors.white70),
            ),
            Text(
              'Points Remaining: $remaining / 27',
              style: TextStyle(
                color: isOver ? Colors.redAccent : Colors.greenAccent,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      );
    }

    if (mode == 'standard' || (mode == 'rolled' && controller.rollMethod != 'classic_3d6_down')) {
      final assignedCount = controller.assignedScores.length;
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isComplete
              ? Colors.green.shade900.withValues(alpha: 0.25)
              : Colors.amber.shade900.withValues(alpha: 0.25),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isComplete ? Colors.greenAccent : Colors.amberAccent,
            width: 0.8,
          ),
        ),
        child: Row(
          children: [
            Icon(
              isComplete ? Icons.check_circle_outline : Icons.info_outline,
              color: isComplete ? Colors.greenAccent : Colors.amberAccent,
              size: 16,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                isComplete
                    ? 'All 6 attributes allocated! Ready to proceed.'
                    : 'Consumable Pool: Assign all 6 attributes ($assignedCount/6 allocated)',
                style: TextStyle(
                  fontSize: 12,
                  color: isComplete ? Colors.greenAccent : Colors.amberAccent,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      );
    }

    return const SizedBox.shrink();
  }

  // ==========================================
  // CONSUMABLE POOL & SLOTS (STANDARD ARRAY)
  // ==========================================
  Widget _buildStandardArraySection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildConsumablePoolHeader(
          context,
          title: 'Standard Array Pool',
          onAutoAssign: () {
            HapticService.selectionTick(context);
            A11yService.announce('Auto-assigned Standard Array');
            controller.autoAssignStandardArray();
          },
          onReset: () {
            HapticService.selectionTick(context);
            A11yService.announce('Reset Standard Array pool');
            controller.populateStandardArray(clear: true);
          },
        ),
        const SizedBox(height: 10),
        _buildPoolChips(context),
        const SizedBox(height: 14),
        ...AbilityType.values.map((ab) => _buildConsumableSlotRow(context, ab)),
      ],
    );
  }

  // ==========================================
  // CONSUMABLE POOL & SLOTS (DICE ROLL)
  // ==========================================
  Widget _buildDiceRollSection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.purple.shade900.withValues(alpha: 0.25),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.purpleAccent.withValues(alpha: 0.4)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(Icons.casino, color: Colors.purpleAccent, size: 18),
                  SizedBox(width: 8),
                  Text(
                    'Dice Rolling Method',
                    style: TextStyle(fontWeight: FontWeight.bold, color: Colors.purpleAccent),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                initialValue: controller.rollMethod,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  isDense: true,
                  contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                ),
                items: const [
                  DropdownMenuItem(value: 'standard_4d6', child: Text('Standard Roll (4d6 drop lowest)')),
                  DropdownMenuItem(value: 'classic_3d6_down', child: Text('Old School (3d6 down the line)')),
                  DropdownMenuItem(value: 'classic_3d6_nice', child: Text('Old School (Nice) (3d6, assignable)')),
                  DropdownMenuItem(value: 'silly_d20', child: Text('Silly, don\'t use this (1d20 per stat)')),
                ],
                onChanged: (v) {
                  if (v == null) return;
                  HapticService.selectionTick(context);
                  controller.setRollMethod(v);
                },
              ),
              const SizedBox(height: 10),
              ElevatedButton.icon(
                icon: const Icon(Icons.casino_outlined, size: 16),
                label: const Text('Roll / Re-roll Dice'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.purple.shade800,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(160, 48),
                ),
                onPressed: () {
                  HapticService.heavyImpact(context);
                  A11yService.announce('Rolled new ability scores');
                  controller.rollScores();
                },
              ),
              if (controller.rolledBreakdowns.isNotEmpty) ...[
                const SizedBox(height: 10),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.black45,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: controller.rolledBreakdowns
                        .map((b) => Text(b, style: const TextStyle(fontSize: 11, color: Colors.purpleAccent)))
                        .toList(),
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 14),

        if (controller.rollMethod == 'classic_3d6_down') ...[
          const Text(
            '3d6 Down the Line: scores assigned strictly in sequence (STR, DEX, CON, INT, WIS, CHA):',
            style: TextStyle(fontSize: 12, color: Colors.white70, fontStyle: FontStyle.italic),
          ),
          const SizedBox(height: 8),
          ...AbilityType.values.map((ab) {
            final score = controller.effectiveBaseScores.getScore(ab);
            final mod = score.dndModifier;
            final modStr = mod >= 0 ? '+$mod' : '$mod';
            return Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('${ab.name.toUpperCase()} ($modStr)', style: const TextStyle(fontWeight: FontWeight.bold)),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.purple.shade900.withValues(alpha: 0.4),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: Colors.purpleAccent, width: 0.8),
                    ),
                    child: Text('$score', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
                  ),
                ],
              ),
            );
          }),
        ] else ...[
          _buildConsumablePoolHeader(
            context,
            title: 'Rolled Dice Pool',
            onReset: () {
              HapticService.selectionTick(context);
              A11yService.announce('Reset rolled dice pool');
              controller.populateRolledScores(controller.rolledPool);
            },
          ),
          const SizedBox(height: 10),
          _buildPoolChips(context),
          const SizedBox(height: 14),
          ...AbilityType.values.map((ab) => _buildConsumableSlotRow(context, ab)),
        ],
      ],
    );
  }

  // ==========================================
  // POOL CHIPS & ACTIONS
  // ==========================================
  Widget _buildConsumablePoolHeader(
    BuildContext context, {
    required String title,
    VoidCallback? onAutoAssign,
    required VoidCallback onReset,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            const Icon(Icons.tune, color: Colors.cyanAccent, size: 16),
            const SizedBox(width: 6),
            Text(
              '$title (${controller.availableScores.length} remaining):',
              style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 13),
            ),
          ],
        ),
        Row(
          children: [
            if (onAutoAssign != null)
              TextButton.icon(
                style: TextButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  foregroundColor: Colors.cyanAccent,
                ),
                icon: const Icon(Icons.auto_awesome, size: 14),
                label: const Text('Auto-Assign', style: TextStyle(fontSize: 11)),
                onPressed: onAutoAssign,
              ),
            TextButton.icon(
              style: TextButton.styleFrom(
                visualDensity: VisualDensity.compact,
                foregroundColor: Colors.white70,
              ),
              icon: const Icon(Icons.refresh, size: 14),
              label: const Text('Reset', style: TextStyle(fontSize: 11)),
              onPressed: onReset,
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildPoolChips(BuildContext context) {
    if (controller.availableScores.isEmpty) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.white12),
        ),
        child: const Row(
          children: [
            Icon(Icons.check, size: 16, color: Colors.greenAccent),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                'All scores assigned. Tap any slot to swap or unassign.',
                style: TextStyle(fontSize: 11.5, color: Colors.white70, fontStyle: FontStyle.italic),
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Tap a score to select it, then tap an unassigned ability slot to assign it (or use dropdowns):',
          style: TextStyle(fontSize: 11.5, color: Colors.white60),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: controller.availableScores.map((score) {
            final isSelected = controller.selectedPoolScore == score;
            return Semantics(
              button: true,
              label: 'Available score $score${isSelected ? ', selected' : ', tap to select'}',
              child: InkWell(
                onTap: () {
                  HapticService.selectionTick(context);
                  controller.selectPoolScore(score);
                },
                borderRadius: BorderRadius.circular(20),
                child: Container(
                  constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
                  alignment: Alignment.center,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? Colors.cyanAccent.withValues(alpha: 0.35)
                        : const Color(0xFF334155),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(
                      color: isSelected ? Colors.cyanAccent : Colors.white24,
                      width: isSelected ? 2.0 : 1.0,
                    ),
                    boxShadow: isSelected
                        ? [
                            BoxShadow(
                              color: Colors.cyanAccent.withValues(alpha: 0.4),
                              blurRadius: 8,
                              spreadRadius: 1,
                            )
                          ]
                        : null,
                  ),
                  child: Text(
                    '$score',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: isSelected ? Colors.cyanAccent : Colors.white,
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  // ==========================================
  // CONSUMABLE SLOT ROW
  // ==========================================
  Widget _buildConsumableSlotRow(BuildContext context, AbilityType ab) {
    final assignedScore = controller.assignedScores[ab];
    final isAssigned = assignedScore != null;
    final selectedPool = controller.selectedPoolScore;
    final isSelectTarget = !isAssigned && selectedPool != null;

    // Dynamic dropdown items: all unique available scores PLUS currently assigned score
    final dropdownValues = <int>{
      ...controller.availableScores,
      if (assignedScore != null) assignedScore,
    }.toList()
      ..sort((a, b) => b.compareTo(a));

    final mod = isAssigned ? assignedScore.dndModifier : null;
    final modStr = mod != null ? (mod >= 0 ? '+$mod' : '$mod') : '--';

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isSelectTarget
              ? Colors.cyanAccent.withValues(alpha: 0.12)
              : (isAssigned ? const Color(0xFF0F172A) : Colors.black26),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelectTarget
                ? Colors.cyanAccent
                : (isAssigned ? Colors.white24 : Colors.white12),
            width: isSelectTarget ? 1.5 : 1.0,
          ),
        ),
        child: Row(
          children: [
            // Ability Name & Mod
            Expanded(
              flex: 3,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    ab.name.toUpperCase(),
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.white),
                  ),
                  Text(
                    isAssigned ? 'Mod: $modStr' : 'Unassigned',
                    style: TextStyle(
                      fontSize: 11,
                      color: isAssigned ? Colors.cyanAccent : Colors.white38,
                    ),
                  ),
                ],
              ),
            ),

            // Tap-to-assign action if a score is selected from pool
            if (isSelectTarget) ...[
              Expanded(
                flex: 4,
                child: Semantics(
                  button: true,
                  label: 'Assign $selectedPool to ${ab.name}',
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.cyanAccent.shade700,
                      foregroundColor: Colors.black,
                      minimumSize: const Size(110, 48),
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    ),
                    icon: const Icon(Icons.arrow_downward, size: 16),
                    label: Text('Assign $selectedPool', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                    onPressed: () {
                      HapticService.selectionTick(context);
                      A11yService.announce('Assigned $selectedPool to ${ab.name}');
                      controller.assignSelectedPoolScore(ab);
                    },
                  ),
                ),
              ),
              const SizedBox(width: 8),
            ],

            // Dynamic Dropdown Selection
            Expanded(
              flex: isSelectTarget ? 3 : 5,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: Colors.white24),
                  color: const Color(0xFF1E293B),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<int?>(
                    value: assignedScore,
                    isExpanded: true,
                    isDense: true,
                    hint: const Text('--', style: TextStyle(color: Colors.white38)),
                    items: [
                      const DropdownMenuItem<int?>(
                        value: null,
                        child: Text('-- None --', style: TextStyle(color: Colors.white38, fontSize: 13)),
                      ),
                      ...dropdownValues.map((val) {
                        final itemMod = val.dndModifier;
                        final itemModStr = itemMod >= 0 ? '+$itemMod' : '$itemMod';
                        return DropdownMenuItem<int?>(
                          value: val,
                          child: Text('$val ($itemModStr)', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                        );
                      }),
                    ],
                    onChanged: (v) {
                      HapticService.selectionTick(context);
                      if (v == null) {
                        controller.unassignScore(ab);
                      } else {
                        controller.assignScore(ab, v);
                      }
                    },
                  ),
                ),
              ),
            ),

            // Unassign "X" Button (only when assigned)
            if (isAssigned) ...[
              const SizedBox(width: 4),
              Semantics(
                button: true,
                label: 'Unassign ${ab.name}',
                child: IconButton(
                  icon: const Icon(Icons.close, color: Colors.redAccent, size: 18),
                  tooltip: 'Unassign ${ab.name}',
                  constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
                  onPressed: () {
                    HapticService.selectionTick(context);
                    A11yService.announce('Unassigned ${ab.name}');
                    controller.unassignScore(ab);
                  },
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // ==========================================
  // POINT BUY SECTION
  // ==========================================
  Widget _buildPointBuySection(BuildContext context) {
    return Column(
      children: AbilityType.values.map((ab) {
        final score = controller.pointBuyScores.getScore(ab);
        final mod = score.dndModifier;
        final modStr = mod >= 0 ? '+$mod' : '$mod';
        return Padding(
          padding: const EdgeInsets.only(bottom: 4),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('${ab.name.toUpperCase()} ($modStr)', style: const TextStyle(fontWeight: FontWeight.bold)),
              Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.remove_circle_outline, size: 20),
                    constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
                    onPressed: score > 8
                        ? () {
                            HapticService.selectionTick(context);
                            controller.adjustPointBuy(ab, -1);
                          }
                        : null,
                  ),
                  Container(
                    width: 36,
                    alignment: Alignment.center,
                    child: Text('$score', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  ),
                  IconButton(
                    icon: const Icon(Icons.add_circle_outline, size: 20),
                    constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
                    onPressed: score < 15 && controller.pointBuyPointsRemaining > 0
                        ? () {
                            HapticService.selectionTick(context);
                            controller.adjustPointBuy(ab, 1);
                          }
                        : null,
                  ),
                ],
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  // ==========================================
  // MANUAL ENTRY SECTION
  // ==========================================
  Widget _buildManualEntrySection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Enter your own custom attributes (3 to 30):',
          style: TextStyle(fontSize: 12, color: Colors.white70),
        ),
        const SizedBox(height: 10),
        ...AbilityType.values.map((ab) {
          final score = controller.manualScores[ab] ?? 10;
          final mod = score.dndModifier;
          final modStr = mod >= 0 ? '+$mod' : '$mod';
          return Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('${ab.name.toUpperCase()} ($modStr)', style: const TextStyle(fontWeight: FontWeight.bold)),
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.remove_circle_outline, size: 20),
                      constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
                      onPressed: score > 3
                          ? () {
                              HapticService.selectionTick(context);
                              controller.setManualScore(ab, score - 1);
                            }
                          : null,
                    ),
                    Container(
                      width: 36,
                      alignment: Alignment.center,
                      child: Text('$score', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    ),
                    IconButton(
                      icon: const Icon(Icons.add_circle_outline, size: 20),
                      constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
                      onPressed: score < 30
                          ? () {
                              HapticService.selectionTick(context);
                              controller.setManualScore(ab, score + 1);
                            }
                          : null,
                    ),
                  ],
                ),
              ],
            ),
          );
        }),
      ],
    );
  }

  // ==========================================
  // LINEAGE & BACKGROUND BONUSES
  // ==========================================
  Widget _buildLineageAndBackgroundSection(
    BuildContext context, {
    required bool hasFlexibleLineageBonus,
    required int flexibleCount,
    required int flexibleBonusValue,
    required bool is2014,
  }) {
    if (hasFlexibleLineageBonus) {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.cyan.shade900.withValues(alpha: 0.25),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.cyanAccent.withValues(alpha: 0.5)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.stars, color: Colors.cyanAccent, size: 18),
                const SizedBox(width: 8),
                Text(
                  '${curSpecies?.name ?? "Species"} Lineage Bonus (+$flexibleBonusValue to $flexibleCount Score${flexibleCount > 1 ? 's' : ''})',
                  style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.cyanAccent, fontSize: 13),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              'Select $flexibleCount different ability score${flexibleCount > 1 ? 's' : ''} to receive a +$flexibleBonusValue bonus:',
              style: const TextStyle(fontSize: 12, color: Colors.white70),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: AbilityType.values.map((ab) {
                final fixedBonuses = curSpecies?.fixedAbilityBonuses2014 ?? const {};
                final isFixed = fixedBonuses.containsKey(ab.name.toLowerCase());
                final isSelected = variantHumanBonuses.contains(ab);
                return FilterChip(
                  label: Text(isFixed
                      ? '${ab.name.toUpperCase()} (+${fixedBonuses[ab.name.toLowerCase()]} Fixed)'
                      : '${ab.name.toUpperCase()} (+$flexibleBonusValue Bonus)'),
                  selected: isSelected,
                  selectedColor: Colors.cyanAccent.withValues(alpha: 0.3),
                  checkmarkColor: Colors.cyanAccent,
                  onSelected: isFixed
                      ? null
                      : (selected) {
                          HapticService.selectionTick(context);
                          final updated = Set<AbilityType>.from(variantHumanBonuses);
                          if (selected) {
                            while (updated.length >= flexibleCount && updated.isNotEmpty) {
                              updated.remove(updated.first);
                            }
                            updated.add(ab);
                          } else {
                            if (updated.length > 1) {
                              updated.remove(ab);
                            }
                          }
                          onVariantHumanBonusesChanged(updated);
                        },
                );
              }).toList(),
            ),
          ],
        ),
      );
    }

    if (!is2014) {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.amber.shade900.withValues(alpha: 0.25),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.amberAccent.withValues(alpha: 0.5)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.workspace_premium, color: Colors.amberAccent, size: 18),
                SizedBox(width: 8),
                Text(
                  'Background Ability Score Bonus (+2 / +1)',
                  style: TextStyle(fontWeight: FontWeight.bold, color: Colors.amberAccent, fontSize: 13),
                ),
              ],
            ),
            const SizedBox(height: 6),
            const Text(
              '2024 rules grant a +2 bonus to your primary attribute and +1 to your secondary attribute:',
              style: TextStyle(fontSize: 12, color: Colors.white70),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<AbilityType>(
                    initialValue: backgroundPrimaryBonus,
                    decoration: const InputDecoration(
                      labelText: '+2 Primary Bonus',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    items: AbilityType.values
                        .map((ab) => DropdownMenuItem(value: ab, child: Text('${ab.name.toUpperCase()} (+2)')))
                        .toList(),
                    onChanged: (v) {
                      if (v == null) return;
                      HapticService.selectionTick(context);
                      onBackgroundPrimaryBonusChanged(v);
                      if (backgroundSecondaryBonus == v) {
                        onBackgroundSecondaryBonusChanged(AbilityType.values.firstWhere((a) => a != v));
                      }
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: DropdownButtonFormField<AbilityType>(
                    initialValue: backgroundSecondaryBonus,
                    decoration: const InputDecoration(
                      labelText: '+1 Secondary Bonus',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    items: AbilityType.values
                        .map((ab) => DropdownMenuItem(value: ab, child: Text('${ab.name.toUpperCase()} (+1)')))
                        .toList(),
                    onChanged: (v) {
                      if (v == null) return;
                      HapticService.selectionTick(context);
                      onBackgroundSecondaryBonusChanged(v);
                      if (backgroundPrimaryBonus == v) {
                        onBackgroundPrimaryBonusChanged(AbilityType.values.firstWhere((a) => a != v));
                      }
                    },
                  ),
                ),
              ],
            ),
          ],
        ),
      );
    }

    return _buildSpeciesRacialBonusCard(context);
  }

  Widget _buildSpeciesRacialBonusCard(BuildContext context) {
    if (curSpecies == null) {
      return Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.white10,
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Row(
          children: [
            Icon(Icons.info_outline, color: Colors.cyanAccent, size: 16),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                'Lineage bonuses will apply once a species is chosen.',
                style: TextStyle(fontSize: 12, color: Colors.white70),
              ),
            ),
          ],
        ),
      );
    }
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white10,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          const Icon(Icons.info_outline, color: Colors.cyanAccent, size: 16),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '2014 Species Racial Bonus: ${curSpecies!.abilityScoreSummary}',
              style: const TextStyle(fontSize: 12, color: Colors.white70),
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================
  // FINAL PREVIEW CARD
  // ==========================================
  Widget _buildFinalPreviewCard(BuildContext context) {
    final baseScores = controller.effectiveBaseScores;

    return Card(
      color: const Color(0xFF1E293B),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'FINAL STARTING ATTRIBUTES PREVIEW',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 12,
                letterSpacing: 1.1,
                color: Colors.cyanAccent,
              ),
            ),
            const Divider(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: AbilityType.values.map((ab) {
                final base = baseScores.getScore(ab);
                final bonus = bonusScores.getScore(ab);
                final total = base + bonus;
                final mod = total.dndModifier;
                final modStr = mod >= 0 ? '+$mod' : '$mod';
                return Column(
                  children: [
                    Text(
                      ab.name.toUpperCase(),
                      style: const TextStyle(
                        fontSize: 10,
                        color: Colors.white60,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '$total',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    Text(
                      modStr,
                      style: const TextStyle(
                        fontSize: 11,
                        color: Colors.cyanAccent,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (bonus > 0)
                      Text(
                        '+$bonus bonus',
                        style: const TextStyle(fontSize: 8.5, color: Colors.amberAccent),
                      ),
                  ],
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }
}
