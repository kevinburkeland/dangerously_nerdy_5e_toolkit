import 'package:flutter/material.dart';
import '../../models/domain/character_models.dart';
import '../../services/haptic_service.dart';

/// Selection payload indicating the spell slot level and whether it expends a Pact Magic slot.
@immutable
class SpellCastSelection {
  final int slotLevel;
  final bool isPactMagic;

  const SpellCastSelection({
    required this.slotLevel,
    this.isPactMagic = false,
  });

  const SpellCastSelection.regular(this.slotLevel) : isPactMagic = false;
  const SpellCastSelection.pact(this.slotLevel) : isPactMagic = true;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SpellCastSelection &&
          other.slotLevel == slotLevel &&
          other.isPactMagic == isPactMagic) ||
      (other is int && other == slotLevel);

  @override
  int get hashCode => slotLevel.hashCode ^ isPactMagic.hashCode;

  @override
  String toString() => isPactMagic ? 'Pact Magic Lvl $slotLevel' : 'Slot Lvl $slotLevel';
}

/// Internal option representation for slot selection rows.
class _SpellUpcastOption {
  final int level;
  final bool isPactMagic;
  final int currentSlots;
  final int maxSlots;

  const _SpellUpcastOption({
    required this.level,
    required this.isPactMagic,
    required this.currentSlots,
    required this.maxSlots,
  });
}

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

  /// Displays the upcasting sheet, returning the chosen slot selection or `null` if dismissed.
  static Future<SpellCastSelection?> show(
    BuildContext context, {
    required String spellName,
    required int spellLevel,
    required CharacterResourcePool resources,
  }) {
    HapticService.selectionTick(context);
    return showModalBottomSheet<SpellCastSelection>(
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
    final minLevel = spellLevel < 1 ? 1 : spellLevel;

    // Build eligible regular and Pact Magic slot options
    final options = <_SpellUpcastOption>[];
    for (int lvl = minLevel; lvl <= 9; lvl++) {
      final max = maxSlotsMap[lvl] ?? 0;
      if (max > 0) {
        options.add(_SpellUpcastOption(
          level: lvl,
          isPactMagic: false,
          currentSlots: currentSlotsMap[lvl] ?? max,
          maxSlots: max,
        ));
      }
    }

    // Add Pact Magic option if character possesses pact slots >= spell level
    if (pool.pactMagicMax > 0 && pool.pactMagicSlotLevel >= minLevel) {
      options.add(_SpellUpcastOption(
        level: pool.pactMagicSlotLevel,
        isPactMagic: true,
        currentSlots: pool.pactMagicCurrent,
        maxSlots: pool.pactMagicMax,
      ));
    }

    // Sort options by level, with regular slots preceding Pact Magic if same level
    options.sort((a, b) {
      final cmp = a.level.compareTo(b.level);
      if (cmp != 0) return cmp;
      if (!a.isPactMagic && b.isPactMagic) return -1;
      if (a.isPactMagic && !b.isPactMagic) return 1;
      return 0;
    });

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
              if (options.isEmpty) ...[
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
                ...options.map((opt) {
                  final lvl = opt.level;
                  final max = opt.maxSlots;
                  final cur = opt.currentSlots;
                  final isAvailable = cur > 0;
                  final isBaseLevel = lvl == spellLevel;
                  final upcastDelta = lvl - spellLevel;

                  final ordinal = switch (lvl) {
                    1 => '1st',
                    2 => '2nd',
                    3 => '3rd',
                    _ => '${lvl}th',
                  };

                  final levelTitle = opt.isPactMagic
                      ? '$ordinal Level Slot (Pact)'
                      : '$ordinal Level Slot';

                  final semanticLabel = isAvailable
                      ? 'Cast at $levelTitle, $cur slots remaining${upcastDelta > 0 ? " (+$upcastDelta level upcast)" : ""}'
                      : '$levelTitle, 0 slots remaining (exhausted)';

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
                                  Navigator.of(context).pop(
                                    SpellCastSelection(
                                      slotLevel: lvl,
                                      isPactMagic: opt.isPactMagic,
                                    ),
                                  );
                                }
                              : null,
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(minHeight: 48),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                              decoration: BoxDecoration(
                                color: isAvailable
                                    ? (opt.isPactMagic
                                        ? Colors.purple.withValues(alpha: 0.18)
                                        : (isBaseLevel
                                            ? Colors.purple.withValues(alpha: 0.12)
                                            : theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.4)))
                                    : theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: isAvailable
                                      ? (opt.isPactMagic
                                          ? Colors.purpleAccent.withValues(alpha: 0.8)
                                          : (isBaseLevel
                                              ? Colors.purpleAccent.withValues(alpha: 0.6)
                                              : theme.colorScheme.outlineVariant))
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
                                          ? (opt.isPactMagic
                                              ? Colors.purpleAccent
                                              : (isBaseLevel ? Colors.purpleAccent : theme.colorScheme.primary))
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
                                        Wrap(
                                          crossAxisAlignment: WrapCrossAlignment.center,
                                          spacing: 6,
                                          runSpacing: 4,
                                          children: [
                                            Text(
                                              levelTitle,
                                              style: theme.textTheme.bodyMedium?.copyWith(
                                                fontWeight: FontWeight.bold,
                                                color: isAvailable
                                                    ? (opt.isPactMagic ? Colors.purpleAccent : null)
                                                    : theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
                                              ),
                                            ),
                                            if (opt.isPactMagic)
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                decoration: BoxDecoration(
                                                  color: Colors.purpleAccent.withValues(alpha: 0.2),
                                                  borderRadius: BorderRadius.circular(4),
                                                  border: Border.all(color: Colors.purpleAccent.withValues(alpha: 0.4)),
                                                ),
                                                child: const Text(
                                                  'PACT',
                                                  style: TextStyle(
                                                    fontSize: 10,
                                                    fontWeight: FontWeight.bold,
                                                    color: Colors.purpleAccent,
                                                  ),
                                                ),
                                              ),
                                            if (upcastDelta > 0)
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
                                        ),
                                        Text(
                                          opt.isPactMagic
                                              ? '$cur of $max pact slots remaining • Recharges on Short Rest'
                                              : '$cur of $max slots remaining',
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
                                      color: opt.isPactMagic
                                          ? Colors.purpleAccent
                                          : (isBaseLevel ? Colors.purpleAccent : theme.colorScheme.primary),
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
