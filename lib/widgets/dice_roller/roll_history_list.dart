import 'package:flutter/material.dart';
import '../../models/dice_roll.dart';
import '../../models/room_roll.dart';
import '../../services/dice_room_service.dart';
import '../../theme/app_theme.dart';

class RollHistoryList extends StatelessWidget {
  final List<DiceRollResult> localHistory;
  final String? activeRoomCode;
  final String? playerName;
  final DiceRoomService roomService;

  RollHistoryList({
    super.key,
    required this.localHistory,
    this.activeRoomCode,
    this.playerName,
    DiceRoomService? roomService,
  }) : roomService = roomService ?? DiceRoomService();

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<RoomSession?>(
      valueListenable: roomService.activeSessionNotifier,
      builder: (context, session, _) {
        final effectiveRoomCode = activeRoomCode ?? session?.roomCode ?? roomService.activeRoomCode;
        final effectivePlayerName = playerName ?? session?.playerName ?? roomService.playerName;

        if (effectiveRoomCode != null && effectiveRoomCode.isNotEmpty) {
          return LiveRoomRollFeed(
            roomCode: effectiveRoomCode,
            playerName: effectivePlayerName,
            roomService: roomService,
          );
        } else if (localHistory.isNotEmpty) {
          return _buildLocalRollHistory(context);
        }
        return const SizedBox.shrink();
      },
    );
  }

  Widget _buildLocalRollHistory(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final tabletop = theme.extension<TabletopColors>() ?? (isDark ? TabletopColors.dark : TabletopColors.light);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Roll History',
              style: TextStyle(
                  color: theme.colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.bold,
                  fontSize: 14),
            ),
            Text(
              '${localHistory.length} rolls',
              style: TextStyle(color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.6), fontSize: 12),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: localHistory.length,
          itemBuilder: (context, index) {
            final item = localHistory[index];
            return Container(
              key: ValueKey('local_roll_${item.timestamp.microsecondsSinceEpoch}_$index'),
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: tabletop.cardBackground,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: tabletop.cardBorder),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.formulaString,
                        style: TextStyle(
                            color: isDark ? Colors.cyanAccent : theme.colorScheme.primary,
                            fontWeight: FontWeight.bold,
                            fontSize: 14),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Rolls: ${item.individualRolls.join(', ')}${item.droppedRolls != null ? ' (dropped ${item.droppedRolls!.join(', ')})' : ''}',
                        style: TextStyle(
                            color: theme.colorScheme.onSurfaceVariant, fontSize: 12),
                      ),
                    ],
                  ),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: item.isCrit
                          ? tabletop.critGold.withValues(alpha: 0.2)
                          : item.isFumble
                              ? tabletop.fumbleRed.withValues(alpha: 0.2)
                              : (isDark ? Colors.black26 : theme.colorScheme.surfaceContainerHighest),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: item.isCrit
                            ? tabletop.critGold
                            : item.isFumble
                                ? tabletop.fumbleRed
                                : theme.colorScheme.outlineVariant.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Text(
                      '${item.total}',
                      style: TextStyle(
                        color: item.isCrit
                            ? tabletop.critGold
                            : item.isFumble
                                ? tabletop.fumbleRed
                                : theme.colorScheme.onSurface,
                        fontWeight: FontWeight.w900,
                        fontSize: 16,
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ],
    );
  }
}

class LiveRoomRollFeed extends StatefulWidget {
  final String roomCode;
  final String? playerName;
  final DiceRoomService roomService;

  const LiveRoomRollFeed({
    super.key,
    required this.roomCode,
    required this.playerName,
    required this.roomService,
  });

  @override
  State<LiveRoomRollFeed> createState() => _LiveRoomRollFeedState();
}

class _LiveRoomRollFeedState extends State<LiveRoomRollFeed> {
  late Stream<List<RoomRoll>> _rollStream;
  final Set<String> _expandedRollIds = {};

  @override
  void initState() {
    super.initState();
    _rollStream = widget.roomService.streamRoomRolls(widget.roomCode);
  }

  @override
  void didUpdateWidget(covariant LiveRoomRollFeed oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.roomCode != widget.roomCode || oldWidget.roomService != widget.roomService) {
      _rollStream = widget.roomService.streamRoomRolls(widget.roomCode);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                const Icon(Icons.sensors, color: Colors.cyanAccent, size: 18),
                const SizedBox(width: 6),
                Text(
                  'Live Feed: ${widget.roomCode}',
                  style: const TextStyle(
                      color: Colors.cyanAccent,
                      fontWeight: FontWeight.bold,
                      fontSize: 14),
                ),
              ],
            ),
            const Text(
              'Real-Time Sync',
              style: TextStyle(color: Colors.white38, fontSize: 12),
            ),
          ],
        ),
        const SizedBox(height: 8),
        StreamBuilder<List<RoomRoll>>(
          stream: _rollStream,
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return Container(
                padding: const EdgeInsets.all(16),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: Colors.redAccent.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.redAccent.withValues(alpha: 0.3)),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.sync_problem, color: Colors.redAccent, size: 20),
                    SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        'Live room feed unavailable. Check network or room connection.',
                        style: TextStyle(color: Colors.white70, fontSize: 13),
                      ),
                    ),
                  ],
                ),
              );
            }

            if (snapshot.connectionState == ConnectionState.waiting &&
                !snapshot.hasData) {
              return const Padding(
                padding: EdgeInsets.all(20.0),
                child: Center(
                    child: CircularProgressIndicator(color: Colors.cyanAccent)),
              );
            }

            final theme = Theme.of(context);
            final isDark = theme.brightness == Brightness.dark;
            final tabletop = theme.extension<TabletopColors>() ?? (isDark ? TabletopColors.dark : TabletopColors.light);
            final primary = theme.colorScheme.primary;
            final secondary = theme.colorScheme.secondary;

            final roomRolls = snapshot.data ?? [];

            if (roomRolls.isEmpty) {
              return Container(
                padding: const EdgeInsets.all(20),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: tabletop.cardBackground,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: tabletop.cardBorder),
                ),
                child: Text(
                  'No rolls in this room yet. Tap ROLL to broadcast first roll!',
                  style: TextStyle(color: theme.colorScheme.onSurfaceVariant, fontSize: 14),
                ),
              );
            }

            return ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: roomRolls.length,
              itemBuilder: (context, index) {
                final item = roomRolls[index];
                final bool isSelf = item.playerName == (widget.roomService.playerName ?? widget.playerName);
                final bool hasDetails = item.details != null && item.details!.isNotEmpty;
                final bool isExpanded = _expandedRollIds.contains(item.id);

                return Container(
                  key: ValueKey('room_roll_${item.id}_$index'),
                  margin: const EdgeInsets.only(bottom: 8),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: isSelf
                        ? (isDark ? const Color(0xFF23203E) : theme.colorScheme.surfaceContainerHighest)
                        : tabletop.cardBackground,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: isSelf
                          ? primary.withValues(alpha: 0.5)
                          : tabletop.cardBorder,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Row(
                              children: [
                                CircleAvatar(
                                  radius: 14,
                                  backgroundColor: isSelf
                                      ? primary
                                      : secondary,
                                  child: Text(
                                    item.playerName.isNotEmpty
                                        ? item.playerName[0].toUpperCase()
                                        : '?',
                                    style: TextStyle(
                                        color: isSelf ? theme.colorScheme.onPrimary : theme.colorScheme.onSecondary,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 12),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Text(
                                            item.playerName,
                                            style: TextStyle(
                                              color: isSelf
                                                  ? primary
                                                  : (isDark ? Colors.amber : const Color(0xFFB45309)),
                                              fontWeight: FontWeight.bold,
                                              fontSize: 13,
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          Flexible(
                                            child: Text(
                                              item.formulaString,
                                              style: TextStyle(
                                                  color: theme.colorScheme.onSurface, fontSize: 13),
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 2),
                                      Row(
                                        children: [
                                          Expanded(
                                            child: Text(
                                              'Rolls: ${item.individualRolls.join(', ')}${item.droppedRolls != null ? ' (dropped ${item.droppedRolls!.join(', ')})' : ''}',
                                              style: TextStyle(
                                                  color: theme.colorScheme.onSurfaceVariant, fontSize: 12),
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                          if (hasDetails)
                                            InkWell(
                                              onTap: () {
                                                setState(() {
                                                  if (isExpanded) {
                                                    _expandedRollIds.remove(item.id);
                                                  } else {
                                                    _expandedRollIds.add(item.id);
                                                  }
                                                });
                                              },
                                              borderRadius: BorderRadius.circular(4),
                                              child: Padding(
                                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                child: Row(
                                                  mainAxisSize: MainAxisSize.min,
                                                  children: [
                                                    Icon(
                                                      isExpanded ? Icons.expand_less : Icons.expand_more,
                                                      size: 14,
                                                      color: primary,
                                                    ),
                                                    const SizedBox(width: 2),
                                                    Text(
                                                      isExpanded ? 'Hide' : 'Papertrail (${item.details!.length})',
                                                      style: TextStyle(
                                                        color: primary,
                                                        fontSize: 11,
                                                        fontWeight: FontWeight.w600,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: item.isCrit
                                  ? tabletop.critGold.withValues(alpha: 0.2)
                                  : item.isFumble
                                      ? tabletop.fumbleRed.withValues(alpha: 0.2)
                                      : (isDark ? Colors.black26 : theme.colorScheme.surfaceContainerHighest),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(
                                color: item.isCrit
                                    ? tabletop.critGold
                                    : item.isFumble
                                        ? tabletop.fumbleRed
                                        : theme.colorScheme.outlineVariant.withValues(alpha: 0.3),
                              ),
                            ),
                            child: Text(
                              '${item.total}',
                              style: TextStyle(
                                color: item.isCrit
                                  ? tabletop.critGold
                                  : item.isFumble
                                      ? tabletop.fumbleRed
                                      : theme.colorScheme.onSurface,
                                fontWeight: FontWeight.w900,
                                fontSize: 16,
                              ),
                            ),
                          ),
                        ],
                      ),
                      if (isExpanded && hasDetails) ...[
                        const SizedBox(height: 8),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: isDark ? const Color(0xFF141224) : theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: theme.colorScheme.outlineVariant.withValues(alpha: 0.2)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(Icons.history_edu, size: 14, color: primary),
                                  const SizedBox(width: 6),
                                  Text(
                                    'To-Hit & Damage Papertrail:',
                                    style: TextStyle(
                                      color: primary,
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              ...item.details!.map(
                                (line) => Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 2),
                                  child: Text(
                                    '• $line',
                                    style: TextStyle(
                                      color: theme.colorScheme.onSurface.withValues(alpha: 0.85),
                                      fontSize: 11,
                                      fontFamily: 'monospace',
                                      height: 1.3,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                );
              },
            );
          },
        ),
      ],
    );
  }
}
