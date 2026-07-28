import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../utils/product_utils.dart';
import '../utils/category_utils.dart';

class ProductFormController {
  final nameController = TextEditingController();
  final barcodeController = TextEditingController();
  final costPriceController = TextEditingController();
  final sellingPriceController = TextEditingController();
  final stockController = TextEditingController();
  final reorderController = TextEditingController();
  final profitMarginController = TextEditingController();
  final pricingMarginController = TextEditingController();
  final descriptionController = TextEditingController();
  final tagController = TextEditingController();

  Color marginColor = Colors.black87;
  String selectedProductLine = 'Select Product Line';
  int? selectedCategoryId;
  String selectedCategoryName = 'Select Category';
  
  final List<String> productTags = [];
  final List<String> serverImages = [];
  final List<XFile> selectedImages = [];
  final List<Map<String, dynamic>> variants = [];

  void dispose() {
    nameController.dispose();
    barcodeController.dispose();
    costPriceController.dispose();
    sellingPriceController.dispose();
    stockController.dispose();
    reorderController.dispose();
    profitMarginController.dispose();
    pricingMarginController.dispose();
    descriptionController.dispose();
    tagController.dispose();
  }

  void calculateMargins() {
    double cost = double.tryParse(costPriceController.text) ?? 0;
    double selling = double.tryParse(sellingPriceController.text) ?? 0;

    if (selling > 0) {
      double profit = selling - cost;
      double marginPercent = (profit / selling) * 100;

      if (profit > 0) {
        marginColor = Colors.green.shade700;
      } else if (profit < 0) {
        marginColor = Colors.red.shade700;
      } else {
        marginColor = Colors.orange.shade800;
      }

      pricingMarginController.text = profit.toStringAsFixed(2);
      profitMarginController.text = "${marginPercent.toStringAsFixed(0)}%";
    } else {
      marginColor = Colors.black87;
      pricingMarginController.text = '0.00';
      profitMarginController.text = '0%';
    }
  }

  void updateTotalStockFromVariants() {
    if (variants.isEmpty) return;
    int total = 0;
    for (var v in variants) {
      total += int.tryParse(v['stock']?.toString() ?? '0') ?? 0;
    }
    stockController.text = total.toString();
  }

  void generateBarcode() {
    barcodeController.text = ProductUtils.generateBarcode("PROD");
  }

  void clearForm() {
    nameController.clear();
    barcodeController.clear();
    costPriceController.clear();
    sellingPriceController.clear();
    stockController.clear();
    reorderController.clear();
    profitMarginController.clear();
    pricingMarginController.clear();
    descriptionController.clear();
    tagController.clear();
    
    selectedCategoryId = null;
    selectedCategoryName = 'Select Category';
    selectedProductLine = 'Select Product Line';
    productTags.clear();
    selectedImages.clear();
    serverImages.clear();
    variants.clear();
    marginColor = Colors.black87;
  }

  void loadProduct(Map<String, dynamic> product, List<dynamic> categories, List<String> productLines) {
    nameController.text = product['name']?.toString() ?? '';
    barcodeController.text = product['barcode']?.toString() ?? '';
    costPriceController.text = product['cost_price']?.toString() ?? '';
    sellingPriceController.text = product['selling_price']?.toString() ?? '';
    stockController.text = product['stock_quantity']?.toString() ?? '';
    reorderController.text = product['reorder_level']?.toString() ?? '';
    descriptionController.text = product['description']?.toString() ?? '';

    selectedCategoryId = product['category_id'] != null ? int.tryParse(product['category_id'].toString()) : null;
    selectedCategoryName = product['category_name']?.toString() ?? 
        CategoryUtils.findNameById(categories, selectedCategoryId);

    String pLine = product['product_line']?.toString() ?? 'Select Product Line';
    selectedProductLine = productLines.contains(pLine) ? pLine : 'Select Product Line';

    productTags.clear();
    if (product['tags'] != null) {
      try {
        var tagsData = product['tags'];
        List<dynamic> tagsList = (tagsData is String) ? (tagsData.startsWith('[') ? jsonDecode(tagsData) : tagsData.split(',')) : tagsData;
        productTags.addAll(tagsList.map((e) => e.toString().trim()).where((e) => e.isNotEmpty));
      } catch (e) {
        debugPrint("Error decoding tags: $e");
      }
    }

    serverImages.clear();
    selectedImages.clear();
    var imagesData = product['images'] ?? product['product_images'] ?? product['gallery'];
    if (imagesData != null && imagesData.toString().isNotEmpty) {
      try {
        List<dynamic> imgsList = (imagesData is String) ? (imagesData.startsWith('[') ? jsonDecode(imagesData) : imagesData.split(',')) : imagesData;
        serverImages.addAll(imgsList.map((e) => e.toString().trim()).where((e) => e.isNotEmpty));
      } catch (e) {}
    }
    if (product['image_url'] != null && product['image_url'].toString().isNotEmpty) {
      String mainImg = product['image_url'].toString().trim();
      if (!serverImages.contains(mainImg)) serverImages.insert(0, mainImg);
    }

    variants.clear();
    if (product['variants'] != null) {
      try {
        var variantsData = product['variants'];
        List<dynamic> variantsList = (variantsData is String) ? jsonDecode(variantsData) : variantsData;
        for (var v in variantsList) {
          variants.add({
            'name': v['color_name'] ?? '',
            'color': Color(int.parse((v['color_hex'] ?? 'ff607d8b').replaceFirst('#', 'ff'), radix: 16)),
            'size': v['size'] ?? '',
            'stock': int.tryParse(v['stock']?.toString() ?? '0') ?? 0,
          });
        }
      } catch (e) {}
    }
    calculateMargins();
  }
  
  Map<String, dynamic> getOptimisticData(dynamic existingProduct, String tempId) {
    return {
      'id': existingProduct?['id'] ?? tempId,
      'name': nameController.text,
      'cost_price': costPriceController.text,
      'selling_price': sellingPriceController.text,
      'stock_quantity': stockController.text,
      'category_id': selectedCategoryId,
      'category_name': selectedCategoryName,
      'product_line': selectedProductLine,
      'tags': productTags,
      'local_image_path': selectedImages.isNotEmpty ? selectedImages[0].path : null,
      'status': 'Active',
      'is_syncing': true,
      'variants': variants,
    };
  }
}
