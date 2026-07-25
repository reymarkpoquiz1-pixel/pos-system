import 'dart:convert';

class ProductModel {
  final int? id;
  final int? categoryId;
  final String? categoryName;
  final String barcode;
  final String name;
  final String? description;
  final double costPrice;
  final double sellingPrice;
  final int stockQuantity;
  final int reorderLevel;
  final String? imageUrl;
  final List<String> images;
  final String productLine;
  final List<String> tags;
  final List<ProductVariant> variants;
  final String status;

  ProductModel({
    this.id,
    this.categoryId,
    this.categoryName,
    required this.barcode,
    required this.name,
    this.description,
    this.costPrice = 0.0,
    this.sellingPrice = 0.0,
    this.stockQuantity = 0,
    this.reorderLevel = 0,
    this.imageUrl,
    this.images = const [],
    this.productLine = 'Standard',
    this.tags = const [],
    this.variants = const [],
    this.status = 'Active',
  });

  factory ProductModel.fromMap(Map<String, dynamic> map) {
    // Handle variants parsing
    List<ProductVariant> parsedVariants = [];
    if (map['variants'] != null) {
      try {
        var variantsData = map['variants'];
        List<dynamic> list = (variantsData is String) ? json.decode(variantsData) : variantsData;
        parsedVariants = list.map((v) => ProductVariant.fromMap(v)).toList();
      } catch (e) {
        print("Error parsing variants: $e");
      }
    }

    // Handle images parsing
    List<String> parsedImages = [];
    var imagesData = map['images'] ?? map['product_images'] ?? map['gallery'];
    if (imagesData != null) {
      try {
        if (imagesData is String) {
          if (imagesData.startsWith('[') && imagesData.endsWith(']')) {
            parsedImages = List<String>.from(json.decode(imagesData));
          } else {
            parsedImages = imagesData.split(',').map((s) => s.trim()).where((s) => s.isNotEmpty).toList();
          }
        } else if (imagesData is List) {
          parsedImages = imagesData.map((e) => e.toString()).toList();
        }
      } catch (e) {
        print("Error parsing images: $e");
      }
    }

    // Handle tags parsing
    List<String> parsedTags = [];
    if (map['tags'] != null) {
      try {
        var tagsData = map['tags'];
        List<dynamic> list = (tagsData is String) ? json.decode(tagsData) : tagsData;
        parsedTags = list.map((e) => e.toString()).toList();
      } catch (e) {
        print("Error parsing tags: $e");
      }
    }

    return ProductModel(
      id: map['id'] != null ? int.tryParse(map['id'].toString()) : null,
      categoryId: map['category_id'] != null ? int.tryParse(map['category_id'].toString()) : null,
      categoryName: map['category_name'],
      barcode: map['barcode'] ?? '',
      name: map['name'] ?? '',
      description: map['description'],
      costPrice: double.tryParse(map['cost_price']?.toString() ?? '0') ?? 0.0,
      sellingPrice: double.tryParse(map['selling_price']?.toString() ?? '0') ?? 0.0,
      stockQuantity: int.tryParse(map['stock_quantity']?.toString() ?? '0') ?? 0,
      reorderLevel: int.tryParse(map['reorder_level']?.toString() ?? '0') ?? 0,
      imageUrl: map['image_url'],
      images: parsedImages,
      productLine: map['product_line'] ?? 'Standard',
      tags: parsedTags,
      variants: parsedVariants,
      status: map['status'] ?? 'Active',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'category_id': categoryId,
      'barcode': barcode,
      'name': name,
      'description': description,
      'cost_price': costPrice,
      'selling_price': sellingPrice,
      'stock_quantity': stockQuantity,
      'reorder_level': reorderLevel,
      'image_url': imageUrl,
      'images': json.encode(images),
      'product_line': productLine,
      'tags': json.encode(tags),
      'variants': json.encode(variants.map((v) => v.toMap()).toList()),
      'status': status,
    };
  }
}

class ProductVariant {
  final String name;
  final String? colorHex;
  final String? size;
  final int stock;

  ProductVariant({
    required this.name,
    this.colorHex,
    this.size,
    this.stock = 0,
  });

  factory ProductVariant.fromMap(Map<String, dynamic> map) {
    return ProductVariant(
      name: map['color_name'] ?? map['name'] ?? '',
      colorHex: map['color_hex'],
      size: map['size'],
      stock: int.tryParse(map['stock']?.toString() ?? '0') ?? 0,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'color_name': name,
      'color_hex': colorHex,
      'size': size,
      'stock': stock,
    };
  }
}
