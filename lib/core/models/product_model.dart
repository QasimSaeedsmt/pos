import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../features/product_selling/product_selling_base.dart';
import 'category_model.dart';

import 'package:hive/hive.dart';

part 'product_model.g.dart';

@HiveType(typeId: 14)
class Product {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final String name;

  @HiveField(2)
  final String sku;

  @HiveField(3)
  final double price;

  @HiveField(4)
  final double? purchasePrice;

  @HiveField(5)
  final double? regularPrice;

  @HiveField(6)
  final double? salePrice;

  @HiveField(7)
  final String? imageUrl;

  @HiveField(8)
  final List<String> imageUrls;

  @HiveField(9)
  final int stockQuantity;

  @HiveField(10)
  final bool inStock;

  @HiveField(11)
  final String stockStatus;

  @HiveField(12)
  final String? description;

  @HiveField(13)
  final String? shortDescription;

  @HiveField(14)
  final List<Category> categories;

  @HiveField(15)
  final List<Attribute> attributes;

  @HiveField(16)
  final Map<String, dynamic> metaData;

  @HiveField(17)
  final DateTime? dateCreated;

  @HiveField(18)
  final DateTime? dateModified;

  @HiveField(19)
  final bool purchasable;

  @HiveField(20)
  final String? type;

  @HiveField(21)
  final String? status;

  @HiveField(22)
  final bool featured;

  @HiveField(23)
  final String? permalink;

  @HiveField(24)
  final double? averageRating;

  @HiveField(25)
  final int? ratingCount;

  @HiveField(26)
  final String? parentId;

  @HiveField(27)
  final List<String> variations;

  @HiveField(28)
  final String? weight;

  @HiveField(29)
  final String? dimensions;

  @HiveField(30)
  final double totalCostValue;

  @HiveField(31)
  final int totalUnitsPurchased;

  @HiveField(32)
  final DateTime? lastRestockDate;

  Product({
    required this.id,
    required this.name,
    required this.sku,
    required this.price,
    this.purchasePrice,
    this.regularPrice,
    this.salePrice,
    this.imageUrl,
    this.imageUrls = const [],
    required this.stockQuantity,
    required this.inStock,
    required this.stockStatus,
    this.description,
    this.shortDescription,
    this.categories = const [],
    this.attributes = const [],
    this.metaData = const {},
    this.dateCreated,
    this.dateModified,
    this.purchasable = true,
    this.type,
    this.status,
    this.featured = false,
    this.permalink,
    this.averageRating,
    this.ratingCount,
    this.parentId,
    this.variations = const [],
    this.weight,
    this.dimensions,
    this.totalCostValue = 0.0,
    this.totalUnitsPurchased = 0,
    this.lastRestockDate,
  });

  List<String> get categoryNames => categories.map((cat) => cat.name).toList();

  bool hasCategory(String categoryId) {
    return categories.any((cat) => cat.id == categoryId);
  }

  Product copyWith({
    String? id,
    String? name,
    String? sku,
    double? price,
    double? purchasePrice,
    double? regularPrice,
    double? salePrice,
    String? imageUrl,
    List<String>? imageUrls,
    int? stockQuantity,
    bool? inStock,
    String? stockStatus,
    String? description,
    String? shortDescription,
    List<Category>? categories,
    List<Attribute>? attributes,
    Map<String, dynamic>? metaData,
    DateTime? dateCreated,
    DateTime? dateModified,
    bool? purchasable,
    String? type,
    String? status,
    bool? featured,
    String? permalink,
    double? averageRating,
    int? ratingCount,
    String? parentId,
    List<String>? variations,
    String? weight,
    String? dimensions,
    double? totalCostValue,
    int? totalUnitsPurchased,
    DateTime? lastRestockDate,
  }) {
    return Product(
      id: id ?? this.id,
      name: name ?? this.name,
      sku: sku ?? this.sku,
      price: price ?? this.price,
      purchasePrice: purchasePrice ?? this.purchasePrice,
      regularPrice: regularPrice ?? this.regularPrice,
      salePrice: salePrice ?? this.salePrice,
      imageUrl: imageUrl ?? this.imageUrl,
      imageUrls: imageUrls ?? this.imageUrls,
      stockQuantity: stockQuantity ?? this.stockQuantity,
      inStock: inStock ?? this.inStock,
      stockStatus: stockStatus ?? this.stockStatus,
      description: description ?? this.description,
      shortDescription: shortDescription ?? this.shortDescription,
      categories: categories ?? this.categories,
      attributes: attributes ?? this.attributes,
      metaData: metaData ?? this.metaData,
      dateCreated: dateCreated ?? this.dateCreated,
      dateModified: dateModified ?? this.dateModified,
      purchasable: purchasable ?? this.purchasable,
      type: type ?? this.type,
      status: status ?? this.status,
      featured: featured ?? this.featured,
      permalink: permalink ?? this.permalink,
      averageRating: averageRating ?? this.averageRating,
      ratingCount: ratingCount ?? this.ratingCount,
      parentId: parentId ?? this.parentId,
      variations: variations ?? this.variations,
      weight: weight ?? this.weight,
      dimensions: dimensions ?? this.dimensions,
      totalCostValue: totalCostValue ?? this.totalCostValue,
      totalUnitsPurchased: totalUnitsPurchased ?? this.totalUnitsPurchased,
      lastRestockDate: lastRestockDate ?? this.lastRestockDate,
    );
  }

  factory Product.fromFirestore(Map<String, dynamic> data, String id) {
    final List<Category> categories = [];
    if (data['categories'] is List) {
      for (final catData in data['categories']) {
        if (catData is Map<String, dynamic>) {
          try {
            categories.add(Category.fromFirestore(catData, catData['id']?.toString() ?? ''));
          } catch (e) {
            debugPrint('Error parsing category: $e');
          }
        }
      }
    }

    final List<String> imageUrls = [];
    if (data['imageUrls'] is List) {
      for (final url in data['imageUrls']) {
        if (url != null) {
          imageUrls.add(url.toString());
        }
      }
    }

    final List<Attribute> attributes = [];
    if (data['attributes'] is List) {
      for (final attrData in data['attributes']) {
        if (attrData is Map<String, dynamic>) {
          try {
            attributes.add(Attribute.fromFirestore(attrData, attrData['id'] ?? 0));
          } catch (e) {
            debugPrint('Error parsing attribute: $e');
          }
        }
      }
    }

    return Product(
      id: id,
      name: data['name']?.toString() ?? 'Unnamed Product',
      sku: data['sku']?.toString() ?? '',
      price: _parseDouble(data['price']) ?? 0.0,
      purchasePrice: _parseDouble(data['purchasePrice']),
      regularPrice: _parseDouble(data['regularPrice']),
      salePrice: _parseDouble(data['salePrice']),
      imageUrl: data['imageUrl']?.toString(),
      imageUrls: imageUrls,
      stockQuantity: _parseInt(data['stockQuantity']) ?? 0,
      inStock: data['inStock'] ?? true,
      stockStatus: data['stockStatus']?.toString() ?? 'instock',
      description: data['description']?.toString(),
      shortDescription: data['shortDescription']?.toString(),
      categories: categories,
      attributes: attributes,
      metaData: data['metaData'] is Map ? Map<String, dynamic>.from(data['metaData']) : {},
      dateCreated: _parseDate(data['dateCreated']),
      dateModified: _parseDate(data['dateModified']),
      purchasable: data['purchasable'] ?? true,
      type: data['type']?.toString(),
      status: data['status']?.toString() ?? 'publish',
      featured: data['featured'] ?? false,
      permalink: data['permalink']?.toString(),
      averageRating: _parseDouble(data['averageRating']),
      ratingCount: _parseInt(data['ratingCount']),
      parentId: data['parentId']?.toString(),
      variations: data['variations'] is List ? List<String>.from(data['variations']) : [],
      weight: data['weight']?.toString(),
      dimensions: data['dimensions']?.toString(),
      totalCostValue: _parseDouble(data['totalCostValue']) ?? 0.0,
      totalUnitsPurchased: _parseInt(data['totalUnitsPurchased']) ?? 0,
      lastRestockDate: _parseDate(data['lastRestockDate']),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'id': id,
      'name': name,
      'sku': sku,
      'price': price,
      'purchasePrice': purchasePrice,
      'regularPrice': regularPrice,
      'salePrice': salePrice,
      'imageUrl': imageUrl,
      'imageUrls': imageUrls,
      'stockQuantity': stockQuantity,
      'inStock': inStock,
      'stockStatus': stockStatus,
      'description': description,
      'shortDescription': shortDescription,
      'categories': categories.map((cat) => cat.toFirestore()).toList(),
      'attributes': attributes.map((attr) => attr.toFirestore()).toList(),
      'metaData': metaData,
      'dateCreated': dateCreated?.toIso8601String(),
      'dateModified': dateModified?.toIso8601String(),
      'purchasable': purchasable,
      'type': type,
      'status': status,
      'featured': featured,
      'permalink': permalink,
      'averageRating': averageRating,
      'ratingCount': ratingCount,
      'parentId': parentId,
      'variations': variations,
      'weight': weight,
      'dimensions': dimensions,
      'totalCostValue': totalCostValue,
      'totalUnitsPurchased': totalUnitsPurchased,
      'lastRestockDate': lastRestockDate?.toIso8601String(),
      'searchKeywords': _generateSearchKeywords(),
    };
  }

  List<String> _generateSearchKeywords() {
    final keywords = <String>[];

    keywords.addAll(name.toLowerCase().split(' '));

    if (sku.isNotEmpty) {
      keywords.add(sku.toLowerCase());
    }

    for (final category in categories) {
      keywords.addAll(category.name.toLowerCase().split(' '));
    }

    if (description != null && description!.isNotEmpty) {
      keywords.addAll(description!.toLowerCase().split(' '));
    }

    return keywords.where((k) => k.length > 1).toSet().toList();
  }

  double get inventoryValue {
    return (purchasePrice ?? 0.0) * stockQuantity;
  }

  double get profitMargin {
    if (purchasePrice == null || purchasePrice == 0) return 0.0;
    return ((price - purchasePrice!) / purchasePrice!) * 100;
  }

  static int? _parseInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is double) return value.toInt();
    if (value is String) return int.tryParse(value);
    return null;
  }

  static double? _parseDouble(dynamic value) {
    if (value == null) return null;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) return double.tryParse(value);
    return null;
  }

  static DateTime? _parseDate(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) return value;
    if (value is Timestamp) return value.toDate();
    if (value is String) {
      try {
        return DateTime.parse(value);
      } catch (e) {
        return null;
      }
    }
    if (value is int) {
      return DateTime.fromMillisecondsSinceEpoch(value);
    }
    return null;
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Product && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() {
    return 'Product{id: $id, name: $name, price: $price, stock: $stockQuantity}';
  }
}