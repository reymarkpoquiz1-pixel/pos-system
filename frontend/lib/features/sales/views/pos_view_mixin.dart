import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:pos/core/services/api_service.dart';
import 'dart:convert';
import 'package:pos/core/services/database_helper.dart';
import 'package:pos/core/services/sync_service.dart';
import 'package:pos/core/services/connectivity_service.dart';
import 'pos_view.dart';
import 'package:pos/core/widgets/dashboard_widgets.dart';

mixin PosViewMixin on State<PosView> {
  // State variables that will be accessed by other mixins
  List<dynamic> products = [];
  List<dynamic> filteredProducts = [];
  final List<Map<String, dynamic>> cart = [];
  bool isLoading = true;
  bool isShiftOpen = false;
  Map<String, dynamic>? selectedCustomer;
  
  final TextEditingController searchController = TextEditingController();
  final TextEditingController paymentController = TextEditingController();
  final TextEditingController referenceController = TextEditingController();
  
  int pendingSyncCount = 0;
  bool isScannerOpen = false;
  bool isOffline = false;

  String formatDateTime(DateTime dt) {
    String month = dt.month.toString().padLeft(2, '0');
    String day = dt.day.toString().padLeft(2, '0');
    String year = dt.year.toString();

    int hour = dt.hour > 12 ? dt.hour - 12 : (dt.hour == 0 ? 12 : dt.hour);
    String minute = dt.minute.toString().padLeft(2, '0');
    String period = dt.hour >= 12 ? 'PM' : 'AM';

    return "$month-$day-$year $hour:$minute $period";
  }

  void onConnectivityChanged() {
    if (mounted) {
      setState(() {
        isOffline = !ConnectivityService.instance.isConnectedNotifier.value;
      });
    }
  }

  Future<void> updatePendingSync() async {
    int count = await SyncService.getPendingCount();
    if (mounted) setState(() => pendingSyncCount = count);
  }

  Future<void> checkShiftStatus() async {
    try {
      final response = await ApiService.get('sales/get_active_shift');
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        setState(() {
          isShiftOpen = data['success'] ?? false;
        });
        if (!isShiftOpen && mounted) {
          showShiftAlert();
        }
      }
    } catch (e) {
      debugPrint('Error checking shift: $e');
    }
  }

  Future<void> fetchProducts() async {
    setState(() => isLoading = true);
    try {
      final response = await ApiService.get('products/get_products');
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        setState(() {
          products = data['products'] ?? [];
          filteredProducts = products;
          isLoading = false;
        });
        checkLowStock();
      }
    } catch (e) {
      setState(() => isLoading = false);
      debugPrint('Error: $e');
    }
  }

  void checkLowStock() {
    int lowStockCount = products.where((p) {
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

  void filterProducts(String query) {
    if (query.isEmpty) {
      setState(() {
        filteredProducts = products;
      });
      return;
    }

    final lowerQuery = query.toLowerCase();

    try {
      final exactMatch = products.firstWhere(
        (p) => p['barcode'].toString().toLowerCase() == lowerQuery,
        orElse: () => null,
      );

      if (exactMatch != null) {
        searchController.clear();
        addToCart(exactMatch);
        setState(() {
          filteredProducts = products;
        });
        return;
      }
    } catch (e) {}

    setState(() {
      filteredProducts = products
          .where((p) =>
              p['name'].toString().toLowerCase().contains(lowerQuery) ||
              p['barcode'].toString().toLowerCase().contains(lowerQuery))
          .toList();
    });
  }

  void addToCart(Map<String, dynamic> product) {
    if (!isShiftOpen) {
      showShiftAlert();
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
      showVariantSelectionDialog(product, variants);
    } else {
      performAddToCart(product);
    }
  }

  void performAddToCart(Map<String, dynamic> product, [Map<String, dynamic>? variant]) {
    final int maxStock = variant != null
        ? (int.tryParse(variant['stock']?.toString() ?? '0') ?? 0)
        : (int.tryParse(product['stock_quantity']?.toString() ?? '0') ?? 0);

    setState(() {
      final String variantName = variant?['color_name'] ?? '';
      final String variantSize = variant?['size'] ?? '';

      final index = cart.indexWhere((item) =>
        item['id'] == product['id'] &&
        item['variant_name'] == variantName &&
        item['variant_size'] == variantSize
      );

      if (index >= 0) {
        if (cart[index]['quantity'] < maxStock) {
          cart[index]['quantity']++;
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('⚠️ Max stock reached for this item.'), backgroundColor: Colors.orange),
          );
        }
      } else {
        cart.add({
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

  void removeFromCart(int index) {
    setState(() {
      if (cart[index]['quantity'] > 1) {
        cart[index]['quantity']--;
      } else {
        cart.removeAt(index);
      }
    });
  }

  double get totalAmount {
    return cart.fold(0, (sum, item) => sum + (item['price'] * item['quantity']));
  }

  Future<void> finalizeTransaction(double tendered, double change, String method) async {
    Navigator.pop(context);

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    final cartItems = cart.map((item) => {
      'product_id': item['id'],
      'quantity': item['quantity'],
      'unit_price': item['price'],
    }).toList();

    final orderData = {
      'items': cartItems,
      'total_amount': totalAmount,
      'discount': 0.0,
      'amount_paid': tendered,
      'change': change,
      'payment_method': method,
      'payment_reference': referenceController.text,
      'payment_status': 'Paid',
      'order_status': 'Delivered',
      'order_type': 'Walk-in',
      'customer_id': selectedCustomer != null ? selectedCustomer!['id'] : null,
    };

    try {
      final response = await ApiService.post('place_order', orderData);
      final data = json.decode(response.body);

      if (!mounted) return;
      Navigator.pop(context);

      if (data['success'] == true || response.statusCode == 200) {
        handleSuccessfulSale(data['sale_id']?.toString() ?? 'OFFLINE', tendered, change, method);
      } else if (response.statusCode >= 500) {
        saveOffline(orderData, tendered, change, method);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${data['message']}'), backgroundColor: Colors.red),
        );
      }
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context);
      saveOffline(orderData, tendered, change, method);
    }
  }

  void saveOffline(Map<String, dynamic> orderData, double tendered, double change, String method) async {
    final List<Map<String, dynamic>> items = (orderData['items'] as List).cast<Map<String, dynamic>>();
    await DatabaseHelper.instance.saveOfflineSale(orderData, items);

    handleSuccessfulSale('OFFLINE-${DateTime.now().millisecondsSinceEpoch}', tendered, change, method, isOffline: true);
    updatePendingSync();
  }

  void handleSuccessfulSale(String saleId, double tendered, double change, String method, {bool isOffline = false}) {
    final transactionData = {
      'transaction_id': saleId,
      'date_created': formatDateTime(DateTime.now()),
      'customer_name': selectedCustomer != null ? selectedCustomer!['name'] : 'Walk-in Customer',
      'cashier_name': widget.username,
      'terminal_id': widget.terminalId > 0 ? widget.terminalId : 1,
      'total_amount': totalAmount.toStringAsFixed(2),
      'amount_tendered': tendered.toStringAsFixed(2),
      'change': change.toStringAsFixed(2),
      'payment_method': method,
      'status': isOffline ? 'Offline Pending' : 'Paid',
      'items': List<Map<String, dynamic>>.from(cart),
    };

    showProfessionalReceipt(context, transactionData, storeSettings: widget.storeSettings);

    if (transactionData['payment_method'] == 'Cash') {
      simulateCashDrawerKick();
    }

    setState(() {
      cart.clear();
      selectedCustomer = null;
    });

    fetchProducts();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(isOffline ? '⚠️ Order saved offline! It will sync later.' : '✅ Transaction completed successfully!'),
        backgroundColor: isOffline ? Colors.orange : Colors.green
      ),
    );
  }

  void handleBarcodeScanned(String code) {
    try {
      final product = products.firstWhere(
        (p) => p['barcode'].toString().toLowerCase() == code.toLowerCase(),
        orElse: () => null,
      );

      if (product != null) {
        addToCart(product);
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

  void simulateCashDrawerKick() {
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

  // Abstract methods that will be implemented in other mixins
  void showShiftAlert();
  void showVariantSelectionDialog(Map<String, dynamic> product, List<dynamic> variants);
}
