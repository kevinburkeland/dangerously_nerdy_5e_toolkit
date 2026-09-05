import 'package:flutter/material.dart';
import '../../models/characters/srd_proficiencies_library.dart';
import '../../models/dice_roll.dart';
import '../../models/room_roll.dart';
import '../../providers/character_sheet_controller.dart';
import '../../services/dice_room_service.dart';
import '../../services/haptic_service.dart';
import '../../theme/app_theme.dart';
import '../../utils/secure_random.dart';

/// Interactive Languages Known and Tool Proficiencies section with live dice rolling,
/// ability modifier recommendation badges, and management dialogs.
class LanguagesToolsSection extends StatelessWidget {
  final CharacterSheetController controller;

  const LanguagesToolsSection({
    super.key,
    required this.controller,
  });

  void _dispatchToolRoll(BuildContext context, String tool) {
    HapticService.lightImpact(context);

    final ability = SrdProficienciesLibrary.getRecommendedAbility(tool);
    final abilityMod = controller.stats.effectiveScores.getModifier(ability);
    final profBonus = controller.stats.proficiencyBonus;
    final totalModifier = profBonus + abilityMod;

    final rollResult = DiceRollResult.roll(
      dieType: DieType.d20,
      modifier: totalModifier,
      rollMode: RollMode.normal,
    );

    final roomService = DiceRoomService();
    final activeRoom = roomService.activeRoomCode;
    final characterName = controller.character.name.isNotEmpty
        ? controller.character.name
        : 'Player';

    if (activeRoom != null) {
      final roomRoll = RoomRoll.fromDiceRollResult(
        id: 'tool-roll-${DateTime.now().millisecondsSinceEpoch}-${secureRandom.nextInt(9999)}',
        roomCode: activeRoom,
        playerName: characterName,
        result: rollResult,
        details: ['$tool Check (${ability.shortName})'],
      );
      roomService.broadcastRoll(roomRoll);
    }

    final sign = totalModifier >= 0 ? '+$totalModifier' : '$totalModifier';
    final modBreakdown = 'd20 ($sign [PB +$profBonus, ${ability.shortName} ${abilityMod >= 0 ? "+$abilityMod" : "$abilityMod"}])';
    final baseRoll = rollResult.individualRolls.isNotEmpty ? rollResult.individualRolls.first : (rollResult.total - totalModifier);

    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: const Color(0xFF1E293B),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 4),
        content: Row(
          children: [
            const Icon(Icons.casino, color: Colors.cyanAccent, size: 22),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '$tool Check: ${rollResult.total}',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.white),
                  ),
                  Text(
                    'Rolled $baseRoll with $modBreakdown',
                    style: const TextStyle(fontSize: 12, color: Colors.white70),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showAddLanguageDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (dialogCtx) => _AddLanguageDialog(controller: controller),
    );
  }

  void _showAddToolDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (dialogCtx) => _AddToolDialog(controller: controller),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final customColors = theme.extension<TabletopColors>();
    final languages = controller.character.languages;
    final tools = controller.character.toolProficiencies;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ==========================================
        // 1. LANGUAGES KNOWN CARD
        // ==========================================
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.35),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: customColors?.cardBorder ?? theme.colorScheme.outlineVariant,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.translate, size: 18, color: Colors.cyanAccent),
                      const SizedBox(width: 8),
                      Text(
                        'Languages Known',
                        style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.cyanAccent.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          '${languages.length}',
                          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.cyanAccent),
                        ),
                      ),
                    ],
                  ),
                  TextButton.icon(
                    onPressed: () => _showAddLanguageDialog(context),
                    icon: const Icon(Icons.add, size: 16),
                    label: const Text('Add Language', style: TextStyle(fontSize: 12)),
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.cyanAccent,
                      visualDensity: VisualDensity.compact,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              if (languages.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 8),
                  child: Text(
                    'No languages recorded. Tap "+ Add Language" to add common or exotic languages.',
                    style: TextStyle(fontSize: 12, color: Colors.white54, fontStyle: FontStyle.italic),
                  ),
                )
              else
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: languages.map((lang) {
                    final category = SrdProficienciesLibrary.getLanguageCategory(lang);
                    final isExotic = category == LanguageCategory.exotic;
                    final isSecret = category == LanguageCategory.secret;

                    return Chip(
                      avatar: Icon(
                        isSecret ? Icons.lock : (isExotic ? Icons.auto_awesome : Icons.chat_bubble_outline),
                        size: 14,
                        color: isSecret ? Colors.amberAccent : (isExotic ? Colors.purpleAccent : Colors.cyanAccent),
                      ),
                      label: Text(
                        lang,
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                      ),
                      backgroundColor: Colors.white.withValues(alpha: 0.06),
                      deleteIcon: const Icon(Icons.close, size: 14),
                      deleteIconColor: Colors.white54,
                      deleteButtonTooltipMessage: 'Remove $lang',
                      onDeleted: () {
                        HapticService.selectionTick(context);
                        controller.removeLanguage(lang);
                      },
                    );
                  }).toList(),
                ),
            ],
          ),
        ),

        const SizedBox(height: 16),

        // ==========================================
        // 2. TOOL PROFICIENCIES CARD
        // ==========================================
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.35),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: customColors?.cardBorder ?? theme.colorScheme.outlineVariant,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.construction, size: 18, color: Colors.amberAccent),
                      const SizedBox(width: 8),
                      Text(
                        'Tool Proficiencies',
                        style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.amberAccent.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          '${tools.length}',
                          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.amberAccent),
                        ),
                      ),
                    ],
                  ),
                  TextButton.icon(
                    onPressed: () => _showAddToolDialog(context),
                    icon: const Icon(Icons.add, size: 16),
                    label: const Text('Add Tool', style: TextStyle(fontSize: 12)),
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.amberAccent,
                      visualDensity: VisualDensity.compact,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              if (tools.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 8),
                  child: Text(
                    'No tool proficiencies recorded. Tap "+ Add Tool" to add artisan tools, kits, instruments, or gaming sets.',
                    style: TextStyle(fontSize: 12, color: Colors.white54, fontStyle: FontStyle.italic),
                  ),
                )
              else
                ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: tools.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final tool = tools[index];
                    final category = SrdProficienciesLibrary.getToolCategory(tool);
                    final recAbility = SrdProficienciesLibrary.getRecommendedAbility(tool);
                    final abilityMod = controller.stats.effectiveScores.getModifier(recAbility);
                    final totalMod = controller.stats.proficiencyBonus + abilityMod;
                    final modStr = totalMod >= 0 ? '+$totalMod' : '$totalMod';

                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.05),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.white12),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            _getToolIcon(category),
                            size: 18,
                            color: Colors.amberAccent,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  tool,
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                ),
                                Text(
                                  '${category.displayName} • ${recAbility.shortName} check ($modStr)',
                                  style: const TextStyle(fontSize: 11, color: Colors.white70),
                                ),
                              ],
                            ),
                          ),
                          ElevatedButton.icon(
                            onPressed: () => _dispatchToolRoll(context, tool),
                            icon: const Icon(Icons.casino, size: 14),
                            label: Text(
                              'Roll $modStr',
                              style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.amber.shade900.withValues(alpha: 0.6),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              visualDensity: VisualDensity.compact,
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete_outline, size: 18, color: Colors.white38),
                            tooltip: 'Remove $tool',
                            onPressed: () {
                              HapticService.selectionTick(context);
                              controller.removeToolProficiency(tool);
                            },
                          ),
                        ],
                      ),
                    );
                  },
                ),
            ],
          ),
        ),
      ],
    );
  }

  static IconData _getToolIcon(ToolCategory category) {
    return switch (category) {
      ToolCategory.artisansTools => Icons.handyman,
      ToolCategory.gamingSets => Icons.casino,
      ToolCategory.musicalInstruments => Icons.music_note,
      ToolCategory.vehicles => Icons.directions_boat,
      ToolCategory.kits => Icons.medical_services,
    };
  }
}

class _AddLanguageDialog extends StatefulWidget {
  final CharacterSheetController controller;

  const _AddLanguageDialog({required this.controller});

  @override
  State<_AddLanguageDialog> createState() => _AddLanguageDialogState();
}

class _AddLanguageDialogState extends State<_AddLanguageDialog> {
  final _customController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _customController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final existingLangs = widget.controller.character.languages.map((l) => l.toLowerCase()).toSet();
    final availableStandard = SrdProficienciesLibrary.standardLanguages
        .where((l) => !existingLangs.contains(l.toLowerCase()))
        .where((l) => l.toLowerCase().contains(_searchQuery.toLowerCase()))
        .toList();
    final availableExotic = SrdProficienciesLibrary.exoticLanguages
        .where((l) => !existingLangs.contains(l.toLowerCase()))
        .where((l) => l.toLowerCase().contains(_searchQuery.toLowerCase()))
        .toList();

    return AlertDialog(
      title: const Text('Add Language Known'),
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: _customController,
                decoration: const InputDecoration(
                  labelText: 'Custom Language',
                  hintText: 'Enter language name...',
                  prefixIcon: Icon(Icons.language),
                  border: OutlineInputBorder(),
                ),
                onChanged: (val) => setState(() => _searchQuery = val.trim()),
              ),
              const SizedBox(height: 16),
              if (availableStandard.isNotEmpty) ...[
                const Text('Standard Languages', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.cyanAccent)),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: availableStandard.map((lang) {
                    return ActionChip(
                      label: Text(lang),
                      onPressed: () {
                        widget.controller.addLanguage(lang);
                        Navigator.of(context).pop();
                      },
                    );
                  }).toList(),
                ),
                const SizedBox(height: 12),
              ],
              if (availableExotic.isNotEmpty) ...[
                const Text('Exotic Languages', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.purpleAccent)),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: availableExotic.map((lang) {
                    return ActionChip(
                      label: Text(lang),
                      onPressed: () {
                        widget.controller.addLanguage(lang);
                        Navigator.of(context).pop();
                      },
                    );
                  }).toList(),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () {
            final custom = _customController.text.trim();
            if (custom.isNotEmpty) {
              widget.controller.addLanguage(custom);
            }
            Navigator.of(context).pop();
          },
          child: const Text('Add Custom'),
        ),
      ],
    );
  }
}

class _AddToolDialog extends StatefulWidget {
  final CharacterSheetController controller;

  const _AddToolDialog({required this.controller});

  @override
  State<_AddToolDialog> createState() => _AddToolDialogState();
}

class _AddToolDialogState extends State<_AddToolDialog> {
  final _customController = TextEditingController();
  ToolCategory _selectedCategory = ToolCategory.artisansTools;
  String _searchQuery = '';

  @override
  void dispose() {
    _customController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final existingTools = widget.controller.character.toolProficiencies.map((t) => t.toLowerCase()).toSet();
    final allCategoryTools = switch (_selectedCategory) {
      ToolCategory.artisansTools => SrdProficienciesLibrary.artisansTools,
      ToolCategory.gamingSets => SrdProficienciesLibrary.gamingSets,
      ToolCategory.musicalInstruments => SrdProficienciesLibrary.musicalInstruments,
      ToolCategory.kits => SrdProficienciesLibrary.kitsAndSpecialized,
      ToolCategory.vehicles => SrdProficienciesLibrary.vehicles,
    };

    final availableTools = allCategoryTools
        .where((t) => !existingTools.contains(t.toLowerCase()))
        .where((t) => t.toLowerCase().contains(_searchQuery.toLowerCase()))
        .toList();

    return AlertDialog(
      title: const Text('Add Tool Proficiency'),
      content: SizedBox(
        width: 460,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: _customController,
                decoration: const InputDecoration(
                  labelText: 'Search or Custom Tool',
                  hintText: 'Search or enter custom tool name...',
                  prefixIcon: Icon(Icons.search),
                  border: OutlineInputBorder(),
                ),
                onChanged: (val) => setState(() => _searchQuery = val.trim()),
              ),
              const SizedBox(height: 12),
              // Category Segmented Selector
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: ToolCategory.values.map((cat) {
                    final isSel = _selectedCategory == cat;
                    return Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: ChoiceChip(
                        label: Text(cat.displayName, style: const TextStyle(fontSize: 11)),
                        selected: isSel,
                        onSelected: (_) => setState(() => _selectedCategory = cat),
                      ),
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(height: 12),
              if (availableTools.isNotEmpty)
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: availableTools.map((tool) {
                    return ActionChip(
                      label: Text(tool),
                      onPressed: () {
                        widget.controller.addToolProficiency(tool);
                        Navigator.of(context).pop();
                      },
                    );
                  }).toList(),
                )
              else
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: Text('No matching tools in this category.', style: TextStyle(fontSize: 12, color: Colors.white54)),
                ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () {
            final custom = _customController.text.trim();
            if (custom.isNotEmpty) {
              widget.controller.addToolProficiency(custom);
            }
            Navigator.of(context).pop();
          },
          child: const Text('Add Custom'),
        ),
      ],
    );
  }
}
