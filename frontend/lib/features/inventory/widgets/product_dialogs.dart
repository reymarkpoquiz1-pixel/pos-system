import 'package:flutter/material.dart';
import 'package:pos/features/inventory/utils/product_utils.dart';

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
}
