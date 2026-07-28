import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:pos/core/widgets/dashboard_widgets.dart';
import 'package:pos/core/services/background_removal_service.dart';
import '../services/product_service.dart';
import '../controllers/product_form_controller.dart';
import '../widgets/product_details_panel.dart';
import '../widgets/product_dialogs.dart';
import '../widgets/products/product_master_list.dart';
import '../widgets/products/product_header.dart';

class ProductsView extends StatefulWidget {
  final List<dynamic> productsList;
  final VoidCallback onRefresh;
  final Function(dynamic)? onProductUpdated;
  final bool isMobile;
  final int? userId;
  final bool isLoading;

  const ProductsView({
    super.key,
    required this.productsList,
    required this.onRefresh,
    this.onProductUpdated,
    required this.isMobile,
    this.userId,
    this.isLoading = false,
  });

  @override
  State<ProductsView> createState() => _ProductsViewState();
}

class _ProductsViewState extends State<ProductsView> {
  final _formKey = GlobalKey<FormState>();
  final ProductFormController _formController = ProductFormController();
  final TextEditingController _searchController = TextEditingController();

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
  int _activeImageIndex = 0;
  
  List<dynamic> _categories = [];
  final List<String> _productLines = ['Standard', 'Premium', 'Limited Edition', 'Seasonal'];

  @override
  void initState() {
    super.initState();
    _fetchCategories();
    _searchController.addListener(() {
      setState(() => _searchQuery = _searchController.text.toLowerCase());
    });
    
    _formController.costPriceController.addListener(() => setState(() => _formController.calculateMargins()));
    _formController.sellingPriceController.addListener(() => setState(() => _formController.calculateMargins()));
  }

  @override
  void dispose() {
    _searchController.dispose();
    _formController.dispose();
    super.dispose();
  }

  Future<void> _fetchCategories() async {
    final cats = await ProductService.fetchCategories();
    if (mounted) setState(() => _categories = cats);
  }

  void _selectProduct(Map<String, dynamic>? product) {
    setState(() {
      _selectedProduct = product;
      _activeImageIndex = 0;
      if (product != null) {
        _showDetails = true;
        _isEditing = false;
        _panelTitle = product['name']?.toString() ?? 'Product Details';
        _formController.loadProduct(product, _categories, _productLines);
      } else {
        _formController.clearForm();
        _isEditing = true;
        _panelTitle = "Add New Product";
        _showDetails = true;
      }
    });
  }

  Future<void> _pickImage() async {
    try {
      final ImagePicker picker = ImagePicker();
      final List<XFile> images = await picker.pickMultiImage(maxWidth: 800, imageQuality: 85);
      
      if (images.isNotEmpty) {
        int remainingSlots = 5 - (_formController.selectedImages.length + _formController.serverImages.length);
        if (remainingSlots <= 0) {
          if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Max 5 images')));
          return;
        }

        setState(() {
          _formController.selectedImages.addAll(images.take(remainingSlots));
        });

        if (_autoRemoveBackground) await _cleanAllLocalImages();
      }
    } catch (e) {
      debugPrint('Error picking image: $e');
    }
  }

  Future<void> _cleanAllLocalImages() async {
    setState(() { _isProcessingImage = true; _processingMessage = "Magic Cleaning..."; });
    try {
      for (int i = 0; i < _formController.selectedImages.length; i++) {
        final cleaned = await BackgroundRemovalService.removeBackground(_formController.selectedImages[i]);
        if (cleaned != null) {
          setState(() { _formController.selectedImages[i] = cleaned; });
        }
      }
    } finally {
      setState(() => _isProcessingImage = false);
    }
  }

  Future<void> _saveProduct() async {
    if (_formController.nameController.text.isEmpty || _formController.selectedCategoryId == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please fill name and category')));
      return;
    }

    final String tempId = 'temp_${DateTime.now().millisecondsSinceEpoch}';
    final Map<String, dynamic> optimisticProduct = _formController.getOptimisticData(_selectedProduct, tempId);

    if (widget.onProductUpdated != null) widget.onProductUpdated!(optimisticProduct);
    
    setState(() { _showDetails = false; _isSaving = false; });

    try {
      final finalData = await ProductService.saveProduct(
        name: _formController.nameController.text,
        barcode: _formController.barcodeController.text,
        costPrice: _formController.costPriceController.text,
        sellingPrice: _formController.sellingPriceController.text,
        stockQuantity: _formController.stockController.text,
        reorderLevel: _formController.reorderController.text,
        description: _formController.descriptionController.text,
        productLine: _formController.selectedProductLine,
        tags: _formController.productTags,
        serverImages: _formController.serverImages,
        selectedImages: _formController.selectedImages,
        variants: _formController.variants,
        userId: widget.userId,
        categoryId: _formController.selectedCategoryId,
        existingProduct: _selectedProduct,
      );

      if (finalData != null) {
        finalData['is_syncing'] = false;
        finalData['temp_id'] = tempId;
        if (widget.onProductUpdated != null) widget.onProductUpdated!(finalData);
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Sync failed: $e')));
    } finally {
      _formController.clearForm();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7E6E9),
      body: buildThemedBackground(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isNarrow = constraints.maxWidth < 800;
            return Stack(
              children: [
                Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: ProductHeader(
                        isSearchExpanded: _isSearchExpanded,
                        onSearchExpandedChanged: (val) => setState(() => _isSearchExpanded = val),
                        searchController: _searchController,
                        onShowArchived: () => ProductDialogs.showArchivedProductsDialog(context, widget.productsList, widget.onRefresh),
                        onAddProduct: () => _selectProduct(null),
                      ),
                    ),
                    Expanded(
                      child: ProductMasterList(
                        products: widget.productsList,
                        searchQuery: _searchQuery,
                        selectedProduct: _selectedProduct,
                        onSelectProduct: _selectProduct,
                      ),
                    ),
                  ],
                ),
                if (_showDetails) ...[
                  GestureDetector(
                    onTap: () => setState(() => _showDetails = false),
                    child: Container(color: Colors.black26),
                  ),
                  Positioned(
                    right: 20, top: 20, bottom: 20,
                    width: isNarrow ? constraints.maxWidth * 0.9 : 750,
                    child: ProductDetailsPanel(
                      panelTitle: _panelTitle,
                      nameController: _formController.nameController,
                      barcodeController: _formController.barcodeController,
                      costPriceController: _formController.costPriceController,
                      sellingPriceController: _formController.sellingPriceController,
                      stockController: _formController.stockController,
                      reorderController: _formController.reorderController,
                      profitMarginController: _formController.profitMarginController,
                      pricingMarginController: _formController.pricingMarginController,
                      descriptionController: _formController.descriptionController,
                      formKey: _formKey,
                      selectedProduct: _selectedProduct,
                      isEditing: _isEditing,
                      isSaving: _isSaving,
                      isProcessingImage: _isProcessingImage,
                      processingMessage: _processingMessage,
                      autoRemoveBackground: _autoRemoveBackground,
                      marginColor: _formController.marginColor,
                      activeImageIndex: _activeImageIndex,
                      serverImages: _formController.serverImages,
                      selectedImages: _formController.selectedImages,
                      productTags: _formController.productTags,
                      selectedProductLine: _formController.selectedProductLine,
                      productLines: _productLines,
                      selectedCategoryId: _formController.selectedCategoryId,
                      selectedCategoryName: _formController.selectedCategoryName,
                      categories: _categories,
                      variants: _formController.variants,
                      onToggleEditing: () => setState(() => _isEditing = !_isEditing),
                      onClose: () => setState(() => _showDetails = false),
                      onPickImage: _pickImage,
                      onToggleAutoRemove: (val) {
                        setState(() => _autoRemoveBackground = val);
                        if (val) _cleanAllLocalImages();
                      },
                      onSelectImage: (idx) => setState(() => _activeImageIndex = idx),
                      onRemoveImage: (idx, isServer) {
                        setState(() {
                          if (isServer) {
                            _formController.serverImages.removeAt(idx);
                          } else {
                            _formController.selectedImages.removeAt(idx);
                          }
                          _activeImageIndex = 0;
                        });
                      },
                      onShowAddTagDialog: () => ProductDialogs.showAddTagDialog(
                        context: context,
                        tagController: _formController.tagController,
                        productTags: _formController.productTags,
                        onTagsUpdated: (tags) => setState(() {}),
                      ),
                      onRemoveTag: (tag) => setState(() => _formController.productTags.remove(tag)),
                      onProductLineChanged: (val) => setState(() => _formController.selectedProductLine = val!),
                      onGenerateBarcode: () => setState(() => _formController.generateBarcode()),
                      onCategorySelected: (id, name, desc) {
                        setState(() {
                          _formController.selectedCategoryId = id;
                          _formController.selectedCategoryName = name;
                          if (desc != null && desc.isNotEmpty) _formController.descriptionController.text = desc;
                        });
                      },
                      onAddVariant: () => ProductDialogs.showAddVariantDialog(
                        context: context,
                        onVariantAdded: (v) {
                          setState(() {
                            _formController.variants.add(v);
                            _formController.updateTotalStockFromVariants();
                          });
                        },
                      ),
                      onRemoveVariant: (idx) {
                        setState(() {
                          _formController.variants.removeAt(idx);
                          _formController.updateTotalStockFromVariants();
                        });
                      },
                      onEditVariant: (idx) => ProductDialogs.showEditVariantDialog(
                        context: context,
                        index: idx,
                        variants: _formController.variants,
                        onVariantUpdated: (i, v) {
                          setState(() {
                            _formController.variants[i] = v;
                            _formController.updateTotalStockFromVariants();
                          });
                        },
                      ),
                      onSaveProduct: _saveProduct,
                      onArchiveProduct: () async {
                        if (_selectedProduct == null) return;
                        final confirmed = await ProductDialogs.showArchiveConfirmation(context, _selectedProduct!['name']);
                        if (confirmed && mounted) {
                          final success = await ProductService.archiveProduct(_selectedProduct!['id']);
                          if (success && mounted) {
                            final scaffoldMessenger = ScaffoldMessenger.of(context);
                            scaffoldMessenger.showSnackBar(const SnackBar(content: Text('Archived')));
                            widget.onRefresh();
                            setState(() => _showDetails = false);
                          }
                        }
                      },
                    ),
                  ),
                ],
              ],
            );
          },
        ),
      ),
    );
  }
}
