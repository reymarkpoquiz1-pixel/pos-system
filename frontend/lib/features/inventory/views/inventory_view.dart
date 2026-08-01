import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:pos/core/services/api_service.dart';
import 'package:pos/core/widgets/dashboard_widgets.dart';
import 'package:pos/core/constants/config.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

class InventoryView extends StatefulWidget {
  final List<dynamic> productsList;
  final int? userId;
  final VoidCallback? onRefresh;

  const InventoryView({
    super.key, 
    required this.productsList,
    this.userId,
    this.onRefresh,
  });

  @override
  State<InventoryView> createState() => _InventoryViewState();
}

class _InventoryViewState extends State<InventoryView> {
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();
  Map<String, dynamic>? _selectedProduct;
  bool _isSearchExpanded = false;

  // Stock History Tracking
  List<dynamic> _stockHistory = [];
  bool _isLoadingHistory = false;
  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();
    _initializeSelection();
  }

  @override
  void didUpdateWidget(InventoryView oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Sync selection when product list changes (e.g., after archive or refresh)
    if (widget.productsList != oldWidget.productsList) {
      _syncSelection();
    }
  }

  void _initializeSelection() {
    final activeProducts = widget.productsList.where((p) => (p['status'] ?? 'Active') != 'Archived').toList();
    if (activeProducts.isNotEmpty) {
      _selectedProduct = activeProducts[0];
      _fetchStockHistory(_selectedProduct!['id']);
    }
  }

  void _syncSelection() {
    if (_selectedProduct == null) {
      _initializeSelection();
      return;
    }

    // Check if currently selected product still exists and is not archived
    final String currentId = _selectedProduct!['id'].toString();
    final List<dynamic> activeProducts = widget.productsList.where((p) => (p['status'] ?? 'Active') != 'Archived').toList();
    
    bool stillExists = activeProducts.any((p) => p['id'].toString() == currentId);

    if (!stillExists) {
      setState(() {
        if (activeProducts.isNotEmpty) {
          _selectedProduct = activeProducts[0];
          _fetchStockHistory(_selectedProduct!['id']);
        } else {
          _selectedProduct = null;
          _stockHistory = [];
        }
      });
    } else {
      // Update the selected product data (in case prices/stock changed)
      final updatedProd = activeProducts.firstWhere((p) => p['id'].toString() == currentId);
      setState(() {
        _selectedProduct = updatedProd;
      });
    }
  }

  Future<void> _fetchStockHistory(dynamic productId) async {
    setState(() => _isLoadingHistory = true);
    try {
      final response = await ApiService.get('products/get_stock_history?product_id=$productId');
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true && mounted) {
          setState(() {
            _stockHistory = data['history'] ?? [];
            _isLoadingHistory = false;
          });
        }
      }
    } catch (e) {
      debugPrint('Error fetching stock history: $e');
      if (mounted) setState(() => _isLoadingHistory = false);
    }
  }

  void _showReorderList() async {
    showDialog(
      context: context,
      builder: (context) => FutureBuilder<http.Response>(
        future: ApiService.get('inventory/get_reorder_list'),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
          final data = json.decode(snapshot.data!.body);
          final products = data['products'] as List;

          return AlertDialog(
            title: const Text('Items to Reorder', style: TextStyle(fontWeight: FontWeight.bold)),
            content: SizedBox(
              width: 400,
              height: 300,
              child: products.isEmpty 
                ? const Center(child: Text('All stocks are healthy!'))
                : ListView.builder(
                    itemCount: products.length,
                    itemBuilder: (context, index) {
                      final p = products[index];
                      return Material(
                        color: Colors.transparent,
                        child: ListTile(
                          leading: CircleAvatar(backgroundColor: Colors.red.shade100, child: const Icon(Icons.warning_amber_rounded, color: Colors.red)),
                          title: Text(p['name']),
                          subtitle: Text('Stock: ${p['stock_quantity']} (Min: ${p['reorder_level']})'),
                          trailing: IconButton(icon: const Icon(Icons.edit_note), onPressed: () {
                            Navigator.pop(context);
                            _showAdjustmentDialog(p);
                          }),
                        ),
                      );
                    },
                  ),
            ),
            actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close'))],
          );
        },
      ),
    );
  }

  void _showAdjustmentDialog(Map<String, dynamic> prod, {int? preselectedIndex}) {
    final TextEditingController amountController = TextEditingController();
    String type = 'Add'; // Default
    String reason = 'Restock';
    final List<String> reasons = ['Restock', 'Damage', 'Correction', 'Sold (Manual)', 'Return'];
    
    List<dynamic> variants = [];
    if (prod['variants'] != null) {
      try {
        variants = (prod['variants'] is String) ? json.decode(prod['variants']) : prod['variants'];
      } catch (e) {
        debugPrint('Error parsing variants: $e');
      }
    }

    // Default selection to preselected index, or first variant if exists
    int? selectedVariantIndex = preselectedIndex ?? (variants.isNotEmpty ? 0 : null);

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: const Color(0xFFFBECEF),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          title: Text('Stock Adjustment: ${prod['name']}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Expanded(
                    child: ChoiceChip(
                      label: const Text('Add Stock'),
                      selected: type == 'Add',
                      onSelected: (val) => setDialogState(() => type = 'Add'),
                      selectedColor: Colors.green.shade100,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ChoiceChip(
                      label: const Text('Remove Stock'),
                      selected: type == 'Subtract',
                      onSelected: (val) => setDialogState(() => type = 'Subtract'),
                      selectedColor: Colors.red.shade100,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              if (variants.isNotEmpty) ...[
                DropdownButtonFormField<int>(
                  initialValue: selectedVariantIndex,
                  decoration: InputDecoration(
                    labelText: 'Select Color/Size',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                  items: variants.asMap().entries.map((entry) {
                    final v = entry.value;
                    final int vStock = int.tryParse(v['stock']?.toString() ?? '0') ?? 0;
                    return DropdownMenuItem<int>(
                      value: entry.key,
                      child: Text('${v['color_name']} (${v['size']}) - Stock: $vStock'),
                    );
                  }).toList(),
                  onChanged: (val) => setDialogState(() => selectedVariantIndex = val),
                ),
                const SizedBox(height: 16),
              ],
              TextField(
                controller: amountController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: 'Quantity',
                  hintText: 'Enter amount...',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                initialValue: reason,
                decoration: InputDecoration(
                  labelText: 'Reason',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
                items: reasons.map((r) => DropdownMenuItem(value: r, child: Text(r))).toList(),
                onChanged: (val) => setDialogState(() => reason = val!),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: _isProcessing ? null : () => Navigator.pop(context), 
              child: const Text('Cancel')
            ),
            ElevatedButton(
              onPressed: _isProcessing ? null : () => _processAdjustment(
                prod['id'], 
                type, 
                amountController.text, 
                reason,
                variantIndex: selectedVariantIndex
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFD68A96),
                foregroundColor: Colors.white,
                disabledBackgroundColor: Colors.grey.shade400,
              ),
              child: _isProcessing 
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                : const Text('Confirm'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _processAdjustment(dynamic productId, String type, String amountStr, String reason, {int? variantIndex}) async {
    int amount = int.tryParse(amountStr) ?? 0;
    if (amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please enter a valid quantity.')));
      return;
    }

    setState(() => _isProcessing = true);

    // Negate if subtracting
    int finalAmount = type == 'Add' ? amount : -amount;

    try {
      final Map<String, String> body = {
        'product_id': productId.toString(),
        'adjustment': finalAmount.toString(),
        'reason': reason,
        'user_id': widget.userId?.toString() ?? '1',
      };
      
      if (variantIndex != null) {
        body['variant_index'] = variantIndex.toString();
      }

      final response = await ApiService.post(
        'products/adjust_stock',
        body,
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success']) {
          if (!mounted) return;
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Stock adjusted successfully!'), backgroundColor: Colors.green)
          );
          widget.onRefresh?.call();
          _fetchStockHistory(productId);
        } else {
          throw Exception(data['message'] ?? 'Failed to adjust stock');
        }
      } else {
        throw Exception('Server returned status code ${response.statusCode}');
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: ${e.toString()}'), backgroundColor: Colors.red)
      );
      debugPrint('Error adjusting stock: $e');
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  String _formatName(String? name) {
    if (name == null || name.isEmpty) return 'Admin';
    return name.split(' ').map((word) {
      if (word.isEmpty) return '';
      return word[0].toUpperCase() + word.substring(1).toLowerCase();
    }).join(' ');
  }

  String _formatDateTime(String? dateTimeStr) {
    if (dateTimeStr == null || dateTimeStr.isEmpty) return 'N/A';
    try {
      DateTime dt = DateTime.parse(dateTimeStr);
      int hour = dt.hour;
      String ampm = hour >= 12 ? 'PM' : 'AM';
      int displayHour = hour % 12;
      if (displayHour == 0) displayHour = 12;
      String minute = dt.minute.toString().padLeft(2, '0');
      
      String year = dt.year.toString();
      String month = dt.month.toString().padLeft(2, '0');
      String day = dt.day.toString().padLeft(2, '0');
      
      return '$month-$day-$year $displayHour:$minute $ampm';
    } catch (e) {
      return dateTimeStr;
    }
  }

  String _formatDateOnly(String? dateTimeStr) {
    if (dateTimeStr == null || dateTimeStr.isEmpty) return 'N/A';
    try {
      DateTime dt = DateTime.parse(dateTimeStr);
      String year = dt.year.toString();
      String month = dt.month.toString().padLeft(2, '0');
      String day = dt.day.toString().padLeft(2, '0');
      return '$month-$day-$year';
    } catch (e) {
      return dateTimeStr.split(' ')[0];
    }
  }

  String _formatTimeOnly(String? dateTimeStr) {
    if (dateTimeStr == null || dateTimeStr.isEmpty) return '';
    try {
      DateTime dt = DateTime.parse(dateTimeStr);
      int hour = dt.hour;
      String ampm = hour >= 12 ? 'PM' : 'AM';
      int displayHour = hour % 12;
      if (displayHour == 0) displayHour = 12;
      String minute = dt.minute.toString().padLeft(2, '0');
      return '$displayHour:$minute $ampm';
    } catch (e) {
      return '';
    }
  }

  List<dynamic> get _filteredProducts {
    final List<dynamic> baseList = widget.productsList.where((prod) => (prod['status'] ?? 'Active') != 'Archived').toList();
    if (_searchQuery.isEmpty) return baseList;
    return baseList.where((prod) {
      final name = (prod['name'] ?? '').toString().toLowerCase();
      final barcode = (prod['barcode'] ?? '').toString().toLowerCase();
      return name.contains(_searchQuery) || barcode.contains(_searchQuery);
    }).toList();
  }

  void _showBarcodeModal(String barcode, String productName) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFFFBECEF),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        contentPadding: const EdgeInsets.all(32),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.qr_code_scanner_rounded, size: 60, color: Color(0xFFD68A96)),
            const SizedBox(height: 20),
            Text(
              productName,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF1C1B1F)),
            ),
            const SizedBox(height: 8),
            const Text('Product Barcode', style: TextStyle(fontSize: 12, color: Colors.black45)),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFEFAFB8)),
              ),
              child: Text(
                barcode,
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Color(0xFF1C1B1F), letterSpacing: 1.5, fontFamily: 'monospace'),
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFD68A96),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 0,
                ),
                child: const Text('Close'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _printBarcodeLabel(String barcode, String productName) async {
    final doc = pw.Document();
    
    // Fetch barcode image
    final response = await http.get(Uri.parse('https://bwipjs-api.metafloor.com/?bcid=code128&text=$barcode&scale=3&height=10&includetext=false'));
    final barcodeImage = pw.MemoryImage(response.bodyBytes);

    doc.addPage(
      pw.Page(
        pageFormat: PdfPageFormat(50 * PdfPageFormat.mm, 30 * PdfPageFormat.mm, marginAll: 2 * PdfPageFormat.mm),
        build: (pw.Context context) {
          return pw.Column(
            mainAxisAlignment: pw.MainAxisAlignment.center,
            children: [
              pw.Text(productName, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 8), textAlign: pw.TextAlign.center),
              pw.SizedBox(height: 2),
              pw.Image(barcodeImage, height: 15 * PdfPageFormat.mm),
              pw.SizedBox(height: 2),
              pw.Text(barcode, style: const pw.TextStyle(fontSize: 7, letterSpacing: 2)),
            ],
          );
        },
      ),
    );

    await Printing.layoutPdf(onLayout: (PdfPageFormat format) async => doc.save());
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

  Widget _buildStatusBadge(int stock, int reorder) {
    bool isOut = stock <= 0;
    bool isLow = stock <= reorder && stock > 0;
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: isOut ? Colors.red.withValues(alpha: 0.1) : (isLow ? Colors.orange.withValues(alpha: 0.1) : Colors.green.withValues(alpha: 0.1)),
        borderRadius: BorderRadius.circular(20),
      ),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.circle, size: 8, color: isOut ? Colors.red : (isLow ? Colors.orange : Colors.green)),
            const SizedBox(width: 6),
            Text(
              isOut ? 'Out Stock' : 'Stock',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: isOut ? Colors.red : (isLow ? Colors.orange.shade800 : Colors.green.shade700)
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
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
                    const Text(
                      'Inventory Stock Management',
                      style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Color(0xFF1C1B1F), letterSpacing: -0.5),
                    ),
                  const Spacer(),
                  // REORDER BUTTON (Outside Search for better layout)
                  ElevatedButton.icon(
                    onPressed: _showReorderList,
                    icon: const Icon(Icons.list_alt_rounded, size: 18),
                    label: const Text('Reorder List', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFD68A96),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    ),
                  ),
                  const SizedBox(width: 12),
                  // SEARCH BAR
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    width: _isSearchExpanded ? 240 : 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(22),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.05),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
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
                                hintText: 'Search products...',
                                hintStyle: TextStyle(fontSize: 13, color: Colors.grey),
                                border: InputBorder.none,
                                contentPadding: EdgeInsets.only(right: 16),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              Expanded(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // MASTER LIST (Left)
                    Expanded(
                      flex: 3,
                      child: _buildMasterList(),
                    ),
                    const SizedBox(width: 24),
                    // DETAIL PANEL (Right)
                    Expanded(
                      flex: 2,
                      child: _buildDetailPanel(),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMasterList() {
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
                  Expanded(flex: 4, child: Text('Name', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13), overflow: TextOverflow.ellipsis)),
                  Expanded(flex: 1, child: Text('Stock', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13), textAlign: TextAlign.center, overflow: TextOverflow.ellipsis)),
                  Expanded(flex: 3, child: Text('Date Added', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13), textAlign: TextAlign.center, overflow: TextOverflow.ellipsis)),
                  Expanded(flex: 2, child: Text('Added By', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13), textAlign: TextAlign.center, overflow: TextOverflow.ellipsis)),
                  Expanded(flex: 3, child: Text('Status', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13), textAlign: TextAlign.center, overflow: TextOverflow.ellipsis)),
                ],
              ),
            ),
            Expanded(
              child: _filteredProducts.isEmpty
                  ? const Center(child: Text('No items found.'))
                  : ListView.separated(
                      itemCount: _filteredProducts.length,
                      separatorBuilder: (context, index) => Divider(height: 1, color: Colors.pink.shade50),
                      itemBuilder: (context, index) {
                        final prod = _filteredProducts[index];
                        final int stock = int.tryParse(prod['stock_quantity']?.toString() ?? '0') ?? 0;
                        final int reorder = int.tryParse(prod['reorder_level']?.toString() ?? '20') ?? 20;
                        final bool isSelected = _selectedProduct?['id'] == prod['id'];

                        return InkWell(
                          onTap: () {
                            setState(() {
                              _selectedProduct = prod;
                              _fetchStockHistory(prod['id']);
                            });
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                            color: isSelected ? const Color(0xFFFCE1E5) : Colors.transparent,
                            child: Row(
                              children: [
                                Expanded(
                                  flex: 4,
                                  child: Row(
                                    children: [
                                      Container(
                                        width: 45,
                                        height: 45,
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          border: Border.all(color: Colors.white, width: 2),
                                          image: prod['image_url'] != null
                                              ? DecorationImage(
                                                  image: NetworkImage(_getImageUrl(prod['image_url'].toString())),
                                                  fit: BoxFit.cover,
                                                )
                                              : null,
                                        ),
                                        child: prod['image_url'] == null ? const Icon(Icons.image_outlined, size: 20, color: Colors.grey) : null,
                                      ),
                                      const SizedBox(width: 14),
                                      Expanded(
                                        child: Text(
                                          prod['name'] ?? '',
                                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF1C1B1F)),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Expanded(
                                  flex: 1,
                                  child: Center(
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: stock <= reorder ? Colors.red.withValues(alpha: 0.1) : Colors.green.withValues(alpha: 0.1),
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: Text(
                                        '$stock',
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                          color: stock <= reorder ? Colors.red : Colors.green.shade700,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ),
                                ),
                                Expanded(
                                  flex: 3,
                                  child: Center(
                                    child: prod['created_at'] != null
                                      ? Column(
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          children: [
                                            Text(
                                              _formatDateOnly(prod['created_at']?.toString()),
                                              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF1C1B1F)),
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                            Text(
                                              _formatTimeOnly(prod['created_at'].toString()),
                                              style: const TextStyle(fontSize: 9, color: Colors.black54),
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ],
                                        )
                                      : const Text('N/A', style: TextStyle(fontSize: 12, color: Colors.black54)),
                                  ),
                                ),
                                Expanded(
                                  flex: 2,
                                  child: Center(
                                    child: Text(
                                      _formatName(prod['added_by_name']),
                                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ),
                                Expanded(
                                  flex: 3,
                                  child: Center(child: _buildStatusBadge(stock, reorder)),
                                ),
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

  Widget _buildDetailPanel() {
    if (_selectedProduct == null) {
      return const Center(child: Text('Select a product to view details.', style: TextStyle(color: Colors.grey)));
    }

    final prod = _selectedProduct!;
    final int totalStock = int.tryParse(prod['stock_quantity']?.toString() ?? '0') ?? 0;
    final int reorder = int.tryParse(prod['reorder_level']?.toString() ?? '20') ?? 20;
    
    List<dynamic> variants = [];
    if (prod['variants'] != null) {
      try {
        variants = (prod['variants'] is String) ? json.decode(prod['variants']) : prod['variants'];
      } catch (e) {
        debugPrint('Error parsing variants: $e');
      }
    }

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
                  const Text('Description', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF1C1B1F))),
                  const SizedBox(height: 12),
                  Text(
                    prod['description'] ?? 'No description available for this product.',
                    style: const TextStyle(fontSize: 14, color: Colors.black54, height: 1.6),
                  ),
                  const SizedBox(height: 32),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 130,
                        height: 130,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: const Color(0xFFFBECEF),
                          border: Border.all(color: Colors.white, width: 4),
                          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10)],
                          image: prod['image_url'] != null
                              ? DecorationImage(
                                  image: NetworkImage(_getImageUrl(prod['image_url'].toString())),
                                  fit: BoxFit.cover,
                                )
                              : null,
                        ),
                        child: prod['image_url'] == null ? const Icon(Icons.image_outlined, size: 40, color: Colors.grey) : null,
                      ),
                      const SizedBox(width: 28),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              prod['name'] ?? '',
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w500,
                                color: Color(0xFF1C1B1F),
                                letterSpacing: 0.2,
                              ),
                            ),
                            const SizedBox(height: 4),
                            const Text('Variant Stocks', style: TextStyle(fontSize: 13, color: Colors.grey, fontWeight: FontWeight.w500)),
                            const SizedBox(height: 16),
                            if (variants.isEmpty)
                              const Text('Standard item (No variants)', style: TextStyle(fontSize: 12, color: Colors.grey, fontStyle: FontStyle.italic))
                            else
                              ...variants.map((v) {
                                // Kunin ang kulay mula sa color_hex, kung wala ay default BlueGrey
                                Color variantColor = const Color(0xFF607D8B);
                                if (v['color_hex'] != null) {
                                  try {
                                    String hex = v['color_hex'].toString().replaceFirst('#', '');
                                    variantColor = Color(int.parse(hex, radix: 16));
                                  } catch (e) {
                                    debugPrint('Error parsing variant color: $e');
                                  }
                                }

                                final int vStock = int.tryParse(v['stock']?.toString() ?? '0') ?? 0;

                                return Padding(
                                  padding: const EdgeInsets.only(bottom: 10.0),
                                  child: Row(
                                    children: [
                                      Icon(Icons.circle, size: 8, color: variantColor),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: Text(
                                          '${v['color_name'] != null && v['color_name'].toString().isNotEmpty ? v['color_name'].toString()[0].toUpperCase() + v['color_name'].toString().substring(1) : ''} (${v['size']}): ',
                                          style: const TextStyle(fontSize: 13, color: Colors.black87),
                                        ),
                                      ),
                                      Text(
                                        '$vStock',
                                        style: TextStyle(
                                          fontSize: 13, 
                                          fontWeight: FontWeight.bold,
                                          color: vStock <= 0 ? Colors.red : (vStock <= reorder ? Colors.orange.shade800 : Colors.black87),
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              }),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 32),
                  const Text('Audit Trail', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFCE1E5),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      children: [
                        _buildAuditRow(Icons.calendar_today_rounded, 'Date Added:', _formatDateTime(prod['created_at'])),
                        const SizedBox(height: 10),
                        _buildAuditRow(Icons.person_outline_rounded, 'Added By:', _formatName(prod['added_by_name'])),
                        const SizedBox(height: 10),
                        _buildAuditRow(Icons.update_rounded, 'Last Updated:', _formatDateTime(prod['updated_at'])),
                      ],
                    ),
                  ),
                  const SizedBox(height: 32),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Stock Adjustment History', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                      if (_isLoadingHistory)
                        const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFFD68A96))),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Container(
                    height: 200,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFFFBECEF)),
                    ),
                    child: _stockHistory.isEmpty
                        ? const Center(child: Text('No history available.', style: TextStyle(fontSize: 12, color: Colors.grey)))
                        : ListView.separated(
                            padding: const EdgeInsets.all(12),
                            itemCount: _stockHistory.length,
                            separatorBuilder: (context, index) => const Divider(height: 16),
                            itemBuilder: (context, index) {
                              final h = _stockHistory[index];
                              final int adj = int.tryParse(h['adjustment'].toString()) ?? 0;
                              final bool isAdd = adj > 0;
                              return Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(6),
                                    decoration: BoxDecoration(
                                      color: isAdd ? Colors.green.shade50 : Colors.red.shade50,
                                      shape: BoxShape.circle,
                                    ),
                                    child: Icon(
                                      isAdd ? Icons.add_circle_outline : Icons.remove_circle_outline,
                                      size: 16,
                                      color: isAdd ? Colors.green : Colors.red,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          '${h['reason']} (${adj > 0 ? '+' : ''}$adj)',
                                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                                        ),
                                        Text(
                                          'By: ${_formatName(h['user_name'])} • ${_formatDateTime(h['created_at'])}',
                                          style: const TextStyle(fontSize: 10, color: Colors.grey),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              );
                            },
                          ),
                  ),
                  const SizedBox(height: 32),
                  const Text('Inventory Health', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            totalStock <= 0 ? 'Out of Stock' : (totalStock <= reorder ? 'Low Stock Warning' : 'Healthy Stock'),
                            style: TextStyle(
                              fontSize: 12, 
                              fontWeight: FontWeight.w600, 
                              color: totalStock <= 0 ? Colors.red : (totalStock <= reorder ? Colors.orange.shade800 : Colors.green.shade700)
                            ),
                          ),
                          Text(
                            '${((totalStock / (reorder * 2)).clamp(0.0, 1.0) * 100).toInt()}%',
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.black54),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Container(
                        height: 10,
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: const Color(0xFFFBECEF),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: FractionallySizedBox(
                          alignment: Alignment.centerLeft,
                          widthFactor: (totalStock / (reorder * 2)).clamp(0.0, 1.0),
                          child: Container(
                            decoration: BoxDecoration(
                              color: totalStock <= 0 
                                  ? Colors.red 
                                  : (totalStock <= reorder ? Colors.orange : const Color(0xFFD68A96)),
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          // Dito ang mga totoong actions na gagana sa data mo
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            decoration: BoxDecoration(
              color: const Color(0xFFFBECEF).withValues(alpha: 0.3),
              border: Border(top: BorderSide(color: Colors.pink.shade50)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                _detailActionIcon(Icons.print_outlined, () => _printBarcodeLabel(prod['barcode'] ?? 'N/A', prod['name'] ?? '')),
                const SizedBox(width: 20),
                _detailActionIcon(Icons.qr_code_scanner_rounded, () => _showBarcodeModal(prod['barcode'] ?? 'N/A', prod['name'] ?? '')),
                const SizedBox(width: 20),
                _detailActionIcon(Icons.edit_outlined, () => _showAdjustmentDialog(prod)),
                const SizedBox(width: 20),
                _detailActionIcon(Icons.delete_outline, () => _archiveProduct(prod['id'], prod['name'] ?? 'Product'), color: Colors.redAccent),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _archiveProduct(dynamic productId, String productName) async {
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFFFBECEF),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Text('Archive Product?', style: TextStyle(fontWeight: FontWeight.bold)),
        content: Text('Are you sure you want to archive "$productName"? It will be hidden from the app but preserved in your sales records.'),
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

    setState(() => _isProcessing = true);
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
          widget.onRefresh?.call();
          setState(() {
            _selectedProduct = null;
            _stockHistory = [];
          });
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
      if (mounted) setState(() => _isProcessing = false);
    }
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
        Icon(icon, size: 16, color: const Color(0xFFD68A96)),
        const SizedBox(width: 10),
        Text(label, style: const TextStyle(fontSize: 12, color: Colors.black54)),
        const Spacer(),
        Text(value, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF1C1B1F))),
      ],
    );
  }
}
