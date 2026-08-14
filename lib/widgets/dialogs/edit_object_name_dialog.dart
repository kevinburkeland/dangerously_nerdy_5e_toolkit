import 'package:flutter/material.dart';
import 'value_input_dialog.dart';

/// Facade dialog for renaming an active summon or minion object.
class EditObjectNameDialog {
  static Future<String?> show(BuildContext context, {required String initialName}) {
    return ValueInputDialog.showText(
      context,
      title: 'Rename Object',
      icon: Icons.edit_note,
      labelText: 'Custom Object Name',
      initialValue: initialName,
      confirmLabel: 'Save',
    );
  }
}
