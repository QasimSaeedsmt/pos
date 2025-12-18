import 'package:hive/hive.dart';

part 'category_model.g.dart';

@HiveType(typeId: 12)
class Category {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final String name;

  @HiveField(2)
  final String slug;

  @HiveField(3)
  final String? description;

  @HiveField(4)
  final int count;

  @HiveField(5)
  final String? imageUrl;

  Category({
    required this.id,
    required this.name,
    required this.slug,
    this.description,
    required this.count,
    this.imageUrl,
  });

  factory Category.fromFirestore(Map<String, dynamic> data, String id) {
    return Category(
      id: id,
      name: data['name']?.toString() ?? '',
      slug: data['slug']?.toString() ?? '',
      description: data['description']?.toString(),
      count: data['count'] ?? 0,
      imageUrl: data['imageUrl']?.toString(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'name': name,
      'slug': slug,
      'description': description,
      'count': count,
      'imageUrl': imageUrl,
    };
  }

  Category copyWith({
    String? id,
    String? name,
    String? slug,
    String? description,
    int? count,
    String? imageUrl,
  }) {
    return Category(
      id: id ?? this.id,
      name: name ?? this.name,
      slug: slug ?? this.slug,
      description: description ?? this.description,
      count: count ?? this.count,
      imageUrl: imageUrl ?? this.imageUrl,
    );
  }

  @override
  String toString() {
    return 'Category{id: $id, name: $name, count: $count}';
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
          other is Category && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;
}