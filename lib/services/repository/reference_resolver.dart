import 'package:vtt_ruleset_dnd5e/vtt_ruleset_dnd5e.dart';
import 'layered_priority_repository.dart';

/// Dynamic Reference Resolver that walks the active priority repository stack.
class ReferenceResolver implements IEntityResolver {
  final LayeredPriorityRepository _repository;

  ReferenceResolver(this._repository);

  /// Resolves a reference returning a DomainEntity (or UnresolvedReference Null-Object).
  @override
  DomainEntity resolve(EntityReference ref) {
    final found = _repository.lookup(
      ref.slug,
      type: ref.refType,
      preferredRuleset: ref.rulesetPreferred,
    );

    if (found != null) {
      return found;
    }

    // Null-Object Pattern: Return safe stub instead of crashing UI or throwing exceptions
    return UnresolvedReference(
      slug: ref.slug,
      entityType: ref.refType,
      reason: 'Entity [${ref.slug}] not found in active priority layers',
    );
  }

  /// Strongly typed resolution returning a ResolutionResult container.
  @override
  ResolutionResult<T> resolveTyped<T extends DomainEntity>(
      EntityReference<T> ref) {
    final found = _repository.lookup<T>(
      ref.slug,
      type: ref.refType,
      preferredRuleset: ref.rulesetPreferred,
    );

    if (found != null) {
      return ResolutionResult.success(found);
    }

    return ResolutionResult.missing(
      UnresolvedReference(
        slug: ref.slug,
        entityType: ref.refType,
        reason: 'Entity [${ref.slug}] not found in active priority layers',
      ),
    );
  }

  /// Batch resolution helper for spell lists, monster actions, equipment, etc.
  List<DomainEntity> resolveAll(List<EntityReference> refs) {
    return refs.map((ref) => resolve(ref)).toList();
  }

  /// Batch typed resolution helper.
  List<ResolutionResult<T>> resolveAllTyped<T extends DomainEntity>(
      List<EntityReference<T>> refs) {
    return refs.map((ref) => resolveTyped<T>(ref)).toList();
  }
}
