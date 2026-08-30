import 'package:flutter/material.dart';
import '../../models/dm_screen_data.dart';
import '../common/edition_diff_badge.dart';
import '../interactive/pressable_card.dart';
import 'dm_interactive_tools.dart';

/// Modular, interactive card presenting a single 5e rulebook entry with search highlighting and embedded tools.
class DmRuleCard extends StatefulWidget {
  final DmReferenceItem item;
  final DmRulesEdition edition;
  final bool isPinned;
  final VoidCallback onTogglePin;
  final VoidCallback onTap;
  final String searchQuery;

  const DmRuleCard({
    super.key,
    required this.item,
    required this.edition,
    required this.isPinned,
    required this.onTogglePin,
    required this.onTap,
    this.searchQuery = '',
  });

  @override
  State<DmRuleCard> createState() => _DmRuleCardState();
}

class _DmRuleCardState extends State<DmRuleCard> {
  bool _showTool = false;

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    final edition = widget.edition;
    final isPinned = widget.isPinned;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final itemColor = item.getLegibleColor(isDark);
    final diffColor = isDark ? Colors.amber : const Color(0xFFB45309);
    final activeRules = item.getRules(edition);
    final cost = item.getCost(edition);

    return PressableCard(
      onTap: widget.onTap,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(
          color: isPinned ? diffColor.withValues(alpha: 0.7) : itemColor.withValues(alpha: 0.35),
          width: isPinned ? 1.5 : 1.2,
        ),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Row
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: itemColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(item.icon, color: itemColor, size: 22),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildHighlightedText(
                      text: item.title,
                      query: widget.searchQuery,
                      style: TextStyle(
                        color: theme.colorScheme.onSurface,
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                      highlightColor: diffColor.withValues(alpha: 0.3),
                    ),
                    const SizedBox(height: 2),
                    Text.rich(
                      TextSpan(
                        children: [
                          TextSpan(
                            text: item.category.label,
                            style: TextStyle(
                              color: theme.colorScheme.onSurfaceVariant,
                              fontSize: 11,
                            ),
                          ),
                          if (cost != null) ...[
                            TextSpan(
                              text: ' • ',
                              style: TextStyle(
                                color: theme.colorScheme.onSurfaceVariant,
                                fontSize: 11,
                              ),
                            ),
                            TextSpan(
                              text: cost,
                              style: TextStyle(
                                color: itemColor,
                                fontWeight: FontWeight.w600,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ],
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              if (item.isChangedIn2024) ...[
                const EditionDiffBadge(),
                const SizedBox(width: 6),
              ],
              IconButton(
                icon: Icon(
                  isPinned ? Icons.push_pin : Icons.push_pin_outlined,
                  color: isPinned ? diffColor : theme.colorScheme.onSurfaceVariant,
                  size: 20,
                ),
                tooltip: isPinned ? 'Unpin rule from top' : 'Pin rule to top',
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 30, minHeight: 30),
                splashRadius: 18,
                onPressed: widget.onTogglePin,
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Summary
          _buildHighlightedText(
            text: item.summary,
            query: widget.searchQuery,
            style: TextStyle(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.85),
              fontSize: 12,
              fontStyle: FontStyle.italic,
            ),
            highlightColor: diffColor.withValues(alpha: 0.3),
          ),
          Divider(height: 16, color: theme.colorScheme.outlineVariant.withValues(alpha: 0.2)),

          // 2024 Diff Callout if changed
          if (item.isChangedIn2024 && item.diffSummary != null) ...[
            Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: diffColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: diffColor.withValues(alpha: 0.35)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.bolt, color: diffColor, size: 14),
                  const SizedBox(width: 6),
                  Expanded(
                    child: _buildHighlightedText(
                      text: item.diffSummary!,
                      query: widget.searchQuery,
                      style: TextStyle(
                        color: theme.colorScheme.onSurface,
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                        height: 1.25,
                      ),
                      highlightColor: diffColor.withValues(alpha: 0.4),
                    ),
                  ),
                ],
              ),
            ),
          ],

          // Rule Bullet points for current edition
          ...activeRules.map((rule) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('• ', style: TextStyle(color: itemColor, fontWeight: FontWeight.bold)),
                    Expanded(
                      child: _buildHighlightedText(
                        text: rule,
                        query: widget.searchQuery,
                        style: TextStyle(
                          color: theme.colorScheme.onSurface.withValues(alpha: 0.85),
                          fontSize: 13,
                          height: 1.35,
                        ),
                        highlightColor: diffColor.withValues(alpha: 0.3),
                      ),
                    ),
                  ],
                ),
              )),

          // Embedded Interactive Tool if applicable
          if (item.interactiveTool != null) ...[
            const SizedBox(height: 6),
            InkWell(
              onTap: () => setState(() => _showTool = !_showTool),
              borderRadius: BorderRadius.circular(8),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: itemColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: itemColor.withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.tune, size: 14, color: itemColor),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        _showTool ? 'Hide Interactive Calculator' : 'Open Interactive Calculator',
                        style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: itemColor),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Icon(_showTool ? Icons.expand_less : Icons.expand_more, size: 16, color: itemColor),
                  ],
                ),
              ),
            ),
            if (_showTool) ...[
              const SizedBox(height: 8),
              _buildToolWidget(item.interactiveTool!),
            ],
          ],

          const SizedBox(height: 8),

          // Bottom Action: Tap to Compare
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Text(
                'Compare 2014 vs 2024',
                style: TextStyle(
                  color: itemColor,
                  fontWeight: FontWeight.bold,
                  fontSize: 11.5,
                ),
              ),
              const SizedBox(width: 4),
              Icon(Icons.compare_arrows, color: itemColor, size: 14),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildToolWidget(String toolId) {
    return switch (toolId) {
      'concentration' => const ConcentrationCalculatorWidget(),
      'falling' => const FallingDamageCalculatorWidget(),
      'grapple_shove' => const GrappleShoveCalculatorWidget(),
      'dc_benchmark' => const DcBenchmarkSelectorWidget(),
      _ => const SizedBox.shrink(),
    };
  }

  Widget _buildHighlightedText({
    required String text,
    required String query,
    required TextStyle style,
    required Color highlightColor,
  }) {
    final trimmed = query.trim().toLowerCase();
    final terms = trimmed
        .split(RegExp(r'\s+'))
        .where((t) => t.isNotEmpty && !t.contains(':'))
        .toList();

    if (terms.isEmpty) {
      return Text(text, style: style);
    }

    final lowerText = text.toLowerCase();
    final spans = <TextSpan>[];
    int start = 0;

    while (start < text.length) {
      int nextMatchIndex = -1;
      String nextMatchedTerm = '';

      for (final term in terms) {
        final idx = lowerText.indexOf(term, start);
        if (idx != -1 && (nextMatchIndex == -1 || idx < nextMatchIndex)) {
          nextMatchIndex = idx;
          nextMatchedTerm = term;
        }
      }

      if (nextMatchIndex == -1) {
        spans.add(TextSpan(text: text.substring(start), style: style));
        break;
      }

      if (nextMatchIndex > start) {
        spans.add(TextSpan(text: text.substring(start, nextMatchIndex), style: style));
      }

      final matchEnd = nextMatchIndex + nextMatchedTerm.length;
      spans.add(
        TextSpan(
          text: text.substring(nextMatchIndex, matchEnd),
          style: style.copyWith(
            backgroundColor: highlightColor,
            fontWeight: FontWeight.w900,
          ),
        ),
      );

      start = matchEnd;
    }

    return Text.rich(
      TextSpan(children: spans),
      style: style,
    );
  }
}
