import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:pos/core/services/api_service.dart';
import 'package:pos/core/constants/config.dart';
import 'package:pos/core/widgets/dashboard_widgets.dart';

class PromosView extends StatefulWidget {
  const PromosView({super.key});

  @override
  State<PromosView> createState() => _PromosViewState();
}

class _PromosViewState extends State<PromosView> {
  List<dynamic> _promos = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchPromos();
  }

  Future<void> _fetchPromos() async {
    setState(() => _isLoading = true);
    try {
      final response = await ApiService.get('marketing/get_promos');
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success']) {
          setState(() {
            _promos = data['promos'] ?? [];
          });
        }
      }
    } catch (e) {
      if (mounted) {
        debugPrint('Promos Fetch Error: $e');
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
                    '🏷️ Discount & Promo Codes',
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Color(0xFF1C1B1F), letterSpacing: -0.5),
                  ),
                  SizedBox(
                    height: 44,
                    child: ElevatedButton.icon(
                      onPressed: () => _showAddPromoDialog(),
                      icon: const Icon(Icons.add_circle_outline, size: 18),
                      label: const Text('Create Promo', style: TextStyle(fontWeight: FontWeight.bold)),
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
                    : _promos.isEmpty
                        ? const Center(child: Text('No active promotions.', style: TextStyle(color: Colors.grey)))
                        : _buildPromoGrid(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPromoGrid() {
    return GridView.builder(
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 2.2,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
      ),
      itemCount: _promos.length,
      itemBuilder: (context, index) {
        final promo = _promos[index];
        final bool isExpired = DateTime.parse(promo['expiry_date']).isBefore(DateTime.now());

        return Container(
          decoration: cardDecoration(),
          child: Stack(
            children: [
              Positioned(
                right: -10,
                bottom: -10,
                child: Icon(Icons.percent, size: 80, color: const Color(0xFFD68A96).withAlpha(15)),
              ),
              Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFBECEF),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: const Color(0xFFEFAFB8)),
                          ),
                          child: Text(
                            promo['code'],
                            style: const TextStyle(fontWeight: FontWeight.w900, color: Color(0xFFD68A96), fontSize: 16, letterSpacing: 1),
                          ),
                        ),
                        _statusBadge(isExpired ? 'Expired' : 'Active', !isExpired),
                      ],
                    ),
                    const Spacer(),
                    Text(
                      promo['discount_percent'] != '0.00' 
                        ? '${promo['discount_percent']}% OFF' 
                        : '₱${promo['discount_fixed']} OFF',
                      style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF1C1B1F)),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Valid until: ${promo['expiry_date']}',
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  ],
                ),
              ),
              Positioned(
                top: 8,
                right: 8,
                child: IconButton(
                  icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 18),
                  onPressed: () => _confirmDelete(promo['id']),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _statusBadge(String label, bool active) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: active ? Colors.green.withAlpha(26) : Colors.red.withAlpha(26),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: TextStyle(color: active ? Colors.green : Colors.red, fontSize: 10, fontWeight: FontWeight.bold),
      ),
    );
  }

  void _showAddPromoDialog() {
    final codeController = TextEditingController();
    final discountController = TextEditingController();
    final dateController = TextEditingController();
    String type = 'Percent';
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: const Color(0xFFFBECEF),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          title: const Text('Create New Promo', style: TextStyle(fontWeight: FontWeight.bold)),
          content: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildField(codeController, 'Promo Code (e.g. SALE20)', Icons.qr_code),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: ChoiceChip(
                        label: const Text('Percent (%)'),
                        selected: type == 'Percent',
                        onSelected: (val) => setDialogState(() => type = 'Percent'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ChoiceChip(
                        label: const Text('Fixed (₱)'),
                        selected: type == 'Fixed',
                        onSelected: (val) => setDialogState(() => type = 'Fixed'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _buildField(discountController, 'Discount Value', Icons.money_off, isNumber: true),
                const SizedBox(height: 16),
                _buildField(dateController, 'Expiry Date (YYYY-MM-DD)', Icons.calendar_today, onTap: () async {
                  DateTime? picked = await showDatePicker(
                    context: context,
                    initialDate: DateTime.now(),
                    firstDate: DateTime.now(),
                    lastDate: DateTime(2030),
                  );
                  if (picked != null) {
                    setDialogState(() => dateController.text = picked.toString().split(' ')[0]);
                  }
                }),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () => _savePromo(codeController.text, type, discountController.text, dateController.text),
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFD68A96), foregroundColor: Colors.white),
              child: const Text('Save Promo'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildField(TextEditingController controller, String label, IconData icon, {bool isNumber = false, VoidCallback? onTap}) {
    return TextFormField(
      controller: controller,
      keyboardType: isNumber ? TextInputType.number : TextInputType.text,
      readOnly: onTap != null,
      onTap: onTap,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: const Color(0xFFD68A96), size: 20),
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
      ),
    );
  }

  Future<void> _savePromo(String code, String type, String value, String date) async {
    if (code.isEmpty || value.isEmpty || date.isEmpty) return;
    try {
      final response = await ApiService.post(
        'marketing/add_promo',
        {
          'code': code,
          'discount_percent': type == 'Percent' ? value : '0',
          'discount_fixed': type == 'Fixed' ? value : '0',
          'expiry_date': date,
        },
      );
      if (json.decode(response.body)['success']) {
        if (!mounted) return;
        Navigator.pop(context);
        _fetchPromos();
      }
    } catch (e) {
      debugPrint('Error: $e');
    }
  }

  void _confirmDelete(dynamic id) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Promo?'),
        content: const Text('Are you sure you want to remove this promo code?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          TextButton(
            onPressed: () async {
              await ApiService.post('marketing/delete_promo', {'id': id});
              if (!mounted) return;
              Navigator.pop(context);
              _fetchPromos();
            },
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}
