import 'package:flutter/material.dart';
import '../../models/tables/rollable_table.dart';
import '../../services/haptic_service.dart';

/// Interactive card component representing a rollable SRD table with dice rolls,
/// search term highlighting, and landed row highlighting.
class RollableTableCard extends StatefulWidget {
  final RollableTable table;
  final String searchQuery;
  final bool initiallyExpanded;

  const RollableTableCard({
    super.key,
    required this.table,
    this.searchQuery = '',
    this.initiallyExpanded = false,
  });

  @override
  State<RollableTableCard> createState() => _RollableTableCardState();
}

class _RollableTableCardState extends State<RollableTableCard> {
  TableRollResult? _lastResult;
  bool _isExpanded = false;

  @override
  void initState() {
    super.initState();
    _isExpanded = widget.initiallyExpanded || widget.searchQuery.isNotEmpty;
  }

  @override
  void didUpdateWidget(covariant RollableTableCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.searchQuery.isNotEmpty && !_isExpanded) {
      _isExpanded = true;
    }
  }

  void _rollTable() {
    HapticService.mediumImpact(context);
    setState(() {
      _lastResult = widget.table.roll();
      _isExpanded = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final table = widget.table;
    final catColor = table.category.accentColor;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 2),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E2230) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: _lastResult != null
              ? catColor.withAlpha(isDark ? 160 : 140)
              : (isDark ? const Color(0xFF2A2E3D) : const Color(0xFFE2E8F0)),
          width: _lastResult != null ? 1.5 : 1.0,
        ),
        boxShadow: [
          if (_lastResult != null)
            BoxShadow(
              color: catColor.withAlpha(isDark ? 30 : 20),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header / Tap to expand
          InkWell(
            onTap: () {
              HapticService.selectionTick(context);
              setState(() => _isExpanded = !_isExpanded);
            },
            borderRadius: BorderRadius.circular(16),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: catColor.withAlpha(isDark ? 30 : 20),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: catColor.withAlpha(80)),
                    ),
                    child: Icon(table.category.icon, color: catColor, size: 20),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          table.name,
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${table.diceFormula} • ${table.entries.length} entries',
                          style: TextStyle(
                            fontSize: 11,
                            color: isDark ? Colors.white60 : Colors.black54,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Dice Roll Button
                  ElevatedButton.icon(
                    icon: const Icon(Icons.casino_outlined, size: 16),
                    label: Text(table.diceFormula),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: catColor.withAlpha(35),
                      foregroundColor: catColor,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                        side: BorderSide(color: catColor.withAlpha(120)),
                      ),
                    ),
                    onPressed: _rollTable,
                  ),
                  const SizedBox(width: 4),
                  Icon(
                    _isExpanded ? Icons.expand_less : Icons.expand_more,
                    color: isDark ? Colors.white38 : Colors.black38,
                    size: 20,
                  ),
                ],
              ),
            ),
          ),

          // Last Roll Result Banner (if rolled)
          if (_lastResult != null)
            Container(
              margin: const EdgeInsets.fromLTRB(12, 0, 12, 10),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: catColor.withAlpha(isDark ? 30 : 20),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: catColor.withAlpha(120)),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: catColor,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      'Roll ${_lastResult!.rollValue}',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: Colors.black,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      _lastResult!.entry.label,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                    ),
                  ),
                ],
              ),
            ),

          // Expanded Entries Table
          if (_isExpanded) ...[
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
              child: Text(
                table.description,
                style: TextStyle(
                  fontSize: 11,
                  fontStyle: FontStyle.italic,
                  color: isDark ? Colors.white60 : Colors.black54,
                ),
              ),
            ),
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              itemCount: table.entries.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, idx) {
                final entry = table.entries[idx];
                final isLanded = _lastResult != null && entry.matchesRoll(_lastResult!.rollValue);

                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                  decoration: BoxDecoration(
                    color: isLanded
                        ? catColor.withAlpha(isDark ? 40 : 25)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(6),
                    border: isLanded
                        ? Border.all(color: catColor, width: 1)
                        : null,
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 48,
                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF13151F) : const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          entry.rangeDisplay,
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: isLanded ? catColor : (isDark ? Colors.white70 : Colors.black87),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              entry.label,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: isLanded ? FontWeight.bold : FontWeight.w600,
                                color: isLanded
                                    ? (isDark ? Colors.white : Colors.black)
                                    : (isDark ? Colors.white70 : Colors.black87),
                              ),
                            ),
                            if (entry.description != null)
                              Text(
                                entry.description!,
                                style: TextStyle(
                                  fontSize: 11,
                                  color: isDark ? Colors.white54 : Colors.black54,
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ],
        ],
      ),
    );
  }
}
