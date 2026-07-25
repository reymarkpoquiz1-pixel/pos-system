import 'package:flutter/material.dart';
import 'package:pos/features/inventory/utils/category_utils.dart';

class CategorySelector extends StatefulWidget {
  final bool isEditing;
  final String selectedCategoryName;
  final int? selectedCategoryId;
  final List<dynamic> categories;
  final Function(int?, String, String?) onCategorySelected;

  const CategorySelector({
    super.key,
    required this.isEditing,
    required this.selectedCategoryName,
    required this.selectedCategoryId,
    required this.categories,
    required this.onCategorySelected,
  });

  @override
  State<CategorySelector> createState() => _CategorySelectorState();
}

class _CategorySelectorState extends State<CategorySelector> {
  final LayerLink _layerLink = LayerLink();
  OverlayEntry? _overlayEntry;
  int _selectedMainIndex = 0;

  void _toggleDropdown() {
    if (_overlayEntry == null) {
      _overlayEntry = _createOverlayEntry();
      Overlay.of(context).insert(_overlayEntry!);
    } else {
      _overlayEntry?.remove();
      _overlayEntry = null;
    }
  }

  OverlayEntry _createOverlayEntry() {
    return OverlayEntry(
      builder: (context) => Stack(
        children: [
          GestureDetector(
            onTap: () {
              _overlayEntry?.remove();
              _overlayEntry = null;
            },
            behavior: HitTestBehavior.translucent,
            child: Container(width: double.infinity, height: double.infinity, color: Colors.transparent),
          ),
          Positioned(
            width: 550,
            child: CompositedTransformFollower(
              link: _layerLink,
              showWhenUnlinked: false,
              targetAnchor: Alignment.bottomRight,
              followerAnchor: Alignment.topRight,
              offset: const Offset(0, 4),
              child: Material(
                elevation: 12,
                borderRadius: BorderRadius.circular(16),
                color: Colors.white,
                clipBehavior: Clip.antiAlias,
                child: StatefulBuilder(
                  builder: (context, setPopupState) {
                    final mainCategories = widget.categories;
                    final selectedMain = mainCategories.isNotEmpty && _selectedMainIndex < mainCategories.length 
                        ? mainCategories[_selectedMainIndex] 
                        : null;
                    
                    // Kuhanin ang sub_categories mula sa nested structure na galing sa backend
                    final List<dynamic> subCategories = selectedMain != null 
                        ? (selectedMain['sub_categories'] as List? ?? [])
                        : [];

                    return Container(
                      height: 400,
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey.shade300),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            flex: 5,
                            child: Container(
                              color: const Color(0xFFF7F7F9),
                              child: mainCategories.isEmpty 
                                ? const Center(child: Text('No Main Categories', style: TextStyle(fontSize: 12)))
                                : ListView.builder(
                                    padding: const EdgeInsets.symmetric(vertical: 8),
                                    itemCount: mainCategories.length,
                                    itemBuilder: (context, index) {
                                      final cat = mainCategories[index];
                                      final isSelected = _selectedMainIndex == index;
                                      return InkWell(
                                        onTap: () => setPopupState(() {
                                          _selectedMainIndex = index;
                                        }),
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                                          color: isSelected ? const Color(0xFFFBECEF) : Colors.transparent,
                                          child: Row(
                                            children: [
                                              Icon(
                                                CategoryUtils.getIconForName(cat['name']),
                                                size: 22, 
                                                color: isSelected ? const Color(0xFFD68A96) : Colors.black87
                                              ),
                                              const SizedBox(width: 14),
                                              Expanded(
                                                child: Text(
                                                  cat['name'] ?? '',
                                                  style: TextStyle(
                                                    fontSize: 13,
                                                    fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                                                    color: Colors.black87,
                                                  ),
                                                ),
                                              ),
                                              const Icon(Icons.chevron_right, size: 16, color: Colors.black26),
                                            ],
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                            ),
                          ),
                          Container(width: 1, color: Colors.grey.shade200),
                          Expanded(
                            flex: 7,
                            child: Container(
                              color: Colors.white,
                              child: subCategories.isEmpty
                                ? const Center(child: Text('No items in this category', style: TextStyle(fontSize: 12, color: Colors.grey)))
                                : ListView.builder(
                                    padding: const EdgeInsets.symmetric(vertical: 8),
                                    itemCount: subCategories.length,
                                    itemBuilder: (context, index) {
                                      final sub = subCategories[index];
                                      return Column(
                                        children: [
                                          Material(
                                            color: Colors.transparent,
                                            child: ListTile(
                                              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
                                              leading: Icon(
                                                CategoryUtils.getIconForName(sub['name']),
                                                size: 20, 
                                                color: Colors.black54
                                              ),
                                              title: Text(sub['name'] ?? '', style: const TextStyle(fontSize: 13, color: Colors.black87)),
                                              subtitle: sub['description'] != null && sub['description'].toString().isNotEmpty
                                                  ? Text(sub['description'], style: const TextStyle(fontSize: 11, color: Colors.grey))
                                                  : null,
                                              trailing: widget.selectedCategoryId.toString() == sub['id'].toString() ? const Icon(Icons.check, size: 16, color: Color(0xFFD68A96)) : null,
                                              onTap: () {
                                                widget.onCategorySelected(
                                                  int.tryParse(sub['id'].toString()),
                                                  sub['name'] ?? '',
                                                  sub['description']?.toString(),
                                                );
                                                _toggleDropdown();
                                              },
                                            ),
                                          ),
                                          if (index != subCategories.length - 1)
                                            const Divider(height: 1, indent: 50, color: Color(0xFFEEEEEE)),
                                        ],
                                      );
                                    },
                                  ),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Category', style: TextStyle(fontSize: 11, color: Color(0xFF1C1B1F), fontWeight: FontWeight.w600)),
        const SizedBox(height: 4),
        CompositedTransformTarget(
          link: _layerLink,
          child: InkWell(
            onTap: widget.isEditing ? _toggleDropdown : null,
            child: Container(
              height: 36,
              padding: const EdgeInsets.symmetric(horizontal: 10),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFEFAFB8)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      widget.selectedCategoryName,
                      style: const TextStyle(fontSize: 12, color: Colors.black87),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const Icon(Icons.arrow_drop_down, size: 20, color: Colors.black87),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
