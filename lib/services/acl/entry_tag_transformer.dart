/// Backward-compatibility shim.
///
/// [EntryTagTransformer] is now a type alias for [EntryNodeTransformer].
/// All code that instantiates `EntryTagTransformer()` continues to work
/// because the alias is fully constructable.
///
library;

export 'entry_node_transformer.dart'
    show EntryNodeTransformer, ParsedEntryResult;

// Re-export the class under the legacy name so existing files that
// reference `EntryTagTransformer` compile without any changes.
import 'entry_node_transformer.dart';

// ignore: camel_case_types
typedef EntryTagTransformer = EntryNodeTransformer;
