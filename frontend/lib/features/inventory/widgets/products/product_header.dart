import 'package:flutter/material.dart';

class ProductHeader extends StatelessWidget {
  final bool isSearchExpanded;
  final Function(bool) onSearchExpandedChanged;
  final TextEditingController searchController;
  final VoidCallback onShowArchived;
  final VoidCallback onAddProduct;

  const ProductHeader({
    super.key,
    required this.isSearchExpanded,
    required this.onSearchExpandedChanged,
    required this.searchController,
    required this.onShowArchived,
    required this.onAddProduct,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        bool isNarrow = constraints.maxWidth < 650;
        
        return Row(
          children: [
            if (!isSearchExpanded)
              Text(
                isNarrow ? 'Products' : 'Products & Apparel',
                style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Color(0xFF1C1B1F)),
              ),
            const Spacer(),
            AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              width: isSearchExpanded ? (isNarrow ? 150 : 200) : 44,
              height: 44,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(22),
              ),
              child: Row(
                children: [
                  InkWell(
                    onTap: () => onSearchExpandedChanged(!isSearchExpanded),
                    borderRadius: BorderRadius.circular(22),
                    child: SizedBox(
                      width: 44,
                      height: 44,
                      child: Icon(isSearchExpanded ? Icons.close : Icons.search, size: 20, color: Colors.grey),
                    ),
                  ),
                  if (isSearchExpanded)
                    Expanded(
                      child: TextField(
                        controller: searchController,
                        autofocus: true,
                        style: const TextStyle(fontSize: 13),
                        decoration: const InputDecoration(
                          hintText: 'Search...',
                          hintStyle: TextStyle(fontSize: 13, color: Colors.grey),
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.symmetric(vertical: 11),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            SizedBox(
              height: 44,
              child: ElevatedButton.icon(
                onPressed: onShowArchived,
                icon: const Icon(Icons.archive_outlined, size: 18),
                label: isNarrow ? const SizedBox.shrink() : const Text('Archived', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: const Color(0xFFD68A96),
                  side: const BorderSide(color: Color(0xFFD68A96)),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                  elevation: 0,
                  padding: EdgeInsets.symmetric(horizontal: isNarrow ? 8 : 12),
                  minimumSize: isNarrow ? const Size(44, 44) : null,
                ),
              ),
            ),
            const SizedBox(width: 8),
            SizedBox(
              height: 44,
              child: ElevatedButton.icon(
                onPressed: onAddProduct,
                icon: const Icon(Icons.add_circle_outline, size: 18),
                label: isNarrow ? const SizedBox.shrink() : const Text('Add Product', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFD68A96),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                  elevation: 0,
                  padding: EdgeInsets.symmetric(horizontal: isNarrow ? 8 : 12),
                  minimumSize: isNarrow ? const Size(44, 44) : null,
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
