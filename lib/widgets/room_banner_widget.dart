import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/dice_room_service.dart';
import '../theme/app_theme.dart';
import 'dialogs/join_create_room_dialog.dart';

class RoomBannerWidget extends StatelessWidget {
  final DiceRoomService roomService;
  final String? activeRoomCode;
  final String? playerName;
  final bool compact;
  final Function(String roomCode, String playerName)? onJoinRoom;
  final VoidCallback? onLeaveRoom;

  RoomBannerWidget({
    super.key,
    DiceRoomService? roomService,
    this.activeRoomCode,
    this.playerName,
    this.compact = false,
    this.onJoinRoom,
    this.onLeaveRoom,
  }) : roomService = roomService ?? DiceRoomService();

  void _showJoinCreateRoomDialog(BuildContext context, String? currentName, String? currentRoom) {
    JoinCreateRoomDialog.show(
      context,
      initialPlayerName: currentName,
      initialRoomCode: currentRoom,
      onJoinRoom: (code, name) {
        roomService.joinRoom(code, name);
        onJoinRoom?.call(code, name);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final primary = theme.colorScheme.primary;
    final tabletop = theme.extension<TabletopColors>() ?? (isDark ? TabletopColors.dark : TabletopColors.light);

    return ValueListenableBuilder<RoomSession?>(
      valueListenable: roomService.activeSessionNotifier,
      builder: (context, session, _) {
        final String? effectiveRoom = activeRoomCode ?? session?.roomCode;
        final String? effectiveName = playerName ?? session?.playerName;
        final bool isConnected = effectiveRoom != null && effectiveRoom.isNotEmpty;
        final String roomCode = effectiveRoom ?? '';
        final bool isRemembered = session?.isRemembered ?? false;

        return Container(
          padding: EdgeInsets.symmetric(
            horizontal: compact ? 10 : 14,
            vertical: compact ? 6 : 9,
          ),
          decoration: BoxDecoration(
            color: isConnected
                ? primary.withValues(alpha: isDark ? 0.12 : 0.08)
                : tabletop.cardBackground,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isConnected
                  ? primary.withValues(alpha: 0.45)
                  : tabletop.cardBorder.withValues(alpha: 0.6),
            ),
          ),
          child: Row(
            children: [
              Icon(
                isConnected ? Icons.sensors : Icons.sensors_off,
                color: isConnected ? primary : theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
                size: compact ? 18 : 20,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Flexible(
                          child: Text(
                            isConnected ? roomCode : 'Solo Mode',
                            style: TextStyle(
                              color: isConnected ? primary : theme.colorScheme.onSurface,
                              fontWeight: FontWeight.bold,
                              fontSize: compact ? 13 : 13.5,
                              letterSpacing: 0.3,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (isConnected && isRemembered) ...[
                          const SizedBox(width: 6),
                          Tooltip(
                            message: 'Room saved across visits until you leave',
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                              decoration: BoxDecoration(
                                color: primary.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(color: primary.withValues(alpha: 0.3)),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.bookmark_added, color: primary, size: 10),
                                  const SizedBox(width: 2),
                                  Text(
                                    'Saved',
                                    style: TextStyle(
                                      color: primary,
                                      fontSize: 9,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    Text(
                      isConnected
                          ? 'Broadcasting as ${effectiveName ?? "Anonymous"}'
                          : 'Not connected to a live room',
                      style: TextStyle(
                        color: theme.colorScheme.onSurfaceVariant,
                        fontSize: compact ? 11 : 11.5,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              if (isConnected) ...[
                IconButton(
                  icon: Icon(Icons.copy, color: primary, size: 17),
                  tooltip: 'Copy Room Code',
                  visualDensity: VisualDensity.compact,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: roomCode));
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Copied "$roomCode" to clipboard!'),
                        duration: const Duration(seconds: 2),
                      ),
                    );
                  },
                ),
                TextButton(
                  style: TextButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    minimumSize: Size.zero,
                  ),
                  onPressed: () {
                    roomService.leaveRoom();
                    onLeaveRoom?.call();
                  },
                  child: Text(
                    'Leave',
                    style: TextStyle(
                      color: tabletop.fumbleRed,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ] else
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primary.withValues(alpha: 0.15),
                    foregroundColor: primary,
                    elevation: 0,
                    visualDensity: VisualDensity.compact,
                    padding: EdgeInsets.symmetric(
                      horizontal: compact ? 8 : 10,
                      vertical: compact ? 4 : 6,
                    ),
                    minimumSize: Size.zero,
                  ),
                  onPressed: () => _showJoinCreateRoomDialog(context, effectiveName, effectiveRoom),
                  icon: Icon(Icons.hub, size: compact ? 13 : 14),
                  label: Text(
                    'Join Room',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: compact ? 11 : 11.5,
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}
