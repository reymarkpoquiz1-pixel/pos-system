import 'package:flutter/material.dart';
import '../../auth/views/login_screen.dart';

class StoreFrontView extends StatefulWidget {
  const StoreFrontView({super.key});

  @override
  State<StoreFrontView> createState() => _StoreFrontViewState();
}

class _StoreFrontViewState extends State<StoreFrontView> {
  int _selectedIndex = 1; // Default to Catalog as in the image

  final Color primaryColor = const Color(0xFFD68A96);
  final Color secondaryColor = const Color(0xFF5D4037);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            Expanded(
              child: SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildHeroBanner(),
                      const SizedBox(height: 24),
                      _buildCategoryRow(),
                      const SizedBox(height: 24),
                      _buildProductGrid(),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: _buildBottomNavBar(),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      color: Colors.white,
      child: Row(
        children: [
          // Logo & Title
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: primaryColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(Icons.shopping_cart_checkout, color: primaryColor),
              ),
              const SizedBox(width: 12),
              const Text(
                'My POS Store',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF2D3436),
                ),
              ),
            ],
          ),
          const SizedBox(width: 40),
          // Search Bar
          Expanded(
            child: Container(
              height: 48,
              decoration: BoxDecoration(
                color: const Color(0xFFF1F2F6),
                borderRadius: BorderRadius.circular(24),
              ),
              child: const TextField(
                decoration: InputDecoration(
                  hintText: 'Search here',
                  prefixIcon: Icon(Icons.search, color: Colors.grey),
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
          ),
          const SizedBox(width: 40),
          // Login Button
          OutlinedButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const LoginScreen()),
              );
            },
            style: OutlinedButton.styleFrom(
              foregroundColor: secondaryColor,
              side: BorderSide(color: secondaryColor.withOpacity(0.5)),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
            ),
            child: const Text('LOGIN', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _buildHeroBanner() {
    return Container(
      width: double.infinity,
      height: 200,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        gradient: const LinearGradient(
          colors: [Color(0xFF2C5E5F), Color(0xFF4A8B8C)],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
      ),
      child: Stack(
        children: [
          // Background "illustrations" placeholder
          Positioned(
            right: 0, bottom: 0, top: 0,
            child: Opacity(
              opacity: 0.2,
              child: Icon(Icons.shopping_bag, size: 200, color: Colors.white),
            ),
          ),
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text(
                  'DISCOVER YOUR PERFECT CARRY!',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  '- Handcrafted Local Treasures -',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 18,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryRow() {
    final categories = [
      {'name': 'Shoulder Bags', 'icon': Icons.business_center},
      {'name': 'Backpacks', 'icon': Icons.backpack},
      {'name': 'Travel Bags', 'icon': Icons.luggage},
      {'name': 'Accessories', 'icon': Icons.wallet},
    ];

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: categories.map((cat) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 10,
                offset: const Offset(0, 4),
              )
            ],
          ),
          child: Row(
            children: [
              Icon(cat['icon'] as IconData, color: secondaryColor.withOpacity(0.7)),
              const SizedBox(width: 12),
              Text(
                cat['name'] as String,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildProductGrid() {
    final products = [
      {'name': 'Urban Canvas Backpack', 'price': '₱6,500', 'tag': ''},
      {'name': 'Classic Satchel', 'price': '₱9,800', 'tag': ''},
      {'name': 'High-Accuracy Scanner', 'price': '₱15,000', 'tag': 'STAFF FAVORITE', 'original': '₱17,000'},
      {'name': 'Weekend Duffle', 'price': '₱8,200', 'tag': ''},
      {'name': 'Premium Leather Tote', 'price': '₱12,000', 'tag': 'Premium Leather Tote'},
      {'name': 'Artisan Weave Bag', 'price': '₱7,000', 'tag': 'Artisan Weave Bag'},
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        childAspectRatio: 0.85,
        crossAxisSpacing: 24,
        mainAxisSpacing: 24,
      ),
      itemCount: products.length,
      itemBuilder: (context, index) {
        final prod = products[index];
        return _buildProductCard(prod);
      },
    );
  }

  Widget _buildProductCard(Map<String, String> prod) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 15,
            offset: const Offset(0, 8),
          )
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Image Placeholder
          Expanded(
            flex: 3,
            child: Stack(
              children: [
                Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F2F6),
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                  ),
                  child: Center(
                    child: Icon(Icons.image, size: 64, color: Colors.grey.withOpacity(0.3)),
                  ),
                ),
                if (prod['tag']!.isNotEmpty)
                  Positioned(
                    top: 12, left: 12,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: prod['tag'] == 'STAFF FAVORITE' ? Colors.orange : primaryColor,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        prod['tag']!,
                        style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          // Details
          Expanded(
            flex: 2,
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    prod['name']!,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (prod.containsKey('original'))
                        Text(
                          'Original Price ${prod['original']}',
                          style: const TextStyle(fontSize: 12, decoration: TextDecoration.lineThrough, color: Colors.grey),
                        ),
                      Text(
                        prod['price']!,
                        style: TextStyle(color: primaryColor, fontWeight: FontWeight.w900, fontSize: 18),
                      ),
                    ],
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Icon(Icons.shopping_cart_outlined, size: 20, color: secondaryColor.withOpacity(0.6)),
                      const SizedBox(width: 12),
                      Icon(Icons.visibility_outlined, size: 20, color: secondaryColor.withOpacity(0.6)),
                    ],
                  )
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomNavBar() {
    return Container(
      height: 80,
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Colors.grey.withOpacity(0.1))),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildNavItem(0, Icons.home_outlined, 'Home'),
          _buildNavItem(1, Icons.grid_view, 'Catalog'),
          _buildNavItem(2, Icons.shopping_cart_outlined, 'Cart'),
          _buildNavItem(3, Icons.person_outline, 'Me'),
        ],
      ),
    );
  }

  Widget _buildNavItem(int index, IconData icon, String label) {
    bool isSelected = _selectedIndex == index;
    return GestureDetector(
      onTap: () => setState(() => _selectedIndex = index),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: isSelected ? primaryColor : Colors.grey, size: 28),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              color: isSelected ? primaryColor : Colors.grey,
              fontSize: 12,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            ),
          ),
          if (isSelected)
            Container(
              margin: const EdgeInsets.top(4),
              height: 4, width: 24,
              decoration: BoxDecoration(color: primaryColor, borderRadius: BorderRadius.circular(2)),
            )
        ],
      ),
    );
  }
}
