import 'package:dangerously_nerdy_5e_toolkit/theme/domain_ui_extensions.dart';
import 'package:flutter/material.dart';
import '../../models/dm_screen_data.dart';
import '../../screens/table_index_screen.dart';
import '../../services/haptic_service.dart';
import '../common/edition_diff_badge.dart';
import '../common/formatted_markdown_text.dart';
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

    final diffColor = isDark ? Colors.amber : const Color(0xFFB45309);
    final itemColor = item.category.getLegibleColor(isDark);
    final activeRules = item.getRules(edition);
    final cost = item.getCost(edition);
    final isRollable = (item.linkedTableTabIndex != null ||
            item.linkedTableQuery != null ||
            item.subCategory == 'Rollable Tables' ||
            (item.category == DmCategory.tables && item.subCategory != 'Data & Reference Tables')) &&
        item.subCategory != 'Data & Reference Tables';

    return PressableCard(
      onTap: widget.onTap,
      padding: const EdgeInsets.all(14),
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
                    Wrap(
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: 6,
                      runSpacing: 4,
                      children: [
                        Text(
                          item.category == DmCategory.tables && item.subCategory != null
                              ? item.subCategory!
                              : (item.subCategory != null ? '${item.category.label} • ${item.subCategory}' : item.category.label),
                          style: TextStyle(
                            color: theme.colorScheme.onSurfaceVariant,
                            fontSize: 11,
                          ),
                        ),
                        if (cost != null)
                          Text(
                            '• $cost',
                            style: TextStyle(
                              color: itemColor,
                              fontWeight: FontWeight.w600,
                              fontSize: 11,
                            ),
                          ),
                        if (item.category == DmCategory.tables && item.subCategory != null)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: item.subCategory == 'Rollable Tables'
                                  ? const Color(0xFFF59E0B).withValues(alpha: 0.15)
                                  : Colors.tealAccent.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(
                                color: item.subCategory == 'Rollable Tables'
                                    ? const Color(0xFFF59E0B).withValues(alpha: 0.4)
                                    : Colors.tealAccent.withValues(alpha: 0.4),
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  item.subCategory == 'Rollable Tables' ? Icons.casino_outlined : Icons.view_list,
                                  size: 11,
                                  color: item.subCategory == 'Rollable Tables' ? const Color(0xFFF59E0B) : Colors.tealAccent,
                                ),
                                const SizedBox(width: 3),
                                Text(
                                  item.subCategory == 'Rollable Tables' ? 'Rollable' : 'Data Table',
                                  style: TextStyle(
                                    color: item.subCategory == 'Rollable Tables' ? const Color(0xFFF59E0B) : Colors.tealAccent,
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        if (item.isHomebrew)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.pinkAccent.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: Colors.pinkAccent.withValues(alpha: 0.4)),
                            ),
                            child: const Text(
                              'Homebrew',
                              style: TextStyle(
                                color: Colors.pinkAccent,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        if (item.isChangedIn2024)
                          const EditionDiffBadge(),
                      ],
                    ),
                  ],
                ),
              ),
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

          // Formatted Rule Content (supports tables, headings, and bullet points)
          ..._buildRuleContent(activeRules, theme, itemColor, diffColor),

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

          // Linked Table Roller Button (only for Rollable Tables)
          if (isRollable) ...[
            const SizedBox(height: 6),
            InkWell(
                onTap: () {
                  HapticService.selectionTick(context);
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => TableIndexScreen(
                        initialTabIndex: item.linkedTableTabIndex ?? 1,
                        initialSearchQuery: item.linkedTableQuery ?? item.title,
                      ),
                    ),
                  );
                },
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF59E0B).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFF59E0B).withValues(alpha: 0.4)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.table_chart, size: 14, color: Color(0xFFF59E0B)),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          item.linkedTableLabel ?? (item.subCategory == 'Rollable Tables' ? 'Roll on Table' : 'Open in Table Roller'),
                          style: const TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFFF59E0B),
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const Icon(Icons.arrow_forward_ios, size: 11, color: Color(0xFFF59E0B)),
                    ],
                  ),
                ),
            ),
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

  List<Widget> _buildRuleContent(
    List<String> rules,
    ThemeData theme,
    Color itemColor,
    Color diffColor,
  ) {
    final widgets = <Widget>[];
    int i = 0;
    while (i < rules.length) {
      final rule = rules[i].trim();
      if (rule.isEmpty) {
        i++;
        continue;
      }

      // Check if this starts a markdown table block
      if (rule.startsWith('|')) {
        final tableLines = <String>[];
        while (i < rules.length && rules[i].trim().startsWith('|')) {
          tableLines.add(rules[i].trim());
          i++;
        }
        final tableMarkdown = tableLines.join('\n');
        widgets.add(
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: FormattedMarkdownText(
              tableMarkdown,
              style: TextStyle(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.9),
                fontSize: 12.5,
                height: 1.35,
              ),
              boldColor: itemColor,
            ),
          ),
        );
      } else if (rule.startsWith('#')) {
        widgets.add(
          Padding(
            padding: const EdgeInsets.only(bottom: 4, top: 4),
            child: FormattedMarkdownText(
              rule,
              style: TextStyle(
                color: theme.colorScheme.onSurface,
                fontSize: 13,
                fontWeight: FontWeight.bold,
              ),
              boldColor: itemColor,
            ),
          ),
        );
        i++;
      } else {
        widgets.add(
          Padding(
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
          ),
        );
        i++;
      }
    }
    return widgets;
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
