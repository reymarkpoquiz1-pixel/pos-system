import 'package:flutter/material.dart';

class ProductInputField extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final String hint;
  final Widget? suffix;
  final bool readOnly;
  final Color? textColor;

  const ProductInputField({
    super.key,
    required this.label,
    required this.controller,
    required this.hint,
    this.suffix,
    this.readOnly = false,
    this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 11, color: Color(0xFF1C1B1F), fontWeight: FontWeight.w600)),
        const SizedBox(height: 4),
        Container(
          height: 36,
          decoration: BoxDecoration(
            color: readOnly ? const Color(0xFFF5F5F5) : Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFFEFAFB8), width: 1),
          ),
          child: TextFormField(
            controller: controller,
            readOnly: readOnly,
            enabled: !readOnly,
            style: TextStyle(
              fontSize: 12, 
              color: textColor ?? (readOnly ? Colors.black54 : Colors.black87),
              fontWeight: readOnly ? FontWeight.bold : FontWeight.normal,
            ),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: const TextStyle(color: Colors.black38, fontSize: 12),
              contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
              border: InputBorder.none,
              isDense: true,
              suffixIcon: suffix,
            ),
          ),
        ),
      ],
    );
  }
}

class ProductVariantsTable extends StatelessWidget {
  final List<Map<String, dynamic>> variants;
  final bool isEditing;
  final VoidCallback onAddVariant;
  final Function(int) onRemoveVariant;
  final Function(int) onEditVariant;

  const ProductVariantsTable({
    super.key,
    required this.variants,
    required this.isEditing,
    required this.onAddVariant,
    required this.onRemoveVariant,
    required this.onEditVariant,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('Product Variants', style: TextStyle(fontSize: 12, color: Color(0xFF1C1B1F), fontWeight: FontWeight.w600)),
            if (variants.isNotEmpty)
              const Text(
                '* Syncing to Total Stock',
                style: TextStyle(fontSize: 10, color: Color(0xFFD68A96), fontStyle: FontStyle.italic),
              ),
          ],
        ),
        const SizedBox(height: 8),
        Table(
          columnWidths: const {
            0: FlexColumnWidth(2.5), // Color
            1: FlexColumnWidth(1.2), // Size
            2: FlexColumnWidth(1.2), // Stock
            3: FixedColumnWidth(50), // Actions
          },
          defaultVerticalAlignment: TableCellVerticalAlignment.middle,
          children: [
            const TableRow(
              children: [
                Padding(
                  padding: EdgeInsets.only(bottom: 8.0),
                  child: Text('Color', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF1C1B1F))),
                ),
                Padding(
                  padding: EdgeInsets.only(bottom: 8.0),
                  child: Text('Size', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF1C1B1F))),
                ),
                Padding(
                  padding: EdgeInsets.only(bottom: 8.0),
                  child: Text('Stock', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF1C1B1F))),
                ),
                SizedBox(),
              ],
            ),
            ...variants.map((v) {
              int index = variants.indexOf(v);
              String colorName = v['name'] ?? '';
              if (colorName.isNotEmpty) {
                colorName = colorName[0].toUpperCase() + colorName.substring(1);
              }
              String sizeName = v['size'] ?? '';
              if (sizeName.isNotEmpty) {
                sizeName = sizeName[0].toUpperCase() + sizeName.substring(1);
              }
              int stock = int.tryParse(v['stock']?.toString() ?? '0') ?? 0;

              return TableRow(
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4.0),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(width: 12, height: 12, decoration: BoxDecoration(color: v['color'], borderRadius: BorderRadius.circular(3))),
                        const SizedBox(width: 6),
                        Expanded(child: Text(colorName, style: const TextStyle(fontSize: 11, color: Colors.black87), overflow: TextOverflow.ellipsis)),
                      ],
                    ),
                  ),
                  Text(sizeName, style: const TextStyle(fontSize: 11, color: Colors.black87)),
                  Text('$stock', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: stock <= 0 ? Colors.red : Colors.black87)),
                  isEditing
                      ? Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            GestureDetector(
                              onTap: () => onEditVariant(index),
                              child: const Icon(Icons.edit_outlined, size: 14, color: Color(0xFFD68A96)),
                            ),
                            const SizedBox(width: 10),
                            GestureDetector(
                              onTap: () => onRemoveVariant(index),
                              child: const Icon(Icons.remove_circle_outline, size: 14, color: Colors.red),
                            ),
                          ],
                        )
                      : const SizedBox(),
                ],
              );
            }),
          ],
        ),
        if (isEditing) ...[
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: TextButton.icon(
              onPressed: onAddVariant,
              icon: const Icon(Icons.add, size: 16, color: Color(0xFFD68A96)),
              label: const Text('Add Variant', style: TextStyle(fontSize: 12, color: Color(0xFFD68A96), fontWeight: FontWeight.bold)),
              style: TextButton.styleFrom(
                padding: EdgeInsets.zero,
                alignment: Alignment.centerLeft,
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class InventoryComponents {
  static Widget buildInfoRow(String label, String value, IconData icon) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, size: 16, color: Colors.grey),
          const SizedBox(width: 12),
          Text(label, style: const TextStyle(fontSize: 13, color: Colors.grey)),
          const Spacer(),
          Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}
