import 'package:flutter/material.dart';
import '../../models/domain/character_models.dart';
import '../../services/haptic_service.dart';

/// Modal bottom sheet allowing a player to select a spell slot level to cast or upcast a spell.
///
/// Complies with WCAG AA contrast standards and enforces minimum 48x48dp touch targets
/// with comprehensive screen-reader semantics.
class SpellUpcastSheet extends StatelessWidget {
  final String spellName;
  final int spellLevel;
  final CharacterResourcePool resources;

  const SpellUpcastSheet({
    super.key,
    required this.spellName,
    required this.spellLevel,
    required this.resources,
  });

  /// Displays the upcasting sheet, returning the chosen slot level or `null` if dismissed.
  static Future<int?> show(
    BuildContext context, {
    required String spellName,
    required int spellLevel,
    required CharacterResourcePool resources,
  }) {
    HapticService.selectionTick(context);
    return showModalBottomSheet<int>(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => SpellUpcastSheet(
        spellName: spellName,
        spellLevel: spellLevel,
        resources: resources,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final pool = resources.spellSlots;
    final maxSlotsMap = pool.maxSlots;
    final currentSlotsMap = pool.currentSlots;

    // Filter eligible spell slot levels (>= spellLevel) where maxSlots > 0
    final eligibleLevels = <int>[];
    for (int lvl = (spellLevel < 1 ? 1 : spellLevel); lvl <= 9; lvl++) {
      if ((maxSlotsMap[lvl] ?? 0) > 0) {
        eligibleLevels.add(lvl);
      }
    }

    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        border: Border.all(color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5)),
      ),
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 12,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Drag Handle
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 14),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.outlineVariant,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),

              // Title & Subtitle Header
              Semantics(
                header: true,
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.purpleAccent.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.auto_awesome, color: Colors.purpleAccent, size: 22),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Cast $spellName',
                            style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                          ),
                          Text(
                            spellLevel == 0
                                ? 'Base: Cantrip • Select casting slot'
                                : 'Base Level: $spellLevel • Select casting or upcast slot',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Semantics(
                      button: true,
                      label: 'Cancel spellcasting',
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
                        child: IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () => Navigator.of(context).pop(null),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 14),
              const Divider(height: 1),
              const SizedBox(height: 14),

              // Slot Rows List
              if (eligibleLevels.isEmpty) ...[
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 24),
                  child: Center(
                    child: Column(
                      children: [
                        const Icon(Icons.error_outline, size: 36, color: Colors.amberAccent),
                        const SizedBox(height: 8),
                        Text(
                          'No spell slots available for Level $spellLevel+ spells.',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                ),
              ] else ...[
                ...eligibleLevels.map((lvl) {
                  final max = maxSlotsMap[lvl] ?? 0;
                  final cur = currentSlotsMap[lvl] ?? max;
                  final isAvailable = cur > 0;
                  final isBaseLevel = lvl == spellLevel;
                  final upcastDelta = lvl - spellLevel;

                  final ordinal = switch (lvl) {
                    1 => '1st',
                    2 => '2nd',
                    3 => '3rd',
                    _ => '${lvl}th',
                  };

                  final semanticLabel = isAvailable
                      ? 'Cast at $ordinal Level, $cur slots remaining${upcastDelta > 0 ? " (+$upcastDelta level upcast)" : ""}'
                      : '$ordinal Level, 0 slots remaining (exhausted)';

                  return Semantics(
                    button: true,
                    enabled: isAvailable,
                    label: semanticLabel,
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(12),
                          onTap: isAvailable
                              ? () {
                                  HapticService.heavyImpact(context);
                                  Navigator.of(context).pop(lvl);
                                }
                              : null,
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(minHeight: 48),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                              decoration: BoxDecoration(
                                color: isAvailable
                                    ? (isBaseLevel
                                        ? Colors.purple.withValues(alpha: 0.12)
                                        : theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.4))
                                    : theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: isAvailable
                                      ? (isBaseLevel
                                          ? Colors.purpleAccent.withValues(alpha: 0.6)
                                          : theme.colorScheme.outlineVariant)
                                      : theme.colorScheme.outlineVariant.withValues(alpha: 0.3),
                                ),
                              ),
                              child: Row(
                                children: [
                                  // Slot Level Badge
                                  Container(
                                    width: 32,
                                    height: 32,
                                    alignment: Alignment.center,
                                    decoration: BoxDecoration(
                                      color: isAvailable
                                          ? (isBaseLevel ? Colors.purpleAccent : theme.colorScheme.primary)
                                          : theme.colorScheme.outlineVariant.withValues(alpha: 0.4),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      '$lvl',
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.bold,
                                        color: isAvailable ? Colors.black : Colors.white54,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),

                                  // Level Label and Upcast Indicator
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Text(
                                              '$ordinal Level Slot',
                                              style: theme.textTheme.bodyMedium?.copyWith(
                                                fontWeight: FontWeight.bold,
                                                color: isAvailable ? null : theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
                                              ),
                                            ),
                                            if (upcastDelta > 0) ...[
                                              const SizedBox(width: 8),
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                decoration: BoxDecoration(
                                                  color: Colors.cyanAccent.withValues(alpha: 0.15),
                                                  borderRadius: BorderRadius.circular(4),
                                                ),
                                                child: Text(
                                                  '+$upcastDelta UPCAST',
                                                  style: const TextStyle(
                                                    fontSize: 10,
                                                    fontWeight: FontWeight.bold,
                                                    color: Colors.cyanAccent,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ],
                                        ),
                                        Text(
                                          '$cur of $max slots remaining',
                                          style: theme.textTheme.bodySmall?.copyWith(
                                            color: isAvailable
                                                ? theme.colorScheme.onSurfaceVariant
                                                : Colors.redAccent.withValues(alpha: 0.8),
                                            fontWeight: isAvailable ? FontWeight.normal : FontWeight.bold,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),

                                  // Action Icon or Exhausted indicator
                                  if (isAvailable)
                                    Icon(
                                      Icons.arrow_forward_ios,
                                      size: 14,
                                      color: isBaseLevel ? Colors.purpleAccent : theme.colorScheme.primary,
                                    )
                                  else
                                    const Text(
                                      'DEPLETED',
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.redAccent,
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                }),
              ],

              const SizedBox(height: 12),

              // Dismiss / Cancel Button
              ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 48),
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(double.infinity, 48),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: () => Navigator.of(context).pop(null),
                  child: const Text('Cancel'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
