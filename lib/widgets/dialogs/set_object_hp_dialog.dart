import 'package:flutter/material.dart';
import 'app_dialog_frame.dart';

class SetObjectHpResult {
  final int currentHp;
  final int tempHp;
  const SetObjectHpResult({required this.currentHp, required this.tempHp});
}

class SetObjectHpDialog extends StatefulWidget {
  final String objectName;
  final int currentHp;
  final int maxHp;
  final int tempHp;

  const SetObjectHpDialog({
    super.key,
    required this.objectName,
    required this.currentHp,
    required this.maxHp,
    this.tempHp = 0,
  });

  static Future<SetObjectHpResult?> show(
    BuildContext context, {
    required String objectName,
    required int currentHp,
    required int maxHp,
    int tempHp = 0,
  }) {
    return showDialog<SetObjectHpResult>(
      context: context,
      builder: (ctx) => SetObjectHpDialog(
        objectName: objectName,
        currentHp: currentHp,
        maxHp: maxHp,
        tempHp: tempHp,
      ),
    );
  }

  @override
  State<SetObjectHpDialog> createState() => _SetObjectHpDialogState();
}

class _SetObjectHpDialogState extends State<SetObjectHpDialog> {
  late final TextEditingController _hpController;
  late final TextEditingController _tempHpController;

  @override
  void initState() {
    super.initState();
    _hpController = TextEditingController(text: '${widget.currentHp}');
    _tempHpController = TextEditingController(text: '${widget.tempHp}');
  }

  @override
  void dispose() {
    _hpController.dispose();
    _tempHpController.dispose();
    super.dispose();
  }

  void _submit() {
    final rawHp = int.tryParse(_hpController.text) ?? widget.currentHp;
    final enteredTemp = int.tryParse(_tempHpController.text) ?? widget.tempHp;
    final excessHp = rawHp > widget.maxHp ? (rawHp - widget.maxHp) : 0;
    final finalCurrentHp = rawHp.clamp(0, widget.maxHp);
    final finalTempHp = (enteredTemp < 0 ? 0 : enteredTemp) + excessHp;

    Navigator.pop(
      context,
      SetObjectHpResult(
        currentHp: finalCurrentHp,
        tempHp: finalTempHp,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return AppDialogFrame(
      icon: Icons.favorite,
      iconColor: colorScheme.primary,
      title: 'Set HP: ${widget.objectName}',
      maxWidth: 320,
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _hpController,
            keyboardType: TextInputType.number,
            autofocus: true,
            style: TextStyle(color: colorScheme.onSurface),
            decoration: InputDecoration(
              labelText: 'Current HP (Max ${widget.maxHp})',
              prefixIcon: const Icon(Icons.shield_outlined, color: Colors.greenAccent),
              focusedBorder: UnderlineInputBorder(
                borderSide: BorderSide(color: colorScheme.primary, width: 2),
              ),
            ),
            onSubmitted: (_) => _submit(),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _tempHpController,
            keyboardType: TextInputType.number,
            style: TextStyle(color: colorScheme.secondary),
            decoration: InputDecoration(
              labelText: 'Temporary HP (Absorbs damage first)',
              prefixIcon: Icon(Icons.health_and_safety, color: colorScheme.secondary),
              focusedBorder: UnderlineInputBorder(
                borderSide: BorderSide(color: colorScheme.secondary, width: 2),
              ),
            ),
            onSubmitted: (_) => _submit(),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text('Cancel', style: TextStyle(color: colorScheme.onSurfaceVariant)),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: colorScheme.primary,
            foregroundColor: colorScheme.onPrimary,
          ),
          onPressed: _submit,
          child: const Text('Save HP', style: TextStyle(fontWeight: FontWeight.bold)),
        ),
      ],
    );
  }
}

