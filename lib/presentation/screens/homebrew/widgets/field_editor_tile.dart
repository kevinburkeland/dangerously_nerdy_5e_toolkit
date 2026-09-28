import 'package:flutter/material.dart';
import '../../../../domain/ingestion/models/field_state.dart';
import '../../../../domain/ingestion/models/ingestion_field.dart';

/// Interactive tile displaying a single candidate field, its semantic parsing state,
/// source span traceability, and an in-place editor.
class FieldEditorTile extends StatefulWidget {
  final IngestionField<dynamic> field;
  final ValueChanged<dynamic> onValueChanged;
  final VoidCallback? onFocusSourceSpan;

  const FieldEditorTile({
    super.key,
    required this.field,
    required this.onValueChanged,
    this.onFocusSourceSpan,
  });

  @override
  State<FieldEditorTile> createState() => _FieldEditorTileState();
}

class _FieldEditorTileState extends State<FieldEditorTile> {
  late TextEditingController _controller;
  bool _isEditing = false;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(
      text: widget.field.value?.toString() ?? widget.field.rawText ?? '',
    );
  }

  @override
  void didUpdateWidget(covariant FieldEditorTile oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.field.value != widget.field.value ||
        oldWidget.field.state != widget.field.state) {
      if (!_isEditing) {
        _controller.text =
            widget.field.value?.toString() ?? widget.field.rawText ?? '';
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final field = widget.field;
    final state = field.state;

    final (stateColor, stateIcon) = _getStateStyle(state, theme);

    return Semantics(
      label: '${field.label}: ${state.screenReaderLabel}. ${field.value ?? "Not provided"}',
      container: true,
      child: Card(
        margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 0),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: BorderSide(
            color: state.isBlocking && field.isRequired
                ? stateColor.withValues(alpha: 0.6)
                : theme.dividerColor.withValues(alpha: 0.2),
            width: state.isBlocking && field.isRequired ? 1.5 : 1.0,
          ),
        ),
        color: state.isBlocking && field.isRequired
            ? stateColor.withValues(alpha: 0.05)
            : null,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header row: State icon, Label, Required badge, Edited badge, Span badge
              Wrap(
                spacing: 8,
                runSpacing: 4,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  // Semantic State Badge
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: stateColor.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: stateColor.withValues(alpha: 0.4)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(stateIcon, size: 14, color: stateColor),
                        const SizedBox(width: 4),
                        Text(
                          '${state.symbol} ${state.displayName}',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: stateColor,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Field Label
                  Text(
                    field.label,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: theme.colorScheme.onSurface,
                    ),
                  ),

                  if (field.isRequired)
                    Text(
                      '*Required',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.redAccent.shade200,
                        fontWeight: FontWeight.bold,
                      ),
                    ),

                  if (field.isUserEdited)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.blueAccent.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Text(
                        'User Edited',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: Colors.blueAccent,
                        ),
                      ),
                    ),

                  // Source Traceability Span Link
                  if (field.span != null && !field.span!.isEmpty)
                    InkWell(
                      onTap: widget.onFocusSourceSpan,
                      borderRadius: BorderRadius.circular(4),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 4, vertical: 2),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.find_in_page_outlined,
                                size: 12,
                                color: theme.colorScheme.primary),
                            const SizedBox(width: 2),
                            Text(
                              field.span!.locationString,
                              style: TextStyle(
                                fontSize: 10,
                                color: theme.colorScheme.primary,
                                decoration: TextDecoration.underline,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),

              const SizedBox(height: 8),

              // Ambiguity selection chips if multiple choices exist
              if (field.state == IngestionFieldState.ambiguous &&
                  field.ambiguousOptions.isNotEmpty) ...[
                Text(
                  'Select an interpretation:',
                  style: TextStyle(
                    fontSize: 11,
                    fontStyle: FontStyle.italic,
                    color: stateColor,
                  ),
                ),
                const SizedBox(height: 4),
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: field.ambiguousOptions.map((opt) {
                    return ActionChip(
                      label: Text(opt),
                      backgroundColor: theme.colorScheme.surfaceContainerHighest,
                      onPressed: () {
                        _controller.text = opt;
                        widget.onValueChanged(opt);
                      },
                    );
                  }).toList(),
                ),
                const SizedBox(height: 8),
              ],

              // Validation Error Message
              if (field.state == IngestionFieldState.invalid &&
                  field.validationError != null) ...[
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.redAccent.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.error_outline,
                          size: 14, color: Colors.redAccent),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          field.validationError!,
                          style: const TextStyle(
                            fontSize: 11,
                            color: Colors.redAccent,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
              ],

              // In-place text editor
              TextFormField(
                controller: _controller,
                maxLines: _isMultiline(field.key) ? 4 : 1,
                minLines: 1,
                decoration: InputDecoration(
                  isDense: true,
                  hintText: field.state == IngestionFieldState.missing
                      ? 'Type missing value...'
                      : 'Edit value...',
                  hintStyle: TextStyle(
                    fontSize: 13,
                    color: field.state == IngestionFieldState.missing
                        ? Colors.redAccent.withValues(alpha: 0.6)
                        : theme.hintColor,
                  ),
                  filled: true,
                  fillColor: theme.colorScheme.surfaceContainerLow,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: theme.dividerColor),
                  ),
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                ),
                onChanged: (val) {
                  _isEditing = true;
                  widget.onValueChanged(val);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  (Color, IconData) _getStateStyle(
      IngestionFieldState state, ThemeData theme) {
    switch (state) {
      case IngestionFieldState.extracted:
        return (Colors.greenAccent.shade400, Icons.check_circle_outline);
      case IngestionFieldState.inferred:
        return (Colors.cyanAccent.shade400, Icons.auto_awesome);
      case IngestionFieldState.ambiguous:
        return (Colors.amberAccent.shade400, Icons.help_outline);
      case IngestionFieldState.invalid:
        return (Colors.redAccent.shade400, Icons.error_outline);
      case IngestionFieldState.missing:
        return (Colors.orangeAccent.shade400, Icons.remove_circle_outline);
      case IngestionFieldState.optionalNotProvided:
        return (theme.disabledColor, Icons.radio_button_unchecked);
    }
  }

  bool _isMultiline(String key) {
    final lower = key.toLowerCase();
    return lower.contains('markdown') ||
        lower.contains('description') ||
        lower.contains('actions') ||
        lower.contains('traits');
  }
}
