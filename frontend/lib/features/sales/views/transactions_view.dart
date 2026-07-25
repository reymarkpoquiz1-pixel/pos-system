import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:pos/core/services/api_service.dart';
import 'package:pos/core/widgets/dashboard_widgets.dart';

class TransactionsView extends StatefulWidget {
  final List<dynamic> transactionsList;
  final VoidCallback? onRefresh;
  final Map<String, dynamic>? storeSettings;

  const TransactionsView({super.key, required this.transactionsList, this.onRefresh, this.storeSettings});

  @override
  State<TransactionsView> createState() => _TransactionsViewState();
}

class _TransactionsViewState extends State<TransactionsView> {

  Future<void> _updateStatus(int orderId, String newStatus) async {
    try {
      final response = await ApiService.post(
        'sales/update_order_status',
        {
          'order_id': orderId,
          'status': newStatus,
        },
      );

      final data = json.decode(response.body);
      if (data['success'] == true) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Status updated to $newStatus'), backgroundColor: Colors.green),
          );
        }
        if (widget.onRefresh != null) widget.onRefresh!();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  void _showStatusPicker(BuildContext context, dynamic tx) {
    final List<String> statuses = ['Pending', 'Preparing', 'Shipped', 'Delivered', 'Cancelled'];
    final int orderId = int.tryParse(tx['id']?.toString() ?? tx['transaction_id']?.toString() ?? '0') ?? 0;

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Update Order Status', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              if (tx['order_status'] == 'Preparing')
                ListTile(
                  leading: const Icon(Icons.local_shipping_outlined, color: Colors.blue),
                  title: const Text('SHIP ORDER (Courier Details)'),
                  onTap: () {
                    Navigator.pop(context);
                    _showShipDialog(tx);
                  },
                ),
              if (tx['order_status'] == 'Shipped')
                ListTile(
                  leading: const Icon(Icons.check_circle_outline, color: Colors.green),
                  title: const Text('MARK AS DELIVERED'),
                  onTap: () {
                    Navigator.pop(context);
                    _updateStatus(orderId, 'Delivered');
                  },
                ),
              const Divider(),
              ...statuses.map((status) => ListTile(
                title: Text(status),
                leading: Icon(Icons.circle, color: _getStatusColor(status), size: 12),
                onTap: () {
                  Navigator.pop(context);
                  _updateStatus(orderId, status);
                },
              )),
            ],
          ),
        );
      },
    );
  }

  void _showShipDialog(dynamic tx) {
    final courierController = TextEditingController(text: 'J&T Express');
    final trackingController = TextEditingController();
    final int orderId = int.tryParse(tx['id']?.toString() ?? tx['transaction_id']?.toString() ?? '0') ?? 0;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Enter Shipping Details', style: TextStyle(fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: courierController,
              decoration: const InputDecoration(labelText: 'Courier Name', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: trackingController,
              decoration: const InputDecoration(labelText: 'Tracking Number', border: OutlineInputBorder()),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              if (trackingController.text.isEmpty) return;
              Navigator.pop(context);
              await _updateShipping(orderId, courierController.text, trackingController.text);
            },
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFD68A96), foregroundColor: Colors.white),
            child: const Text('Mark as Shipped'),
          ),
        ],
      ),
    );
  }

  Future<void> _updateShipping(int orderId, String courier, String tracking) async {
    try {
      final response = await ApiService.post(
        'sales/update_shipping',
        {
          'order_id': orderId,
          'courier_name': courier,
          'tracking_number': tracking,
        },
      );

      final data = json.decode(response.body);
      if (data['success']) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Order shipped successfully!'), backgroundColor: Colors.green));
        }
        if (widget.onRefresh != null) widget.onRefresh!();
      }
    } catch (e) {
      debugPrint('Error shipping: $e');
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
    final physicalOrders = widget.transactionsList.where((tx) => tx['order_type'] != 'Online').toList();
    final onlineOrders = widget.transactionsList.where((tx) => tx['order_type'] == 'Online').toList();

    return Scaffold(
      backgroundColor: const Color(0xFFF7E6E9),
      body: buildThemedBackground(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    '🧾 Order Management',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1C1B1F),
                      letterSpacing: -0.5,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.refresh),
                    onPressed: widget.onRefresh,
                  ),
                ],
              ),
              const SizedBox(height: 24),
              Expanded(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    bool isWide = constraints.maxWidth > 900;

                    if (isWide) {
                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                              child: _buildOrderPanel(
                                  'Walk-in Orders',
                                  physicalOrders,
                                  Icons.storefront_outlined,
                                  const Color(0xFFD68A96)
                              )
                          ),
                          const SizedBox(width: 24),
                          Expanded(
                              child: _buildOrderPanel(
                                  'Online Orders',
                                  onlineOrders,
                                  Icons.language_outlined,
                                  const Color(0xFF6A8CAF)
                              )
                          ),
                        ],
                      );
                    } else {
                      return ListView(
                        children: [
                          _buildOrderPanel(
                              'Walk-in Orders',
                              physicalOrders,
                              Icons.storefront_outlined,
                              const Color(0xFFD68A96),
                              shrinkWrap: true
                          ),
                          const SizedBox(height: 24),
                          _buildOrderPanel(
                              'Online Orders',
                              onlineOrders,
                              Icons.language_outlined,
                              const Color(0xFF6A8CAF),
                              shrinkWrap: true
                          ),
                        ],
                      );
                    }
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildOrderPanel(String title, List<dynamic> orders, IconData icon, Color color, {bool shrinkWrap = false}) {
    return Container(
      decoration: cardDecoration().copyWith(
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.05),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: Row(
              children: [
                Icon(icon, color: color, size: 20),
                const SizedBox(width: 10),
                Text(title, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: color)),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(12)),
                  child: Text('${orders.length}', style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ),
          if (orders.isEmpty)
            Padding(
              padding: const EdgeInsets.all(40.0),
              child: Column(
                children: [
                  Icon(Icons.inbox_outlined, size: 40, color: Colors.grey.shade300),
                  const SizedBox(height: 10),
                  const Text('No orders found.', style: TextStyle(color: Colors.grey)),
                ],
              ),
            )
          else
            ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: orders.length,
              shrinkWrap: true, // Needed for SingleChildScrollView mode
              physics: shrinkWrap ? const NeverScrollableScrollPhysics() : const BouncingScrollPhysics(),
              itemBuilder: (context, index) {
                final tx = orders[index];
                final bool isOnline = tx['order_type'] == 'Online';
                final String rawStatus = tx['order_status'] ?? 'Pending';
                final String displayStatus = (!isOnline && rawStatus.toLowerCase() == 'delivered')
                    ? 'PAID'
                    : rawStatus.toUpperCase();

                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(15),
                    side: BorderSide(color: Colors.grey.shade100),
                  ),
                  child: Material(
                    color: Colors.transparent,
                    borderRadius: BorderRadius.circular(15),
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      leading: CircleAvatar(
                        backgroundColor: _getStatusColor(rawStatus).withValues(alpha: 0.1),
                        child: Icon(Icons.receipt_long_outlined, color: _getStatusColor(rawStatus), size: 20),
                      ),
                      title: Row(
                        children: [
                          Text('ID: ${tx['id'] ?? tx['transaction_id']}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: _getStatusColor(rawStatus).withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              displayStatus,
                              style: TextStyle(color: _getStatusColor(rawStatus), fontSize: 9, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 4),
                          Text(
                            '${isOnline ? 'Customer' : 'Cashier'}: ${tx['customer_name'] ?? tx['cashier_name'] ?? 'Admin'}',
                            style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                          ),
                          Text(
                            '${tx['transaction_date'] ?? tx['date_created'] ?? 'N/A'}',
                            style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                          ),
                        ],
                      ),
                      trailing: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            '₱${tx['total_amount']}',
                            style: const TextStyle(fontWeight: FontWeight.w900, color: Color(0xFFD68A96), fontSize: 14),
                          ),
                          const Icon(Icons.chevron_right, size: 16, color: Colors.grey),
                        ],
                      ),
                      onTap: () => showProfessionalReceipt(context, tx, onStatusUpdate: widget.onRefresh, storeSettings: widget.storeSettings),
                      onLongPress: () => _showStatusPicker(context, tx),
                    ),
                  ),
                );
              },
            ),
        ],
      ),
    );
  }
}
