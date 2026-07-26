// ignore_for_file: const_icon_data
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:pos/core/services/api_service.dart';
import 'package:pos/core/services/database_helper.dart';
import 'package:pos/core/services/background_removal_service.dart';
import 'package:pos/core/constants/config.dart';
import 'package:pos/core/widgets/dashboard_widgets.dart';
import '../utils/product_utils.dart';
import '../widgets/product_grid_card.dart';
import '../widgets/product_details_panel.dart';
import '../widgets/product_dialogs.dart';

class ProductsView extends StatefulWidget {
  final List<dynamic> productsList;
  final VoidCallback onRefresh;
  final bool isMobile;
  final int? userId;
  final bool isLoading;

  const ProductsView({
    super.key,
    required this.productsList,
    required this.onRefresh,
    required this.isMobile,
    this.userId,
    this.isLoading = false,
  });

  @override
  State<ProductsView> createState() => _ProductsViewState();
}

class _ProductsViewState extends State<ProductsView> {
  final _formKey = GlobalKey<FormState>();

  // Controllers
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _barcodeController = TextEditingController();
  final TextEditingController _costPriceController = TextEditingController();
  final TextEditingController _sellingPriceController = TextEditingController();
  final TextEditingController _stockController = TextEditingController();
  final TextEditingController _reorderController = TextEditingController();
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _profitMarginController = TextEditingController();
  final TextEditingController _pricingMarginController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();

  bool _isSearchExpanded = false;
  String _searchQuery = '';
  bool _showDetails = false;
  String _panelTitle = 'Add New Product';
  bool _isSaving = false;
  bool _isEditing = false;
  bool _isProcessingImage = false;
  String _processingMessage = 'Magic Cleaning...';
  bool _autoRemoveBackground = false;
  Map<String, dynamic>? _selectedProduct;
  Color _marginColor = Colors.black87;
  int _activeImageIndex = 0;
  
  final List<String> _productTags = [];
  final List<String> _serverImages = [];
  final TextEditingController _tagController = TextEditingController();

  final ImagePicker _picker = ImagePicker();
  final List<XFile> _selectedImages = [];

  String _selectedProductLine = 'Select Product Line';
  final List<String> _productLines = ['Standard', 'Premium', 'Limited Edition', 'Seasonal'];

  final List<Map<String, dynamic>> _variants = [];

  int? _selectedCategoryId;
  String _selectedCategoryName = 'Select Category';
  List<dynamic> _categories = [];

  List<dynamic> _products = [];

  @override
  void initState() {
    super.initState();
    _products = widget.productsList;
    _loadLocalProducts();
    _fetchCategories();
    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text.toLowerCase();
      });
    });
    
    _costPriceController.addListener(_calculateMargins);
    _sellingPriceController.addListener(_calculateMargins);
  }

  Future<void> _loadLocalProducts() async {
    if (_products.isNotEmpty) return;
    
    try {
      final local = await DatabaseHelper.instance.getLocalProducts();
      if (local.isNotEmpty && mounted) {
        setState(() {
          _products = local;
        });
      }
    } catch (e) {
      debugPrint('Local Product Error: $e');
    }
  }

  @override
  void didUpdateWidget(ProductsView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.productsList != oldWidget.productsList) {
      setState(() {
        _products = widget.productsList;
      });
    }
  }

  void _updateTotalStockFromVariants() {
    if (_variants.isEmpty) return;
    int total = 0;
    for (var v in _variants) {
      total += int.tryParse(v['stock']?.toString() ?? '0') ?? 0;
    }
    _stockController.text = total.toString();
  }

  void _calculateMargins() {
    setState(() {
      double cost = double.tryParse(_costPriceController.text) ?? 0;
      double selling = double.tryParse(_sellingPriceController.text) ?? 0;

      if (selling > 0) {
        double profit = selling - cost;
        double marginPercent = (profit / selling) * 100;

        if (profit > 0) {
          _marginColor = Colors.green.shade700;
        } else if (profit < 0) {
          _marginColor = Colors.red.shade700;
        } else {
          _marginColor = Colors.orange.shade800;
        }

        _pricingMarginController.text = profit.toStringAsFixed(2);
        _profitMarginController.text = "${marginPercent.toStringAsFixed(0)}%";
      } else {
        _marginColor = Colors.black87;
        _pricingMarginController.text = '0.00';
        _profitMarginController.text = '0%';
      }
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _nameController.dispose();
    _barcodeController.dispose();
    _costPriceController.dispose();
    _sellingPriceController.dispose();
    _stockController.dispose();
    _reorderController.dispose();
    _profitMarginController.dispose();
    _pricingMarginController.dispose();
    _descriptionController.dispose();
    _tagController.dispose();
    super.dispose();
  }

  Future<void> _fetchCategories() async {
    try {
      final response = await ApiService.get('category/get_categories');
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success']) {
          if (!mounted) return;
          setState(() {
            _categories = data['categories'];
          });
        }
      }
    } catch (e) {
      debugPrint('Error fetching categories: $e');
    }
  }

  void _selectProduct(Map<String, dynamic>? product) {
    setState(() {
      _selectedProduct = product;
      _activeImageIndex = 0;
      if (product != null) {
        _showDetails = true;
        _isEditing = false;
        _nameController.text = product['name']?.toString() ?? '';
        _barcodeController.text = product['barcode']?.toString() ?? '';
        _costPriceController.text = product['cost_price']?.toString() ?? '';
        _sellingPriceController.text = product['selling_price']?.toString() ?? '';
        _stockController.text = product['stock_quantity']?.toString() ?? '';
        _reorderController.text = product['reorder_level']?.toString() ?? '';
        _descriptionController.text = product['description']?.toString() ?? '';
        _panelTitle = product['name']?.toString() ?? 'Product Details';

        // Load Category
        _selectedCategoryId = product['category_id'] != null ? int.tryParse(product['category_id'].toString()) : null;
        if (_selectedCategoryId != null && _categories.isNotEmpty) {
          try {
            final cat = _categories.firstWhere((c) => c['id'].toString() == _selectedCategoryId.toString());
            _selectedCategoryName = cat['name'] ?? 'Select Category';
          } catch (e) {
            _selectedCategoryName = 'Select Category';
          }
        } else {
          _selectedCategoryName = 'Select Category';
        }

        // Load Product Line
        String pLine = product['product_line']?.toString() ?? 'Select Product Line';
        if (_productLines.contains(pLine)) {
          _selectedProductLine = pLine;
        } else {
          _selectedProductLine = 'Select Product Line';
        }

        // Load Tags
        _productTags.clear();
        if (product['tags'] != null) {
          try {
            var tagsData = product['tags'];
            List<dynamic> tagsList = (tagsData is String) ? json.decode(tagsData) : tagsData;
            _productTags.addAll(tagsList.map((e) => e.toString()));
          } catch (e) {
            debugPrint("Error decoding tags: $e");
          }
        }

        // Improved Image Loading logic
        _serverImages.clear();
        _selectedImages.clear();
        
        var imagesData = product['images'] ?? product['product_images'] ?? product['gallery'];
        
        if (imagesData != null && imagesData.toString().isNotEmpty) {
          try {
            List<dynamic> imgsList = [];
            if (imagesData is String) {
              String trimmed = imagesData.trim();
              if (trimmed.startsWith('[') && trimmed.endsWith(']')) {
                imgsList = json.decode(trimmed);
              } else {
                imgsList = trimmed.split(',').where((s) => s.trim().isNotEmpty).toList();
              }
            } else if (imagesData is List) {
              imgsList = imagesData;
            }
            
            _serverImages.addAll(imgsList.map((e) => e.toString().trim()).where((e) => e.isNotEmpty));
          } catch (e) {
            debugPrint("Error parsing images list: $e");
          }
        }

        if (product['image_url'] != null && product['image_url'].toString().isNotEmpty) {
          String mainImg = product['image_url'].toString().trim();
          if (!_serverImages.contains(mainImg)) {
            _serverImages.insert(0, mainImg);
          }
        }

        // Load Variants
        _variants.clear();
        if (product['variants'] != null) {
          try {
            var variantsData = product['variants'];
            List<dynamic> variantsList = (variantsData is String) ? json.decode(variantsData) : variantsData;
            for (var v in variantsList) {
              _variants.add({
                'name': v['color_name'] ?? '',
                'color': Color(int.parse(v['color_hex'] ?? 'ff607d8b', radix: 16)),
                'size': v['size'] ?? '',
                'stock': int.tryParse(v['stock']?.toString() ?? '0') ?? 0,
              });
            }
          } catch (e) {
            debugPrint("Error decoding variants: $e");
          }
        }
      } else {
        _clearForm();
        _isEditing = true;
        _panelTitle = "Add New Product";
        _showDetails = true;
      }
    });
  }

  void _generateBarcode() {
    setState(() {
      _barcodeController.text = ProductUtils.generateBarcode("PROD");
    });
  }

  List<dynamic> get _filteredProducts {
    return _products.where((prod) {
      final status = (prod['status'] ?? 'Active').toString();
      if (status == 'Archived') return false;
      
      final name = (prod['name'] ?? '').toString().toLowerCase();
      final barcode = (prod['barcode'] ?? '').toString().toLowerCase();
      return name.contains(_searchQuery) || barcode.contains(_searchQuery);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7E6E9),
      body: buildThemedBackground(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: LayoutBuilder(
            builder: (context, constraints) {
            int crossAxisCount;
            double aspectRatio = 0.84; // Decreased from 0.9 to make it slimmer

            if (_showDetails) {
              // Fewer columns and taller cards when side-panel is open
              crossAxisCount = constraints.maxWidth > 1200 ? 2 : 1;
              aspectRatio = 0.75; // Decreased from 0.8 to make it slimmer
            } else {
              if (constraints.maxWidth > 1500) {
                crossAxisCount = 6;
              } else if (constraints.maxWidth > 1100) {
                crossAxisCount = 5;
              } else if (constraints.maxWidth > 850) {
                crossAxisCount = 4;
              } else if (constraints.maxWidth > 650) {
                crossAxisCount = 3;
              } else if (constraints.maxWidth > 400) {
                crossAxisCount = 2;
              } else {
                crossAxisCount = 1;
              }
            }

            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: _showDetails ? 4 : 10,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildProductHeader(),
                      const SizedBox(height: 16),
                      Expanded(
                        child: GridView.builder(
                          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: crossAxisCount,
                            crossAxisSpacing: 20,
                            mainAxisSpacing: 20,
                            childAspectRatio: aspectRatio,
                          ),
                          itemCount: (widget.isLoading && _filteredProducts.isEmpty) ? 10 : _filteredProducts.length,
                          itemBuilder: (context, index) {
                            if (widget.isLoading && _filteredProducts.isEmpty) {
                              return SkeletonLoader(width: double.infinity, height: double.infinity, borderRadius: 16);
                            }
                            return ProductGridCard(
                              product: _filteredProducts[index],
                              onTap: () => _selectProduct(_filteredProducts[index]),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
                if (_showDetails) ...[
                  const SizedBox(width: 16),
                  Expanded(
                    flex: 6,
                    child: ProductDetailsPanel(
                      panelTitle: _panelTitle,
                      nameController: _nameController,
                      barcodeController: _barcodeController,
                      costPriceController: _costPriceController,
                      sellingPriceController: _sellingPriceController,
                      stockController: _stockController,
                      reorderController: _reorderController,
                      profitMarginController: _profitMarginController,
                      pricingMarginController: _pricingMarginController,
                      descriptionController: _descriptionController,
                      formKey: _formKey,
                      selectedProduct: _selectedProduct,
                      isEditing: _isEditing,
                      isSaving: _isSaving,
                      isProcessingImage: _isProcessingImage,
                      autoRemoveBackground: _autoRemoveBackground,
                      marginColor: _marginColor,
                      activeImageIndex: _activeImageIndex,
                      serverImages: _serverImages,
                      selectedImages: _selectedImages,
                      productTags: _productTags,
                      selectedProductLine: _selectedProductLine,
                      productLines: _productLines,
                      selectedCategoryId: _selectedCategoryId,
                      selectedCategoryName: _selectedCategoryName,
                      categories: _categories,
                      variants: _variants,
                      processingMessage: _processingMessage,
                      onToggleEditing: () => setState(() => _isEditing = !_isEditing),
                      onClose: () => setState(() => _showDetails = false),
                      onPickImage: _pickImage,
                      onToggleAutoRemove: (val) {
                        setState(() => _autoRemoveBackground = val);
                        if (val) {
                          _cleanAllLocalImages();
                        }
                      },
                      onSelectImage: (idx) => setState(() => _activeImageIndex = idx),
                      onRemoveImage: (idx, isServer) {
                        setState(() {
                          if (isServer) {
                            _serverImages.removeAt(idx);
                          } else {
                            _selectedImages.removeAt(idx);
                          }
                          _activeImageIndex = 0;
                        });
                      },
                      onShowAddTagDialog: () => ProductDialogs.showAddTagDialog(
                        context: context,
                        tagController: _tagController,
                        productTags: _productTags,
                        onTagsUpdated: (tags) => setState(() {}),
                      ),
                      onRemoveTag: (tag) => setState(() => _productTags.remove(tag)),
                      onProductLineChanged: (val) => setState(() => _selectedProductLine = val!),
                      onGenerateBarcode: _generateBarcode,
                      onCategorySelected: (id, name, desc) {
                        setState(() {
                          _selectedCategoryId = id;
                          _selectedCategoryName = name;
                          if (desc != null && desc.isNotEmpty) {
                            _descriptionController.text = desc;
                          }
                        });
                      },
                      onAddVariant: () => ProductDialogs.showAddVariantDialog(
                        context: context,
                        onVariantAdded: (v) {
                          setState(() {
                            _variants.add(v);
                            _updateTotalStockFromVariants();
                          });
                        },
                      ),
                      onRemoveVariant: (idx) {
                        setState(() {
                          _variants.removeAt(idx);
                          _updateTotalStockFromVariants();
                        });
                      },
                      onEditVariant: (idx) => ProductDialogs.showEditVariantDialog(
                        context: context,
                        index: idx,
                        variants: _variants,
                        onVariantUpdated: (i, v) {
                          setState(() {
                            _variants[i] = v;
                            _updateTotalStockFromVariants();
                          });
                        },
                      ),
                      onSaveProduct: _saveProduct,
                      onArchiveProduct: _archiveSelectedProduct,
                    ),
                  ),
                ],
              ],
            );
          },
        ),
      ),
    ),
    );
  }

  Widget _buildProductHeader() {
    return LayoutBuilder(
      builder: (context, constraints) {
        bool isNarrow = constraints.maxWidth < 650;
        
        return Row(
          children: [
            if (!_isSearchExpanded)
              Text(
                isNarrow ? 'Products' : 'Products & Apparel',
                style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Color(0xFF1C1B1F)),
              ),
            const Spacer(),
            AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              width: _isSearchExpanded ? (isNarrow ? 150 : 200) : 44,
              height: 44,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(22),
              ),
              child: Row(
                children: [
                  InkWell(
                    onTap: () {
                      setState(() {
                        _isSearchExpanded = !_isSearchExpanded;
                        if (!_isSearchExpanded) {
                          _searchController.clear();
                        }
                      });
                    },
                    borderRadius: BorderRadius.circular(22),
                    child: SizedBox(
                      width: 44,
                      height: 44,
                      child: Icon(_isSearchExpanded ? Icons.close : Icons.search, size: 20, color: Colors.grey),
                    ),
                  ),
                  if (_isSearchExpanded)
                    Expanded(
                      child: TextField(
                        controller: _searchController,
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
                onPressed: _showArchivedProductsDialog,
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
                onPressed: () => _selectProduct(null),
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

  void _showArchivedProductsDialog() {
    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final archivedItems = widget.productsList.where((p) => (p['status'] ?? 'Active') == 'Archived').toList();
            
            return AlertDialog(
              backgroundColor: const Color(0xFFFBECEF),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
              title: Row(
                children: [
                  const Icon(Icons.archive_outlined, color: Color(0xFFD68A96)),
                  const SizedBox(width: 10),
                  const Text('Archived Products', style: TextStyle(fontWeight: FontWeight.bold)),
                  const Spacer(),
                  IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close)),
                ],
              ),
              content: SizedBox(
                width: 500,
                height: 400,
                child: archivedItems.isEmpty
                    ? const Center(child: Text('No archived products found.'))
                    : ListView.separated(
                        itemCount: archivedItems.length,
                        separatorBuilder: (context, index) => const Divider(),
                        itemBuilder: (context, index) {
                          final item = archivedItems[index];
                          return ListTile(
                            leading: Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(8),
                                image: item['image_url'] != null
                                    ? DecorationImage(
                                        image: NetworkImage(item['image_url'].toString().startsWith('http') 
                                            ? item['image_url'] 
                                            : '$baseUrl/${item['image_url']}'),
                                        fit: BoxFit.cover)
                                    : null,
                              ),
                              child: item['image_url'] == null ? const Icon(Icons.image) : null,
                            ),
                            title: Text(item['name'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold)),
                            subtitle: Text('ID: ${item['id']} • ₱${item['selling_price']}'),
                            trailing: ElevatedButton.icon(
                              onPressed: () async {
                                final res = await _restoreArchivedItem(item['id'], item['name']);
                                if (res) {
                                  setDialogState(() {}); // Refresh dialog list
                                }
                              },
                              icon: const Icon(Icons.unarchive, size: 16),
                              label: const Text('Restore', style: TextStyle(fontSize: 12)),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.green,
                                foregroundColor: Colors.white,
                                elevation: 0,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                              ),
                            ),
                          );
                        },
                      ),
              ),
            );
          },
        );
      },
    );
  }

  Future<bool> _restoreArchivedItem(dynamic id, String name) async {
    try {
      final response = await ApiService.post('products/restore_product', {'id': id.toString()});
      final data = json.decode(response.body);
      if (data['success']) {
        if (!mounted) return true;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('"$name" restored successfully!'), backgroundColor: Colors.green)
        );
        widget.onRefresh();
        return true;
      }
    } catch (e) {
      debugPrint('Error restoring item: $e');
    }
    return false;
  }

  Future<void> _archiveSelectedProduct() async {
    if (_selectedProduct == null) return;
    
    final String productName = _selectedProduct!['name'] ?? 'Product';
    final dynamic productId = _selectedProduct!['id'];

    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFFFBECEF),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Text('Archive Product?', style: TextStyle(fontWeight: FontWeight.bold)),
        content: Text('Are you sure you want to archive "$productName"? It will be hidden from the app but preserved in your records.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            child: const Text('Archive'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _isSaving = true);
    try {
      final response = await ApiService.post('products/archive_product', {
        'id': productId.toString(),
      });

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success']) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Product archived successfully'), backgroundColor: Colors.green)
          );
          _clearForm();
          setState(() => _showDetails = false);
          widget.onRefresh();
        } else {
          throw Exception(data['message']);
        }
      } else {
        throw Exception('Failed to connect to server');
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red)
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _cleanAllLocalImages() async {
    if (_selectedImages.isEmpty) return;

    setState(() {
      _isProcessingImage = true;
      _processingMessage = 'Cleaning 1 of ${_selectedImages.length}...';
    });

    for (int i = 0; i < _selectedImages.length; i++) {
      if (!mounted) break;
      
      setState(() {
        _processingMessage = 'Cleaning ${i + 1} of ${_selectedImages.length}...';
      });

      XFile originalXFile = _selectedImages[i];
      // Skip if na-clean na (filename starts with 'cleaned_')
      if (originalXFile.name.startsWith('cleaned_')) {
        continue;
      }

      try {
        final cleanedXFile = await BackgroundRemovalService.removeBackground(originalXFile);
        
        if (mounted) {
          if (cleanedXFile != null) {
            setState(() {
              _selectedImages[i] = cleanedXFile;
            });
          }
        }
      } catch (e) {
        debugPrint('Error cleaning image $i: $e');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(Icons.error_outline, color: Colors.white),
                  const SizedBox(width: 8),
                  Expanded(child: Text(e.toString())),
                ],
              ),
              backgroundColor: Colors.red.shade800,
              duration: const Duration(seconds: 8),
              action: SnackBarAction(
                label: 'RETRY',
                textColor: Colors.white,
                onPressed: () => _cleanAllLocalImages(),
              ),
            ),
          );
        }
        break; // Stop cleaning other images if one fails
      }
    }

    if (mounted) {
      setState(() {
        _isProcessingImage = false;
        _processingMessage = 'Magic Cleaning...';
      });
    }
  }

  Future<void> _pickImage() async {
    try {
      final List<XFile> images = await _picker.pickMultiImage();
      if (images.isNotEmpty) {
        int remainingSlots = 5 - (_selectedImages.length + _serverImages.length);
        if (remainingSlots <= 0) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Maximum 5 images allowed.'))
            );
          }
          return;
        }

        List<XFile> newFiles = images.take(remainingSlots).toList();
        
        setState(() {
          _selectedImages.addAll(newFiles);
        });

        if (_autoRemoveBackground) {
          await _cleanAllLocalImages();
        }
      }
    } catch (e) {
      debugPrint('Error picking image: $e');
      if (mounted) setState(() => _isProcessingImage = false);
    }
  }

  Future<void> _saveProduct() async {
    if (_nameController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please enter a product name')));
      return;
    }
    if (_selectedCategoryId == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please select a category')));
      return;
    }

    setState(() => _isSaving = true);
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('jwt_token');

      var request = http.MultipartRequest('POST', Uri.parse('$baseUrl/products/add_product'));
      
      if (token != null) {
        request.headers['Authorization'] = 'Bearer $token';
      }

      if (_selectedProduct != null) {
        request.fields['id'] = _selectedProduct!['id'].toString();
      }
      request.fields['name'] = _nameController.text;
      request.fields['category_id'] = _selectedCategoryId.toString();
      request.fields['barcode'] = _barcodeController.text;
      request.fields['description'] = _descriptionController.text;
      request.fields['cost_price'] = _costPriceController.text;
      request.fields['selling_price'] = _sellingPriceController.text;
      request.fields['stock_quantity'] = _stockController.text;
      request.fields['reorder_level'] = _reorderController.text;
      request.fields['product_line'] = _selectedProductLine;
      request.fields['tags'] = json.encode(_productTags);
      request.fields['existing_images'] = json.encode(_serverImages);
      if (widget.userId != null) {
        request.fields['added_by'] = widget.userId.toString();
      }
      
      request.fields['variants'] = json.encode(_variants.map((v) => {
        'color_name': v['name'],
        'color_hex': v['color'].value.toRadixString(16),
        'size': v['size'],
        'stock': v['stock'] ?? 0,
      }).toList());

      if (_selectedImages.isNotEmpty) {
        for (var i = 0; i < _selectedImages.length; i++) {
          if (kIsWeb) {
            final bytes = await _selectedImages[i].readAsBytes();
            request.files.add(http.MultipartFile.fromBytes(
              'images[]',
              bytes,
              filename: _selectedImages[i].name,
            ));
          } else {
            request.files.add(await http.MultipartFile.fromPath(
              'images[]',
              _selectedImages[i].path,
            ));
          }
        }
      }

      var response = await request.send();
      var responseData = await response.stream.bytesToString();
      final data = json.decode(responseData);

      if (data['success']) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Product saved successfully!'), backgroundColor: Colors.green));
        _clearForm();
        setState(() => _showDetails = false);
        widget.onRefresh();
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: ${data['message']}')));
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Connection Error: $e')));
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _clearForm() {
    _nameController.clear();
    _barcodeController.clear();
    _costPriceController.clear();
    _sellingPriceController.clear();
    _stockController.clear();
    _reorderController.clear();
    _profitMarginController.clear();
    _pricingMarginController.clear();
    _descriptionController.clear();
    setState(() {
      _selectedCategoryId = null;
      _selectedCategoryName = 'Select Category';
      _selectedProductLine = 'Select Product Line';
      _productTags.clear();
      _selectedImages.clear();
      _serverImages.clear();
      _activeImageIndex = 0;
      _variants.clear();
      _marginColor = Colors.black87;
    });
  }
}
