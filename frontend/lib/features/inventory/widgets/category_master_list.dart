import 'package:flutter/material.dart';
import 'package:pos/features/inventory/utils/category_utils.dart';

class CategoryMasterList extends StatelessWidget {
  final List<dynamic> categories;
  final Map<String, dynamic>? selectedCategory;
  final Function(Map<String, dynamic>) onCategorySelected;
  final bool isLoading;

  const CategoryMasterList({
    super.key,
    required this.categories,
    required this.selectedCategory,
    required this.onCategorySelected,
    required this.isLoading,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFEFAFB8).withValues(alpha: 0.3)),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              color: const Color(0xFFD68A96),
              child: const Row(
                children: [
                  Expanded(flex: 4, child: Text('Category Name', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
                  Expanded(flex: 3, child: Text('Sub-categories', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold), textAlign: TextAlign.center)),
                  Expanded(flex: 3, child: Text('Date Created', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold), textAlign: TextAlign.center)),
                  Expanded(flex: 2, child: Text('Status', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold), textAlign: TextAlign.center)),
                ],
              ),
            ),
            Expanded(
              child: isLoading
                  ? const Center(child: CircularProgressIndicator(color: Color(0xFFD68A96)))
                  : ListView.separated(
                itemCount: categories.length,
                separatorBuilder: (context, index) => Divider(height: 1, color: Colors.pink.shade50),
                itemBuilder: (context, index) {
                  final cat = categories[index];
                  final bool isSelected = selectedCategory?['id'] == cat['id'];
                  final subList = (cat['sub_categories'] as List?) ?? [];

                  return InkWell(
                    onTap: () => onCategorySelected(cat),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                      color: isSelected ? const Color(0xFFFCE1E5) : Colors.transparent,
                      child: Row(
                        children: [
                          Expanded(
                            flex: 4,
                            child: Row(
                              children: [
                                Icon(CategoryUtils.getIconForName(cat['name']), size: 20, color: const Color(0xFFD68A96)),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    cat['name'] ?? '', 
                                    style: const TextStyle(fontWeight: FontWeight.w600, color: Colors.black54),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Expanded(flex: 3, child: Center(child: Text('${subList.length} Items', style: const TextStyle(color: Colors.black54)))),
                          Expanded(flex: 3, child: Center(child: Text(CategoryUtils.formatDateOnly(cat['created_at']), style: const TextStyle(color: Colors.black54)))),
                          Expanded(flex: 2, child: Center(child: CategoryUtils.buildStatusBadge(cat['status']))),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
