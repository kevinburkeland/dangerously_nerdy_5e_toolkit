// Compatibility re-export bridging domain entity and infrastructure DTO.
import 'package:vtt_engine_core/models/minion_instance.dart';

export 'package:vtt_engine_core/models/generic_tabletop_primitives.dart';
export 'package:vtt_engine_core/models/minion_instance.dart';
export '../infrastructure/dtos/animated_object_dto.dart';

/// Compatibility aliases preserving backward compatibility for existing callers
/// while the domain layer adopts generic tabletop [MinionInstance] primitives.
typedef AnimatedObjectInstance = MinionInstance;
typedef AnimatedObjectStats = MinionStats;
typedef ObjectSize = EntitySize;
