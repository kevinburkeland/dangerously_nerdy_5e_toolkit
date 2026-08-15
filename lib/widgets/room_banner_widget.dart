import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/dice_room_service.dart';
import 'dialogs/join_create_room_dialog.dart';

class RoomBannerWidget extends StatelessWidget {
  final DiceRoomService roomService;
  final String? activeRoomCode;
  final String? playerName;
  final Function(String roomCode, String playerName)? onJoinRoom;
  final VoidCallback? onLeaveRoom;

  RoomBannerWidget({
    super.key,
    DiceRoomService? roomService,
    this.activeRoomCode,
    this.playerName,
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
    return ValueListenableBuilder<RoomSession?>(
      valueListenable: roomService.activeSessionNotifier,
      builder: (context, session, _) {
        final String? effectiveRoom = activeRoomCode ?? session?.roomCode;
        final String? effectiveName = playerName ?? session?.playerName;
        final bool isConnected = effectiveRoom != null && effectiveRoom.isNotEmpty;
        final String roomCode = effectiveRoom ?? '';

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: isConnected ? Colors.cyanAccent.withValues(alpha: 0.1) : const Color(0xFF1E1B2E),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isConnected ? Colors.cyanAccent.withValues(alpha: 0.5) : Colors.white12,
            ),
          ),
          child: Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 8,
            runSpacing: 8,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    isConnected ? Icons.sensors : Icons.sensors_off,
                    color: isConnected ? Colors.cyanAccent : Colors.white38,
                    size: 22,
                  ),
                  const SizedBox(width: 10),
                  Flexible(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          isConnected ? roomCode : 'Solo Mode',
                          style: TextStyle(
                            color: isConnected ? Colors.cyanAccent : Colors.white70,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          isConnected ? 'Player: ${effectiveName ?? "Anonymous"}' : 'Not connected to a live room',
                          style: const TextStyle(color: Colors.white54, fontSize: 12),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (isConnected) ...[
                    IconButton(
                      icon: const Icon(Icons.copy, color: Colors.cyanAccent, size: 18),
                      tooltip: 'Copy Room Code',
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
                      onPressed: () {
                        roomService.leaveRoom();
                        onLeaveRoom?.call();
                      },
                      child: const Text('Leave', style: TextStyle(color: Colors.redAccent, fontSize: 13)),
                    ),
                  ] else
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.cyanAccent.withValues(alpha: 0.2),
                        foregroundColor: Colors.cyanAccent,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      ),
                      onPressed: () => _showJoinCreateRoomDialog(context, effectiveName, effectiveRoom),
                      icon: const Icon(Icons.hub, size: 16),
                      label: const Text('Join / Create Room', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                    ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

