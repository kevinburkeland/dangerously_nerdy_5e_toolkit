import 'package:flutter/material.dart';
import '../../../../domain/ingestion/models/source_block.dart';

/// Component presenting unrecognized or unassigned source text with ignore controls.
class UnrecognizedSourceView extends StatelessWidget {
  final String title;
  final String explanation;
  final List<SourceBlock> blocks;
  final Set<String> ignoredBlockIds;
  final ValueChanged<String>? onToggleIgnore;

  const UnrecognizedSourceView({
    super.key,
    required this.title,
    required this.explanation,
    required this.blocks,
    this.ignoredBlockIds = const {},
    this.onToggleIgnore,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (blocks.isEmpty) {
      return const SizedBox.shrink();
    }

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(color: Colors.amberAccent.withValues(alpha: 0.3)),
      ),
      color: Colors.amberAccent.withValues(alpha: 0.03),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.info_outline, size: 16, color: Colors.amberAccent),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                      color: Colors.amberAccent,
                    ),
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.amberAccent.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    '${blocks.length} blocks',
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: Colors.amberAccent,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              explanation,
              style: TextStyle(
                fontSize: 11,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 10),
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: blocks.length,
              separatorBuilder: (_, __) => const SizedBox(height: 6),
              itemBuilder: (context, index) {
                final block = blocks[index];
                final isIgnored = ignoredBlockIds.contains(block.id);

                return Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  decoration: BoxDecoration(
                    color: isIgnored
                        ? theme.disabledColor.withValues(alpha: 0.05)
                        : theme.colorScheme.surfaceContainerHigh,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: isIgnored
                          ? theme.disabledColor.withValues(alpha: 0.2)
                          : theme.dividerColor.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(
                          block.span.locationString,
                          style: TextStyle(
                            fontSize: 10,
                            color: theme.colorScheme.primary,
                            fontFamily: 'monospace',
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          block.normalizedText,
                          style: TextStyle(
                            fontSize: 12,
                            color: isIgnored
                                ? theme.disabledColor
                                : theme.colorScheme.onSurface,
                            decoration:
                                isIgnored ? TextDecoration.lineThrough : null,
                          ),
                        ),
                      ),
                      if (onToggleIgnore != null)
                        Semantics(
                          label: isIgnored
                              ? 'Unignore block at ${block.span.locationString}'
                              : 'Ignore block at ${block.span.locationString}',
                          button: true,
                          child: IconButton(
                            iconSize: 18,
                            constraints: const BoxConstraints(
                              minWidth: 48,
                              minHeight: 48,
                            ),
                            tooltip: isIgnored ? 'Include block' : 'Ignore block',
                            icon: Icon(
                              isIgnored
                                  ? Icons.visibility_off_outlined
                                  : Icons.visibility_outlined,
                              color: isIgnored
                                  ? theme.disabledColor
                                  : theme.colorScheme.primary,
                            ),
                            onPressed: () => onToggleIgnore!(block.id),
                          ),
                        ),
                    ],
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
