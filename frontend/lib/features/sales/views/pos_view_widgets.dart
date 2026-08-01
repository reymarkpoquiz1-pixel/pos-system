import 'package:flutter/material.dart';
import 'package:pos/core/services/sync_service.dart';
import 'pos_view_dialogs.dart';

mixin PosViewWidgets on PosViewDialogs {
  Widget buildSkeletonGrid(double availableWidth) {
    int crossAxisCount = availableWidth > 1200 ? 5 : (availableWidth > 900 ? 4 : (availableWidth > 600 ? 3 : 2));
    double aspectRatio = MediaQuery.of(context).orientation == Orientation.landscape ? 0.85 : 0.75;

    return GridView.builder(
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        childAspectRatio: aspectRatio,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
      ),
      itemCount: 10,
      itemBuilder: (context, index) => Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey.shade100),
        ),
        child: Column(
          children: [
            Expanded(child: Container(color: Colors.grey.shade50)),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(height: 12, width: double.infinity, color: Colors.grey.shade100),
                  const SizedBox(height: 8),
                  Container(height: 12, width: 60, color: Colors.grey.shade100),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget buildSearchBar() {
    return Row(
      children: [
        if (isOffline)
          Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: Tooltip(
              message: 'Offline Mode: Transactions will be saved locally.',
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(color: Colors.red.shade50, borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.red.shade100)),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.cloud_off_rounded, size: 14, color: Colors.red.shade700),
                    const SizedBox(width: 4),
                    Text('OFFLINE', style: TextStyle(color: Colors.red.shade700, fontSize: 10, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
            ),
          ),
        if (pendingSyncCount > 0)
          Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: ActionChip(
              avatar: const Icon(Icons.sync_problem, size: 16, color: Colors.white),
              label: Text('Sync ($pendingSyncCount)', style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
              backgroundColor: Colors.orange.shade700,
              onPressed: () async {
                await SyncService.syncOfflineSales(context);
                updatePendingSync();
              },
            ),
          ),
        Expanded(
          child: TextField(
            controller: searchController,
            onChanged: filterProducts,
            decoration: InputDecoration(
              hintText: 'Search product...',
              prefixIcon: const Icon(Icons.search, size: 20),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade300)),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade200)),
              filled: true,
              fillColor: Colors.white,
              contentPadding: const EdgeInsets.symmetric(vertical: 0),
            ),
          ),
        ),
        IconButton(
          onPressed: showScannerDialog,
          icon: const Icon(Icons.qr_code_scanner_rounded, size: 20),
          style: IconButton.styleFrom(
            backgroundColor: Colors.purple.shade50,
            foregroundColor: Colors.purple,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
        const SizedBox(width: 10),
        IconButton(
          onPressed: fetchProducts,
          icon: const Icon(Icons.refresh, size: 20),
          style: IconButton.styleFrom(
            backgroundColor: Colors.blue.shade50,
            foregroundColor: Colors.blue,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
      ],
    );
  }

  Widget buildProductGrid(double availableWidth) {
    if (filteredProducts.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.search_off_rounded, size: 64, color: Colors.grey.shade300),
            const SizedBox(height: 16),
            Text('No products found', style: TextStyle(color: Colors.grey.shade600, fontSize: 16)),
          ],
        ),
      );
    }

    int crossAxisCount = availableWidth > 1200 ? 5 : (availableWidth > 900 ? 4 : (availableWidth > 600 ? 3 : 2));
    double aspectRatio = MediaQuery.of(context).orientation == Orientation.landscape ? 0.85 : 0.75;

    return GridView.builder(
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        childAspectRatio: aspectRatio,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
      ),
      itemCount: filteredProducts.length,
      itemBuilder: (context, index) {
        final product = filteredProducts[index];
        return PosProductCard(
          product: product,
          onTap: () => addToCart(product),
        );
      },
    );
  }

  @override
  Widget buildCartHeader() {
    return Container(
      padding: const EdgeInsets.all(16),
      color: Colors.blue.shade600,
      child: Row(
        children: [
          const Icon(Icons.shopping_cart, color: Colors.white),
          const SizedBox(width: 10),
          const Text('Current Order', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
          const Spacer(),
          TextButton.icon(
            onPressed: showCustomerSelectionDialog,
            icon: const Icon(Icons.person_add, color: Colors.white, size: 18),
            label: Text(
              selectedCustomer != null ? selectedCustomer!['name'] : 'Customer',
              style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
            ),
            style: TextButton.styleFrom(
              backgroundColor: Colors.white.withValues(alpha: 0.2),
              padding: const EdgeInsets.symmetric(horizontal: 12),
            ),
          ),
        ],
      ),
    );
  }

  Widget buildCartList() {
    if (cart.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.shopping_basket_outlined, size: 60, color: Colors.grey.shade300),
            const SizedBox(height: 10),
            const Text('Cart is empty', style: TextStyle(color: Colors.grey)),
          ],
        ),
      );
    }
    return ListView.builder(
      itemCount: cart.length,
      itemBuilder: (context, index) {
        final item = cart[index];
        final String variantInfo = [item['variant_name'], item['variant_size']]
            .where((s) => s != null && s.isNotEmpty)
            .join(', ');

        return ListTile(
          title: Text(item['name'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (variantInfo.isNotEmpty)
                Text(variantInfo, style: const TextStyle(fontSize: 11, color: Colors.blue, fontWeight: FontWeight.w600)),
              Text('₱${item['price']} x ${item['quantity']}'),
            ],
          ),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('₱${(item['price'] * item['quantity']).toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold)),
              IconButton(onPressed: () => removeFromCart(index), icon: const Icon(Icons.remove_circle_outline, color: Colors.red, size: 20)),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget buildSummaryArea() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Colors.grey.shade100)),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, -5))
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Total Amount', style: TextStyle(fontSize: 14, color: Colors.grey.shade600, fontWeight: FontWeight.bold)),
              Text('₱${totalAmount.toStringAsFixed(2)}',
                  style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: Color(0xFF1E293B))),
            ],
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            height: 60,
            child: ElevatedButton(
              onPressed: cart.isEmpty ? null : showPaymentDialog,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1E293B),
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.payments_rounded),
                  SizedBox(width: 12),
                  Text('PAY NOW', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18, letterSpacing: 1)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class PosProductCard extends StatefulWidget {
  final Map<String, dynamic> product;
  final VoidCallback onTap;

  const PosProductCard({super.key, required this.product, required this.onTap});

  @override
  State<PosProductCard> createState() => _PosProductCardState();
}

class _PosProductCardState extends State<PosProductCard> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.95).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final product = widget.product;
    int stock = int.tryParse(product['stock_quantity']?.toString() ?? '0') ?? 0;
    bool isLowStock = stock > 0 && stock <= 5;
    bool isOutOfStock = stock <= 0;

    return GestureDetector(
      onTapDown: (_) => _controller.forward(),
      onTapUp: (_) => _controller.reverse(),
      onTapCancel: () => _controller.reverse(),
      onTap: widget.onTap,
      child: ScaleTransition(
        scale: _scaleAnimation,
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
            border: Border.all(
              color: isOutOfStock ? Colors.red.withValues(alpha: 0.1) : Colors.grey.shade100,
              width: 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Stack(
                  children: [
                    Container(
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade50,
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                      ),
                      child: Center(
                        child: Icon(
                          Icons.inventory_2_rounded,
                          size: 40,
                          color: isOutOfStock ? Colors.grey.shade300 : Colors.blue.shade100
                        ),
                      ),
                    ),
                    if (isLowStock || isOutOfStock)
                      Positioned(
                        top: 8,
                        right: 8,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: isOutOfStock ? Colors.red : Colors.orange,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            isOutOfStock ? 'OUT OF STOCK' : 'LOW STOCK',
                            style: const TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      product['name'] ?? '',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF1E293B)),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '₱${product['selling_price']}',
                          style: TextStyle(
                            color: isOutOfStock ? Colors.grey : Colors.blue.shade700,
                            fontWeight: FontWeight.w900,
                            fontSize: 15,
                          ),
                        ),
                        Text(
                          'QTY: $stock',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: isOutOfStock ? Colors.red : Colors.grey.shade500,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
