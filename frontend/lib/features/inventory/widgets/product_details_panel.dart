import 'dart:io' show File;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart' show XFile;
import 'package:pos/core/constants/config.dart';
import 'product_components.dart';
import 'category_selector.dart';

class ProductDetailsPanel extends StatelessWidget {
  final String panelTitle;
  final TextEditingController nameController;
  final TextEditingController barcodeController;
  final TextEditingController costPriceController;
  final TextEditingController sellingPriceController;
  final TextEditingController stockController;
  final TextEditingController reorderController;
  final TextEditingController profitMarginController;
  final TextEditingController pricingMarginController;
  final TextEditingController descriptionController;
  final GlobalKey<FormState> formKey;
  
  final Map<String, dynamic>? selectedProduct;
  final bool isEditing;
  final bool isSaving;
  final bool isProcessingImage;
  final String processingMessage;
  final bool autoRemoveBackground;
  final Color marginColor;
  final int activeImageIndex;
  final List<String> serverImages;
  final List<XFile> selectedImages;
  final List<String> productTags;
  final String selectedProductLine;
  final List<String> productLines;
  final int? selectedCategoryId;
  final String selectedCategoryName;
  final List<dynamic> categories;
  final List<Map<String, dynamic>> variants;

  final VoidCallback onToggleEditing;
  final VoidCallback onClose;
  final VoidCallback onPickImage;
  final Function(bool) onToggleAutoRemove;
  final Function(int) onSelectImage;
  final Function(int, bool) onRemoveImage;
  final VoidCallback onShowAddTagDialog;
  final Function(String) onRemoveTag;
  final Function(String?) onProductLineChanged;
  final VoidCallback onGenerateBarcode;
  final Function(int?, String, String?) onCategorySelected;
  final VoidCallback onAddVariant;
  final Function(int) onRemoveVariant;
  final Function(int) onEditVariant;
  final VoidCallback onSaveProduct;
  final VoidCallback? onArchiveProduct;

  const ProductDetailsPanel({
    super.key,
    required this.panelTitle,
    required this.nameController,
    required this.barcodeController,
    required this.costPriceController,
    required this.sellingPriceController,
    required this.stockController,
    required this.reorderController,
    required this.profitMarginController,
    required this.pricingMarginController,
    required this.descriptionController,
    required this.formKey,
    required this.selectedProduct,
    required this.isEditing,
    required this.isSaving,
    required this.isProcessingImage,
    required this.processingMessage,
    required this.autoRemoveBackground,
    required this.marginColor,
    required this.activeImageIndex,
    required this.serverImages,
    required this.selectedImages,
    required this.productTags,
    required this.selectedProductLine,
    required this.productLines,
    required this.selectedCategoryId,
    required this.selectedCategoryName,
    required this.categories,
    required this.variants,
    required this.onToggleEditing,
    required this.onClose,
    required this.onPickImage,
    required this.onToggleAutoRemove,
    required this.onSelectImage,
    required this.onRemoveImage,
    required this.onShowAddTagDialog,
    required this.onRemoveTag,
    required this.onProductLineChanged,
    required this.onGenerateBarcode,
    required this.onCategorySelected,
    required this.onAddVariant,
    required this.onRemoveVariant,
    required this.onEditVariant,
    required this.onSaveProduct,
    this.onArchiveProduct,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFFBECEF),
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 20,
            offset: const Offset(0, 4),
          )
        ],
      ),
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  panelTitle,
                  style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Color(0xFF1C1B1F), letterSpacing: -0.5),
                ),
              ),
              Row(
                children: [
                  Text(
                    '₱${sellingPriceController.text.isEmpty ? '0.00' : sellingPriceController.text}',
                    style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Color(0xFF1C1B1F)),
                  ),
                  const SizedBox(width: 8),
                  if (selectedProduct != null) ...[
                    IconButton(
                      onPressed: onArchiveProduct,
                      icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                      tooltip: 'Archive Product',
                    ),
                    IconButton(
                      onPressed: onToggleEditing,
                      icon: Icon(isEditing ? Icons.lock_open : Icons.lock, color: const Color(0xFFD68A96)),
                      tooltip: isEditing ? 'Lock' : 'Unlock to Edit',
                    ),
                  ],
                  IconButton(
                    onPressed: onClose,
                    icon: const Icon(Icons.close, color: Color(0xFF1C1B1F)),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),

          Expanded(
            child: Form(
              key: formKey,
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: 200,
                      child: Column(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFCE1E5),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  height: 150,
                                  width: double.infinity,
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(16),
                                    image: activeImageIndex < serverImages.length
                                    ? DecorationImage(
                                        image: NetworkImage(serverImages[activeImageIndex].startsWith('http') 
                                            ? serverImages[activeImageIndex] 
                                            : '$baseUrl/${serverImages[activeImageIndex]}'),
                                        fit: BoxFit.contain,
                                        onError: (exception, stackTrace) {
                                          debugPrint('Main product image error: $exception');
                                        }) // Switched to contain for clean look
                                    : (activeImageIndex - serverImages.length < selectedImages.length)
                                        ? DecorationImage(
                                            image: kIsWeb 
                                              ? NetworkImage(selectedImages[activeImageIndex - serverImages.length].path)
                                              : FileImage(File(selectedImages[activeImageIndex - serverImages.length].path)) as ImageProvider,
                                            fit: BoxFit.contain)
                                        : null,
                                  ),
                                  child: isProcessingImage 
                                    ? Container(
                                        color: Colors.black12,
                                        child: Center(
                                          child: Column(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              const CircularProgressIndicator(color: Color(0xFFD68A96)),
                                              const SizedBox(height: 8),
                                              Text(processingMessage, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFFD68A96))),
                                            ],
                                          ),
                                        ),
                                      )
                                    : (selectedImages.isEmpty && serverImages.isEmpty)
                                      ? const Center(child: Icon(Icons.image_outlined, size: 48, color: Colors.black26))
                                      : null,
                                ),
                                const SizedBox(height: 8),
                                // Magic Clean Toggle
                                if (isEditing)
                                  Padding(
                                    padding: const EdgeInsets.only(bottom: 8.0),
                                    child: Row(
                                      children: [
                                        const Icon(Icons.auto_fix_high, size: 16, color: Color(0xFFD68A96)),
                                        const SizedBox(width: 6),
                                        const Expanded(child: Text('Magic Clean', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold))),
                                        Transform.scale(
                                          scale: 0.7,
                                          child: Switch(
                                            value: autoRemoveBackground,
                                            activeColor: const Color(0xFFD68A96),
                                            onChanged: (val) => onToggleAutoRemove(val),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                const SizedBox(height: 8),
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                                  alignment: WrapAlignment.start,
                                  children: [
                                    ...serverImages.asMap().entries.map((entry) {
                                      int idx = entry.key;
                                      String url = entry.value;
                                      return GestureDetector(
                                        onTap: () => onSelectImage(idx),
                                        child: Stack(
                                          children: [
                                            Container(
                                              width: 40,
                                              height: 40,
                                              decoration: BoxDecoration(
                                                borderRadius: BorderRadius.circular(8),
                                                border: activeImageIndex == idx ? Border.all(color: const Color(0xFFD68A96), width: 2) : null,
                                                image: DecorationImage(
                                                  image: NetworkImage(url.startsWith('http') ? url : '$baseUrl/$url'),
                                                  fit: BoxFit.cover,
                                                  onError: (exception, stackTrace) {
                                                    debugPrint('Gallery server image error: $exception');
                                                  },
                                                ),
                                              ),
                                            ),
                                            if (isEditing)
                                              Positioned(
                                                top: -2,
                                                right: -2,
                                                child: GestureDetector(
                                                  onTap: () => onRemoveImage(idx, true),
                                                  child: Container(
                                                    padding: const EdgeInsets.all(1),
                                                    decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
                                                    child: const Icon(Icons.close, size: 10, color: Colors.white),
                                                  ),
                                                ),
                                              ),
                                          ],
                                        ),
                                      );
                                    }),
                                    ...selectedImages.asMap().entries.map((entry) {
                                      int idx = entry.key;
                                      XFile file = entry.value;
                                      int displayIdx = serverImages.length + idx;
                                      return GestureDetector(
                                        onTap: () => onSelectImage(displayIdx),
                                        child: Stack(
                                          children: [
                                            Container(
                                              width: 40,
                                              height: 40,
                                              decoration: BoxDecoration(
                                                borderRadius: BorderRadius.circular(8),
                                                border: activeImageIndex == displayIdx ? Border.all(color: const Color(0xFFD68A96), width: 2) : null,
                                                image: DecorationImage(
                                                  image: kIsWeb 
                                                    ? NetworkImage(file.path)
                                                    : FileImage(File(file.path)) as ImageProvider,
                                                  fit: BoxFit.cover
                                                ),
                                              ),
                                            ),
                                            if (isEditing)
                                              Positioned(
                                                top: -2,
                                                right: -2,
                                                child: GestureDetector(
                                                  onTap: () => onRemoveImage(idx, false),
                                                  child: Container(
                                                    padding: const EdgeInsets.all(1),
                                                    decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
                                                    child: const Icon(Icons.close, size: 10, color: Colors.white),
                                                  ),
                                                ),
                                              ),
                                          ],
                                        ),
                                      );
                                    }),
                                    if (isEditing && (selectedImages.length + serverImages.length) < 5)
                                      Material(
                                        color: Colors.transparent,
                                        child: InkWell(
                                          onTap: onPickImage,
                                          borderRadius: BorderRadius.circular(8),
                                          child: Container(
                                            width: 40,
                                            height: 40,
                                            decoration: BoxDecoration(
                                              borderRadius: BorderRadius.circular(8),
                                              border: Border.all(color: const Color(0xFFD68A96), width: 1.5),
                                            ),
                                            child: const Icon(Icons.add, size: 20, color: Color(0xFFD68A96)),
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.symmetric(vertical: 8),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFD68A96),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: const Text(
                                    'Media Gallery',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(fontSize: 12, color: Colors.white, fontWeight: FontWeight.w600),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 12),
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFCE1E5),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Column(
                              children: [
                                ProductInputField(label: 'Pricing & Margin (P)', controller: pricingMarginController, hint: '0.00', readOnly: true, textColor: marginColor),
                                const SizedBox(height: 8),
                                ProductInputField(label: 'Profit Margin %', controller: profitMarginController, hint: '0%', readOnly: true, textColor: marginColor),
                              ],
                            ),
                          ),
                          const SizedBox(height: 12),
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFCE1E5),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    const Text(
                                      'Product Tags',
                                      style: TextStyle(fontSize: 12, color: Color(0xFF1C1B1F), fontWeight: FontWeight.w600),
                                    ),
                                    if (isEditing)
                                      Material(
                                        color: const Color(0xFFB3737E),
                                        borderRadius: BorderRadius.circular(8),
                                        child: InkWell(
                                          onTap: onShowAddTagDialog,
                                          borderRadius: BorderRadius.circular(8),
                                          child: const Padding(
                                            padding: EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                            child: Text(
                                              'Add Tag',
                                              style: TextStyle(
                                                fontSize: 11,
                                                color: Colors.white,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Wrap(
                                  spacing: 4,
                                  runSpacing: 4,
                                  children: productTags.map((tag) => Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                        color: const Color(0xFFD68A96),
                                        borderRadius: BorderRadius.circular(8)
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(
                                          tag,
                                          style: const TextStyle(
                                            fontSize: 11,
                                            color: Colors.white,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                        const SizedBox(width: 4),
                                        if (isEditing)
                                          GestureDetector(
                                            onTap: () => onRemoveTag(tag),
                                            child: const Icon(Icons.close, size: 10, color: Colors.white),
                                          ),
                                      ],
                                    ),
                                  )).toList(),
                                ),
                                const SizedBox(height: 12),
                                _buildProductLineDropdown(),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 16),

                    Expanded(
                      child: Column(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFCE1E5),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Column(
                              children: [
                                Row(
                                  children: [
                                    Expanded(flex: 3, child: ProductInputField(label: 'Product Name', controller: nameController, hint: 'Enter product name...', readOnly: !isEditing)),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      flex: 2,
                                      child: ProductInputField(
                                        label: 'Barcode',
                                        controller: barcodeController,
                                        hint: 'Scan or...',
                                        readOnly: !isEditing,
                                        suffix: isEditing ? IconButton(
                                          icon: const Icon(Icons.auto_fix_high, size: 18, color: Color(0xFFD68A96)),
                                          onPressed: onGenerateBarcode,
                                          padding: EdgeInsets.zero,
                                          constraints: const BoxConstraints(),
                                        ) : null,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                CategorySelector(
                                  isEditing: isEditing,
                                  selectedCategoryName: selectedCategoryName,
                                  selectedCategoryId: selectedCategoryId,
                                  categories: categories,
                                  onCategorySelected: onCategorySelected,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 12),
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFCE1E5),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Column(
                              children: [
                                Row(
                                  children: [
                                    Expanded(child: ProductInputField(label: 'Cost Price (P)', controller: costPriceController, hint: '0.00', readOnly: !isEditing)),
                                    const SizedBox(width: 12),
                                    Expanded(child: ProductInputField(label: 'Selling Price (P) (Oet)', controller: sellingPriceController, hint: '0.00', readOnly: !isEditing)),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          ProductInputField(
                                            label: 'Total Stock',
                                            controller: stockController,
                                            hint: '0',
                                            readOnly: !isEditing || variants.isNotEmpty
                                          ),
                                          if (variants.isNotEmpty)
                                            const Padding(
                                              padding: EdgeInsets.only(top: 4, left: 4),
                                              child: Text(
                                                'Sum of all variants',
                                                style: TextStyle(fontSize: 10, color: Color(0xFFD68A96), fontStyle: FontStyle.italic),
                                              ),
                                            ),
                                        ],
                                      )
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(child: ProductInputField(label: 'Reorder Level', controller: reorderController, hint: '0', readOnly: !isEditing)),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 12),
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFCE1E5),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: ProductVariantsTable(
                              variants: variants,
                              isEditing: isEditing,
                              onAddVariant: onAddVariant,
                              onRemoveVariant: onRemoveVariant,
                              onEditVariant: onEditVariant,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFCE1E5),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Description', style: TextStyle(fontSize: 12, color: Color(0xFF1C1B1F), fontWeight: FontWeight.w600)),
                                const SizedBox(height: 6),
                                Container(
                                  height: 60,
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(color: const Color(0xFFEFAFB8), width: 1),
                                  ),
                                  child: TextField(
                                    controller: descriptionController,
                                    maxLines: 2,
                                    readOnly: !isEditing,
                                    enabled: isEditing,
                                    style: const TextStyle(fontSize: 13, color: Colors.black, fontWeight: FontWeight.w400),
                                    decoration: const InputDecoration(
                                      hintText: 'Enter product description...',
                                      hintStyle: TextStyle(color: Colors.black38, fontSize: 13),
                                      contentPadding: EdgeInsets.all(10),
                                      border: InputBorder.none,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),
                          SizedBox(
                            width: double.infinity,
                            height: 48,
                            child: ElevatedButton(
                              onPressed: (isSaving || (!isEditing && selectedProduct != null)) ? null : onSaveProduct,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFFD68A96),
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                elevation: 0,
                              ),
                              child: isSaving 
                                ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                                : const Text('Save Product', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProductLineDropdown() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Product Line', style: TextStyle(fontSize: 11, color: Color(0xFF1C1B1F), fontWeight: FontWeight.w600)),
        const SizedBox(height: 4),
        Container(
          height: 36,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFFEFAFB8)),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: selectedProductLine == 'Select Product Line' ? null : selectedProductLine,
              hint: const Text('Select Product Line', style: TextStyle(fontSize: 12, color: Colors.black38)),
              isExpanded: true,
              icon: const Icon(Icons.keyboard_arrow_down, size: 18, color: Colors.black87),
              style: const TextStyle(fontSize: 12, color: Colors.black87),
              items: productLines.map((String line) {
                return DropdownMenuItem<String>(
                  value: line,
                  child: Text(line),
                );
              }).toList(),
              onChanged: isEditing ? onProductLineChanged : null,
            ),
          ),
        ),
      ],
    );
  }
}
