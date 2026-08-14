import 'package:flutter/material.dart';
import '../../services/dice_room_service.dart';

class JoinCreateRoomDialog extends StatefulWidget {
  final String? initialPlayerName;
  final String? initialRoomCode;
  final Function(String roomCode, String playerName)? onJoinRoom;

  const JoinCreateRoomDialog({
    super.key,
    this.initialPlayerName,
    this.initialRoomCode,
    this.onJoinRoom,
  });

  static Future<void> show(
    BuildContext context, {
    String? initialPlayerName,
    String? initialRoomCode,
    Function(String roomCode, String playerName)? onJoinRoom,
  }) {
    return showDialog<void>(
      context: context,
      builder: (ctx) => JoinCreateRoomDialog(
        initialPlayerName: initialPlayerName,
        initialRoomCode: initialRoomCode,
        onJoinRoom: onJoinRoom,
      ),
    );
  }

  @override
  State<JoinCreateRoomDialog> createState() => _JoinCreateRoomDialogState();
}

class _JoinCreateRoomDialogState extends State<JoinCreateRoomDialog> {
  late final TextEditingController _nameController;
  late final TextEditingController _roomController;
  final DiceRoomService _roomService = DiceRoomService();

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.initialPlayerName ?? '');
    _roomController = TextEditingController(text: widget.initialRoomCode ?? '');
  }

  @override
  void dispose() {
    _nameController.dispose();
    _roomController.dispose();
    super.dispose();
  }

  void _submit() {
    final name = _nameController.text.trim();
    final room = _roomController.text.trim();
    if (name.isNotEmpty && room.isNotEmpty) {
      DiceRoomService().joinRoom(room, name);
      widget.onJoinRoom?.call(room, name);
      Navigator.pop(context);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter both your name and a room code.'),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
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
            controller: _nameController,
            autofocus: widget.initialPlayerName == null || widget.initialPlayerName!.isEmpty,
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
                  controller: _roomController,
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
                  setState(() {
                    _roomController.text = _roomService.generateRoomCode();
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
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel', style: TextStyle(color: Colors.white54)),
        ),
        ElevatedButton.icon(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.cyanAccent,
            foregroundColor: Colors.black,
          ),
          onPressed: _submit,
          icon: const Icon(Icons.meeting_room, size: 18),
          label: const Text('Enter Room', style: TextStyle(fontWeight: FontWeight.bold)),
        ),
      ],
    );
  }
}
