export 'package:vtt_engine_core/models/feature_grant.dart';
import '../../services/acl/compendium_pipe_parser.dart';
import 'package:vtt_engine_core/models/feature_grant.dart';

final bool featureGrantPipeParserInitialized = () {
  FeatureGrant.spellDescriptorExtractor =
      CompendiumPipeParser.extractSpellDescriptors;
  FeatureGrant.spellNameExtractor = CompendiumPipeParser.extractSpellNames;
  FeatureGrant.bonusSpellsExtractor = CompendiumPipeParser.extractBonusSpells;
  return true;
}();
