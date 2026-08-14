import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Unified, theme-aware dialog for single-value numeric or text input.
class ValueInputDialog<T> extends StatefulWidget {
  final String title;
  final IconData icon;
  final Color? accentColor;
  final String labelText;
  final String initialValue;
  final String confirmLabel;
  final TextInputType keyboardType;
  final List<TextInputFormatter>? inputFormatters;
  final T? Function(String raw) parser;

  const ValueInputDialog({
    super.key,
    required this.title,
    required this.icon,
    this.accentColor,
    required this.labelText,
    this.initialValue = '',
    this.confirmLabel = 'Confirm',
    this.keyboardType = TextInputType.text,
    this.inputFormatters,
    required this.parser,
  });

  /// Helper for single integer inputs (e.g. HP, Temp HP, Damage, Custom Sides)
  static Future<int?> showInt(
    BuildContext context, {
    required String title,
    required IconData icon,
    Color? accentColor,
    required String labelText,
    int? initialValue,
    int min = 1,
    int max = 9999,
    String confirmLabel = 'Apply',
  }) {
    return showDialog<int>(
      context: context,
      builder: (ctx) => ValueInputDialog<int>(
        title: title,
        icon: icon,
        accentColor: accentColor,
        labelText: labelText,
        initialValue: initialValue?.toString() ?? '',
        confirmLabel: confirmLabel,
        keyboardType: TextInputType.number,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        parser: (raw) => int.tryParse(raw.trim())?.clamp(min, max),
      ),
    );
  }

  /// Helper for string inputs (e.g. renaming objects, room names)
  static Future<String?> showText(
    BuildContext context, {
    required String title,
    required IconData icon,
    Color? accentColor,
    required String labelText,
    String initialValue = '',
    int maxLength = 50,
    String confirmLabel = 'Save',
  }) {
    return showDialog<String>(
      context: context,
      builder: (ctx) => ValueInputDialog<String>(
        title: title,
        icon: icon,
        accentColor: accentColor,
        labelText: labelText,
        initialValue: initialValue,
        confirmLabel: confirmLabel,
        inputFormatters: [LengthLimitingTextInputFormatter(maxLength)],
        parser: (raw) => raw.trim().isNotEmpty ? raw.trim() : null,
      ),
    );
  }

  // --- Domain-Specific Semantic Helpers ---

  /// Configures a custom polyhedral die with 2 to 1000 sides.
  static Future<int?> showCustomDie(BuildContext context, {int initialSides = 7}) =>
      showInt(
        context,
        title: 'Custom Sided Die',
        icon: Icons.tune,
        labelText: 'Number of Sides (2 to 1000)',
        initialValue: initialSides,
        min: 2,
        max: 1000,
        confirmLabel: 'Add Die',
      );

  /// Grants Temporary HP to the entire minion squad.
  static Future<int?> showGroupTempHp(BuildContext context) =>
      showInt(
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

  /// Applies AoE damage to all active squad minions.
  static Future<int?> showMassDamage(BuildContext context) =>
      showInt(
        context,
        title: 'Apply Group Damage',
        icon: Icons.local_fire_department,
        accentColor: Theme.of(context).colorScheme.error,
        labelText: 'Damage Amount to ALL minions',
        min: 1,
        max: 999,
        confirmLabel: 'Apply Damage',
      );

  /// Renames an active summon or minion instance.
  static Future<String?> showRename(BuildContext context, {required String initialName}) =>
      showText(
        context,
        title: 'Rename Object',
        icon: Icons.edit_note,
        labelText: 'Custom Object Name',
        initialValue: initialName,
        confirmLabel: 'Save',
      );

  @override
  State<ValueInputDialog<T>> createState() => _ValueInputDialogState<T>();
}

class _ValueInputDialogState<T> extends State<ValueInputDialog<T>> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialValue);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final parsed = widget.parser(_controller.text);
    if (parsed != null) {
      Navigator.of(context).pop(parsed);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accent = widget.accentColor ?? theme.colorScheme.primary;

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Row(
        children: [
          Icon(widget.icon, color: accent, size: 22),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              widget.title,
              style: TextStyle(color: accent, fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
      content: TextField(
        controller: _controller,
        autofocus: true,
        keyboardType: widget.keyboardType,
        inputFormatters: widget.inputFormatters,
        style: TextStyle(color: theme.colorScheme.onSurface),
        decoration: InputDecoration(
          labelText: widget.labelText,
          focusedBorder: UnderlineInputBorder(
            borderSide: BorderSide(color: accent, width: 2),
          ),
        ),
        onSubmitted: (_) => _submit(),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text('Cancel', style: TextStyle(color: theme.colorScheme.onSurfaceVariant)),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: accent),
          onPressed: _submit,
          child: Text(
            widget.confirmLabel,
            style: TextStyle(
              color: ThemeData.estimateBrightnessForColor(accent) == Brightness.dark
                  ? Colors.white
                  : Colors.black,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    );
  }
}
