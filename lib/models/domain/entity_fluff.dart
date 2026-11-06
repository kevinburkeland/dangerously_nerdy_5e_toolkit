import 'package:meta/meta.dart';

/// Container for rich lore, background description, and image URLs attached to a 5e entity.
@immutable
class EntityFluff {
  final String
      entityType; // 'monster', 'spell', 'item', 'class', 'feat', 'race', 'background'
  final String slug;
  final String loreMarkdown;
  final List<String> images;
  final String? source;

  const EntityFluff({
    required this.entityType,
    required this.slug,
    required this.loreMarkdown,
    this.images = const [],
    this.source,
  });

  Map<String, dynamic> toMap() => {
        'entityType': entityType,
        'slug': slug,
        'loreMarkdown': loreMarkdown,
        'images': images,
        if (source != null) 'source': source,
      };

  factory EntityFluff.fromMap(Map<String, dynamic> map) {
    return EntityFluff(
      entityType: map['entityType'] as String? ?? 'generic',
      slug: map['slug'] as String? ?? '',
      loreMarkdown: map['loreMarkdown'] as String? ?? '',
      images: (map['images'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          const [],
      source: map['source'] as String?,
    );
  }
}
