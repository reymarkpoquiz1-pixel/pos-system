import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:pos/core/services/api_service.dart';
import 'package:pos/core/constants/config.dart';
import '../services/cart_service.dart';

class ProductDetailsView extends StatefulWidget {
  final dynamic product;
  const ProductDetailsView({super.key, required this.product});

  @override
  State<ProductDetailsView> createState() => _ProductDetailsViewState();
}

class _ProductDetailsViewState extends State<ProductDetailsView> {
  List<dynamic> _variants = [];
  List<dynamic> _recommendations = [];
  Map<String, dynamic>? _selectedVariant;
  int _quantity = 1;
  bool _isWishlisted = false;

  static const Color primaryColor = Color(0xFFD68A96);
  static const Color bgColor = Color(0xFFF7E6E9);

  @override
  void initState() {
    super.initState();
    _parseVariants();
    _fetchRecommendations();
  }

  Future<void> _fetchRecommendations() async {
    try {
      final response = await ApiService.get('products/get_recommendations?product_id=${widget.product['id']}');
      final data = json.decode(response.body);
      if (data['success']) {
        setState(() => _recommendations = data['recommendations'] ?? []);
      }
    } catch (e) {
      debugPrint('Recs Error: $e');
    }
  }

  Future<void> _toggleWishlist() async {
    final prefs = await SharedPreferences.getInstance();
    final int userId = prefs.getInt('user_id') ?? 0;
    if (userId == 0) return;

    try {
      final response = await ApiService.post('products/add_to_wishlist', {
        'user_id': userId,
        'product_id': widget.product['id'],
      });
      final data = jsonDecode(response.body);
      if (data['success']) {
        setState(() => _isWishlisted = data['status'] == 'added');
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(data['status'] == 'added' ? 'Added to Wishlist!' : 'Removed from Wishlist'), duration: const Duration(seconds: 1)),
        );
      }
    } catch (e) {
      debugPrint('Wishlist Error: $e');
    }
  }

  void _showReviewDialog() {
    final commentController = TextEditingController();
    int rating = 5;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text('Write a Review'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(5, (index) => IconButton(
                  icon: Icon(index < rating ? Icons.star : Icons.star_border, color: Colors.orange),
                  onPressed: () => setDialogState(() => rating = index + 1),
                )),
              ),
              TextField(
                controller: commentController,
                maxLines: 3,
                decoration: const InputDecoration(hintText: 'Share your experience...', border: OutlineInputBorder()),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () async {
                final messenger = ScaffoldMessenger.of(context);
                final navigator = Navigator.of(context);
                final prefs = await SharedPreferences.getInstance();
                if (!mounted) return;
                final int userId = prefs.getInt('user_id') ?? 0;
                if (userId == 0) return;

                final response = await ApiService.post('products/submit_review', {
                  'user_id': userId,
                  'product_id': widget.product['id'],
                  'rating': rating,
                  'comment': commentController.text,
                });
                if (jsonDecode(response.body)['success']) {
                  navigator.pop();
                  messenger.showSnackBar(const SnackBar(content: Text('Review submitted for moderation!'), backgroundColor: Colors.green));
                }
              },
              style: ElevatedButton.styleFrom(backgroundColor: primaryColor, foregroundColor: Colors.white),
              child: const Text('Submit Review'),
            ),
          ],
        ),
      ),
    );
  }

  void _parseVariants() {
    if (widget.product['variants'] != null) {
      try {
        final variantsData = widget.product['variants'];
        _variants = (variantsData is String) ? json.decode(variantsData) : variantsData;
        if (_variants.isNotEmpty) {
          _selectedVariant = _variants[0];
        }
      } catch (e) {
        debugPrint('Error parsing variants: $e');
      }
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
    final prod = widget.product;
    final String imageUrl = prod['image_url'] != null
        ? _getImageUrl(prod['image_url'].toString())
        : '';

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.black87),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: Icon(_isWishlisted ? Icons.favorite : Icons.favorite_border, color: _isWishlisted ? Colors.red : Colors.black87),
            onPressed: _toggleWishlist,
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Product Image
            Container(
              height: 350,
              width: double.infinity,
              decoration: BoxDecoration(
                color: bgColor,
                image: imageUrl.isNotEmpty
                    ? DecorationImage(
                        image: NetworkImage(imageUrl),
                        fit: BoxFit.cover,
                        onError: (exception, stackTrace) {
                          debugPrint('Product detail image error: $exception');
                        },
                      )
                    : null,
              ),
              child: imageUrl.isEmpty
                  ? const Center(child: Icon(Icons.image_not_supported_outlined, size: 80, color: Colors.grey))
                  : null,
            ),
            Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          prod['name'] ?? 'Product',
                          style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: Color(0xFF1C1B1F)),
                        ),
                      ),
                      Text(
                        '₱${prod['selling_price']}',
                        style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: primaryColor),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    prod['category_name'] ?? 'General Category',
                    style: const TextStyle(color: Colors.grey, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 24),
                  const Text('Description', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Text(
                    prod['description'] ?? 'No description available.',
                    style: const TextStyle(fontSize: 14, color: Colors.black54, height: 1.5),
                  ),
                  const SizedBox(height: 24),

                  // Variants Picker
                  if (_variants.isNotEmpty) ...[
                    const Text('Select Variant', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 12),
                    SizedBox(
                      height: 50,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        itemCount: _variants.length,
                        itemBuilder: (context, index) {
                          final variant = _variants[index];
                          final bool isSelected = _selectedVariant == variant;
                          return GestureDetector(
                            onTap: () => setState(() => _selectedVariant = variant),
                            child: Container(
                              margin: const EdgeInsets.only(right: 12),
                              padding: const EdgeInsets.symmetric(horizontal: 16),
                              decoration: BoxDecoration(
                                color: isSelected ? primaryColor : Colors.white,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: isSelected ? primaryColor : Colors.grey.shade300),
                              ),
                              child: Center(
                                child: Text(
                                  '${variant['color_name']} - ${variant['size']}',
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
                    ),
                    const SizedBox(height: 24),
                  ],

                  // Quantity Selector
                  Row(
                    children: [
                      const Text('Quantity', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      const Spacer(),
                      _quantityBtn(Icons.remove, () {
                        if (_quantity > 1) setState(() => _quantity--);
                      }),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: Text('$_quantity', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      ),
                      _quantityBtn(Icons.add, () => setState(() => _quantity++)),
                    ],
                  ),
                  const SizedBox(height: 40),

                  // AI Recommendations
                  if (_recommendations.isNotEmpty) ...[
                    const Text('You may also like', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 16),
                    SizedBox(
                      height: 180,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        itemCount: _recommendations.length,
                        itemBuilder: (context, index) {
                          final rec = _recommendations[index];
                          return _buildRecommendationCard(rec);
                        },
                      ),
                    ),
                    const SizedBox(height: 40),
                  ],

                  // Review Button
                  Center(
                    child: TextButton.icon(
                      onPressed: _showReviewDialog,
                      icon: const Icon(Icons.rate_review_outlined, color: primaryColor),
                      label: const Text('Write a Product Review', style: TextStyle(color: primaryColor, fontWeight: FontWeight.bold)),
                    ),
                  ),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [BoxShadow(color: Colors.black.withAlpha(26), blurRadius: 20, offset: const Offset(0, -5))],
        ),
        child: Row(
          children: [
            Expanded(
              child: ElevatedButton(
                onPressed: () {
                  CartService().addToCart(CartItem(
                    id: prod['id'].toString(),
                    name: prod['name'],
                    price: double.parse(prod['selling_price'].toString()),
                    imageUrl: imageUrl,
                    selectedVariant: _selectedVariant,
                    quantity: _quantity,
                  ));
                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Added to cart!'), backgroundColor: Colors.green),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryColor,
                  foregroundColor: Colors.white,
                  minimumSize: const Size.fromHeight(55),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                  elevation: 0,
                ),
                child: const Text('Add to Cart', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _quantityBtn(IconData icon, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, size: 20, color: primaryColor),
      ),
    );
  }

  Widget _buildRecommendationCard(dynamic prod) {
    final String imageUrl = prod['image_url'] != null
        ? _getImageUrl(prod['image_url'].toString())
        : '';

    return GestureDetector(
      onTap: () {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => ProductDetailsView(product: prod)),
        );
      },
      child: Container(
        width: 140,
        margin: const EdgeInsets.only(right: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(15),
          boxShadow: [BoxShadow(color: Colors.black.withAlpha(13), blurRadius: 10)],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(15)),
                child: Container(
                  width: double.infinity,
                  color: bgColor,
                  child: imageUrl.isNotEmpty
                      ? Image.network(
                          imageUrl,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) => const Icon(Icons.image_not_supported_outlined, color: Colors.grey),
                        )
                      : const Icon(Icons.image_not_supported_outlined, color: Colors.grey),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(prod['name'] ?? 'Product', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold), maxLines: 1, overflow: TextOverflow.ellipsis),
                  Text('₱${prod['selling_price']}', style: const TextStyle(fontSize: 12, color: primaryColor, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
