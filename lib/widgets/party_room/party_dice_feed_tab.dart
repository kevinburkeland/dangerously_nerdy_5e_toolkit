import 'package:material_ui/material_ui.dart';

import '../../models/room_roll.dart';
import '../../screens/dice_roller_screen.dart';
import '../../services/dice_room_service.dart';
import '../../theme/app_theme.dart';

/// Live Dice Feed tab in the Party Room Screen.
class PartyDiceFeedTab extends StatelessWidget {
  final TabletopColors tabletop;
  final bool isDark;
  final String roomCode;
  final Stream<List<RoomRoll>> rollStream;
  final DiceRoomService diceService;

  const PartyDiceFeedTab({
    super.key,
    required this.tabletop,
    required this.isDark,
    required this.roomCode,
    required this.rollStream,
    required this.diceService,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<RoomRoll>>(
      stream: rollStream,
      initialData: diceService.getCachedRolls(roomCode),
      builder: (context, snapshot) {
        final rolls = snapshot.data ?? [];

        if (rolls.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.casino_outlined, size: 48, color: Colors.grey),
                const SizedBox(height: 12),
                const Text(
                  'No dice rolls logged yet for this room.\nRoll dice to broadcast in real time!',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey),
                ),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => DiceRollerScreen(
                        roomService: diceService,
                      ),
                    ),
                  ),
                  icon: const Icon(Icons.casino),
                  label: const Text('Open Dice Roller'),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          itemCount: rolls.length,
          itemBuilder: (context, index) {
            final roll = rolls[index];
            return _buildRollCard(roll, isDark);
          },
        );
      },
    );
  }

  Widget _buildRollCard(RoomRoll roll, bool isDark) {
    Color cardColor =
        isDark ? const Color(0xFF1E2230) : const Color(0xFFF8FAFC);
    Color totalColor = Colors.blueAccent;

    if (roll.isCrit) {
      totalColor = Colors.greenAccent.shade700;
    } else if (roll.isFumble) {
      totalColor = Colors.redAccent;
    }

    return Card(
      key: ValueKey(roll.id),
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      color: cardColor,
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: totalColor.withValues(alpha: 0.2),
          child: Text(
            '${roll.total}',
            style: TextStyle(fontWeight: FontWeight.bold, color: totalColor),
          ),
        ),
        title: Row(
          children: [
            Text(roll.playerName,
                style: const TextStyle(
                    fontWeight: FontWeight.bold, fontSize: 13.5)),
            const SizedBox(width: 8),
            if (roll.isCrit)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                decoration: BoxDecoration(
                    color: Colors.green,
                    borderRadius: BorderRadius.circular(4)),
                child: const Text('NAT 20',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 9,
                        fontWeight: FontWeight.bold)),
              ),
            if (roll.isFumble)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                decoration: BoxDecoration(
                    color: Colors.red, borderRadius: BorderRadius.circular(4)),
                child: const Text('FUMBLE',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 9,
                        fontWeight: FontWeight.bold)),
              ),
          ],
        ),
        subtitle: Text(
          '${roll.formulaString} (${roll.individualRolls.join(', ')})',
          style: const TextStyle(fontSize: 12),
        ),
        trailing: Text(
          '${roll.timestamp.hour.toString().padLeft(2, '0')}:${roll.timestamp.minute.toString().padLeft(2, '0')}',
          style: const TextStyle(fontSize: 11, color: Colors.grey),
        ),
      ),
    );
  }

  // =========================================================================
  // TAB 3: AUDIT HISTORY & HOST TRASH RESTORE
  // =========================================================================


}
