import 'package:flutter/material.dart';
import 'package:pos/features/inventory/utils/product_utils.dart';
import 'package:pos/core/constants/config.dart';
import 'package:pos/core/services/api_service.dart';
import 'dart:convert';

class ProductDialogs {
  static void showAddTagDialog({
    required BuildContext context,
    required TextEditingController tagController,
    required List<String> productTags,
    required Function(List<String>) onTagsUpdated,
  }) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add New Tag'),
        content: TextField(
          controller: tagController,
          decoration: const InputDecoration(hintText: 'Enter tag name (e.g. #new)...'),
        ),
        actions: [
          TextButton(
            onPressed: () {
              tagController.clear();
              Navigator.pop(context);
            },
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () {
              if (tagController.text.isNotEmpty) {
                String tag = tagController.text.trim();
                if (!tag.startsWith('#')) tag = '#$tag';
                if (!productTags.contains(tag)) {
                  productTags.add(tag);
                  onTagsUpdated(productTags);
                }
                tagController.clear();
              }
              Navigator.pop(context);
            },
            child: const Text('Add', style: TextStyle(color: Color(0xFFD68A96))),
          ),
        ],
      ),
    );
  }

  static void showEditVariantDialog({
    required BuildContext context,
    required int index,
    required List<Map<String, dynamic>> variants,
    required Function(int, Map<String, dynamic>) onVariantUpdated,
  }) {
    final variant = variants[index];
    final colorController = TextEditingController(text: variant['name']);
    final sizeController = TextEditingController(text: variant['size']);
    final stockController = TextEditingController(text: (variant['stock'] ?? '0').toString());
    Color previewColor = variant['color'];

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            title: const Text('Edit Variant', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: colorController, 
                          textCapitalization: TextCapitalization.words,
                          decoration: const InputDecoration(labelText: 'Color Name (e.g. Red)'),
                          onChanged: (val) {
                            setDialogState(() {
                              previewColor = ProductUtils.getColorFromName(val);
                            });
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      Container(
                        width: 30,
                        height: 30,
                        decoration: BoxDecoration(
                          color: previewColor,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.black12),
                          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 4)],
                        ),
                      ),
                    ],
                  ),
                  TextField(
                    controller: sizeController, 
                    textCapitalization: TextCapitalization.words,
                    decoration: const InputDecoration(labelText: 'Size (e.g. XL, 42)')
                  ),
                  TextField(
                    controller: stockController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Total Stock'),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
              TextButton(
                onPressed: () {
                  onVariantUpdated(index, {
                    'color': previewColor,
                    'name': colorController.text,
                    'size': sizeController.text,
                    'stock': int.tryParse(stockController.text) ?? 0,
                  });
                  Navigator.pop(context);
                },
                child: const Text('Save Changes', style: TextStyle(color: Color(0xFFD68A96))),
              ),
            ],
          );
        }
      ),
    );
  }

  static void showAddVariantDialog({
    required BuildContext context,
    required Function(Map<String, dynamic>) onVariantAdded,
  }) {
    final colorController = TextEditingController();
    final sizeController = TextEditingController();
    final stockController = TextEditingController(text: '0');
    Color previewColor = const Color(0xff607d8b);

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            title: const Text('Add Variant', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: colorController, 
                          textCapitalization: TextCapitalization.words,
                          decoration: const InputDecoration(labelText: 'Color Name (e.g. Red)'),
                          onChanged: (val) {
                            setDialogState(() {
                              previewColor = ProductUtils.getColorFromName(val);
                            });
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      Container(
                        width: 30,
                        height: 30,
                        decoration: BoxDecoration(
                          color: previewColor,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.black12),
                          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 4)],
                        ),
                      ),
                    ],
                  ),
                  TextField(
                    controller: sizeController, 
                    textCapitalization: TextCapitalization.words,
                    decoration: const InputDecoration(labelText: 'Size (e.g. XL, 42)')
                  ),
                  TextField(
                    controller: stockController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Total Stock'),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
              TextButton(
                onPressed: () {
                  onVariantAdded({
                    'color': previewColor,
                    'name': colorController.text,
                    'size': sizeController.text,
                    'stock': int.tryParse(stockController.text) ?? 0,
                  });
                  Navigator.pop(context);
                },
                child: const Text('Add', style: TextStyle(color: Color(0xFFD68A96))),
              ),
            ],
          );
        }
      ),
    );
  }

  static void showArchivedProductsDialog(BuildContext context, List<dynamic> productsList, VoidCallback onRefresh) {
    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final archivedItems = productsList.where((p) => (p['status'] ?? 'Active') == 'Archived').toList();
            
            return AlertDialog(
              backgroundColor: const Color(0xFFFBECEF),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
              title: Row(
                children: [
                  const Icon(Icons.archive_outlined, color: Color(0xFFD68A96)),
                  const SizedBox(width: 10),
                  const Text('Archived Products', style: TextStyle(fontWeight: FontWeight.bold)),
                  const Spacer(),
                  IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close)),
                ],
              ),
              content: SizedBox(
                width: 500,
                height: 400,
                child: archivedItems.isEmpty
                    ? const Center(child: Text('No archived products found.'))
                    : ListView.separated(
                        itemCount: archivedItems.length,
                        separatorBuilder: (context, index) => const Divider(),
                        itemBuilder: (context, index) {
                          final item = archivedItems[index];
                          return ListTile(
                            leading: Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(8),
                                image: item['image_url'] != null
                                    ? DecorationImage(
                                        image: NetworkImage(item['image_url'].toString().startsWith('http') 
                                            ? item['image_url'] 
                                            : '$baseUrl/${item['image_url']}'),
                                        fit: BoxFit.cover)
                                    : null,
                              ),
                              child: item['image_url'] == null ? const Icon(Icons.image) : null,
                            ),
                            title: Text(item['name'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold)),
                            subtitle: Text('ID: ${item['id']} • ₱${item['selling_price']}'),
                            trailing: ElevatedButton.icon(
                              onPressed: () async {
                                final res = await _restoreArchivedItem(context, item['id'], item['name']);
                                if (res) {
                                  onRefresh();
                                  setDialogState(() {}); // Refresh dialog list
                                }
                              },
                              icon: const Icon(Icons.unarchive, size: 16),
                              label: const Text('Restore', style: TextStyle(fontSize: 11)),
                              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFD68A96), foregroundColor: Colors.white),
                            ),
                          );
                        },
                      ),
              ),
            );
          },
        );
      },
    );
  }

  static Future<bool> _restoreArchivedItem(BuildContext context, dynamic id, String name) async {
    try {
      final response = await ApiService.post('products/restore_product', {'id': id.toString()});
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success']) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('"$name" restored successfully!')));
          return true;
        }
      }
    } catch (e) {
      debugPrint('Error restoring item: $e');
    }
    return false;
  }

  static Future<bool> showArchiveConfirmation(BuildContext context, String productName) async {
    return await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Archive Product?'),
        content: Text('Are you sure you want to archive "$productName"?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Archive', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    ) ?? false;
  }
}
