import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:pos/core/services/api_service.dart';
import 'package:pos/core/constants/config.dart';
import 'package:pos/core/widgets/dashboard_widgets.dart';
import 'track_order_view.dart';

class OrderHistoryView extends StatefulWidget {
  final int userId;
  const OrderHistoryView({super.key, required this.userId});

  @override
  State<OrderHistoryView> createState() => _OrderHistoryViewState();
}

class _OrderHistoryViewState extends State<OrderHistoryView> {
  bool _isLoading = true;
  List<dynamic> _orders = [];

  @override
  void initState() {
    super.initState();
    _fetchOrders();
  }

  Future<void> _fetchOrders() async {
    setState(() => _isLoading = true);
    try {
      final response = await ApiService.get(
        'sales/get_user_orders?user_id=${widget.userId}',
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          setState(() {
            _orders = data['orders'] ?? [];
            _isLoading = false;
          });
        } else {
          if (mounted) setState(() => _isLoading = false);
        }
      } else {
        if (mounted) setState(() => _isLoading = false);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'pending': return Colors.orange;
      case 'preparing': return Colors.blue;
      case 'shipped': return Colors.purple;
      case 'delivered': return Colors.green;
      case 'cancelled': return Colors.red;
      default: return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7E6E9),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.black87),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('My Orders', style: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold)),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFFD68A96)))
          : _orders.isEmpty
              ? _buildEmptyOrders()
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _orders.length,
                  itemBuilder: (context, index) {
                    final order = _orders[index];
                    return _buildOrderCard(order);
                  },
                ),
    );
  }

  Widget _buildEmptyOrders() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.history_rounded, size: 80, color: Colors.grey),
          SizedBox(height: 16),
          Text('No orders yet.', style: TextStyle(color: Colors.grey, fontSize: 16)),
        ],
      ),
    );
  }

  Future<void> _confirmOrderReceived(int orderId) async {
    bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Order Received?'),
        content: const Text('Confirming this means you have successfully received your items. Continue?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('No')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
            child: const Text('Yes, Received'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      final response = await ApiService.post(
        'sales/update_order_status',
        {
          'order_id': orderId,
          'status': 'Delivered',
        },
      );

      final data = json.decode(response.body);
      if (data['success'] == true) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Order marked as Delivered!'), backgroundColor: Colors.green),
          );
        }
        _fetchOrders(); // Refresh list
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: ${data['message']}'), backgroundColor: Colors.red),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Connection Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Widget _buildOrderCard(dynamic order) {
    final status = order['order_status'] ?? 'Pending';
    final items = order['items'] as List<dynamic>;
    final int orderId = int.tryParse(order['id'].toString()) ?? 0;
    
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 10, offset: const Offset(0, 5))],
      ),
      child: Column(
        children: [
          ListTile(
            title: Text('Order ID: ${order['id']}', style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Text('Date: ${order['date_created']}'),
            trailing: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: _getStatusColor(status).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                status.toUpperCase(),
                style: TextStyle(color: _getStatusColor(status), fontSize: 10, fontWeight: FontWeight.bold),
              ),
            ),
          ),
          const Divider(),
          ...items.take(2).map((item) => ListTile(
            leading: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.network(
                item['image_url'] != null && item['image_url'].toString().startsWith('http')
                    ? item['image_url']
                    : '$baseUrl/${item['image_url']}',
                width: 40, height: 40, fit: BoxFit.cover,
                errorBuilder: (c, e, s) => const Icon(Icons.image_not_supported),
              ),
            ),
            title: Text(item['product_name'] ?? 'Unknown Product', style: const TextStyle(fontSize: 13)),
            subtitle: Text('Qty: ${item['quantity']} x ₱${item['unit_price']}'),
          )),
          if (items.length > 2)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text('+ ${items.length - 2} more items', style: const TextStyle(color: Colors.grey, fontSize: 12)),
            ),
          const Divider(),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Total: ₱${order['total_amount']}', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: Color(0xFFD68A96))),
                    Row(
                      children: [
                        if (status == 'Shipped' || status == 'Delivered')
                          IconButton(
                            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => TrackOrderView(order: order))),
                            icon: const Icon(Icons.local_shipping_outlined, color: Colors.blue),
                            tooltip: 'Track Order',
                          ),
                        ElevatedButton(
                          onPressed: () {
                            showProfessionalReceipt(context, order);
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFFBECEF),
                            foregroundColor: const Color(0xFFD68A96),
                            elevation: 0,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          child: const Text('Details'),
                        ),
                      ],
                    ),
                  ],
                ),
                if (status == 'Shipped') ...[
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () => _confirmOrderReceived(orderId),
                      icon: const Icon(Icons.check_circle_outline),
                      label: const Text('ORDER RECEIVED', style: TextStyle(fontWeight: FontWeight.bold)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
