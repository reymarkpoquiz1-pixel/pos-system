import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:pos/core/services/api_service.dart';
import 'package:pos/core/constants/config.dart';
import 'package:image_picker/image_picker.dart';

class ProductService {
  static Future<List<dynamic>> fetchCategories() async {
    try {
      final response = await ApiService.get('category/get_categories');
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success']) {
          return data['categories'] ?? [];
        }
      }
    } catch (e) {
      debugPrint('Error fetching categories: $e');
    }
    return [];
  }

  static Future<Map<String, dynamic>?> saveProduct({
    required String name,
    required String barcode,
    required String costPrice,
    required String sellingPrice,
    required String stockQuantity,
    required String reorderLevel,
    required String description,
    required String productLine,
    required List<String> tags,
    required List<String> serverImages,
    required List<XFile> selectedImages,
    required List<Map<String, dynamic>> variants,
    int? userId,
    int? categoryId,
    Map<String, dynamic>? existingProduct,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('jwt_token');

      var request = http.MultipartRequest('POST', Uri.parse('$baseUrl/products/add_product'));
      
      if (token != null) {
        request.headers['Authorization'] = 'Bearer $token';
      }

      if (existingProduct != null) {
        request.fields['id'] = existingProduct['id'].toString();
      }
      request.fields['name'] = name;
      request.fields['category_id'] = categoryId?.toString() ?? '';
      request.fields['barcode'] = barcode;
      request.fields['description'] = description;
      request.fields['cost_price'] = costPrice;
      request.fields['selling_price'] = sellingPrice;
      request.fields['stock_quantity'] = stockQuantity;
      request.fields['reorder_level'] = reorderLevel;
      request.fields['product_line'] = productLine;
      request.fields['tags'] = json.encode(tags);
      request.fields['existing_images'] = json.encode(serverImages);
      
      if (userId != null) {
        request.fields['added_by'] = userId.toString();
      }
      
      request.fields['variants'] = json.encode(variants.map((v) => {
        'color_name': v['name'],
        'color_hex': v['color'].value.toRadixString(16),
        'size': v['size'],
        'stock': v['stock'] ?? 0,
      }).toList());

      for (var file in selectedImages) {
        if (kIsWeb) {
          final bytes = await file.readAsBytes();
          request.files.add(http.MultipartFile.fromBytes(
            'images[]',
            bytes,
            filename: file.name,
          ));
        } else {
          request.files.add(await http.MultipartFile.fromPath(
            'images[]',
            file.path,
          ));
        }
      }

      var response = await request.send();
      var responseData = await response.stream.bytesToString();
      final data = json.decode(responseData);

      if (data['success']) {
        return data['data'];
      } else {
        throw Exception(data['message']);
      }
    } catch (e) {
      debugPrint('ProductService Save Error: $e');
      rethrow;
    }
  }

  static Future<bool> archiveProduct(dynamic productId) async {
    try {
      final response = await ApiService.post('products/archive_product', {
        'id': productId.toString(),
      });

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data['success'] == true;
      }
    } catch (e) {
      debugPrint('ProductService Archive Error: $e');
    }
    return false;
  }
}
