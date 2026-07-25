import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:pos/core/services/api_service.dart';
import 'package:pos/core/widgets/dashboard_widgets.dart';

class RefundsView extends StatefulWidget {
  const RefundsView({super.key});

  @override
  State<RefundsView> createState() => _RefundsViewState();
}

class _RefundsViewState extends State<RefundsView> with SingleTickerProviderStateMixin {
  bool _isLoading = true;
  List<dynamic> _refundableOrders = [];
  List<dynamic> _refundHistory = [];
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _fetchAllRefundData();
  }

  Future<void> _fetchAllRefundData() async {
    await Future.wait([
      _fetchRefundableOrders(),
      _fetchRefundHistory(),
    ]);
  }

  Future<void> _fetchRefundHistory() async {
    try {
      final response = await ApiService.get('sales/get_refunds');
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success']) {
          setState(() {
            _refundHistory = data['refunds'] ?? [];
          });
        }
      }
    } catch (e) {
      debugPrint('Error fetching history: $e');
    }
  }

  Future<void> _fetchRefundableOrders() async {
    setState(() => _isLoading = true);
    try {
      final response = await ApiService.get('sales/get_refundable_orders');
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success']) {
          setState(() {
            _refundableOrders = data['orders'] ?? [];
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  Future<void> _processRefund(int saleId, double amount, String reason, bool returnToStock) async {
    try {
      final response = await ApiService.post(
        'sales/process_refund',
        {
          'sale_id': saleId,
          'refund_amount': amount,
          'reason': reason,
          'return_to_stock': returnToStock,
        },
      );

      final data = json.decode(response.body);
      if (data['success']) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Refund processed successfully!'), backgroundColor: Colors.green),
          );
        }
        _fetchRefundableOrders();
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

  void _showRefundDialog(dynamic order) {
    final reasonController = TextEditingController();
    bool returnToStock = true;
    final double total = double.parse(order['total_amount'].toString());
    final int saleId = int.parse(order['id'].toString());

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text('Process Refund for ID: $saleId', style: const TextStyle(fontWeight: FontWeight.bold)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Total Amount: ₱${total.toStringAsFixed(2)}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Color(0xFFD68A96))),
              const SizedBox(height: 16),
              TextField(
                controller: reasonController,
                decoration: InputDecoration(
                  labelText: 'Reason for Refund',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  filled: true,
                  fillColor: Colors.grey.shade50,
                ),
                maxLines: 2,
              ),
              const SizedBox(height: 12),
              SwitchListTile(
                title: const Text('Return items to stock?', style: TextStyle(fontSize: 14)),
                value: returnToStock,
                activeThumbColor: const Color(0xFFD68A96),
                onChanged: (val) => setDialogState(() => returnToStock = val),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () {
                if (reasonController.text.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please provide a reason.')));
                  return;
                }
                if (!mounted) return;
                Navigator.pop(context);
                _processRefund(saleId, total, reasonController.text, returnToStock);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFD68A96),
                foregroundColor: Colors.white,
              ),
              child: const Text('Confirm Refund'),
            ),
          ],
        ),
      ),
    );
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
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    '🔄 Refund & Cancellation',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1C1B1F),
                      letterSpacing: -0.5,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.refresh),
                    onPressed: _fetchAllRefundData,
                  ),
                ],
              ),
              const SizedBox(height: 16),
              TabBar(
                controller: _tabController,
                labelColor: const Color(0xFFD68A96),
                unselectedLabelColor: Colors.grey,
                indicatorColor: const Color(0xFFD68A96),
                tabs: const [
                  Tab(text: 'Process Refund'),
                  Tab(text: 'Refund History'),
                ],
              ),
              const SizedBox(height: 24),
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    // TAB 1: Process Refund
                    _isLoading
                        ? const Center(child: CircularProgressIndicator(color: Color(0xFFD68A96)))
                        : _refundableOrders.isEmpty
                            ? const Center(child: Text('No refundable orders found.', style: TextStyle(color: Colors.black54)))
                            : _buildRefundableList(),
                    
                    // TAB 2: Refund History
                    _isLoading
                        ? const Center(child: CircularProgressIndicator(color: Color(0xFFD68A96)))
                        : _refundHistory.isEmpty
                            ? const Center(child: Text('No refund history found.', style: TextStyle(color: Colors.black54)))
                            : _buildRefundHistoryList(),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRefundableList() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: cardDecoration(),
      child: ListView.separated(
        itemCount: _refundableOrders.length,
        separatorBuilder: (context, index) => const Divider(),
        itemBuilder: (context, index) {
          final order = _refundableOrders[index];
          final bool isOnline = order['order_type'] == 'Online';
          final String status = order['order_status'] ?? 'Pending';
          
          return Material(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(24),
            child: ListTile(
              leading: const CircleAvatar(
                backgroundColor: Color(0xFFFBECEF),
                child: Icon(Icons.receipt_long, color: Color(0xFFD68A96)),
              ),
              title: Text('Order ID: ${order['id']}', style: const TextStyle(fontWeight: FontWeight.bold)),
              subtitle: Text(
                '${order['transaction_date']} | '
                '${isOnline ? 'Customer' : 'Cashier'}: ${order['customer_name'] ?? order['cashier_name'] ?? 'Admin'}'
              ),
              trailing: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text('₱${order['total_amount']}', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black87)),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.green.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      (!isOnline && status.toLowerCase() == 'delivered') ? 'PAID' : status.toUpperCase(),
                      style: const TextStyle(color: Colors.green, fontSize: 9, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
              onTap: () => _showRefundDialog(order),
            ),
          );
        },
      ),
    );
  }

  Widget _buildRefundHistoryList() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: cardDecoration(),
      child: ListView.separated(
        itemCount: _refundHistory.length,
        separatorBuilder: (context, index) => const Divider(),
        itemBuilder: (context, index) {
          final refund = _refundHistory[index];
          return Material(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(24),
            child: ListTile(
              leading: const CircleAvatar(
                backgroundColor: Color(0xFFFBECEF),
                child: Icon(Icons.history, color: Colors.blueGrey),
              ),
              title: Text('Refund for ID: ${refund['sale_id']}', style: const TextStyle(fontWeight: FontWeight.bold)),
              subtitle: Text(
                'Reason: ${refund['reason']}\n'
                'Orig. Amount: ₱${refund['final_amount']} | Date: ${refund['transaction_date']}',
              ),
              isThreeLine: true,
              trailing: Text(
                '-₱${refund['refund_amount']}',
                style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.red),
              ),
            ),
          );
        },
      ),
    );
  }
}
