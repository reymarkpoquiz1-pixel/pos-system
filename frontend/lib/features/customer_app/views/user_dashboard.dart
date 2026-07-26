import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:pos/core/services/api_service.dart';
import 'package:pos/core/constants/config.dart';
import 'package:pos/features/auth/views/login_screen.dart';
import 'product_details_view.dart';
import '../services/cart_service.dart';
import 'cart_view.dart';
import 'wishlist_view.dart';
import 'order_history_view.dart';

class UserDashboard extends StatefulWidget {
  final String username;
  final int userId;
  final String storeName;
  final String? logoUrl;
  const UserDashboard({super.key, required this.username, required this.userId, this.storeName = 'My POS Store', this.logoUrl});

  @override
  State<UserDashboard> createState() => _UserDashboardState();
}

class _UserDashboardState extends State<UserDashboard> {
  bool _isLoading = true;
  List<dynamic> _categories = [];
  List<dynamic> _products = [];
  String _selectedCategoryId = '0'; // '0' means All
  final TextEditingController _searchController = TextEditingController();

  static const Color primaryColor = Color(0xFFD68A96);
  static const Color bgColor = Color(0xFFF7E6E9);

  @override
  void initState() {
    super.initState();
    _fetchInitialData();
  }

  Future<void> _fetchInitialData() async {
    setState(() => _isLoading = true);
    try {
      final responses = await Future.wait([
        ApiService.get('category/get_user_categories'),
        ApiService.get('products/get_user_products'),
      ]);

      if (responses.every((res) => res.statusCode == 200)) {
        final catData = json.decode(responses[0].body);
        final prodData = json.decode(responses[1].body);

        setState(() {
          _categories = catData['categories'] ?? [];
          _products = prodData['products'] ?? [];
          _isLoading = false;
        });
      } else {
        if (mounted) {
          setState(() => _isLoading = false);
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Failed to load data from server.')));
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  Future<void> _filterProducts({String? categoryId, String? search}) async {
    setState(() => _isLoading = true);
    try {
      String url = 'products/get_user_products?';
      if (categoryId != null && categoryId != '0') url += 'category_id=$categoryId&';
      if (search != null) url += 'search=$search';

      final response = await ApiService.get(url);
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        setState(() {
          _products = data['products'] ?? [];
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String _getImageUrl(String url) {
    if (url.isEmpty) return '';
    if (url.startsWith('http')) return url;
    String path = url.trim();
    if (path.startsWith('/')) path = path.substring(1);
    if (!path.startsWith('uploads/') && !path.startsWith('assets/')) {
      path = 'uploads/products/$path';
    }
    return '$baseUrl/$path';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Row(
          children: [
            if (widget.logoUrl != null)
              Container(
                width: 32,
                height: 32,
                margin: const EdgeInsets.only(right: 12),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  image: DecorationImage(
                    image: NetworkImage('$baseUrl/${widget.logoUrl}'),
                    fit: BoxFit.contain,
                    onError: (exception, stackTrace) {
                      debugPrint('User app bar logo error: $exception');
                    },
                  ),
                ),
              ),
            Text(
              widget.storeName,
              style: const TextStyle(color: primaryColor, fontWeight: FontWeight.w900, fontSize: 24),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.favorite_border, color: Colors.black87),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => WishlistView(userId: widget.userId)),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.receipt_long_outlined, color: Colors.black87),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => OrderHistoryView(userId: widget.userId)),
              );
            },
          ),
          ListenableBuilder(
            listenable: CartService(),
            builder: (context, child) {
              int count = CartService().itemCount;
              return Stack(
                alignment: Alignment.center,
                children: [
                  IconButton(
                    icon: const Icon(Icons.shopping_cart_outlined, color: Colors.black87),
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => CartView(userId: widget.userId)),
                      );
                    },
                  ),
                  if (count > 0)
                    Positioned(
                      right: 8,
                      top: 8,
                      child: Container(
                        padding: const EdgeInsets.all(2),
                        decoration: BoxDecoration(color: Colors.red, borderRadius: BorderRadius.circular(10)),
                        constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                        child: Text(
                          '$count',
                          style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.black87),
            onPressed: () {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (context) => const LoginScreen()),
              );
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: primaryColor))
          : Column(
              children: [
                _buildSearchBar(),
                _buildCategoryList(),
                Expanded(child: _buildProductGrid()),
              ],
            ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      padding: const EdgeInsets.all(16),
      color: Colors.white,
      child: TextField(
        controller: _searchController,
        onChanged: (val) => _filterProducts(categoryId: _selectedCategoryId, search: val),
        decoration: InputDecoration(
          hintText: 'Search products...',
          prefixIcon: const Icon(Icons.search, color: primaryColor),
          filled: true,
          fillColor: bgColor.withValues(alpha: 0.5),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(15),
            borderSide: BorderSide.none,
          ),
          contentPadding: const EdgeInsets.symmetric(vertical: 0),
        ),
      ),
    );
  }

  Widget _buildCategoryList() {
    return Container(
      height: 60,
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: _categories.length + 1,
        itemBuilder: (context, index) {
          final bool isAll = index == 0;
          final String catId = isAll ? '0' : _categories[index - 1]['id'].toString();
          final String catName = isAll ? 'All' : _categories[index - 1]['name'];
          final bool isSelected = _selectedCategoryId == catId;

          return GestureDetector(
            onTap: () {
              setState(() => _selectedCategoryId = catId);
              _filterProducts(categoryId: catId, search: _searchController.text);
            },
            child: Container(
              margin: const EdgeInsets.only(right: 10),
              padding: const EdgeInsets.symmetric(horizontal: 20),
              decoration: BoxDecoration(
                color: isSelected ? primaryColor : Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  if (isSelected)
                    BoxShadow(color: primaryColor.withValues(alpha: 0.3), blurRadius: 8, offset: const Offset(0, 4))
                ],
              ),
              child: Center(
                child: Text(
                  catName,
                  style: TextStyle(
                    color: isSelected ? Colors.white : Colors.black87,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildProductGrid() {
    if (_products.isEmpty) {
      return const Center(child: Text('No products found.', style: TextStyle(color: Colors.grey)));
    }

    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 0.75,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
      ),
      itemCount: _products.length,
      itemBuilder: (context, index) {
        final prod = _products[index];
        return GestureDetector(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => ProductDetailsView(product: prod)),
            );
          },
          child: _buildProductCard(prod),
        );
      },
    );
  }

  Widget _buildProductCard(dynamic prod) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(25),
        boxShadow: [
          BoxShadow(color: primaryColor.withValues(alpha: 0.1), blurRadius: 20, offset: const Offset(0, 10))
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(25),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Stack(
                children: [
                  Container(
                    decoration: BoxDecoration(
                      color: bgColor,
                      image: prod['image_url'] != null
                          ? DecorationImage(
                              image: NetworkImage(_getImageUrl(prod['image_url'].toString())),
                              fit: BoxFit.cover,
                              onError: (exception, stackTrace) {
                                debugPrint('User product card image error: $exception');
                              },
                            )
                          : null,
                    ),
                    child: prod['image_url'] == null
                        ? const Center(child: Icon(Icons.image_not_supported_outlined, color: Colors.grey))
                        : null,
                  ),
                  Positioned(
                    top: 10, right: 10,
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                      child: const Icon(Icons.favorite_border, size: 18, color: primaryColor),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(15),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    prod['name'] ?? 'Product',
                    style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: Color(0xFF1C1B1F)),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '₱${prod['selling_price']}',
                        style: const TextStyle(color: primaryColor, fontWeight: FontWeight.w900, fontSize: 18),
                      ),
                      GestureDetector(
                        onTap: () {
                          CartService().addToCart(CartItem(
                            id: prod['id'].toString(),
                            name: prod['name'],
                            price: double.parse(prod['selling_price'].toString()),
                            imageUrl: prod['image_url'] != null
                                ? _getImageUrl(prod['image_url'].toString())
                                : '',
                          ));
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Added to cart!'), backgroundColor: Colors.green, duration: Duration(seconds: 1)),
                          );
                        },
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(color: primaryColor, borderRadius: BorderRadius.circular(10)),
                          child: const Icon(Icons.add_shopping_cart, color: Colors.white, size: 18),
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
    );
  }
}
