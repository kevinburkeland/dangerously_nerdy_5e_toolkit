import 'package:flutter/material.dart';
import 'value_input_dialog.dart';

/// Facade dialog for granting Temporary HP to the entire squad.
class GrantTempHpDialog {
  static Future<int?> show(BuildContext context) {
    return ValueInputDialog.showInt(
      context,
      title: 'Grant Group Temp HP',
      icon: Icons.health_and_safety,
      accentColor: Theme.of(context).colorScheme.secondary,
      labelText: 'Temporary HP Amount',
      initialValue: 5,
      min: 1,
      max: 999,
      confirmLabel: 'Grant Temp HP',
    );
  }
}
