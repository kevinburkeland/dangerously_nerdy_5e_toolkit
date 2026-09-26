export 'package:vtt_engine_core/models/entity_reference.dart';
import 'package:vtt_engine_core/models/entity_reference.dart';
import 'package:vtt_engine_core/models/generic_tabletop_primitives.dart';
import '../characters/srd_feats_library.dart';

final bool entityRefFeatResolverInitialized = () {
  EntityReference.externalTraitResolver = (slug) {
    final featDef = SrdFeatsLibrary.findBySlug(slug);
    if (featDef == null) return null;
    return ITraitDefinition(
      id: featDef.id.slug,
      name: featDef.name,
      category: 'feat',
      properties: {
        if (featDef.prerequisite != null) 'prerequisite': featDef.prerequisite,
        ...featDef.customProperties,
      },
    );
  };
  return true;
}();
