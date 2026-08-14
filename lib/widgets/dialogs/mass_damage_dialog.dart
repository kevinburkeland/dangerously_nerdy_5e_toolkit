import 'package:flutter/material.dart';
import 'value_input_dialog.dart';

/// Facade dialog for applying AoE damage to all active squad minions.
class MassDamageDialog {
  static Future<int?> show(BuildContext context) {
    final theme = Theme.of(context);
    return ValueInputDialog.showInt(
      context,
      title: 'Apply Group Damage',
      icon: Icons.local_fire_department,
      accentColor: theme.colorScheme.error,
      labelText: 'Damage Amount to ALL minions',
      min: 1,
      max: 999,
      confirmLabel: 'Apply Damage',
    );
  }
}
