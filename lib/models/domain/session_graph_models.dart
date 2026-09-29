import 'package:vtt_engine_core/models/session_graph_models.dart';
import 'package:vtt_engine_core/models/value_objects/hit_points.dart';
export 'package:vtt_engine_core/models/session_graph_models.dart';

/// Entity Types bindable within a 5e session or room node
enum SessionRefType {
  character,
  monster,
  npc,
  lootContainer;

  String get displayName => switch (this) {
        SessionRefType.character => 'Player Character',
        SessionRefType.monster => 'Monster',
        SessionRefType.npc => 'NPC',
        SessionRefType.lootContainer => 'Loot Container',
      };
}

extension EncounterParticipant5e on EncounterParticipant {
  int get armorClass => defense ?? 10;
  HitPoints get hitPoints => HitPoints(
        currentHp: currentHp ?? 10,
        maxHp: maxHp ?? 10,
        tempHp: tempHp ?? 0,
        isDead: isDead ?? false,
      );
}

extension RoomEntityLink5e on RoomEntityLink {
  SessionRefType get sessionRefType {
    if (refType is SessionRefType) return refType as SessionRefType;
    final name = refType?.toString();
    return SessionRefType.values.firstWhere(
      (t) => t.name == name,
      orElse: () => SessionRefType.character,
    );
  }
}
