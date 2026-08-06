import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/dice_room_service.dart';

class RoomBannerWidget extends StatelessWidget {
  final String? activeRoomCode;
  final String? playerName;
  final Function(String roomCode, String playerName) onJoinRoom;
  final VoidCallback onLeaveRoom;

  const RoomBannerWidget({
    super.key,
    required this.activeRoomCode,
    required this.playerName,
    required this.onJoinRoom,
    required this.onLeaveRoom,
  });

  void _showJoinCreateRoomDialog(BuildContext context) {
    final nameController = TextEditingController(text: playerName ?? '');
    final roomController = TextEditingController(text: activeRoomCode ?? '');
    final DiceRoomService roomService = DiceRoomService();

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: const Color(0xFF1E1B2E),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: const Row(
                children: [
                  Icon(Icons.hub, color: Colors.cyanAccent),
                  SizedBox(width: 10),
                  Text('Shared Dice Room', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Join or create a live shared dice room to see everyone\'s rolls in real time.',
                    style: TextStyle(color: Colors.white70, fontSize: 13),
                  ),
                  const SizedBox(height: 16),

                  // Player Name Input
                  TextField(
                    controller: nameController,
                    autofocus: playerName == null || playerName!.isEmpty,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      labelText: 'Your Display Name',
                      labelStyle: const TextStyle(color: Colors.cyanAccent),
                      hintText: 'e.g. Gandalf, Gimli',
                      hintStyle: const TextStyle(color: Colors.white30),
                      filled: true,
                      fillColor: Colors.black26,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Room Code Input with Generator
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: roomController,
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                          textCapitalization: TextCapitalization.characters,
                          decoration: InputDecoration(
                            labelText: 'Room Code',
                            labelStyle: const TextStyle(color: Colors.cyanAccent),
                            hintText: 'e.g. ROOM-A82F',
                            hintStyle: const TextStyle(color: Colors.white30),
                            filled: true,
                            fillColor: Colors.black26,
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.cyanAccent.withValues(alpha: 0.2),
                          foregroundColor: Colors.cyanAccent,
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 16),
                        ),
                        onPressed: () {
                          setDialogState(() {
                            roomController.text = roomService.generateRoomCode();
                          });
                        },
                        child: const Column(
                          children: [
                            Icon(Icons.autorenew, size: 18),
                            Text('New', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Cancel', style: TextStyle(color: Colors.white54)),
                ),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.cyanAccent,
                    foregroundColor: Colors.black,
                  ),
                  onPressed: () {
                    final name = nameController.text.trim();
                    final room = roomController.text.trim();
                    if (name.isNotEmpty && room.isNotEmpty) {
                      onJoinRoom(room, name);
                      Navigator.pop(ctx);
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Please enter both your name and a room code.'),
                          backgroundColor: Colors.redAccent,
                        ),
                      );
                    }
                  },
                  icon: const Icon(Icons.meeting_room, size: 18),
                  label: const Text('Enter Room', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool isConnected = activeRoomCode != null && activeRoomCode!.isNotEmpty;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: isConnected ? Colors.cyanAccent.withValues(alpha: 0.1) : const Color(0xFF1E1B2E),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isConnected ? Colors.cyanAccent.withValues(alpha: 0.5) : Colors.white12,
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Icon(
                isConnected ? Icons.sensors : Icons.sensors_off,
                color: isConnected ? Colors.cyanAccent : Colors.white38,
                size: 22,
              ),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isConnected ? activeRoomCode! : 'Solo Mode',
                    style: TextStyle(
                      color: isConnected ? Colors.cyanAccent : Colors.white70,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                  Text(
                    isConnected ? 'Player: $playerName' : 'Not connected to a live room',
                    style: const TextStyle(color: Colors.white54, fontSize: 12),
                  ),
                ],
              ),
            ],
          ),
          Row(
            children: [
              if (isConnected) ...[
                IconButton(
                  icon: const Icon(Icons.copy, color: Colors.cyanAccent, size: 18),
                  tooltip: 'Copy Room Code',
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: activeRoomCode!));
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Copied "$activeRoomCode" to clipboard!'),
                        duration: const Duration(seconds: 2),
                      ),
                    );
                  },
                ),
                TextButton(
                  onPressed: onLeaveRoom,
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
                  onPressed: () => _showJoinCreateRoomDialog(context),
                  icon: const Icon(Icons.hub, size: 16),
                  label: const Text('Join / Create Room', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
