import 'package:flutter/material.dart';
import '../../models/dice_roll.dart';
import '../../models/room_roll.dart';
import '../../services/dice_room_service.dart';

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
          return _buildLocalRollHistory();
        }
        return const SizedBox.shrink();
      },
    );
  }

  Widget _buildLocalRollHistory() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Roll History',
              style: TextStyle(
                  color: Colors.white70,
                  fontWeight: FontWeight.bold,
                  fontSize: 14),
            ),
            Text(
              '${localHistory.length} rolls',
              style: const TextStyle(color: Colors.white38, fontSize: 12),
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
                color: const Color(0xFF1E1B2E),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.formulaString,
                        style: const TextStyle(
                            color: Colors.cyanAccent,
                            fontWeight: FontWeight.bold,
                            fontSize: 14),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Rolls: ${item.individualRolls.join(', ')}${item.droppedRolls != null ? ' (dropped ${item.droppedRolls!.join(', ')})' : ''}',
                        style: const TextStyle(
                            color: Colors.white60, fontSize: 12),
                      ),
                    ],
                  ),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: item.isCrit
                          ? Colors.amber.withValues(alpha: 0.2)
                          : item.isFumble
                              ? Colors.redAccent.withValues(alpha: 0.2)
                              : Colors.black26,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: item.isCrit
                            ? Colors.amber
                            : item.isFumble
                                ? Colors.redAccent
                                : Colors.white12,
                      ),
                    ),
                    child: Text(
                      '${item.total}',
                      style: TextStyle(
                        color: item.isCrit
                            ? Colors.amber
                            : item.isFumble
                                ? Colors.redAccent
                                : Colors.white,
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

            final roomRolls = snapshot.data ?? [];

            if (roomRolls.isEmpty) {
              return Container(
                padding: const EdgeInsets.all(20),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: const Color(0xFF1E1B2E),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.white12),
                ),
                child: const Text(
                  'No rolls in this room yet. Tap ROLL to broadcast first roll!',
                  style: TextStyle(color: Colors.white54, fontSize: 14),
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
                        ? const Color(0xFF23203E)
                        : const Color(0xFF1E1B2E),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: isSelf
                          ? Colors.cyanAccent.withValues(alpha: 0.3)
                          : Colors.white.withValues(alpha: 0.05),
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
                                      ? Colors.cyanAccent
                                      : Colors.purpleAccent,
                                  child: Text(
                                    item.playerName.isNotEmpty
                                        ? item.playerName[0].toUpperCase()
                                        : '?',
                                    style: const TextStyle(
                                        color: Colors.black,
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
                                                  ? Colors.cyanAccent
                                                  : Colors.amber,
                                              fontWeight: FontWeight.bold,
                                              fontSize: 13,
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          Flexible(
                                            child: Text(
                                              item.formulaString,
                                              style: const TextStyle(
                                                  color: Colors.white70, fontSize: 13),
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
                                              style: const TextStyle(
                                                  color: Colors.white54, fontSize: 12),
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
                                                      color: Colors.cyanAccent,
                                                    ),
                                                    const SizedBox(width: 2),
                                                    Text(
                                                      isExpanded ? 'Hide' : 'Papertrail (${item.details!.length})',
                                                      style: const TextStyle(
                                                        color: Colors.cyanAccent,
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
                                  ? Colors.amber.withValues(alpha: 0.2)
                                  : item.isFumble
                                      ? Colors.redAccent.withValues(alpha: 0.2)
                                      : Colors.black26,
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(
                                color: item.isCrit
                                    ? Colors.amber
                                    : item.isFumble
                                        ? Colors.redAccent
                                        : Colors.white12,
                              ),
                            ),
                            child: Text(
                              '${item.total}',
                              style: TextStyle(
                                color: item.isCrit
                                  ? Colors.amber
                                  : item.isFumble
                                      ? Colors.redAccent
                                      : Colors.white,
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
                            color: const Color(0xFF141224),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: Colors.white12),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Row(
                                children: [
                                  Icon(Icons.history_edu, size: 14, color: Colors.cyanAccent),
                                  SizedBox(width: 6),
                                  Text(
                                    'To-Hit & Damage Papertrail:',
                                    style: TextStyle(
                                      color: Colors.cyanAccent,
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
                                    style: const TextStyle(
                                      color: Colors.white70,
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
