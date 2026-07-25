import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:pos/core/services/api_service.dart';
import 'dart:convert';
import 'package:pos/core/widgets/dashboard_widgets.dart';
import 'package:pos/core/services/database_helper.dart';
import 'package:pos/core/services/sync_service.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:pos/core/constants/config.dart';
import 'package:pos/core/services/connectivity_service.dart';

class PosView extends StatefulWidget {
  final String username;
  final int userId;
  final int terminalId;
  final Map<String, dynamic>? storeSettings;
  const PosView({super.key, required this.username, required this.userId, required this.terminalId, this.storeSettings});

  @override
  State<PosView> createState() => _PosViewState();
}

class _PosViewState extends State<PosView> {
  List<dynamic> _products = [];
  List<dynamic> _filteredProducts = [];
  final List<Map<String, dynamic>> _cart = [];
  bool _isLoading = true;
  bool _isShiftOpen = false;
  Map<String, dynamic>? _selectedCustomer;
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _paymentController = TextEditingController();
  final TextEditingController _referenceController = TextEditingController();
  int _pendingSyncCount = 0;
  bool _isScannerOpen = false;
  bool _isOffline = false;

  String _formatDateTime(DateTime dt) {
    String month = dt.month.toString().padLeft(2, '0');
    String day = dt.day.toString().padLeft(2, '0');
    String year = dt.year.toString();

    int hour = dt.hour > 12 ? dt.hour - 12 : (dt.hour == 0 ? 12 : dt.hour);
    String minute = dt.minute.toString().padLeft(2, '0');
    String period = dt.hour >= 12 ? 'PM' : 'AM';

    return "$month-$day-$year $hour:$minute $period";
  }

  @override
  void initState() {
    super.initState();
    _isOffline = !ConnectivityService.instance.isConnectedNotifier.value;
    ConnectivityService.instance.isConnectedNotifier.addListener(_onConnectivityChanged);
    _checkShiftStatus();
    _fetchProducts();
    _updatePendingSync();
  }

  void _onConnectivityChanged() {
    if (mounted) {
      setState(() {
        _isOffline = !ConnectivityService.instance.isConnectedNotifier.value;
      });
    }
  }

  @override
  void dispose() {
    ConnectivityService.instance.isConnectedNotifier.removeListener(_onConnectivityChanged);
    _searchController.dispose();
    _paymentController.dispose();
    _referenceController.dispose();
    super.dispose();
  }

  Future<void> _updatePendingSync() async {
    int count = await SyncService.getPendingCount();
    if (mounted) setState(() => _pendingSyncCount = count);
  }

  Future<void> _checkShiftStatus() async {
    try {
      final response = await ApiService.get('sales/get_active_shift');
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        setState(() {
          _isShiftOpen = data['success'] ?? false;
        });
        if (!_isShiftOpen && mounted) {
          _showShiftAlert();
        }
      }
    } catch (e) {
      debugPrint('Error checking shift: $e');
    }
  }

  void _showShiftAlert() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Shift Required', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
        content: const Text('You must open a shift before you can process any sales. Please go to Shift Management.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  Future<void> _fetchProducts() async {
    setState(() => _isLoading = true);
    try {
      final response = await ApiService.get('products/get_products');
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        setState(() {
          _products = data['products'] ?? [];
          _filteredProducts = _products;
          _isLoading = false;
        });
        _checkLowStock();
      }
    } catch (e) {
      setState(() => _isLoading = false);
      debugPrint('Error: $e');
    }
  }

  void _checkLowStock() {
    int lowStockCount = _products.where((p) {
      int stock = int.tryParse(p['stock_quantity']?.toString() ?? '0') ?? 0;
      int reorder = int.tryParse(p['reorder_level']?.toString() ?? '10') ?? 10;
      return stock <= reorder && stock > 0;
    }).length;

    if (lowStockCount > 0 && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('⚠️ Alert: $lowStockCount items are low on stock!'),
          backgroundColor: Colors.orange,
          action: SnackBarAction(label: 'View', textColor: Colors.white, onPressed: () {}),
        ),
      );
    }
  }

  void _filterProducts(String query) {
    if (query.isEmpty) {
      setState(() {
        _filteredProducts = _products;
      });
      return;
    }

    final lowerQuery = query.toLowerCase();

    try {
      final exactMatch = _products.firstWhere(
        (p) => p['barcode'].toString().toLowerCase() == lowerQuery,
        orElse: () => null,
      );

      if (exactMatch != null) {
        _searchController.clear();
        _addToCart(exactMatch);
        setState(() {
          _filteredProducts = _products;
        });
        return;
      }
    } catch (e) {}

    setState(() {
      _filteredProducts = _products
          .where((p) =>
              p['name'].toString().toLowerCase().contains(lowerQuery) ||
              p['barcode'].toString().toLowerCase().contains(lowerQuery))
          .toList();
    });
  }

  void _addToCart(Map<String, dynamic> product) {
    if (!_isShiftOpen) {
      _showShiftAlert();
      return;
    }

    int stock = int.tryParse(product['stock_quantity']?.toString() ?? '0') ?? 0;
    if (stock <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('❌ Error: This item is out of stock!'), backgroundColor: Colors.red),
      );
      return;
    }

    var variantsData = product['variants'];
    List<dynamic> variants = [];
    if (variantsData != null && variantsData.toString().isNotEmpty) {
      try {
        variants = (variantsData is String) ? json.decode(variantsData) : variantsData;
      } catch (e) {
        debugPrint("Error decoding variants: $e");
      }
    }

    if (variants.isNotEmpty) {
      _showVariantSelectionDialog(product, variants);
    } else {
      _performAddToCart(product);
    }
  }

  void _showVariantSelectionDialog(Map<String, dynamic> product, List<dynamic> variants) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Select Variant for ${product['name']}'),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.separated(
            shrinkWrap: true,
            itemCount: variants.length,
            separatorBuilder: (context, index) => const Divider(),
            itemBuilder: (context, index) {
              final v = variants[index];
              final String colorName = v['color_name'] ?? '';
              final String size = v['size'] ?? '';
              final int stock = int.tryParse(v['stock']?.toString() ?? '0') ?? 0;
              final colorHex = v['color_hex'] ?? 'ffffffff';

              return ListTile(
                leading: Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    color: Color(int.parse(colorHex, radix: 16)),
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                ),
                title: Text('$colorName ${size.isNotEmpty ? "($size)" : ""}'),
                subtitle: Text('Stock: $stock', style: TextStyle(color: stock <= 0 ? Colors.red : Colors.green)),
                trailing: const Icon(Icons.add_shopping_cart, size: 20, color: Colors.blue),
                enabled: stock > 0,
                onTap: () {
                  Navigator.pop(context);
                  _performAddToCart(product, v);
                },
              );
            },
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        ],
      ),
    );
  }

  void _performAddToCart(Map<String, dynamic> product, [Map<String, dynamic>? variant]) {
    final int maxStock = variant != null
        ? (int.tryParse(variant['stock']?.toString() ?? '0') ?? 0)
        : (int.tryParse(product['stock_quantity']?.toString() ?? '0') ?? 0);

    setState(() {
      final String variantName = variant?['color_name'] ?? '';
      final String variantSize = variant?['size'] ?? '';

      final index = _cart.indexWhere((item) =>
        item['id'] == product['id'] &&
        item['variant_name'] == variantName &&
        item['variant_size'] == variantSize
      );

      if (index >= 0) {
        if (_cart[index]['quantity'] < maxStock) {
          _cart[index]['quantity']++;
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('⚠️ Max stock reached for this item.'), backgroundColor: Colors.orange),
          );
        }
      } else {
        _cart.add({
          'id': product['id'],
          'name': product['name'],
          'price': double.tryParse(product['selling_price'].toString()) ?? 0.0,
          'quantity': 1,
          'barcode': product['barcode'],
          'variant_name': variantName,
          'variant_size': variantSize,
        });
      }
    });
  }

  void _removeFromCart(int index) {
    setState(() {
      if (_cart[index]['quantity'] > 1) {
        _cart[index]['quantity']--;
      } else {
        _cart.removeAt(index);
      }
    });
  }

  double get _totalAmount {
    return _cart.fold(0, (sum, item) => sum + (item['price'] * item['quantity']));
  }

  void _showPaymentDialog() {
    if (_cart.isEmpty) return;
    _paymentController.clear();
    _referenceController.clear();
    String selectedMethod = 'Cash';

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          final media = MediaQuery.of(context);
          final bool isLandscape = media.orientation == Orientation.landscape;
          final bool isKeyboardOpen = media.viewInsets.bottom > 0;

          double tendered = double.tryParse(_paymentController.text) ?? 0.0;
          double change = tendered > _totalAmount ? tendered - _totalAmount : 0.0;

          return Dialog(
            insetPadding: EdgeInsets.symmetric(
              horizontal: isLandscape ? 40 : 20,
              vertical: isKeyboardOpen ? 10 : 24
            ),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: isLandscape ? 700 : 400),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.payments_outlined, color: Colors.blue, size: 24),
                          const SizedBox(width: 10),
                          const Text('Process Payment', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                          const Spacer(),
                          IconButton(
                            onPressed: () => Navigator.pop(context),
                            icon: const Icon(Icons.close, size: 20, color: Colors.grey),
                          ),
                        ],
                      ),
                      const Divider(height: 24),

                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: ['Cash', 'GCash', 'Maya', 'Card'].map((m) => ChoiceChip(
                          label: Text(m),
                          selected: selectedMethod == m,
                          onSelected: (val) => setDialogState(() => selectedMethod = m),
                        )).toList(),
                      ),
                      const SizedBox(height: 20),

                      if (isLandscape)
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(child: _buildPaymentSummary(change)),
                            const SizedBox(width: 24),
                            Expanded(child: Column(
                              children: [
                                _buildPaymentInput(setDialogState),
                                if (selectedMethod != 'Cash') ...[
                                  const SizedBox(height: 12),
                                  TextField(
                                    controller: _referenceController,
                                    decoration: const InputDecoration(labelText: 'Reference Number', border: OutlineInputBorder()),
                                  ),
                                ]
                              ],
                            )),
                          ],
                        )
                      else ...[
                        _buildPaymentSummary(change),
                        const SizedBox(height: 20),
                        _buildPaymentInput(setDialogState),
                        if (selectedMethod != 'Cash') ...[
                          const SizedBox(height: 12),
                          TextField(
                            controller: _referenceController,
                            decoration: const InputDecoration(labelText: 'Reference Number', border: OutlineInputBorder()),
                          ),
                        ]
                      ],

                      const SizedBox(height: 24),

                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
                          const SizedBox(width: 12),
                          ElevatedButton(
                            onPressed: (selectedMethod == 'Cash' && tendered < _totalAmount) ? null : () => _finalizeTransaction(tendered, change, selectedMethod),
                            style: ElevatedButton.styleFrom(backgroundColor: Colors.blue, foregroundColor: Colors.white),
                            child: const Text('FINALIZE & PRINT'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        }
      ),
    );
  }

  Widget _buildPaymentSummary(double change) {
    final bool isLandscape = MediaQuery.of(context).orientation == Orientation.landscape;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Total Amount to Pay:', style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text('₱${_totalAmount.toStringAsFixed(2)}',
              style: TextStyle(fontSize: isLandscape ? 24 : 32, fontWeight: FontWeight.w900, color: Colors.blue)),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.green.shade50,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Change:', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.green)),
              Text('₱${change.toStringAsFixed(2)}',
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.green)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPaymentInput(StateSetter setDialogState) {
    return TextField(
      controller: _paymentController,
      autofocus: true,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      decoration: const InputDecoration(
        labelText: 'Amount Received',
        hintText: '0.00',
        prefixText: '₱ ',
        border: OutlineInputBorder(),
        filled: true,
        fillColor: Color(0xFFF8FAFC),
      ),
      onChanged: (val) => setDialogState(() {}),
    );
  }

  Future<void> _finalizeTransaction(double tendered, double change, String method) async {
    Navigator.pop(context);

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    final cartItems = _cart.map((item) => {
      'product_id': item['id'],
      'quantity': item['quantity'],
      'unit_price': item['price'],
    }).toList();

    final orderData = {
      'items': cartItems,
      'total_amount': _totalAmount,
      'discount': 0.0,
      'amount_paid': tendered,
      'change': change,
      'payment_method': method,
      'payment_reference': _referenceController.text,
      'payment_status': 'Paid',
      'order_status': 'Delivered',
      'order_type': 'Walk-in',
      'customer_id': _selectedCustomer != null ? _selectedCustomer!['id'] : null,
    };

    try {
      final response = await ApiService.post('place_order', orderData);
      final data = json.decode(response.body);

      if (!mounted) return;
      Navigator.pop(context);

      if (data['success'] == true || response.statusCode == 200) {
        _handleSuccessfulSale(data['sale_id']?.toString() ?? 'OFFLINE', tendered, change, method);
      } else if (response.statusCode >= 500) {
        _saveOffline(orderData, tendered, change, method);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${data['message']}'), backgroundColor: Colors.red),
        );
      }
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context);
      _saveOffline(orderData, tendered, change, method);
    }
  }

  void _saveOffline(Map<String, dynamic> orderData, double tendered, double change, String method) async {
    final List<Map<String, dynamic>> items = (orderData['items'] as List).cast<Map<String, dynamic>>();
    await DatabaseHelper.instance.saveOfflineSale(orderData, items);

    _handleSuccessfulSale('OFFLINE-${DateTime.now().millisecondsSinceEpoch}', tendered, change, method, isOffline: true);
    _updatePendingSync();
  }

  void _handleSuccessfulSale(String saleId, double tendered, double change, String method, {bool isOffline = false}) {
    final transactionData = {
      'transaction_id': saleId,
      'date_created': _formatDateTime(DateTime.now()),
      'customer_name': _selectedCustomer != null ? _selectedCustomer!['name'] : 'Walk-in Customer',
      'cashier_name': widget.username,
      'terminal_id': widget.terminalId > 0 ? widget.terminalId : 1,
      'total_amount': _totalAmount.toStringAsFixed(2),
      'amount_tendered': tendered.toStringAsFixed(2),
      'change': change.toStringAsFixed(2),
      'payment_method': method,
      'status': isOffline ? 'Offline Pending' : 'Paid',
      'items': List<Map<String, dynamic>>.from(_cart),
    };

    showProfessionalReceipt(context, transactionData, storeSettings: widget.storeSettings);

    if (transactionData['payment_method'] == 'Cash') {
      _simulateCashDrawerKick();
    }

    setState(() {
      _cart.clear();
      _selectedCustomer = null;
    });

    _fetchProducts();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(isOffline ? '⚠️ Order saved offline! It will sync later.' : '✅ Transaction completed successfully!'),
        backgroundColor: isOffline ? Colors.orange : Colors.green
      ),
    );
  }

  void _showScannerDialog() {
    setState(() => _isScannerOpen = true);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Scan Product Barcode'),
        content: SizedBox(
          width: 400,
          height: 400,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: MobileScanner(
              onDetect: (capture) {
                final List<Barcode> barcodes = capture.barcodes;
                for (final barcode in barcodes) {
                  final String? code = barcode.rawValue;
                  if (code != null) {
                    debugPrint('Barcode found! $code');
                    _handleBarcodeScanned(code);
                    Navigator.pop(context);
                    break;
                  }
                }
              },
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close')),
        ],
      ),
    ).then((_) => setState(() => _isScannerOpen = false));
  }

  void _handleBarcodeScanned(String code) {
    try {
      final product = _products.firstWhere(
        (p) => p['barcode'].toString().toLowerCase() == code.toLowerCase(),
        orElse: () => null,
      );

      if (product != null) {
        _addToCart(product);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('✅ Added: ${product['name']}'), duration: const Duration(seconds: 1), backgroundColor: Colors.green),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('❌ Product not found!'), backgroundColor: Colors.red),
        );
      }
    } catch (e) {
      debugPrint("Scanner Error: $e");
    }
  }

  void _simulateCashDrawerKick() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Row(
          children: [
            Icon(Icons.door_front_door_outlined, color: Colors.white),
            SizedBox(width: 10),
            Text('KICK! Cash Drawer Opened.', style: TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
        backgroundColor: Colors.blueGrey,
        duration: Duration(seconds: 2),
      ),
    );
  }

  void _showCartBottomSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setBottomSheetState) {
          final media = MediaQuery.of(context);
          final bool isLandscape = media.orientation == Orientation.landscape;

          return Align(
            alignment: Alignment.bottomCenter,
            child: Container(
              width: isLandscape ? 500 : double.infinity,
              height: media.size.height * (isLandscape ? 0.9 : 0.8),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 10, spreadRadius: 1)],
              ),
              child: Column(
                children: [
                  Container(
                    margin: const EdgeInsets.only(top: 12, bottom: 8),
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)),
                  ),
                  _buildCartHeader(),
                    Expanded(
                    child: ListView.builder(
                      itemCount: _cart.length,
                      itemBuilder: (context, index) {
                        final item = _cart[index];
                        final String variantInfo = [item['variant_name'], item['variant_size']]
                            .where((s) => s != null && s.isNotEmpty)
                            .join(', ');

                        return ListTile(
                          title: Text(item['name'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (variantInfo.isNotEmpty)
                                Text(variantInfo, style: const TextStyle(fontSize: 11, color: Colors.blue, fontWeight: FontWeight.w600)),
                              Text('₱${item['price']} x ${item['quantity']}'),
                            ],
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text('₱${(item['price'] * item['quantity']).toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold)),
                              IconButton(
                                onPressed: () {
                                  _removeFromCart(index);
                                  setBottomSheetState(() {});
                                  setState(() {});
                                  if (_cart.isEmpty) Navigator.pop(context);
                                },
                                icon: const Icon(Icons.remove_circle_outline, color: Colors.red, size: 20)
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                  _buildSummaryArea(),
                ],
              ),
            ),
          );
        }
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        bool isSmallScreen = constraints.maxWidth < 900;

        return Scaffold(
          backgroundColor: Colors.transparent,
          body: Row(
            children: [
              Expanded(
                flex: 3,
                child: Container(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      _buildSearchBar(),
                      const SizedBox(height: 16),
                      Expanded(
                        child: _isLoading
                          ? _buildSkeletonGrid(isSmallScreen ? constraints.maxWidth : constraints.maxWidth - 380)
                          : _buildProductGrid(isSmallScreen ? constraints.maxWidth : constraints.maxWidth - 380),
                      ),
                    ],
                  ),
                ),
              ),
              if (!isSmallScreen)
                Container(
                  width: 380,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    border: Border(left: BorderSide(color: Colors.grey.shade200)),
                  ),
                  child: Column(
                    children: [
                      _buildCartHeader(),
                      Expanded(child: _buildCartList()),
                      _buildSummaryArea(),
                    ],
                  ),
                ),
            ],
          ),
          floatingActionButton: isSmallScreen && _cart.isNotEmpty
            ? FloatingActionButton.extended(
                onPressed: _showCartBottomSheet,
                label: Text('View Order (${_cart.length})', style: const TextStyle(fontWeight: FontWeight.bold)),
                icon: const Icon(Icons.shopping_basket),
                backgroundColor: Colors.blue.shade700,
                foregroundColor: Colors.white,
              )
            : null,
        );
      }
    );
  }

  Widget _buildSkeletonGrid(double availableWidth) {
    int crossAxisCount = availableWidth > 1200 ? 5 : (availableWidth > 900 ? 4 : (availableWidth > 600 ? 3 : 2));
    double aspectRatio = MediaQuery.of(context).orientation == Orientation.landscape ? 0.85 : 0.75;

    return GridView.builder(
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        childAspectRatio: aspectRatio,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
      ),
      itemCount: 10,
      itemBuilder: (context, index) => Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey.shade100),
        ),
        child: Column(
          children: [
            Expanded(child: Container(color: Colors.grey.shade50)),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(height: 12, width: double.infinity, color: Colors.grey.shade100),
                  const SizedBox(height: 8),
                  Container(height: 12, width: 60, color: Colors.grey.shade100),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchBar() {
    return Row(
      children: [
        if (_isOffline)
          Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: Tooltip(
              message: 'Offline Mode: Transactions will be saved locally.',
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(color: Colors.red.shade50, borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.red.shade100)),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.cloud_off_rounded, size: 14, color: Colors.red.shade700),
                    const SizedBox(width: 4),
                    Text('OFFLINE', style: TextStyle(color: Colors.red.shade700, fontSize: 10, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
            ),
          ),
        if (_pendingSyncCount > 0)
          Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: ActionChip(
              avatar: const Icon(Icons.sync_problem, size: 16, color: Colors.white),
              label: Text('Sync ($_pendingSyncCount)', style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
              backgroundColor: Colors.orange.shade700,
              onPressed: () async {
                await SyncService.syncOfflineSales(context);
                _updatePendingSync();
              },
            ),
          ),
        Expanded(
          child: TextField(
            controller: _searchController,
            onChanged: _filterProducts,
            decoration: InputDecoration(
              hintText: 'Search product...',
              prefixIcon: const Icon(Icons.search, size: 20),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade300)),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade200)),
              filled: true,
              fillColor: Colors.white,
              contentPadding: const EdgeInsets.symmetric(vertical: 0),
            ),
          ),
        ),
        IconButton(
          onPressed: _showScannerDialog,
          icon: const Icon(Icons.qr_code_scanner_rounded, size: 20),
          style: IconButton.styleFrom(
            backgroundColor: Colors.purple.shade50,
            foregroundColor: Colors.purple,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
        const SizedBox(width: 10),
        IconButton(
          onPressed: _fetchProducts,
          icon: const Icon(Icons.refresh, size: 20),
          style: IconButton.styleFrom(
            backgroundColor: Colors.blue.shade50,
            foregroundColor: Colors.blue,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
      ],
    );
  }

  Widget _buildProductGrid(double availableWidth) {
    if (_filteredProducts.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.search_off_rounded, size: 64, color: Colors.grey.shade300),
            const SizedBox(height: 16),
            Text('No products found', style: TextStyle(color: Colors.grey.shade600, fontSize: 16)),
          ],
        ),
      );
    }

    int crossAxisCount = availableWidth > 1200 ? 5 : (availableWidth > 900 ? 4 : (availableWidth > 600 ? 3 : 2));
    double aspectRatio = MediaQuery.of(context).orientation == Orientation.landscape ? 0.85 : 0.75;

    return GridView.builder(
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        childAspectRatio: aspectRatio,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
      ),
      itemCount: _filteredProducts.length,
      itemBuilder: (context, index) {
        final product = _filteredProducts[index];
        return _ProductCard(
          product: product,
          onTap: () => _addToCart(product),
        );
      },
    );
  }

  Widget _buildCartHeader() {
    return Container(
      padding: const EdgeInsets.all(16),
      color: Colors.blue.shade600,
      child: Row(
        children: [
          const Icon(Icons.shopping_cart, color: Colors.white),
          const SizedBox(width: 10),
          const Text('Current Order', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
          const Spacer(),
          TextButton.icon(
            onPressed: _showCustomerSelectionDialog,
            icon: const Icon(Icons.person_add, color: Colors.white, size: 18),
            label: Text(
              _selectedCustomer != null ? _selectedCustomer!['name'] : 'Customer',
              style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
            ),
            style: TextButton.styleFrom(
              backgroundColor: Colors.white.withValues(alpha: 0.2),
              padding: const EdgeInsets.symmetric(horizontal: 12),
            ),
          ),
        ],
      ),
    );
  }

  void _showCustomerSelectionDialog() async {
    showDialog(
      context: context,
      builder: (context) => FutureBuilder<http.Response>(
        future: ApiService.get('costumers/get_customers'),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
          final data = json.decode(snapshot.data!.body);
          final List customers = data['customers'] ?? [];

          return AlertDialog(
            title: const Text('Select Customer / Suki'),
            content: SizedBox(
              width: 400,
              height: 400,
              child: Column(
                children: [
                  ListTile(
                    leading: const CircleAvatar(child: Icon(Icons.people_outline)),
                    title: const Text('Walk-in Customer (Default)'),
                    onTap: () {
                      setState(() => _selectedCustomer = null);
                      Navigator.pop(context);
                    },
                  ),
                  const Divider(),
                  Expanded(
                    child: ListView.builder(
                      itemCount: customers.length,
                      itemBuilder: (context, index) {
                        final c = customers[index];
                        return ListTile(
                          leading: CircleAvatar(child: Text(c['name'][0])),
                          title: Text(c['name']),
                          subtitle: Text(c['phone'] ?? ''),
                          trailing: Text('${c['points']} pts', style: const TextStyle(color: Colors.blue, fontWeight: FontWeight.bold)),
                          onTap: () {
                            setState(() => _selectedCustomer = c);
                            Navigator.pop(context);
                          },
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildCartList() {
    if (_cart.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.shopping_basket_outlined, size: 60, color: Colors.grey.shade300),
            const SizedBox(height: 10),
            const Text('Cart is empty', style: TextStyle(color: Colors.grey)),
          ],
        ),
      );
    }
    return ListView.builder(
      itemCount: _cart.length,
      itemBuilder: (context, index) {
        final item = _cart[index];
        final String variantInfo = [item['variant_name'], item['variant_size']]
            .where((s) => s != null && s.isNotEmpty)
            .join(', ');

        return ListTile(
          title: Text(item['name'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (variantInfo.isNotEmpty)
                Text(variantInfo, style: const TextStyle(fontSize: 11, color: Colors.blue, fontWeight: FontWeight.w600)),
              Text('₱${item['price']} x ${item['quantity']}'),
            ],
          ),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('₱${(item['price'] * item['quantity']).toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold)),
              IconButton(onPressed: () => _removeFromCart(index), icon: const Icon(Icons.remove_circle_outline, color: Colors.red, size: 20)),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSummaryArea() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Colors.grey.shade100)),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, -5))
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Total Amount', style: TextStyle(fontSize: 14, color: Colors.grey.shade600, fontWeight: FontWeight.bold)),
              Text('₱${_totalAmount.toStringAsFixed(2)}',
                  style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: Color(0xFF1E293B))),
            ],
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            height: 60,
            child: ElevatedButton(
              onPressed: _cart.isEmpty ? null : _showPaymentDialog,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1E293B),
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.payments_rounded),
                  SizedBox(width: 12),
                  Text('PAY NOW', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18, letterSpacing: 1)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ProductCard extends StatefulWidget {
  final Map<String, dynamic> product;
  final VoidCallback onTap;

  const _ProductCard({required this.product, required this.onTap});

  @override
  State<_ProductCard> createState() => _ProductCardState();
}

class _ProductCardState extends State<_ProductCard> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.95).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final product = widget.product;
    int stock = int.tryParse(product['stock_quantity']?.toString() ?? '0') ?? 0;
    bool isLowStock = stock > 0 && stock <= 5;
    bool isOutOfStock = stock <= 0;

    return GestureDetector(
      onTapDown: (_) => _controller.forward(),
      onTapUp: (_) => _controller.reverse(),
      onTapCancel: () => _controller.reverse(),
      onTap: widget.onTap,
      child: ScaleTransition(
        scale: _scaleAnimation,
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
            border: Border.all(
              color: isOutOfStock ? Colors.red.withValues(alpha: 0.1) : Colors.grey.shade100,
              width: 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Stack(
                  children: [
                    Container(
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade50,
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                      ),
                      child: Center(
                        child: Icon(
                          Icons.inventory_2_rounded,
                          size: 40,
                          color: isOutOfStock ? Colors.grey.shade300 : Colors.blue.shade100
                        ),
                      ),
                    ),
                    if (isLowStock || isOutOfStock)
                      Positioned(
                        top: 8,
                        right: 8,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: isOutOfStock ? Colors.red : Colors.orange,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            isOutOfStock ? 'OUT OF STOCK' : 'LOW STOCK',
                            style: const TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      product['name'] ?? '',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF1E293B)),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '₱${product['selling_price']}',
                          style: TextStyle(
                            color: isOutOfStock ? Colors.grey : Colors.blue.shade700,
                            fontWeight: FontWeight.w900,
                            fontSize: 15,
                          ),
                        ),
                        Text(
                          'QTY: $stock',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: isOutOfStock ? Colors.red : Colors.grey.shade500,
                          ),
                        ),
                      ],
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
}
