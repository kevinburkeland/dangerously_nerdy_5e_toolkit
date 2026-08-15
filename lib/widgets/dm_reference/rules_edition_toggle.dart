import 'package:flutter/material.dart';
import '../../models/dm_screen_data.dart';
import '../../services/a11y_service.dart';
import '../../services/haptic_service.dart';

/// A theme-reactive, accessible toggle widget for switching between
/// 2014 5e RAW rules and 2024 Revised rules.
class RulesEditionToggle extends StatelessWidget {
  final DmRulesEdition currentEdition;
  final ValueChanged<DmRulesEdition> onEditionChanged;
  final bool isDense;

  const RulesEditionToggle({
    super.key,
    required this.currentEdition,
    required this.onEditionChanged,
    this.isDense = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final is2024 = currentEdition == DmRulesEdition.v2024;

    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(isDense ? 8 : 10),
        border: Border.all(
          color: theme.colorScheme.primary.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildButton(
            context: context,
            label: '2014',
            edition: DmRulesEdition.v2014,
            isActive: !is2024,
            theme: theme,
          ),
          _buildButton(
            context: context,
            label: '2024',
            edition: DmRulesEdition.v2024,
            isActive: is2024,
            theme: theme,
          ),
        ],
      ),
    );
  }

  Widget _buildButton({
    required BuildContext context,
    required String label,
    required DmRulesEdition edition,
    required bool isActive,
    required ThemeData theme,
  }) {
    return Semantics(
      button: true,
      selected: isActive,
      label: '$label Edition Rules',
      child: InkWell(
        onTap: () {
          if (!isActive) {
            HapticService.selectionTick(context);
            final announcement = edition == DmRulesEdition.v2024
                ? 'Switched to 2024 revised rules edition'
                : 'Switched to 2014 rules edition';
            A11yService.announce(announcement);
            onEditionChanged(edition);
          }
        },
        borderRadius: BorderRadius.circular(isDense ? 6 : 8),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: EdgeInsets.symmetric(
            horizontal: isDense ? 10 : 12,
            vertical: isDense ? 5 : 6,
          ),
          decoration: BoxDecoration(
            color: isActive ? theme.colorScheme.primary : Colors.transparent,
            borderRadius: BorderRadius.circular(isDense ? 6 : 8),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: isActive
                  ? theme.colorScheme.onPrimary
                  : theme.colorScheme.onSurface.withValues(alpha: 0.7),
              fontWeight: FontWeight.bold,
              fontSize: isDense ? 11 : 12,
            ),
          ),
        ),
      ),
    );
  }
}
