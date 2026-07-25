import 'package:flutter/material.dart';
import 'package:pos/core/services/api_service.dart';
import 'dart:convert';
import 'package:pos/core/widgets/dashboard_widgets.dart';

class StaffShiftView extends StatefulWidget {
  final int userId;
  final String username;
  final VoidCallback onShiftStatusChanged;
  final Map<String, dynamic>? storeSettings;

  const StaffShiftView({
    super.key, 
    required this.userId, 
    required this.username,
    required this.onShiftStatusChanged,
    this.storeSettings,
  });

  @override
  State<StaffShiftView> createState() => _StaffShiftViewState();
}

class _StaffShiftViewState extends State<StaffShiftView> {
  bool _isLoading = true;
  Map<String, dynamic>? _activeShift;
  final TextEditingController _cashController = TextEditingController();
  final TextEditingController _notesController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _fetchActiveShift();
  }

  Future<void> _fetchActiveShift() async {
    setState(() => _isLoading = true);
    try {
      final response = await ApiService.get('sales/get_active_shift');
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        setState(() {
          _activeShift = data['success'] ? data['shift'] : null;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error: $e');
      setState(() => _isLoading = false);
    }
  }

  Future<void> _startShift() async {
    double cash = double.tryParse(_cashController.text) ?? 0.0;
    try {
      final response = await ApiService.post('sales/start_shift', {
        'starting_cash': cash,
      });
      final data = json.decode(response.body);
      if (data['success']) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Shift started!'), backgroundColor: Colors.green));
        _fetchActiveShift();
        widget.onShiftStatusChanged();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(data['message']), backgroundColor: Colors.red));
      }
    } catch (e) {
      debugPrint('Error starting shift: $e');
    }
  }

  Future<void> _endShift() async {
    double actualCash = double.tryParse(_cashController.text) ?? 0.0;
    try {
      final response = await ApiService.post('sales/end_shift', {
        'actual_cash': actualCash,
        'notes': _notesController.text,
      });
      final data = json.decode(response.body);
      if (data['success']) {
        _showShiftSummary(data['summary']);
        _fetchActiveShift();
        widget.onShiftStatusChanged();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(data['message']), backgroundColor: Colors.red));
      }
    } catch (e) {
      debugPrint('Error ending shift: $e');
    }
  }

  void _showShiftSummary(Map<String, dynamic> summary) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Shift Summary (Z-Reading)'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _summaryRow('Starting Cash:', '₱${summary['starting_cash']}'),
            _summaryRow('Total Sales:', '₱${summary['total_sales']}'),
            _summaryRow('Expected Cash:', '₱${summary['expected_cash']}'),
            _summaryRow('Actual Cash:', '₱${summary['actual_cash']}'),
            const Divider(),
            Text(
              'Difference: ₱${(double.parse(summary['actual_cash'].toString()) - double.parse(summary['expected_cash'].toString())).toStringAsFixed(2)}',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: (double.parse(summary['actual_cash'].toString()) < double.parse(summary['expected_cash'].toString())) ? Colors.red : Colors.green,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close')),
          ElevatedButton(
            onPressed: () => printZReport(summary, storeSettings: widget.storeSettings), 
            child: const Text('Print Report'),
          ),
        ],
      ),
    );
  }

  Widget _summaryRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label),
          Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: _isLoading 
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(24.0),
              child: Center(
                child: Container(
                  constraints: const BoxConstraints(maxWidth: 500),
                  padding: const EdgeInsets.all(32),
                  decoration: cardDecoration(),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        _activeShift == null ? Icons.lock_open_rounded : Icons.lock_clock_rounded,
                        size: 64,
                        color: _activeShift == null ? Colors.blue : Colors.orange,
                      ),
                      const SizedBox(height: 24),
                      Text(
                        _activeShift == null ? 'Start New Shift' : 'Active Shift #${_activeShift!['id']}',
                        style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _activeShift == null 
                            ? 'Please enter your starting cash to begin.'
                            : 'Shift started at: ${_activeShift!['start_time']}',
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Colors.grey),
                      ),
                      const SizedBox(height: 32),
                      if (_activeShift == null) ...[
                        TextField(
                          controller: _cashController,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'Starting Cash (in Drawer)',
                            prefixText: '₱ ',
                            border: OutlineInputBorder(),
                          ),
                        ),
                        const SizedBox(height: 24),
                        SizedBox(
                          width: double.infinity,
                          height: 50,
                          child: ElevatedButton(
                            onPressed: _startShift,
                            style: ElevatedButton.styleFrom(backgroundColor: Colors.blue, foregroundColor: Colors.white),
                            child: const Text('OPEN SHIFT', style: TextStyle(fontWeight: FontWeight.bold)),
                          ),
                        ),
                      ] else ...[
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(color: Colors.blue.shade50, borderRadius: BorderRadius.circular(12)),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('Sales so far:', style: TextStyle(fontWeight: FontWeight.bold)),
                              Text('₱${_activeShift!['total_sales'] ?? '0.00'}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Colors.blue)),
                            ],
                          ),
                        ),
                        const SizedBox(height: 24),
                        TextField(
                          controller: _cashController,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'Actual Cash in Drawer',
                            prefixText: '₱ ',
                            border: OutlineInputBorder(),
                          ),
                        ),
                        const SizedBox(height: 16),
                        TextField(
                          controller: _notesController,
                          decoration: const InputDecoration(
                            labelText: 'Shift Notes (Optional)',
                            border: OutlineInputBorder(),
                          ),
                          maxLines: 2,
                        ),
                        const SizedBox(height: 24),
                        SizedBox(
                          width: double.infinity,
                          height: 50,
                          child: ElevatedButton(
                            onPressed: _endShift,
                            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent, foregroundColor: Colors.white),
                            child: const Text('CLOSE SHIFT (Z-READING)', style: TextStyle(fontWeight: FontWeight.bold)),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
    );
  }
}
