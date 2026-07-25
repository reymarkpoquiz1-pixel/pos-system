import 'package:flutter/material.dart';
import '../services/cart_service.dart';
import 'package:pos/core/services/api_service.dart';
import 'dart:convert';

class CheckoutView extends StatefulWidget {
  final int userId;
  const CheckoutView({super.key, required this.userId});

  @override
  State<CheckoutView> createState() => _CheckoutViewState();
}

class _CheckoutViewState extends State<CheckoutView> {
  bool _isProcessing = false;
  String _paymentMethod = 'Cash';
  final TextEditingController _addressController = TextEditingController();
  final double _shippingFee = 50.0; // Flat rate for simulation

  Future<void> _handleConfirmOrder() async {
    if (_paymentMethod != 'Cash' && _addressController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please enter delivery address!')));
      return;
    }

    if (_paymentMethod != 'Cash') {
      bool? paid = await _showSimulatedPaymentDialog();
      if (paid != true) return;
    }

    setState(() => _isProcessing = true);
    
    final cartItems = CartService().items.map((item) => {
      'product_id': item.id,
      'quantity': item.quantity,
      'unit_price': item.price,
    }).toList();

    try {
      final response = await ApiService.post(
        'place_order',
        {
          'items': cartItems,
          'total_amount': CartService().totalAmount,
          'discount': 0.0,
          'shipping_fee': _shippingFee,
          'shipping_address': _addressController.text,
          'payment_method': _paymentMethod,
          'payment_status': _paymentMethod == 'Cash' ? 'Pending' : 'Paid',
          'order_status': 'Pending',
        },
      );

      final data = json.decode(response.body);

      if (data['success'] == true) {
        CartService().clearCart();
        if (!mounted) return;
        Navigator.of(context).popUntil((route) => route.isFirst);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Order placed successfully!'), backgroundColor: Colors.green),
        );
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${data['message']}'), backgroundColor: Colors.red),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Connection Error: $e'), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.black87),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Checkout', style: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Center(child: Icon(Icons.check_circle_outline, size: 80, color: Colors.green)),
            const SizedBox(height: 24),
            const Text('Delivery Address', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            TextField(
              controller: _addressController,
              decoration: InputDecoration(
                hintText: 'Enter complete address...',
                prefixIcon: const Icon(Icons.location_on, color: Color(0xFFD68A96)),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                filled: true,
                fillColor: Colors.grey.shade50,
              ),
            ),
            const SizedBox(height: 24),
            const Text('Payment Method', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            Row(
              children: [
                _paymentTile('Cash', Icons.payments_outlined),
                const SizedBox(width: 10),
                _paymentTile('GCash', Icons.smartphone),
                const SizedBox(width: 10),
                _paymentTile('Maya', Icons.account_balance_wallet),
              ],
            ),
            const SizedBox(height: 32),
            const Text(
              'Order Summary',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: CartService().items.length,
              itemBuilder: (context, index) {
                final item = CartService().items[index];
                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(item.name),
                  subtitle: Text('Qty: ${item.quantity}'),
                  trailing: Text('₱${(item.price * item.quantity).toStringAsFixed(2)}'),
                );
              },
            ),
            const Divider(),
            _totalRow('Subtotal', '₱${CartService().totalAmount.toStringAsFixed(2)}'),
            _totalRow('Shipping Fee', '₱${_shippingFee.toStringAsFixed(2)}'),
            const Divider(),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Total to Pay', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  Text(
                    '₱${(CartService().totalAmount + _shippingFee).toStringAsFixed(2)}',
                    style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: Color(0xFFD68A96)),
                  ),
                ],
              ),
            ),
            _isProcessing 
              ? const CircularProgressIndicator()
              : ElevatedButton(
                  onPressed: _handleConfirmOrder,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFD68A96),
                    foregroundColor: Colors.white,
                    minimumSize: const Size.fromHeight(55),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                  ),
                  child: const Text('Confirm Order', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                ),
          ],
        ),
      ),
    );
  }

  Future<bool?> _showSimulatedPaymentDialog() async {
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Icon(_paymentMethod == 'GCash' ? Icons.smartphone : Icons.account_balance_wallet, color: Colors.blue),
            const SizedBox(width: 10),
            Text('$_paymentMethod Payment'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Simulating connection to Payment Gateway...', style: TextStyle(fontSize: 14)),
            const SizedBox(height: 20),
            const CircularProgressIndicator(),
            const SizedBox(height: 20),
            Text('Amount to Pay: ₱${(CartService().totalAmount + _shippingFee).toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              Future.delayed(const Duration(seconds: 1), () {
                if (context.mounted) Navigator.pop(context, true);
              });
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
            child: const Text('Pay Now'),
          ),
        ],
      ),
    );
  }

  Widget _paymentTile(String method, IconData icon) {
    bool isSelected = _paymentMethod == method;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _paymentMethod = method),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xFFD68A96) : Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: isSelected ? const Color(0xFFD68A96) : Colors.grey.shade300),
          ),
          child: Column(
            children: [
              Icon(icon, color: isSelected ? Colors.white : Colors.black87),
              const SizedBox(height: 4),
              Text(method, style: TextStyle(color: isSelected ? Colors.white : Colors.black87, fontSize: 12, fontWeight: FontWeight.bold)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _totalRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.grey, fontSize: 14)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
        ],
      ),
    );
  }
}
