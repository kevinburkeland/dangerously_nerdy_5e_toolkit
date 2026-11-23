import 'package:material_ui/material_ui.dart';

class AssignLootDialog extends StatelessWidget {
  final String itemName;
  final String currentActiveName;
  final List<String> roster;
  final List<String> activePlayers;

  const AssignLootDialog({
    super.key,
    required this.itemName,
    required this.currentActiveName,
    this.roster = const [],
    this.activePlayers = const [],
  });

  static Future<String?> show(
    BuildContext context, {
    required String itemName,
    required String currentActiveName,
    List<String> roster = const [],
    List<String> activePlayers = const [],
  }) {
    return showDialog<String>(
      context: context,
      builder: (_) => AssignLootDialog(
        itemName: itemName,
        currentActiveName: currentActiveName,
        roster: roster,
        activePlayers: activePlayers,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final allCandidates = <String>{
      if (currentActiveName.trim().isNotEmpty) currentActiveName.trim(),
      ...roster.map((s) => s.trim()).where((s) => s.isNotEmpty),
    }.toList();

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Row(
        children: [
          const Icon(Icons.assignment_ind, color: Colors.amber),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Assign "$itemName"',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
      content: SizedBox(
        width: double.maxFinite,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Select who will claim this item into their character inventory:',
                style: TextStyle(fontSize: 12.5),
              ),
              const SizedBox(height: 10),
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 260),
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: allCandidates.length,
                  itemBuilder: (context, idx) {
                    final name = allCandidates[idx];
                    final isMe = name == currentActiveName;

                    return ListTile(
                      dense: true,
                      leading: Icon(isMe ? Icons.star : Icons.person_outline,
                          color: isMe ? Colors.amber : Colors.blue),
                      title: Text(
                        name + (isMe ? ' (You)' : ''),
                        style: TextStyle(
                            fontWeight:
                                isMe ? FontWeight.bold : FontWeight.normal),
                      ),
                      onTap: () => Navigator.pop(context, name),
                    );
                  },
                ),
              ),
              const Divider(),
              ListTile(
                dense: true,
                leading: const Icon(Icons.archive_outlined, color: Colors.grey),
                title: const Text('Return to Vault (Unclaim / Shared)'),
                onTap: () => Navigator.pop(context, '__unclaim__'),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel')),
      ],
    );
  }
}

