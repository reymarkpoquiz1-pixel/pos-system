import 'package:flutter/material.dart';
import 'package:pos/core/services/api_service.dart';
import 'dart:convert';
import 'package:pos/core/widgets/dashboard_widgets.dart';

class VouchersView extends StatefulWidget {
  const VouchersView({super.key});

  @override
  State<VouchersView> createState() => _VouchersViewState();
}

class _VouchersViewState extends State<VouchersView> {
  List<dynamic> _vouchers = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchVouchers();
  }

  Future<void> _fetchVouchers() async {
    setState(() => _isLoading = true);
    try {
      final response = await ApiService.get('marketing/get_vouchers');
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success']) {
          setState(() {
            _vouchers = data['vouchers'] ?? [];
          });
        }
      }
    } catch (e) {
      if (mounted) {
        debugPrint('Vouchers Fetch Error: $e');
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
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
                    '🎫 Voucher Management',
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Color(0xFF1C1B1F), letterSpacing: -0.5),
                  ),
                  SizedBox(
                    height: 44,
                    child: ElevatedButton.icon(
                      onPressed: () => _showGenerateVoucherDialog(),
                      icon: const Icon(Icons.confirmation_number_outlined, size: 18),
                      label: const Text('Generate Voucher', style: TextStyle(fontWeight: FontWeight.bold)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFD68A96),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              Expanded(
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator(color: Color(0xFFD68A96)))
                    : _vouchers.isEmpty
                        ? const Center(child: Text('No vouchers found.', style: TextStyle(color: Colors.grey)))
                        : _buildVoucherList(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildVoucherList() {
    return ListView.separated(
      itemCount: _vouchers.length,
      separatorBuilder: (context, index) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final v = _vouchers[index];
        final bool isUsed = v['is_used'].toString() == '1';

        return Container(
          decoration: cardDecoration(),
          child: IntrinsicHeight(
            child: Row(
              children: [
                // Ticket Notch Decoration
                Container(
                  width: 12,
                  decoration: const BoxDecoration(
                    color: Color(0xFFD68A96),
                    borderRadius: BorderRadius.horizontal(left: Radius.circular(24)),
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        const Icon(Icons.confirmation_num, color: Color(0xFFD68A96), size: 30),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                v['voucher_code'],
                                style: TextStyle(
                                  fontSize: 18, 
                                  fontWeight: FontWeight.w900, 
                                  letterSpacing: 1.5,
                                  decoration: isUsed ? TextDecoration.lineThrough : null,
                                  color: isUsed ? Colors.grey : const Color(0xFF1C1B1F)
                                ),
                              ),
                              Text('Created: ${v['created_at']}', style: const TextStyle(fontSize: 11, color: Colors.grey)),
                            ],
                          ),
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              '₱${v['value']}',
                              style: TextStyle(
                                fontSize: 20, 
                                fontWeight: FontWeight.bold, 
                                color: isUsed ? Colors.grey : Colors.green
                              ),
                            ),
                            const SizedBox(height: 4),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: isUsed ? Colors.grey.withAlpha(26) : Colors.blue.withAlpha(26),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                isUsed ? 'USED' : 'AVAILABLE',
                                style: TextStyle(
                                  color: isUsed ? Colors.grey : Colors.blue, 
                                  fontSize: 10, 
                                  fontWeight: FontWeight.bold
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showGenerateVoucherDialog() {
    final valueController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFFFBECEF),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Text('Generate Voucher', style: TextStyle(fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Enter the value of the credit voucher to generate.', style: TextStyle(fontSize: 13, color: Colors.black54)),
            const SizedBox(height: 16),
            TextField(
              controller: valueController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: 'Voucher Value (₱)',
                prefixIcon: const Icon(Icons.payments_outlined, color: Color(0xFFD68A96)),
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              if (valueController.text.isEmpty) return;
              try {
                final response = await ApiService.post(
                  'marketing/add_voucher',
                  {'value': valueController.text},
                );
                if (json.decode(response.body)['success']) {
                  if (context.mounted) {
                    Navigator.pop(context);
                  }
                  _fetchVouchers();
                }
              } catch (e) {
                debugPrint('Error: $e');
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFD68A96), foregroundColor: Colors.white),
            child: const Text('Generate Now'),
          ),
        ],
      ),
    );
  }
}
