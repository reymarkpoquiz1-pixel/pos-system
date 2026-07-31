import 'package:flutter/material.dart';
import '../product_grid_card.dart';

class ProductMasterList extends StatelessWidget {
  final List<dynamic> products;
  final String searchQuery;
  final dynamic selectedProduct;
  final Function(Map<String, dynamic>?) onSelectProduct;

  const ProductMasterList({
    super.key,
    required this.products,
    required this.searchQuery,
    required this.selectedProduct,
    required this.onSelectProduct,
  });

  List<dynamic> get _filteredProducts {
    return products.where((prod) {
      final status = (prod['status'] ?? 'Active').toString();
      if (status == 'Archived') return false;
      
      final name = (prod['name'] ?? '').toString().toLowerCase();
      final barcode = (prod['barcode'] ?? '').toString().toLowerCase();
      return name.contains(searchQuery.toLowerCase()) || barcode.contains(searchQuery.toLowerCase());
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    if (_filteredProducts.isEmpty) {
      return const Center(child: Text('No products found.'));
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        // Dynamic grid configuration
        int crossAxisCount = 3;
        double aspectRatio = 0.75;

        if (constraints.maxWidth < 600) {
          crossAxisCount = 2; // 2 columns for mobile
          aspectRatio = 0.65; // Taller cards for mobile to prevent overflow
        } else if (constraints.maxWidth > 1200) {
          crossAxisCount = 4; // 4 columns for large screens
        }

        return GridView.builder(
          padding: const EdgeInsets.all(16),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            childAspectRatio: aspectRatio,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
          ),
          itemCount: _filteredProducts.length,
          itemBuilder: (context, index) {
            final prod = _filteredProducts[index];
            final isSelected = selectedProduct != null && selectedProduct['id'].toString() == prod['id'].toString();
            
            return Container(
              decoration: isSelected ? BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFFD68A96), width: 2),
              ) : null,
              child: ProductGridCard(
                product: prod,
                onTap: () => onSelectProduct(prod),
              ),
            );
          },
        );
      },
    );
  }
}
