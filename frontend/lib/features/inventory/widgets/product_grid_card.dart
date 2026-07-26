import 'dart:io' show File;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:pos/core/constants/config.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:pos/core/widgets/dashboard_widgets.dart';

class ProductGridCard extends StatefulWidget {
  final Map<String, dynamic> product;
  final VoidCallback onTap;

  const ProductGridCard({super.key, required this.product, required this.onTap});

  @override
  State<ProductGridCard> createState() => _ProductGridCardState();
}

class _ProductGridCardState extends State<ProductGridCard> {
  int _activeImgIdx = 0;
  List<String> _images = [];

  @override
  void initState() {
    super.initState();
    _parseImages();
  }

  @override
  void didUpdateWidget(ProductGridCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.product != oldWidget.product) {
      _parseImages();
    }
  }

  void _parseImages() {
    final prod = widget.product;
    var imagesData = prod['images'] ?? prod['product_images'] ?? prod['gallery'];

    if (imagesData != null && imagesData.toString().isNotEmpty) {
      try {
        if (imagesData is String) {
          String trimmed = imagesData.trim();
          if (trimmed.startsWith('[') && trimmed.endsWith(']')) {
            _images = List<String>.from(json.decode(trimmed));
          } else {
            _images = trimmed.split(',').map((s) => s.trim()).where((s) => s.isNotEmpty).toList();
          }
        } else if (imagesData is List) {
          _images = imagesData.map((e) => e.toString()).toList();
        }
      } catch (e) {
        debugPrint("Error parsing card images: $e");
      }
    }

    String mainImg = (prod['image_url'] ?? '').toString().trim();
    if (mainImg.isNotEmpty && !_images.contains(mainImg)) {
      _images.insert(0, mainImg);
    }
  }

  String _getImageUrl(String url) {
    if (url.isEmpty) return '';
    if (url.startsWith('http')) return url;
    
    // Normalize path
    String path = url.trim();
    if (path.startsWith('/')) path = path.substring(1);
    
    // If it doesn't start with uploads/ or assets/, assume it's in uploads/products/
    // unless it's a known legacy path
    if (!path.startsWith('uploads/') && !path.startsWith('assets/')) {
      path = 'uploads/products/$path';
    }
    
    return '$baseUrl/$path';
  }

  List<String> _parseTags(dynamic tagsData) {
    try {
      if (tagsData is String) {
        return List<String>.from(json.decode(tagsData));
      } else if (tagsData is List) {
        return tagsData.map((e) => e.toString()).toList();
      }
    } catch (e) {
      debugPrint("Error parsing tags: $e");
    }
    return [];
  }

  Widget _buildVariantsSummary(dynamic variantsData, String styleLabel, double availableWidth) {
    try {
      if (variantsData == null) return const SizedBox.shrink();
      List<dynamic> variants = (variantsData is String) ? json.decode(variantsData) : variantsData;

      Set<String> sizes = {};
      List<Color> colorDots = [];

      for (var v in variants) {
        if (v['color_hex'] != null) {
          try {
            String hex = v['color_hex'].toString().replaceFirst('#', '');
            if (hex.length == 6) hex = 'FF$hex';
            colorDots.add(Color(int.parse(hex, radix: 16)));
          } catch (_) {}
        }
        if (v['size'] != null && v['size'].toString().isNotEmpty) {
          sizes.add(v['size'].toString());
        }
      }

      // More sensitive narrow detection
      bool isExtraNarrow = availableWidth < 160;

      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // COLOR
          Expanded(
            flex: 1,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text('COLOR', softWrap: false, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: Colors.black)),
                ),
                const SizedBox(height: 6),
                if (colorDots.isNotEmpty)
                  Wrap(
                    spacing: 3,
                    runSpacing: 3,
                    children: colorDots.take(isExtraNarrow ? 1 : 3).map((c) => Container(
                      width: 9,
                      height: 9,
                      decoration: BoxDecoration(color: c, shape: BoxShape.circle, border: Border.all(color: Colors.black12, width: 0.5)),
                    )).toList(),
                  )
                else
                  const Text('—', style: TextStyle(fontSize: 10, color: Colors.grey)),
              ],
            ),
          ),
          const SizedBox(width: 4),
          // SIZE
          Expanded(
            flex: 1,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text('SIZE', softWrap: false, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: Colors.black)),
                ),
                const SizedBox(height: 6),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    sizes.isEmpty ? 'N/A' : sizes.join(', '),
                    style: const TextStyle(fontSize: 11, color: Colors.black, fontWeight: FontWeight.w400),
                  ),
                ),
              ],
            ),
          ),
        ],
      );
    } catch (e) {
      return const SizedBox.shrink();
    }
  }

  Widget _buildMainImage(Map<String, dynamic> prod, String displayImg) {
    // 1. Check for local preview path first (Optimistic UI)
    final String? localPath = prod['local_image_path'];
    if (localPath != null && localPath.isNotEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: kIsWeb 
          ? Image.network(localPath, fit: BoxFit.contain)
          : Image.file(File(localPath), fit: BoxFit.contain),
      );
    }

    // 2. Fallback to Network Image (With Advanced Caching)
    if (displayImg.isNotEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: CachedNetworkImage(
          imageUrl: _getImageUrl(displayImg),
          fit: BoxFit.contain,
          width: double.infinity,
          height: double.infinity,
          // Optimization: Scale down image in cache to save memory
          maxWidthDiskCache: 400,
          maxHeightDiskCache: 400,
          placeholder: (context, url) => const Center(
            child: SkeletonLoader(width: double.infinity, height: double.infinity, borderRadius: 16),
          ),
          errorWidget: (context, url, error) => Container(
            color: Colors.grey.shade100,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.image_not_supported_outlined, color: Colors.grey.shade400, size: 32),
                const SizedBox(height: 4),
                Text('No Image', style: TextStyle(color: Colors.grey.shade400, fontSize: 8)),
              ],
            ),
          ),
        ),
      );
    }

    return const Center(child: Icon(Icons.image_outlined, color: Colors.grey, size: 36));
  }

  @override
  Widget build(BuildContext context) {
    final prod = widget.product;
    int stock = int.tryParse(prod['stock_quantity']?.toString() ?? '0') ?? 0;
    int reorder = int.tryParse(prod['reorder_level']?.toString() ?? '20') ?? 20;

    bool isLowStock = stock <= reorder && stock > 0;
    bool isOutOfStock = stock <= 0;

    String displayImg = _images.isNotEmpty ? _images[_activeImgIdx] : '';
    String styleLabel = (prod['product_line']?.toString() ?? 'Standard');

    return GestureDetector(
      onTap: widget.onTap,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Image Section - Adjusted flex for a slimmer look
              Expanded(
                flex: 8,
                child: Stack(
                  children: [
                    Container(
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: const Color(0xFFFBF4F6),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: _buildMainImage(prod, displayImg),
                    ),
                    if (isOutOfStock || isLowStock)
                      Positioned(
                        top: 8,
                        left: 8,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: isOutOfStock ? Colors.red.withValues(alpha: 0.9) : Colors.orange.withValues(alpha: 0.9),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            isOutOfStock ? 'OUT' : 'LOW',
                            style: const TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                    // Thumbnails Overlay
                    if (_images.length > 1)
                      Positioned(
                        bottom: 10,
                        left: 10,
                        child: Row(
                          children: _images.asMap().entries.take(4).map((entry) {
                            int idx = entry.key;
                            String url = entry.value;
                            bool isActive = _activeImgIdx == idx;
                            return GestureDetector(
                              onTap: () {
                                setState(() => _activeImgIdx = idx);
                              },
                              child: Container(
                                margin: const EdgeInsets.only(right: 6),
                                width: 28,
                                height: 28,
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: isActive ? const Color(0xFFD68A96) : Colors.white,
                                    width: 2,
                                  ),
                                  image: DecorationImage(
                                    image: NetworkImage(_getImageUrl(url)),
                                    fit: BoxFit.cover,
                                    onError: (exception, stackTrace) {
                                      debugPrint('Thumbnail image error: $exception');
                                    },
                                  ),
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 10),

              // Product Line
              Text(
                styleLabel,
                style: const TextStyle(fontSize: 10, color: Colors.black, fontWeight: FontWeight.w900),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),

              // Product Name - Increased for readability
              Text(
                prod['name'] ?? '',
                style: const TextStyle(
                  fontFamily: 'serif',
                  fontWeight: FontWeight.w500,
                  fontSize: 16,
                  color: Colors.black,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),

              // Category (Subtext)
              if (prod['category_name'] != null)
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Text(
                    prod['category_name'].toString().toUpperCase(),
                    style: const TextStyle(fontSize: 9, color: Colors.black87, fontWeight: FontWeight.w900, letterSpacing: 0.2),
                  ),
                ),

              const SizedBox(height: 8),

              // Tags
              if (prod['tags'] != null && prod['tags'].toString().isNotEmpty && prod['tags'].toString() != '[]')
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Wrap(
                    spacing: 6,
                    children: _parseTags(prod['tags']).map((tag) => Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFDECEE),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        '#$tag',
                        style: const TextStyle(fontSize: 9, color: Color(0xFFD68A96), fontWeight: FontWeight.w600),
                      ),
                    )).toList(),
                  ),
                ),

              // Bottom Details Row with LayoutBuilder
              LayoutBuilder(
                builder: (context, box) {
                  bool isNarrow = box.maxWidth < 220;

                  return IntrinsicHeight(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Expanded(
                          flex: 5,
                          child: _buildVariantsSummary(prod['variants'], styleLabel, box.maxWidth),
                        ),
                        VerticalDivider(width: isNarrow ? 8 : 16, thickness: 1, color: Colors.black12),
                        Expanded(
                          flex: 3,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              FittedBox(
                                fit: BoxFit.scaleDown,
                                alignment: Alignment.centerLeft,
                                child: Text(
                                  '₱${prod['selling_price'] ?? '0.00'}',
                                  style: const TextStyle(fontSize: 16, color: Colors.black, fontWeight: FontWeight.w900),
                                ),
                              ),
                              const SizedBox(height: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFE8F5E9),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.inventory_2_outlined, size: 10, color: Color(0xFF4CAF50)),
                                    const SizedBox(width: 4),
                                    Flexible(
                                      child: FittedBox(
                                        fit: BoxFit.scaleDown,
                                        child: Text(
                                          'STOCK: $stock',
                                          style: const TextStyle(
                                            fontSize: 9,
                                            fontWeight: FontWeight.w900,
                                            color: Color(0xFF4CAF50),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                }
              ),
            ],
          ),
        ),
      ),
    );
  }
}
