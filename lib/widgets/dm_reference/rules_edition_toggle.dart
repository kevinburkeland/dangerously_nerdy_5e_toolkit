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
  final bool isExpanded;
  final bool showIcons;
  final bool showSubtext;

  const RulesEditionToggle({
    super.key,
    required this.currentEdition,
    required this.onEditionChanged,
    this.isDense = false,
    this.isExpanded = false,
    this.showIcons = false,
    this.showSubtext = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final is2024 = currentEdition == DmRulesEdition.v2024;

    final container = Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(isDense ? 8 : 10),
        border: Border.all(
          color: theme.colorScheme.primary.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        mainAxisSize: isExpanded ? MainAxisSize.max : MainAxisSize.min,
        children: [
          _wrapFlexible(
            _buildButton(
              context: context,
              label: '2014',
              subtext: showSubtext ? '5.1 RAW' : null,
              icon: showIcons ? Icons.history_edu : null,
              edition: DmRulesEdition.v2014,
              isActive: !is2024,
              theme: theme,
            ),
          ),
          _wrapFlexible(
            _buildButton(
              context: context,
              label: '2024',
              subtext: showSubtext ? '5.2 Revised' : null,
              icon: showIcons ? Icons.auto_awesome : null,
              edition: DmRulesEdition.v2024,
              isActive: is2024,
              theme: theme,
            ),
          ),
        ],
      ),
    );

    if (isExpanded) {
      return SizedBox(width: double.infinity, child: container);
    }
    return container;
  }

  Widget _wrapFlexible(Widget child) {
    if (isExpanded) {
      return Expanded(child: child);
    }
    return child;
  }

  Widget _buildButton({
    required BuildContext context,
    required String label,
    String? subtext,
    IconData? icon,
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
            horizontal: isDense ? 10 : (isExpanded ? 16 : 12),
            vertical: isDense ? 5 : (isExpanded ? 10 : 6),
          ),
          decoration: BoxDecoration(
            color: isActive ? theme.colorScheme.primary : Colors.transparent,
            borderRadius: BorderRadius.circular(isDense ? 6 : 8),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: isExpanded ? MainAxisSize.max : MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(
                  icon,
                  size: isDense ? 14 : 16,
                  color: isActive
                      ? theme.colorScheme.onPrimary
                      : theme.colorScheme.onSurface.withValues(alpha: 0.7),
                ),
                const SizedBox(width: 6),
              ],
              Text(
                label,
                style: TextStyle(
                  color: isActive
                      ? theme.colorScheme.onPrimary
                      : theme.colorScheme.onSurface.withValues(alpha: 0.7),
                  fontWeight: FontWeight.bold,
                  fontSize: isDense ? 11 : 12,
                ),
              ),
              if (subtext != null) ...[
                const SizedBox(width: 4),
                Text(
                  '($subtext)',
                  style: TextStyle(
                    color: isActive
                        ? theme.colorScheme.onPrimary.withValues(alpha: 0.85)
                        : theme.colorScheme.onSurface.withValues(alpha: 0.5),
                    fontSize: isDense ? 9.5 : 10.5,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
