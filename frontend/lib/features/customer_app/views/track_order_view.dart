import 'package:flutter/material.dart';
import 'package:pos/core/services/api_service.dart';
import 'dart:convert';

class TrackOrderView extends StatefulWidget {
  final Map<String, dynamic> order;
  const TrackOrderView({super.key, required this.order});

  @override
  State<TrackOrderView> createState() => _TrackOrderViewState();
}

class _TrackOrderViewState extends State<TrackOrderView> {
  late String _currentStatus;
  bool _isUpdating = false;

  @override
  void initState() {
    super.initState();
    _currentStatus = widget.order['order_status'] ?? 'Pending';
  }

  Future<void> _confirmOrderReceived() async {
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

    setState(() => _isUpdating = true);

    try {
      final int orderId = int.tryParse(widget.order['id'].toString()) ?? 0;
      final response = await ApiService.post(
        'sales/update_order_status',
        {
          'order_id': orderId,
          'status': 'Delivered',
        },
      );

      final data = json.decode(response.body);
      if (data['success'] == true) {
        setState(() {
          _currentStatus = 'Delivered';
          _isUpdating = false;
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Order marked as Delivered!'), backgroundColor: Colors.green),
          );
        }
      } else {
        setState(() => _isUpdating = false);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: ${data['message']}'), backgroundColor: Colors.red),
          );
        }
      }
    } catch (e) {
      setState(() => _isUpdating = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Connection Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final String courier = widget.order['courier_name'] ?? 'N/A';
    final String tracking = widget.order['tracking_number'] ?? 'N/A';

    return Scaffold(
      backgroundColor: const Color(0xFFF7E6E9),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.black87),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Track Order', style: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            _buildCourierHeader(courier, tracking),
            const SizedBox(height: 32),
            _buildStatusTimeline(_currentStatus),
            const SizedBox(height: 32),
            _buildOrderDetails(),
            if (_currentStatus == 'Shipped') ...[
              const SizedBox(height: 32),
              _isUpdating
                ? const CircularProgressIndicator()
                : SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _confirmOrderReceived,
                      icon: const Icon(Icons.check_circle_outline),
                      label: const Text('ORDER RECEIVED', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                        padding: const EdgeInsets.symmetric(vertical: 18),
                      ),
                    ),
                  ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildCourierHeader(String courier, String tracking) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10)],
      ),
      child: Row(
        children: [
          const CircleAvatar(
            radius: 30,
            backgroundColor: Color(0xFFFBECEF),
            child: Icon(Icons.local_shipping, color: Color(0xFFD68A96), size: 30),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(courier, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                Text('Tracking #: $tracking', style: const TextStyle(color: Colors.grey, fontSize: 14)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusTimeline(String currentStatus) {
    final List<String> stages = ['Pending', 'Preparing', 'Shipped', 'Delivered'];
    int currentIndex = stages.indexOf(currentStatus);
    if (currentIndex == -1) currentIndex = 0;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10)],
      ),
      child: Column(
        children: List.generate(stages.length, (index) {
          bool isCompleted = index <= currentIndex;
          bool isLast = index == stages.length - 1;

          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Column(
                children: [
                  Icon(
                    isCompleted ? Icons.check_circle : Icons.radio_button_unchecked,
                    color: isCompleted ? const Color(0xFFD68A96) : Colors.grey.shade300,
                  ),
                  if (!isLast)
                    Container(
                      width: 2,
                      height: 40,
                      color: isCompleted ? const Color(0xFFD68A96) : Colors.grey.shade300,
                    ),
                ],
              ),
              const SizedBox(width: 16),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    stages[index],
                    style: TextStyle(
                      fontWeight: isCompleted ? FontWeight.bold : FontWeight.normal,
                      color: isCompleted ? Colors.black87 : Colors.grey,
                    ),
                  ),
                  if (isCompleted && index == currentIndex)
                    const Text('Current Status', style: TextStyle(fontSize: 10, color: Color(0xFFD68A96))),
                ],
              ),
            ],
          );
        }),
      ),
    );
  }

  Widget _buildOrderDetails() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Order Info', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 12),
          Text('Address: ${widget.order['shipping_address'] ?? 'N/A'}', style: const TextStyle(fontSize: 13, color: Colors.black54)),
          const Divider(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Total Amount', style: TextStyle(fontWeight: FontWeight.w600)),
              Text('₱${widget.order['total_amount']}', style: const TextStyle(fontWeight: FontWeight.w900, color: Color(0xFFD68A96))),
            ],
          ),
        ],
      ),
    );
  }
}
