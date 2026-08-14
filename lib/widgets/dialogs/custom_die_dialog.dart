import 'package:flutter/material.dart';
import 'value_input_dialog.dart';

/// Facade dialog for configuring a custom polyhedral die with 2 to 1000 sides.
class CustomDieDialog {
  static Future<int?> show(BuildContext context, {int initialSides = 7}) {
    return ValueInputDialog.showInt(
      context,
      title: 'Custom Sided Die',
      icon: Icons.tune,
      labelText: 'Number of Sides (2 to 1000)',
      initialValue: initialSides,
      min: 2,
      max: 1000,
      confirmLabel: 'Add Die',
    );
  }
}
