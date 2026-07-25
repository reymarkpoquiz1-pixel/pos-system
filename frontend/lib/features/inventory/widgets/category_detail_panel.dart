import 'package:flutter/material.dart';
import 'package:pos/features/inventory/utils/category_utils.dart';
import 'package:pos/core/widgets/dashboard_widgets.dart';

class CategoryDetailPanel extends StatefulWidget {
  final Map<String, dynamic>? selectedCategory;
  final List<dynamic> categories;
  final List<dynamic> history;
  final bool isHistoryLoading;
  final Function(Map<String, dynamic>) onCategorySelected;
  final VoidCallback onFetchCategories;
  final Function(int) onClearHistory;
  final Function(Map<String, dynamic>) onEdit;
  final Function(Map<String, dynamic>) onDelete;

  const CategoryDetailPanel({
    super.key,
    required this.selectedCategory,
    required this.categories,
    required this.history,
    required this.isHistoryLoading,
    required this.onCategorySelected,
    required this.onFetchCategories,
    required this.onClearHistory,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  State<CategoryDetailPanel> createState() => _CategoryDetailPanelState();
}

class _CategoryDetailPanelState extends State<CategoryDetailPanel> {
  bool _showAllHistory = false;
  static const int _displayLimit = 5;

  @override
  Widget build(BuildContext context) {
    if (widget.selectedCategory == null) {
      return const Center(child: Text('Select a category to view details.'));
    }

    final cat = widget.selectedCategory!;
    final bool isMain = cat['parent_id'] == null || cat['parent_id'].toString() == '0' || cat['parent_id'].toString() == '';
    final List<dynamic> subCategories = (cat['sub_categories'] as List?) ?? [];

    return Container(
      decoration: cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(28),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Category Details', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.black45)),
                      if (!isMain)
                        TextButton.icon(
                          onPressed: () {
                            final parent = widget.categories.firstWhere(
                                  (c) => c['id'].toString() == cat['parent_id'].toString(),
                              orElse: () => null,
                            );
                            if (parent != null) {
                              widget.onCategorySelected(parent);
                            } else {
                              widget.onFetchCategories();
                            }
                          },
                          icon: const Icon(Icons.arrow_back, size: 16),
                          label: const Text('Back to Main'),
                        ),
                    ],
                  ),
                  const SizedBox(height: 32),

                  // 1. DESCRIPTION
                  const Text('Description', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.black45)),
                  const SizedBox(height: 12),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFCE1E5).withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Text(
                      cat['description'] ?? (isMain ? 'Main Category Folder' : 'Sub-category details.'),
                      style: const TextStyle(fontSize: 13, color: Colors.black45, height: 1.5),
                    ),
                  ),
                  const SizedBox(height: 40),

                  // 2. NAME AND ICON
                  Row(
                    children: [
                      Container(
                        width: 100,
                        height: 100,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: const Color(0xFFFBECEF),
                          border: Border.all(color: Colors.white, width: 4),
                          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10)],
                        ),
                        child: Icon(CategoryUtils.getIconForName(cat['name']), size: 40, color: const Color(0xFFD68A96)),
                      ),
                      const SizedBox(width: 24),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              cat['name'] ?? '',
                              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w600, color: Colors.black54),
                            ),
                            if (!isMain) ...[
                              const Text('Sub-category', style: TextStyle(fontSize: 14, color: Colors.grey, fontWeight: FontWeight.w500)),
                              const SizedBox(height: 4),
                              FutureBuilder<dynamic>(
                                future: Future.value(widget.categories.firstWhere(
                                      (c) => c['id'].toString() == cat['parent_id'].toString(),
                                  orElse: () => null,
                                )),
                                builder: (context, snapshot) {
                                  final parent = snapshot.data;
                                  if (parent == null && cat['parent_id'] != null && cat['parent_id'].toString() != '0' && cat['parent_id'].toString() != '') {
                                    return const Text(
                                      'Parent: [Inactive or Missing - Please Re-link]',
                                      style: TextStyle(fontSize: 12, color: Colors.red, fontWeight: FontWeight.bold),
                                    );
                                  }
                                  return Text(
                                    'Parent: ${parent != null ? parent['name'] : 'None'}',
                                    style: const TextStyle(fontSize: 12, color: Color(0xFFD68A96), fontWeight: FontWeight.bold),
                                  );
                                },
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 40),

                  // 3. SUB-CATEGORIES (IF ANY)
                  if (subCategories.isNotEmpty) ...[
                    Row(
                      children: [
                        const Text('Sub-categories', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.black45)),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(color: const Color(0xFFFCE1E5), borderRadius: BorderRadius.circular(10)),
                          child: Text('${subCategories.length}', style: const TextStyle(fontSize: 11, color: Color(0xFFD68A96), fontWeight: FontWeight.bold)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Column(
                      children: subCategories.map((sub) => Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: const Color(0xFFFBECEF)),
                        ),
                        child: Material(
                          color: Colors.transparent,
                          borderRadius: BorderRadius.circular(16),
                          child: ListTile(
                            onTap: () => widget.onCategorySelected(sub),
                            dense: true,
                            visualDensity: const VisualDensity(vertical: -2),
                            leading: Icon(CategoryUtils.getIconForName(sub['name']), color: const Color(0xFFD68A96), size: 20),
                            title: Text(sub['name'] ?? '', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: Colors.black54)),
                            subtitle: Text('Created: ${CategoryUtils.formatDateOnly(sub['created_at'])}', style: const TextStyle(fontSize: 11)),
                            trailing: const Icon(Icons.chevron_right, color: Colors.grey, size: 16),
                          ),
                        ),
                      )).toList(),
                    ),
                    const SizedBox(height: 24),
                  ],

                  // 4. AUDIT TRAIL (ONLY FOR SUB-CATEGORIES OR EMPTY MAIN CATEGORIES)
                  if (!isMain || subCategories.isEmpty) ...[
                    const Text('Audit Trail', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.black45)),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFCE1E5).withValues(alpha: 0.7),
                        borderRadius: BorderRadius.circular(24),
                      ),
                      child: Column(
                        children: [
                          _buildAuditRow(Icons.calendar_today_outlined, 'Date Added:', CategoryUtils.formatLogDateTime(cat['created_at'])),
                          const SizedBox(height: 14),
                          _buildAuditRow(Icons.person_outline, 'Added By:', 'Admin'),
                          const SizedBox(height: 14),
                          _buildAuditRow(Icons.history, 'Last Updated:', CategoryUtils.formatLogDateTime(cat['updated_at'] ?? cat['created_at'])),
                        ],
                      ),
                    ),
                    const SizedBox(height: 40),

                    // 5. ACTIVITY HISTORY
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Padding(
                              padding: EdgeInsets.only(left: 4),
                              child: Text('Activity History', 
                                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.black45)),
                            ),
                            Padding(
                              padding: const EdgeInsets.only(left: 4, bottom: 8),
                              child: Text(
                                cat['name'] ?? '',
                                style: const TextStyle(fontSize: 12, color: Color(0xFFD68A96), fontWeight: FontWeight.bold),
                              ),
                            ),
                          ],
                        ),
                        if (widget.history.length > 1)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: TextButton.icon(
                              onPressed: () => _confirmClearHistory(context, int.parse(cat['id'].toString())),
                              icon: const Icon(Icons.delete_sweep_outlined, size: 14, color: Colors.redAccent),
                              label: const Text('Clear logs', style: TextStyle(fontSize: 10, color: Colors.redAccent, fontWeight: FontWeight.bold)),
                              style: TextButton.styleFrom(
                                backgroundColor: Colors.red.withValues(alpha: 0.08),
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                                minimumSize: Size.zero,
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    if (widget.isHistoryLoading)
                      const Center(child: Padding(padding: EdgeInsets.all(20), child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFFD68A96))))
                    else
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxHeight: 400, minHeight: 100),
                        child: Container(
                          width: double.infinity,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(24),
                            border: Border.all(color: const Color(0xFFF5F5F5)),
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Flexible(
                                child: widget.history.isEmpty
                                    ? const Center(
                                        child: Padding(
                                          padding: EdgeInsets.all(40),
                                          child: Text(
                                            'No history available.',
                                            style: TextStyle(fontSize: 14, color: Colors.grey),
                                          ),
                                        ),
                                      )
                                    : ListView.separated(
                                        shrinkWrap: true,
                                        padding: EdgeInsets.zero,
                                        itemCount: _getHistoryToShow().length,
                                        separatorBuilder: (context, index) => const Divider(height: 1, color: Color(0xFFFAFAFA), indent: 70, endIndent: 20),
                                        itemBuilder: (context, index) {
                                          final logs = _getHistoryToShow();
                                          final log = logs[index];
                                          final Color actionColor = CategoryUtils.getLogColor(log['action']);
                                          
                                          return Padding(
                                            padding: const EdgeInsets.all(16),
                                            child: Row(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Container(
                                                  padding: const EdgeInsets.all(10),
                                                  decoration: BoxDecoration(
                                                    color: actionColor.withValues(alpha: 0.08),
                                                    shape: BoxShape.circle,
                                                  ),
                                                  child: Icon(
                                                    CategoryUtils.getLogIcon(log['action']),
                                                    size: 16,
                                                    color: actionColor,
                                                  ),
                                                ),
                                                const SizedBox(width: 16),
                                                Expanded(
                                                  child: Column(
                                                    crossAxisAlignment: CrossAxisAlignment.start,
                                                    children: [
                                                      Text(
                                                        log['details'] ?? '',
                                                        style: const TextStyle(
                                                          fontSize: 13,
                                                          fontWeight: FontWeight.w600,
                                                          color: Colors.black54,
                                                          height: 1.3,
                                                        ),
                                                      ),
                                                      const SizedBox(height: 4),
                                                      Text(
                                                        'By: ${log['admin_name'] ?? 'Admin'} • ${CategoryUtils.formatLogDateTime(log['created_at'])}',
                                                        style: const TextStyle(
                                                          fontSize: 11,
                                                          color: Colors.black38,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              ],
                                            ),
                                          );
                                        },
                                      ),
                              ),
                              if (widget.history.length > _displayLimit)
                                InkWell(
                                  onTap: () => setState(() => _showAllHistory = !_showAllHistory),
                                  child: Container(
                                    width: double.infinity,
                                    padding: const EdgeInsets.symmetric(vertical: 12),
                                    decoration: const BoxDecoration(
                                      border: Border(top: BorderSide(color: Color(0xFFFAFAFA))),
                                    ),
                                    child: Text(
                                      _showAllHistory ? 'See Less' : 'See All (${widget.history.length})',
                                      textAlign: TextAlign.center,
                                      style: const TextStyle(color: Color(0xFFD68A96), fontWeight: FontWeight.bold, fontSize: 13),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ],
              ),
            ),
          ),
          // ACTION BAR
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            decoration: BoxDecoration(
              color: const Color(0xFFFBECEF).withValues(alpha: 0.4),
              border: Border(top: BorderSide(color: Colors.pink.shade50)),
              borderRadius: const BorderRadius.vertical(bottom: Radius.circular(24)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                _detailActionIcon(Icons.edit_outlined, () => widget.onEdit(cat)),
                const SizedBox(width: 16),
                _detailActionIcon(Icons.delete_outline, () => widget.onDelete(cat), color: Colors.redAccent),
              ],
            ),
          ),
        ],
      ),
    );
  }

  List<dynamic> _getHistoryToShow() {
    final filtered = widget.history.where((h) {
      final action = h['action']?.toLowerCase() ?? '';
      return ['updated', 'added', 'restored', 'update', 'add', 'restore'].contains(action);
    }).toList();
    if (_showAllHistory) return filtered;
    return filtered.take(_displayLimit).toList();
  }

  void _confirmClearHistory(BuildContext context, int categoryId) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear History?'),
        content: const Text('This will delete all activity logs for this category except the creation record. Do you want to proceed?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              widget.onClearHistory(categoryId);
            },
            child: const Text('Clear', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  Widget _detailActionIcon(IconData icon, VoidCallback onTap, {Color? color}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Icon(icon, size: 24, color: color ?? Colors.black45),
      ),
    );
  }

  Widget _buildAuditRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, size: 20, color: const Color(0xFFD68A96).withValues(alpha: 0.6)),
        const SizedBox(width: 12),
        Text(label, style: const TextStyle(fontSize: 14, color: Colors.black54, fontWeight: FontWeight.w500)),
        const Spacer(),
        Text(value, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: Colors.black54)),
      ],
    );
  }
}
