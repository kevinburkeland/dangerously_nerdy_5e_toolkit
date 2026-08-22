import 'package:flutter/material.dart';
import '../../models/arena/arena_action_result.dart';

/// Scrollable and filterable combat log feed detailing each turn and attack event.
class ArenaCombatLogView extends StatefulWidget {
  final List<ArenaTurnStep> steps;

  const ArenaCombatLogView({
    super.key,
    required this.steps,
  });

  @override
  State<ArenaCombatLogView> createState() => _ArenaCombatLogViewState();
}

class _ArenaCombatLogViewState extends State<ArenaCombatLogView> {
  final ScrollController _scrollController = ScrollController();
  bool _autoScroll = true;

  @override
  void didUpdateWidget(ArenaCombatLogView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_autoScroll && widget.steps.length != oldWidget.steps.length) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scrollController.hasClients) {
          _scrollController.animateTo(
            _scrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOut,
          );
        }
      });
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    if (widget.steps.isEmpty) {
      return Container(
        height: 120,
        alignment: Center(
          child: Text(
            'Combat log will record attacks, dice rolls, and damage here.',
            style: TextStyle(
              fontSize: 12,
              color: isDark ? Colors.white38 : Colors.black38,
            ),
          ),
        ).alignment,
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF13151F) : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? const Color(0xFF2A2E3D) : const Color(0xFFE2E8F0),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 6),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(Icons.history_edu, size: 16, color: Colors.purpleAccent),
                    const SizedBox(width: 6),
                    Text(
                      'COMBAT ACTION LOG (${widget.steps.length} turns)',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5,
                        color: Colors.purpleAccent,
                      ),
                    ),
                  ],
                ),
                InkWell(
                  onTap: () => setState(() => _autoScroll = !_autoScroll),
                  child: Row(
                    children: [
                      Icon(
                        _autoScroll ? Icons.check_box : Icons.check_box_outline_blank,
                        size: 14,
                        color: _autoScroll ? Colors.purpleAccent : Colors.grey,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Auto-scroll',
                        style: TextStyle(
                          fontSize: 10,
                          color: _autoScroll ? Colors.purpleAccent : Colors.grey,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),

          // Log List
          SizedBox(
            height: 180,
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              itemCount: widget.steps.length,
              itemBuilder: (context, index) {
                final step = widget.steps[index];
                return _buildStepEntry(context, step, isDark);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStepEntry(BuildContext context, ArenaTurnStep step, bool isDark) {
    final teamColor = step.activeCombatant.team.color;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Turn Header Line
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E2230) : const Color(0xFFE2E8F0),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  'R${step.roundNumber}',
                  style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  step.activeCombatant.displayName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: teamColor,
                  ),
                ),
              ),
              if (step.specialEventSummary != null) ...[
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    step.specialEventSummary!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 10,
                      color: Colors.amberAccent,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ),
              ],
            ],
          ),

          // Attack Events within this turn
          ...step.attackEvents.map((evt) => Padding(
                padding: const EdgeInsets.only(left: 12, top: 2),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      evt.evadedWithEvasion
                          ? Icons.bolt
                          : (evt.isSavingThrow
                              ? (evt.saved ? Icons.shield_outlined : (evt.isKillShot ? Icons.dangerous : Icons.whatshot))
                              : (evt.isCrit
                                  ? Icons.star
                                  : (evt.isKillShot
                                      ? Icons.dangerous
                                      : (evt.isHit ? Icons.arrow_right : Icons.close)))),
                      size: 14,
                      color: evt.evadedWithEvasion || evt.isCrit
                          ? const Color(0xFFFFD700)
                          : (evt.isKillShot
                              ? Colors.redAccent
                              : (evt.isSavingThrow
                                  ? (evt.saved ? Colors.blueAccent : Colors.deepOrangeAccent)
                                  : (evt.isHit ? const Color(0xFF10B981) : Colors.grey))),
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: RichText(
                        text: TextSpan(
                          style: TextStyle(
                            fontSize: 11,
                            color: isDark ? Colors.white70 : Colors.black87,
                          ),
                          children: [
                            TextSpan(
                              text: '${evt.attackName} vs ',
                              style: const TextStyle(fontWeight: FontWeight.w600),
                            ),
                            TextSpan(
                              text: '${evt.defenderName}: ',
                              style: TextStyle(
                                color: evt.defenderTeam.color,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            TextSpan(
                              text: evt.summaryText,
                              style: TextStyle(
                                color: evt.isCrit
                                    ? const Color(0xFFFFD700)
                                    : (evt.isKillShot
                                        ? Colors.redAccent
                                        : (evt.isHit
                                            ? (isDark ? Colors.white : Colors.black87)
                                            : Colors.grey)),
                                fontWeight: evt.isCrit || evt.isKillShot
                                    ? FontWeight.bold
                                    : FontWeight.normal,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              )),
        ],
      ),
    );
  }
}
