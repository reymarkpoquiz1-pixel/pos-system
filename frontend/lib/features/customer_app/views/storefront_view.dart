import 'package:flutter/material.dart';
import 'dart:convert';
import '../../../core/services/api_service.dart';
import '../../../core/constants/config.dart';
import '../../auth/views/login_screen.dart';

class StoreFrontView extends StatefulWidget {
  const StoreFrontView({super.key});

  @override
  State<StoreFrontView> createState() => _StoreFrontViewState();
}

class _StoreFrontViewState extends State<StoreFrontView> {
  int _selectedIndex = 1; // Default to Catalog
  bool _isLoading = true;
  List<dynamic> _categories = [];
  List<dynamic> _products = [];
  String _selectedCategoryId = '0';
  final TextEditingController _searchController = TextEditingController();

  // Colors matching the original target image
  final Color primaryTeal = const Color(0xFF007A78);
  final Color accentOrange = const Color(0xFFD65C4F);
  final Color darkTextColor = const Color(0xFF222222);
  final Color lightBgColor = const Color(0xFFF3F4F6);

  @override
  void initState() {
    super.initState();
    _fetchInitialData();
  }

  Future<void> _fetchInitialData() async {
    setState(() => _isLoading = true);
    try {
      final responses = await Future.wait([
        ApiService.get('category/get_categories'),
        ApiService.get('products/get_products'),
      ]);

      if (responses[0].statusCode == 200 && responses[1].statusCode == 200) {
        final catData = json.decode(responses[0].body);
        final prodData = json.decode(responses[1].body);

        setState(() {
          _categories = catData['categories'] ?? catData['data'] ?? [];
          _products = prodData['products'] ?? prodData['data'] ?? [];
          _isLoading = false;
        });
      } else {
        if (mounted) setState(() => _isLoading = false);
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _filterProducts({String? categoryId, String? search}) async {
    setState(() => _isLoading = true);
    try {
      String url = 'products/get_products?';
      if (categoryId != null && categoryId != '0') url += 'category_id=$categoryId&';
      if (search != null && search.isNotEmpty) url += 'search=$search';

      final response = await ApiService.get(url);
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        setState(() {
          _products = data['products'] ?? data['data'] ?? [];
          _isLoading = false;
        });
      } else {
        if (mounted) setState(() => _isLoading = false);
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String _getImageUrl(dynamic prod) {
    var imagesData = prod['images'] ?? prod['product_images'] ?? prod['gallery'] ?? prod['image_url'];
    String? firstImage;

    if (imagesData != null && imagesData.toString().isNotEmpty) {
      if (imagesData is String) {
        String trimmed = imagesData.trim();
        if (trimmed.startsWith('[') && trimmed.endsWith(']')) {
          try {
            List<dynamic> list = json.decode(trimmed);
            if (list.isNotEmpty) firstImage = list[0].toString();
          } catch (_) {}
        } else if (trimmed.contains(',')) {
          firstImage = trimmed.split(',')[0].trim();
        } else {
          firstImage = trimmed;
        }
      } else if (imagesData is List && imagesData.isNotEmpty) {
        firstImage = imagesData[0].toString();
      }
    }

    if (firstImage == null || firstImage.isEmpty) return '';
    if (firstImage.startsWith('http')) return firstImage;

    String path = firstImage.trim();
    if (path.startsWith('/')) path = path.substring(1);

    if (!path.startsWith('uploads/') && !path.startsWith('assets/')) {
      path = 'uploads/products/$path';
    }
    return '$baseUrl/$path';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: lightBgColor,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            Expanded(
              child: _isLoading
                  ? Center(child: CircularProgressIndicator(color: primaryTeal))
                  : RefreshIndicator(
                onRefresh: _fetchInitialData,
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      // TOP SECTION: Left (Banner + Categories) vs Right (Top Featured Products)
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // LEFT SIDE
                          Expanded(
                            flex: 6,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildHeroBanner(),
                                const SizedBox(height: 16),
                                _buildCategoryRow(),
                              ],
                            ),
                          ),
                          const SizedBox(width: 16),
                          // RIGHT SIDE: 2 Top Featured Cards side-by-side
                          if (_products.isNotEmpty)
                            Expanded(
                              flex: 4,
                              child: Row(
                                children: [
                                  Expanded(child: _buildTopFeaturedCard(_products[0], _products[0]['product_line'] ?? 'Featured')),
                                  if (_products.length > 1) ...[
                                    const SizedBox(width: 8),
                                    Expanded(child: _buildTopFeaturedCard(_products[1], _products[1]['product_line'] ?? 'Trending')),
                                  ],
                                ],
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      _buildMainProductGrid(),
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
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      color: Colors.white,
      child: Row(
        children: [
          Row(
            children: [
              Icon(Icons.shopping_cart_outlined, color: primaryTeal, size: 28),
              const SizedBox(width: 8),
              Text(
                'My POS Store',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: darkTextColor),
              ),
            ],
          ),
          const SizedBox(width: 24),
          Expanded(
            child: Container(
              height: 40,
              decoration: BoxDecoration(
                color: const Color(0xFFF0F2F5),
                borderRadius: BorderRadius.circular(20),
              ),
              child: TextField(
                controller: _searchController,
                onChanged: (val) => _filterProducts(categoryId: _selectedCategoryId, search: val),
                decoration: const InputDecoration(
                  hintText: 'Search here',
                  hintStyle: TextStyle(fontSize: 13, color: Colors.grey),
                  prefixIcon: Icon(Icons.search, color: Colors.grey, size: 18),
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(vertical: 8),
                ),
              ),
            ),
          ),
          const SizedBox(width: 24),
          OutlinedButton(
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const LoginScreen())),
            style: OutlinedButton.styleFrom(
              foregroundColor: accentOrange,
              side: BorderSide(color: accentOrange, width: 1.5),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            ),
            child: const Text('LOGIN', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
          ),
        ],
      ),
    );
  }

  Widget _buildHeroBanner() {
    return Container(
      width: double.infinity,
      height: 180,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        gradient: const LinearGradient(
          colors: [Color(0xFF005F5D), Color(0xFF008985)],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
      ),
      child: Stack(
        children: [
          Positioned(
            right: -10, bottom: -10, top: -10,
            child: Opacity(
              opacity: 0.15,
              child: const Icon(Icons.shopping_bag_outlined, size: 200, color: Colors.white),
            ),
          ),
          const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'DISCOVER YOUR PERFECT CARRY!',
                  style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w900, letterSpacing: 1),
                ),
                SizedBox(height: 4),
                Text(
                  '- Handcrafted Local Treasures -',
                  style: TextStyle(color: Colors.white70, fontSize: 14, fontStyle: FontStyle.italic),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryRow() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _buildCategoryItem('0', 'All Categories', Icons.grid_view_rounded),
          if (_categories.isNotEmpty)
            ..._categories.map((cat) => _buildCategoryItem(cat['id'].toString(), cat['name'] ?? 'Category', Icons.category_outlined)),
        ],
      ),
    );
  }

  Widget _buildCategoryItem(String id, String name, IconData icon) {
    bool isSelected = _selectedCategoryId == id;
    return GestureDetector(
      onTap: () {
        setState(() => _selectedCategoryId = id);
        _filterProducts(categoryId: id, search: _searchController.text);
      },
      child: Container(
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: isSelected ? primaryTeal : Colors.grey.shade300),
        ),
        child: Row(
          children: [
            Icon(icon, color: isSelected ? primaryTeal : accentOrange, size: 18),
            const SizedBox(width: 6),
            Text(name, style: TextStyle(fontWeight: isSelected ? FontWeight.bold : FontWeight.normal, fontSize: 12)),
          ],
        ),
      ),
    );
  }

  // Top Featured Product Card (Placed beside the Hero Banner)
  Widget _buildTopFeaturedCard(dynamic prod, String tagTitle) {
    String imageUrl = _getImageUrl(prod);
    return Container(
      height: 235,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Stack(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 6,
                child: ClipRRect(
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(10)),
                  child: imageUrl.isNotEmpty
                      ? Image.network(imageUrl, width: double.infinity, fit: BoxFit.cover)
                      : Container(color: Colors.grey.shade100, child: const Icon(Icons.image, color: Colors.grey)),
                ),
              ),
              Expanded(
                flex: 4,
                child: Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        prod['name'] ?? 'Featured Product',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text('₱${prod['selling_price'] ?? '0'}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Icon(Icons.add_shopping_cart, size: 16, color: primaryTeal),
                          const SizedBox(width: 6),
                          Icon(Icons.visibility_outlined, size: 16, color: primaryTeal),
                        ],
                      )
                    ],
                  ),
                ),
              ),
            ],
          ),
          // Top Red Badge Tag
          Positioned(
            top: 0, left: 0,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: accentOrange,
                borderRadius: const BorderRadius.only(topLeft: Radius.circular(10), bottomRight: Radius.circular(8)),
              ),
              child: Text(
                tagTitle,
                style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold),
              ),
            ),
          )
        ],
      ),
    );
  }

  // Bottom Main Grid (4 Columns as seen in target design)
  Widget _buildMainProductGrid() {
    if (_products.isEmpty) return const SizedBox();

    // Showing rest of products in a 4-column layout
    var gridProducts = _products.length > 2 ? _products.sublist(2) : _products;

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 4, // Changed to 4 Columns matching image_75051f.jpg
        childAspectRatio: 0.70,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
      ),
      itemCount: gridProducts.length,
      itemBuilder: (context, index) {
        final prod = gridProducts[index];
        // Dynamic check: Show "STAFF" badge only if product has the 'staff favorite' tag
        bool isStaffFavorite = false;
        if (prod['tags'] != null) {
          try {
            var tagsData = prod['tags'];
            List<dynamic> tagsList = (tagsData is String) ? json.decode(tagsData) : tagsData;
            isStaffFavorite = tagsList.any((t) => t.toString().toLowerCase() == 'staff favorite');
          } catch (_) {}
        }

        return _buildStandardProductCard(prod, isStaffFavorite: isStaffFavorite);
      },
    );
  }

  Widget _buildStandardProductCard(dynamic prod, {bool isStaffFavorite = false}) {
    String imageUrl = _getImageUrl(prod);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Stack(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 5,
                child: Container(
                  width: double.infinity,
                  color: Colors.grey.shade50,
                  child: ClipRRect(
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(10)),
                    child: imageUrl.isNotEmpty
                        ? Image.network(imageUrl, fit: BoxFit.cover)
                        : const Icon(Icons.image, color: Colors.grey),
                  ),
                ),
              ),
              Expanded(
                flex: 5,
                child: Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        prod['name'] ?? 'Product Name',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Original Price PX', style: TextStyle(fontSize: 9, color: Colors.grey)),
                          Text('₱${prod['selling_price'] ?? '0'}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          // STAFF FAVORITE Badge Icon in Center if applicable
          if (isStaffFavorite)
            Positioned(
              top: 40, left: 20, right: 20,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF324B53),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Column(
                  children: [
                    Text('STAFF', style: TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.bold)),
                    Text('FAVORITE', style: TextStyle(color: Colors.white, fontSize: 7)),
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
      height: 65,
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Colors.grey.shade200)),
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
        mainAxisAlignment: MainAxisAlignment.start,
        children: [
          Container(
            height: 4, width: 40,
            decoration: BoxDecoration(
              color: isSelected ? accentOrange : Colors.transparent,
              borderRadius: const BorderRadius.vertical(bottom: Radius.circular(4)),
            ),
          ),
          const SizedBox(height: 6),
          Icon(icon, color: isSelected ? primaryTeal : Colors.grey.shade600, size: 20),
          Text(label, style: TextStyle(color: isSelected ? primaryTeal : Colors.grey.shade600, fontSize: 10)),
        ],
      ),
    );
  }
}