import 'package:flutter/material.dart';
import 'package:pos/features/inventory/utils/category_utils.dart';

class CategoryDialogs {
  static void showDeletedHistoryDialog({
    required BuildContext context,
    required List<dynamic> deletedHistory,
    required Future<void> Function(int) onRestore,
  }) {
    int currentPage = 1;
    const int itemsPerPage = 4;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          // ACTUAL PAGINATION LOGIC
          final int totalItems = deletedHistory.length;
          final int totalPages = (totalItems / itemsPerPage).ceil();
          final int startIndex = (currentPage - 1) * itemsPerPage;
          final int endIndex = startIndex + itemsPerPage;
          final List<dynamic> pagedList = deletedHistory.sublist(
            startIndex,
            endIndex > totalItems ? totalItems : endIndex,
          );

          return AlertDialog(
            backgroundColor: Colors.white,
            surfaceTintColor: Colors.transparent,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
            titlePadding: const EdgeInsets.fromLTRB(25, 25, 25, 0),
            title: const Row(
              children: [
                Icon(Icons.delete_sweep_outlined, color: Color(0xFFD64452), size: 28),
                SizedBox(width: 12),
                Text(
                  'Deleted Categories History',
                  style: TextStyle(fontWeight: FontWeight.w900, fontSize: 20, color: Color(0xFF1C1B1F), letterSpacing: -0.5),
                ),
              ],
            ),
            contentPadding: const EdgeInsets.fromLTRB(20, 15, 20, 20),
            content: SizedBox(
              width: 500,
              height: 520,
              child: Column(
                children: [
                  Expanded(
                    child: deletedHistory.isEmpty
                        ? const Center(child: Text('No deleted records found.', style: TextStyle(fontStyle: FontStyle.italic)))
                        : ListView.builder(
                      padding: const EdgeInsets.only(top: 5),
                      itemCount: pagedList.length,
                      itemBuilder: (context, index) {
                        final log = pagedList[index];
                        return Container(
                          margin: const EdgeInsets.only(bottom: 10),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(15),
                            border: Border.all(color: const Color(0xFFEFAFB8), width: 1.2),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFFEFAFB8).withValues(alpha: 0.1),
                                blurRadius: 6,
                                offset: const Offset(0, 3),
                              )
                            ],
                          ),
                          child: IntrinsicHeight(
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                // LEFT ICON SECTION
                                Container(
                                  width: 70,
                                  decoration: const BoxDecoration(
                                    border: Border(right: BorderSide(color: Color(0xFFEFAFB8), width: 1)),
                                  ),
                                  child: Center(
                                    child: Container(
                                      width: 44,
                                      height: 44,
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFFBECEF),
                                        shape: BoxShape.circle,
                                        border: Border.all(color: const Color(0xFFEFAFB8), width: 1),
                                      ),
                                      child: Icon(
                                        CategoryUtils.getIconForName(log['category_name']),
                                        color: const Color(0xFFD68A96),
                                        size: 22,
                                      ),
                                    ),
                                  ),
                                ),
                                // MAIN CONTENT SECTION
                                Expanded(
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          children: [
                                            Expanded(
                                              child: Text(
                                                log['category_name'] ?? 'Unknown Category',
                                                style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: Color(0xFF1C1B1F)),
                                              ),
                                            ),
                                            Row(
                                              children: [
                                                _combinedActionBtn(
                                                  onRestore: () async {
                                                    // RESTORE AND CLOSE MODAL
                                                    await onRestore(int.parse(log['category_id'].toString()));
                                                    if (context.mounted) Navigator.pop(context);
                                                  },
                                                  onInfo: () {},
                                                ),
                                              ],
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          'DESCRIPTION: ${log['details'] ?? 'No details provided.'}',
                                          style: const TextStyle(fontSize: 11, color: Colors.black87, height: 1.2, fontWeight: FontWeight.w500),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        const SizedBox(height: 8),
                                        Row(
                                          children: [
                                            _badge('DELETED BY: ${log['admin_name'] ?? 'Admin'}'),
                                            const SizedBox(width: 8),
                                            _badge('AT: ${CategoryUtils.formatLogDateTime(log['created_at'])}'),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 15),
                  // ACTUAL WORKING PAGINATION
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          _pageBtn(
                            Icons.chevron_left,
                            currentPage > 1,
                            onTap: currentPage > 1 ? () => setDialogState(() => currentPage--) : null,
                          ),
                          for (int i = 1; i <= totalPages; i++)
                            if (i == 1 || i == totalPages || (i >= currentPage - 1 && i <= currentPage + 1))
                              _pageBtnText(
                                i.toString(),
                                i == currentPage,
                                onTap: () => setDialogState(() => currentPage = i),
                              )
                            else if (i == currentPage - 2 || i == currentPage + 2)
                              const Padding(
                                padding: EdgeInsets.symmetric(horizontal: 4),
                                child: Text('...', style: TextStyle(color: Colors.grey)),
                              ),
                          _pageBtn(
                            Icons.chevron_right,
                            currentPage < totalPages,
                            onTap: currentPage < totalPages ? () => setDialogState(() => currentPage++) : null,
                          ),
                        ],
                      ),
                      Text(
                        'Showing ${totalItems == 0 ? 0 : startIndex + 1}-${endIndex > totalItems ? totalItems : endIndex} records',
                        style: const TextStyle(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Page $currentPage of ${totalPages == 0 ? 1 : totalPages}',
                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: Colors.black54)),
                      GestureDetector(
                        onTap: () => Navigator.pop(context),
                        child: Container(
                          height: 40,
                          width: 100,
                          decoration: BoxDecoration(
                            color: const Color(0xFFD64452),
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFFD64452).withValues(alpha: 0.3),
                                blurRadius: 8,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Stack(
                            children: [
                              Positioned(
                                top: 0,
                                right: 0,
                                child: Container(
                                  width: 25,
                                  height: 25,
                                  decoration: const BoxDecoration(
                                    color: Color(0xFFEFAFB8),
                                    borderRadius: BorderRadius.only(
                                      topRight: Radius.circular(12),
                                      bottomLeft: Radius.circular(25),
                                    ),
                                  ),
                                ),
                              ),
                              const Center(
                                child: Text(
                                  'Close',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w900,
                                    fontSize: 15,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  static Widget _combinedActionBtn({required VoidCallback onRestore, required VoidCallback onInfo}) {
    return Container(
      height: 26,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFEFAFB8).withValues(alpha: 0.5), width: 1),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(7),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // LEFT PART (RESTORE)
            InkWell(
              onTap: onRestore,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                decoration: const BoxDecoration(
                  color: Color(0xFFFBECEF),
                  border: Border(right: BorderSide(color: Color(0xFFEFAFB8), width: 1)),
                ),
                child: const Center(
                  child: Icon(Icons.sync, size: 14, color: Color(0xFFD68A96)),
                ),
              ),
            ),
            // RIGHT PART (INFO)
            InkWell(
              onTap: onInfo,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                color: Colors.white,
                child: const Center(
                  child: Icon(Icons.info_outline, size: 14, color: Colors.grey),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  static Widget _badge(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFFBECEF),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        text.toUpperCase(),
        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Color(0xFFD64452)),
      ),
    );
  }

  static Widget _pageBtn(IconData icon, bool enabled, {VoidCallback? onTap}) {
    return InkWell(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(right: 6),
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          border: Border.all(color: enabled ? Colors.grey.shade400 : Colors.grey.shade200, width: 1.5),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, size: 20, color: enabled ? Colors.black87 : Colors.grey.shade300),
      ),
    );
  }

  static Widget _pageBtnText(String text, bool active, {VoidCallback? onTap}) {
    return InkWell(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(right: 6),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: active ? const Color(0xFFFBECEF) : Colors.white,
          border: Border.all(color: active ? const Color(0xFFEFAFB8) : Colors.grey.shade300, width: 1.8),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(
          text,
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: active ? const Color(0xFFD68A96) : Colors.grey),
        ),
      ),
    );
  }

  static void showAddDialog({
    required BuildContext context,
    required GlobalKey<FormState> formKey,
    required TextEditingController nameController,
    required TextEditingController descController,
    required TextEditingController newParentController,
    required String? selectedParentId,
    required List<dynamic> categories,
    required bool isSaving,
    required Function(String?) onParentChanged,
    required Function(bool) onNewParentToggled,
    required VoidCallback onSave,
  }) {
    bool isAddingNewParentLocal = false;
    String? currentParentId = selectedParentId;
    String currentParentName = CategoryUtils.findNameById(categories, currentParentId);
    final double dialogWidth = MediaQuery.of(context).size.width * 0.9 > 500 ? 500 : MediaQuery.of(context).size.width * 0.9;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: const Color(0xFFFBECEF),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
          title: const Row(
            children: [
              Icon(Icons.category_outlined, color: Color(0xFFD68A96)),
              SizedBox(width: 12),
              Text('Add New Category', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFFD68A96))),
            ],
          ),
          content: SizedBox(
            width: dialogWidth,
            child: SingleChildScrollView(
              child: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextFormField(
                      controller: nameController,
                      decoration: InputDecoration(
                        labelText: 'Sub-category (e.g. Crossbody Bag)',
                        prefixIcon: const Icon(Icons.shopping_bag_outlined, color: Color(0xFFD68A96)),
                        isDense: true,
                        filled: true,
                        fillColor: Colors.white,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: Color(0xFFEFAFB8)),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: Color(0xFFD68A96), width: 1.5),
                        ),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      validator: (v) => v!.isEmpty ? 'Required' : null,
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Icon(isAddingNewParentLocal ? Icons.add_business : Icons.account_tree_outlined, color: const Color(0xFFD68A96), size: 20),
                        const SizedBox(width: 10),
                        Text(
                          isAddingNewParentLocal ? 'New Category' : 'Select Category',
                          style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFFD68A96), fontSize: 14),
                        ),
                        const Spacer(),
                        TextButton.icon(
                          icon: Icon(isAddingNewParentLocal ? Icons.list : Icons.add_circle_outline, size: 14),
                          label: Text(isAddingNewParentLocal ? 'Pick from List' : 'Add New', style: const TextStyle(fontSize: 12)),
                          onPressed: () {
                            setDialogState(() => isAddingNewParentLocal = !isAddingNewParentLocal);
                            onNewParentToggled(isAddingNewParentLocal);
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    if (isAddingNewParentLocal)
                      TextFormField(
                        controller: newParentController,
                        decoration: InputDecoration(
                          hintText: 'e.g. Bags, Shoes, Clothing',
                          isDense: true,
                          filled: true,
                          fillColor: Colors.white,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: Color(0xFFEFAFB8)),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: Color(0xFFD68A96), width: 1.5),
                          ),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      )
                    else
                      _CustomOverlayPicker(
                        selectedName: currentParentName,
                        categories: categories, // Inalis ang flattenCategories para Main Categories lang ang lumabas
                        onSelected: (id, name, desc) {
                          setDialogState(() {
                            currentParentId = id?.toString();
                            currentParentName = name;
                          });
                          onParentChanged(currentParentId);
                        },
                      ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: descController,
                      maxLines: 2,
                      decoration: InputDecoration(
                        labelText: 'Description',
                        prefixIcon: const Icon(Icons.description_outlined, color: Color(0xFFD68A96)),
                        isDense: true,
                        filled: true,
                        fillColor: Colors.white,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: Color(0xFFEFAFB8)),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: Color(0xFFD68A96), width: 1.5),
                        ),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: isSaving ? null : onSave,
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF3498DB), foregroundColor: Colors.white),
              child: const Text('Save Category'),
            ),
          ],
        ),
      ),
    );
  }

  static void showEditDialog({
    required BuildContext context,
    required Map<String, dynamic> cat,
    required GlobalKey<FormState> formKey,
    required TextEditingController nameController,
    required TextEditingController descController,
    required List<dynamic> categories,
    required String? selectedParentId,
    required Function(String?) onParentChanged,
    required Function(int) onUpdate,
  }) {
    String? currentParentId = selectedParentId;
    String currentParentName = CategoryUtils.findNameById(categories, currentParentId);
    final double dialogWidth = MediaQuery.of(context).size.width * 0.9 > 500 ? 500 : MediaQuery.of(context).size.width * 0.9;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: const Color(0xFFFBECEF),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
          title: const Row(
            children: [
              Icon(Icons.edit_outlined, color: Color(0xFFD68A96)),
              SizedBox(width: 12),
              Text('Edit Category', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFFD68A96))),
            ],
          ),
          content: SizedBox(
            width: dialogWidth,
            child: SingleChildScrollView(
              child: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextFormField(
                      controller: nameController,
                      decoration: InputDecoration(
                        labelText: 'Sub-category',
                        prefixIcon: const Icon(Icons.shopping_bag_outlined, color: Color(0xFFD68A96)),
                        isDense: true,
                        filled: true,
                        fillColor: Colors.white,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: Color(0xFFEFAFB8)),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: Color(0xFFD68A96), width: 1.5),
                        ),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      validator: (v) => v!.isEmpty ? 'Required' : null,
                    ),
                    const SizedBox(height: 16),
                    const Text('Category', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFFD68A96), fontSize: 14)),
                    const SizedBox(height: 8),
                    _CustomOverlayPicker(
                      selectedName: currentParentName,
                      categories: categories.where((c) => c['id'].toString() != cat['id'].toString()).toList(), // Main Categories lang
                      onSelected: (id, name, desc) {
                        setDialogState(() {
                          currentParentId = id?.toString();
                          currentParentName = name;
                        });
                        onParentChanged(currentParentId);
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: descController,
                      maxLines: 2,
                      decoration: InputDecoration(
                        labelText: 'Description',
                        prefixIcon: const Icon(Icons.description_outlined, color: Color(0xFFD68A96)),
                        isDense: true,
                        filled: true,
                        fillColor: Colors.white,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: Color(0xFFEFAFB8)),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: Color(0xFFD68A96), width: 1.5),
                        ),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () => onUpdate(int.parse(cat['id'].toString())),
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF3498DB), foregroundColor: Colors.white),
              child: const Text('Update Category'),
            ),
          ],
        ),
      ),
    );
  }

  static void confirmDelete({
    required BuildContext context,
    required Map<String, dynamic> cat,
    required Function(int) onDelete,
  }) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Category'),
        content: Text('Are you sure you want to delete "${cat['name']}"?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          TextButton(onPressed: () { Navigator.pop(context); onDelete(cat['id']); }, child: const Text('Delete', style: TextStyle(color: Colors.red))),
        ],
      ),
    );
  }
}

class _CustomOverlayPicker extends StatefulWidget {
  final String selectedName;
  final List<dynamic> categories;
  final Function(int?, String, String?) onSelected;

  const _CustomOverlayPicker({
    required this.selectedName,
    required this.categories,
    required this.onSelected,
  });

  @override
  State<_CustomOverlayPicker> createState() => _CustomOverlayPickerState();
}

class _CustomOverlayPickerState extends State<_CustomOverlayPicker> {
  final LayerLink _layerLink = LayerLink();
  OverlayEntry? _overlayEntry;

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
    RenderBox renderBox = context.findRenderObject() as RenderBox;
    var size = renderBox.size;

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
            width: size.width,
            child: CompositedTransformFollower(
              link: _layerLink,
              showWhenUnlinked: false,
              targetAnchor: Alignment.bottomLeft,
              followerAnchor: Alignment.topLeft,
              offset: const Offset(0, 4),
              child: Material(
                elevation: 8,
                borderRadius: BorderRadius.circular(12),
                color: Colors.white,
                child: Container(
                  constraints: const BoxConstraints(maxHeight: 300, minHeight: 100),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: widget.categories.isEmpty
                      ? const Center(child: Text('No categories found', style: TextStyle(fontSize: 13, color: Colors.grey)))
                      : ListView.builder(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    shrinkWrap: true,
                    itemCount: widget.categories.length,
                    itemBuilder: (context, index) {
                      final cat = widget.categories[index];
                      return InkWell(
                        onTap: () {
                          widget.onSelected(
                            int.tryParse(cat['id'].toString()),
                            cat['name'] ?? '',
                            cat['description']?.toString(),
                          );
                          _toggleDropdown();
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                          child: Row(
                            children: [
                              Icon(
                                  CategoryUtils.getIconForName(cat['name']),
                                  size: 22,
                                  color: const Color(0xFFD68A96)
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Text(
                                  cat['name'] ?? '',
                                  style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.black87
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
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return CompositedTransformTarget(
      link: _layerLink,
      child: InkWell(
        onTap: _toggleDropdown,
        child: Container(
          height: 40,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFEFAFB8)),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  widget.selectedName,
                  style: const TextStyle(fontSize: 14, color: Colors.black87),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const Icon(Icons.keyboard_arrow_down, size: 20, color: Color(0xFFD68A96)),
            ],
          ),
        ),
      ),
    );
  }
}
