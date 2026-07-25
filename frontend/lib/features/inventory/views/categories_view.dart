import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:pos/core/services/api_service.dart';
import 'package:pos/core/widgets/dashboard_widgets.dart';
import '../widgets/category_master_list.dart';
import '../widgets/category_detail_panel.dart';
import '../widgets/category_dialogs.dart';

class CategoriesView extends StatefulWidget {
  final List<dynamic> categoriesList;
  final VoidCallback onRefresh;
  final bool isMobile;
  const CategoriesView({super.key, required this.categoriesList, required this.onRefresh, required this.isMobile});

  @override
  State<CategoriesView> createState() => _CategoriesViewState();
}

class _CategoriesViewState extends State<CategoriesView> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _descController = TextEditingController();
  final TextEditingController _newParentController = TextEditingController();
  final TextEditingController _searchController = TextEditingController();

  List<dynamic> _categories = [];
  List<dynamic> _history = [];
  List<dynamic> _deletedHistory = [];
  bool _isLoading = true;
  bool _isHistoryLoading = false;
  bool _isSaving = false;
  bool _isAddingNewParent = false;
  bool _isSearchExpanded = false;
  String _searchQuery = '';

  Map<String, dynamic>? _selectedCategory;
  String? _selectedParentId;

  @override
  void initState() {
    super.initState();
    _categories = widget.categoriesList;
    if (_categories.isNotEmpty) {
      _isLoading = false;
      _selectedCategory = _categories[0];
      _fetchHistory(int.parse(_selectedCategory!['id'].toString()));
    } else {
      _fetchCategories();
    }
    _fetchDeletedHistory();
  }

  @override
  void didUpdateWidget(CategoriesView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.categoriesList != oldWidget.categoriesList) {
      setState(() {
        _categories = widget.categoriesList;
        if (_categories.isNotEmpty && _selectedCategory == null) {
          _selectedCategory = _categories[0];
          _fetchHistory(int.parse(_selectedCategory!['id'].toString()));
        }
      });
    }
  }

  Map<String, dynamic>? _findCategoryById(List<dynamic> list, dynamic id) {
    for (var cat in list) {
      if (cat['id'].toString() == id.toString()) return cat;
      if (cat['sub_categories'] != null) {
        final found = _findCategoryById(cat['sub_categories'], id);
        if (found != null) return found;
      }
    }
    return null;
  }

  Future<void> _fetchCategories({String? selectedId}) async {
    setState(() => _isLoading = true);
    _fetchDeletedHistory();
    try {
      final response = await ApiService.get('category/get_categories');
      if (response.statusCode == 200) {
        if (!mounted) return;
        final data = json.decode(response.body);
        if (data['success']) {
          setState(() {
            _categories = data['categories'];
            _isLoading = false;

            if (selectedId != null) {
              _selectedCategory = _findCategoryById(_categories, selectedId);
            } else if (_selectedCategory != null) {
              final updated = _findCategoryById(_categories, _selectedCategory!['id']);
              if (updated != null) {
                _selectedCategory = updated;
              } else {
                _selectedCategory = _categories.isNotEmpty ? _categories[0] : null;
              }
            } else if (_categories.isNotEmpty) {
              _selectedCategory = _categories[0];
            }

            if (_selectedCategory != null) {
              _fetchHistory(int.parse(_selectedCategory!['id'].toString()));
            }
          });
        }
      }
    } catch (e) {
      setState(() => _isLoading = false);
      debugPrint('Error: $e');
    }
  }

  Future<void> _fetchHistory(int categoryId) async {
    setState(() => _isHistoryLoading = true);
    try {
      final response = await ApiService.get('category/get_category_history?category_id=$categoryId');
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success']) {
          setState(() {
            _history = data['history'];
            _isHistoryLoading = false;
          });
        }
      }
    } catch (e) {
      debugPrint('History Error: $e');
      setState(() => _isHistoryLoading = false);
    }
  }

  Future<void> _fetchDeletedHistory() async {
    try {
      final response = await ApiService.get('category/get_deleted_categories_history');
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success']) {
          setState(() {
            _deletedHistory = data['history'];
          });
        }
      }
    } catch (e) {
      debugPrint('Deleted History Error: $e');
    }
  }

  void _onCategorySelected(Map<String, dynamic> cat) {
    setState(() {
      _selectedCategory = cat;
      _history = [];
    });
    _fetchHistory(int.parse(cat['id'].toString()));
  }

  List<dynamic> get _filteredCategories {
    if (_searchQuery.isEmpty) return _categories;
    return _categories.where((cat) {
      final name = (cat['name'] ?? '').toString().toLowerCase();
      final desc = (cat['description'] ?? '').toString().toLowerCase();
      return name.contains(_searchQuery) || desc.contains(_searchQuery);
    }).toList();
  }

  Future<void> _saveCategory() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);
    try {
      final String finalParentId = _isAddingNewParent ? '' : (_selectedParentId ?? '');
      final response = await ApiService.post(
        'category/add_category',
        {
          'name': _nameController.text,
          'description': _descController.text,
          'parent_id': finalParentId,
          'new_parent_name': _isAddingNewParent ? _newParentController.text : '',
          'user_id': '1', // ID ng Admin (dapat galing sa login session)
          'icon': 'category_icon', // Pangalan ng icon
        },
      );

      final data = json.decode(response.body);
      if (!mounted) return;
      if (data['success']) {
        Navigator.pop(context);
        _fetchCategories();
        widget.onRefresh();
        _nameController.clear();
        _descController.clear();
        _selectedParentId = null;
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Category saved!'), backgroundColor: Colors.green));
      } else {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: ${data['message']}'), backgroundColor: Colors.red));
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _updateCategory(int id) async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);
    try {
      final response = await ApiService.post(
        'category/update_category',
        {
          'id': id.toString(),
          'name': _nameController.text,
          'description': _descController.text,
          'parent_id': _selectedParentId ?? '',
          'user_id': '1', // ID ng nag-update
          'icon': 'category_icon',
        },
      );

      final data = json.decode(response.body);
      if (!mounted) return;
      if (data['success']) {
        Navigator.pop(context);
        _fetchCategories();
        widget.onRefresh();
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Category updated!'), backgroundColor: Colors.green));
      } else {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: ${data['message']}'), backgroundColor: Colors.red));
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _deleteCategory(int id) async {
    try {
      final response = await ApiService.post(
        'category/delete_category',
        {
          'id': id.toString(),
          'user_id': '1', // ID ng nag-delete
        },
      );

      final data = json.decode(response.body);
      if (data['success']) {
        if (!mounted) return;
        _selectedCategory = null;
        _fetchCategories();
        widget.onRefresh();
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Category deleted!'), backgroundColor: Colors.orange));
      }
    } catch (e) {
      debugPrint('Error deleting category: $e');
    }
  }

  Future<void> _restoreCategory(int id) async {
    try {
      final response = await ApiService.post(
        'category/restore_category',
        {
          'category_id': id.toString(),
          'user_id': '1',
        },
      );

      final data = json.decode(response.body);
      if (data['success']) {
        if (!mounted) return;
        _fetchCategories(selectedId: id.toString());
        _fetchDeletedHistory();
        widget.onRefresh();
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Category restored!'), backgroundColor: Colors.green));
      }
    } catch (e) {
      debugPrint('Error restoring category: $e');
    }
  }

  Future<void> _clearCategoryHistory(int id) async {
    try {
      final response = await ApiService.post(
        'category/clear_category_history',
        {
          'category_id': id.toString(),
          'user_id': '1',
        },
      );

      final data = json.decode(response.body);
      if (data['success']) {
        if (!mounted) return;
        _fetchHistory(id);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('History logs cleared!'), backgroundColor: Colors.orange));
      }
    } catch (e) {
      debugPrint('Error clearing history: $e');
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descController.dispose();
    _newParentController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7E6E9),
      body: buildThemedBackground(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // HEADER
              Row(
                children: [
                  if (!_isSearchExpanded)
                    const Text('Category Management', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Color(0xFF1C1B1F))),
                  const Spacer(),
                  // EXPANDABLE SEARCH BAR
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    width: _isSearchExpanded ? 180 : 44,
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
                                _searchQuery = '';
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
                              onChanged: (val) => setState(() => _searchQuery = val.toLowerCase()),
                              decoration: const InputDecoration(
                                hintText: 'Search categories...',
                                hintStyle: TextStyle(fontSize: 13, color: Colors.grey),
                                border: InputBorder.none,
                                contentPadding: EdgeInsets.symmetric(vertical: 11),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  // DELETED HISTORY BUTTON
                  IconButton(
                    onPressed: () => CategoryDialogs.showDeletedHistoryDialog(
                      context: context,
                      deletedHistory: _deletedHistory,
                      onRestore: _restoreCategory,
                    ),
                    icon: const Icon(Icons.history_outlined, color: Colors.grey),
                    tooltip: 'View Deleted History',
                  ),
                  const SizedBox(width: 12),
                  SizedBox(
                    height: 44,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        _nameController.clear();
                        _descController.clear();
                        _newParentController.clear();
                        _selectedParentId = null;
                        _isAddingNewParent = false;
                        CategoryDialogs.showAddDialog(
                          context: context,
                          formKey: _formKey,
                          nameController: _nameController,
                          descController: _descController,
                          newParentController: _newParentController,
                          selectedParentId: _selectedParentId,
                          categories: _categories,
                          isSaving: _isSaving,
                          onParentChanged: (val) => _selectedParentId = val,
                          onNewParentToggled: (val) => _isAddingNewParent = val,
                          onSave: _saveCategory,
                        );
                      },
                      icon: const Icon(Icons.add_circle_outline, size: 18),
                      label: const Text('Add Category', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFD68A96),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              Expanded(
                child: widget.isMobile
                    ? CategoryMasterList(
                  categories: _filteredCategories,
                  selectedCategory: _selectedCategory,
                  onCategorySelected: _onCategorySelected,
                  isLoading: _isLoading,
                )
                    : Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(flex: 3, child: CategoryMasterList(
                      categories: _filteredCategories,
                      selectedCategory: _selectedCategory,
                      onCategorySelected: _onCategorySelected,
                      isLoading: _isLoading,
                    )),
                    const SizedBox(width: 24),
                    Expanded(flex: 2, child: CategoryDetailPanel(
                      selectedCategory: _selectedCategory,
                      categories: _categories,
                      history: _history,
                      isHistoryLoading: _isHistoryLoading,
                      onCategorySelected: _onCategorySelected,
                      onFetchCategories: _fetchCategories,
                      onClearHistory: _clearCategoryHistory,
                      onEdit: (cat) {
                        _nameController.text = cat['name'] ?? '';
                        _descController.text = cat['description'] ?? '';
                        _selectedParentId = (cat['parent_id'] == null || cat['parent_id'].toString() == '0' || cat['parent_id'].toString() == '')
                            ? null
                            : cat['parent_id'].toString();

                        CategoryDialogs.showEditDialog(
                          context: context,
                          cat: cat,
                          formKey: _formKey,
                          nameController: _nameController,
                          descController: _descController,
                          categories: _categories,
                          selectedParentId: _selectedParentId,
                          onParentChanged: (val) => _selectedParentId = val,
                          onUpdate: _updateCategory,
                        );
                      },
                      onDelete: (cat) => CategoryDialogs.confirmDelete(
                        context: context,
                        cat: cat,
                        onDelete: _deleteCategory,
                      ),
                    )),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
