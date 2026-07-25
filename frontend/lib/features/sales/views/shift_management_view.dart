import 'package:flutter/material.dart';
import 'package:pos/core/services/api_service.dart';
import 'dart:convert';
import 'package:pos/core/widgets/dashboard_widgets.dart';

class ShiftManagementView extends StatefulWidget {
  final int userId;
  const ShiftManagementView({super.key, required this.userId});

  @override
  State<ShiftManagementView> createState() => _ShiftManagementViewState();
}

class _ShiftManagementViewState extends State<ShiftManagementView> {
  List<dynamic> _shifts = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchShifts();
  }

  Future<void> _fetchShifts() async {
    setState(() => _isLoading = true);
    try {
      final response = await ApiService.get('sales/get_shift_history');
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success']) {
          setState(() {
            _shifts = data['shifts'] ?? [];
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
                    '🏦 Shift Management & X/Z Reading',
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Color(0xFF1C1B1F), letterSpacing: -0.5),
                  ),
                  IconButton(icon: const Icon(Icons.refresh), onPressed: _fetchShifts),
                ],
              ),
              const SizedBox(height: 24),
              Expanded(
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator(color: Color(0xFFD68A96)))
                    : _shifts.isEmpty
                        ? const Center(child: Text('No shift records found.'))
                        : ListView.builder(
                            itemCount: _shifts.length,
                            itemBuilder: (context, index) {
                              final shift = _shifts[index];
                              final bool isOpen = shift['status'] == 'Open';
                              return Container(
                                margin: const EdgeInsets.only(bottom: 12),
                                decoration: cardDecoration(),
                                child: Material(
                                  color: Colors.transparent,
                                  borderRadius: BorderRadius.circular(24),
                                  child: ListTile(
                                    leading: CircleAvatar(
                                      backgroundColor: isOpen ? Colors.green.withValues(alpha: 0.1) : Colors.grey.withValues(alpha: 0.1),
                                      child: Icon(Icons.account_balance_wallet, color: isOpen ? Colors.green : Colors.grey),
                                    ),
                                    title: Text('Cashier: ${shift['username'] ?? "User ID: ${shift['user_id']}"}', style: const TextStyle(fontWeight: FontWeight.bold)),
                                    subtitle: Text('Start: ${shift['start_time']}\nEnd: ${shift['end_time'] ?? 'ACTIVE'}'),
                                    isThreeLine: true,
                                    trailing: Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      crossAxisAlignment: CrossAxisAlignment.end,
                                      children: [
                                        Text('Sales: ₱${shift['total_sales']}', style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFFD68A96))),
                                        if (!isOpen) Text('Diff: ₱${(double.parse(shift['actual_cash'].toString()) - (double.parse(shift['starting_cash'].toString()) + double.parse(shift['total_sales'].toString()))).toStringAsFixed(2)}', 
                                            style: TextStyle(fontSize: 10, color: (double.parse(shift['actual_cash'].toString()) < (double.parse(shift['starting_cash'].toString()) + double.parse(shift['total_sales'].toString()))) ? Colors.red : Colors.green)),
                                      ],
                                    ),
                                    onTap: () => _showShiftDetails(shift),
                                  ),
                                ),
                              );
                            },
                          ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showShiftDetails(dynamic shift) {
    final bool isOpen = shift['status'] == 'Open';
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Shift Details #${shift['id']}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _detailRow('Cashier:', shift['username'] ?? shift['user_id'].toString()),
            _detailRow('Start Time:', shift['start_time']),
            _detailRow('End Time:', shift['end_time'] ?? 'Active'),
            const Divider(),
            _detailRow('Starting Cash:', '₱${shift['starting_cash']}'),
            _detailRow('Total Sales:', '₱${shift['total_sales']}'),
            _detailRow('Expected Cash:', '₱${(double.parse(shift['starting_cash'].toString()) + double.parse(shift['total_sales'].toString())).toStringAsFixed(2)}'),
            _detailRow('Actual Cash:', '₱${shift['actual_cash']}'),
            const Divider(),
            if (!isOpen) ...[
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () => _generateZReport(shift['id']),
                  icon: const Icon(Icons.analytics_outlined, size: 18),
                  label: const Text('GENERATE Z-REPORT'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue.shade700,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))
                  ),
                ),
              ),
              const Divider(),
            ],
            const Text('Notes:', style: TextStyle(fontWeight: FontWeight.bold)),
            Text(shift['notes'] ?? 'No notes provided.'),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close')),
        ],
      ),
    );
  }

  void _generateZReport(dynamic shiftId) async {
    showDialog(context: context, builder: (ctx) => const Center(child: CircularProgressIndicator()));
    
    try {
      final response = await ApiService.get('reports/get_shift_audit?shift_id=$shiftId');
      if (!mounted) return;
      Navigator.pop(context); // Close loading

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success']) {
          _showZReportDialog(data);
        }
      }
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error generating report: $e')));
    }
  }

  void _showZReportDialog(Map<String, dynamic> data) {
    final shift = data['shift'];
    final payments = data['payment_summary'] as List;
    final categories = data['category_summary'] as List;
    final double profit = double.tryParse(data['profit_summary'].toString()) ?? 0.0;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Z-Report Audit Summary', style: TextStyle(fontWeight: FontWeight.bold)),
        content: SizedBox(
          width: 500,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(8)),
                  child: Column(
                    children: [
                      _detailRow('Total Sales:', '₱${shift['total_sales']}'),
                      _detailRow('Starting Cash:', '₱${shift['starting_cash']}'),
                      _detailRow('Expected In Drawer:', '₱${(double.parse(shift['starting_cash'].toString()) + double.parse(shift['total_sales'].toString())).toStringAsFixed(2)}'),
                      _detailRow('Actual In Drawer:', '₱${shift['actual_cash']}'),
                      const Divider(),
                      _detailRow('NET PROFIT:', '₱${profit.toStringAsFixed(2)}'),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                const Text('Sales by Payment Method:', style: TextStyle(fontWeight: FontWeight.bold)),
                ...payments.map((p) => _detailRow(p['payment_method'], '₱${p['total']}')),
                const SizedBox(height: 20),
                const Text('Sales by Category:', style: TextStyle(fontWeight: FontWeight.bold)),
                ...categories.map((c) => _detailRow(c['category'], '₱${c['total']}')),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close')),
          ElevatedButton(onPressed: () {}, child: const Text('Print Report')),
        ],
      ),
    );
  }

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.grey)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}
