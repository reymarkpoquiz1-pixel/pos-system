import 'package:flutter/material.dart';
import 'package:pos/core/services/api_service.dart';
import 'dart:convert';
import 'package:pos/core/widgets/dashboard_widgets.dart';

class SuppliersView extends StatefulWidget {
  const SuppliersView({super.key});

  @override
  State<SuppliersView> createState() => _SuppliersViewState();
}

class _SuppliersViewState extends State<SuppliersView> with SingleTickerProviderStateMixin {
  List<dynamic> _suppliers = [];
  List<dynamic> _purchaseOrders = [];
  bool _isLoading = true;
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _fetchData();
  }

  Future<void> _fetchData() async {
    await Future.wait([
      _fetchSuppliers(),
      _fetchPurchaseOrders(),
    ]);
  }

  Future<void> _fetchPurchaseOrders() async {
    try {
      final response = await ApiService.get('inventory/get_purchase_orders');
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success']) {
          setState(() {
            _purchaseOrders = data['purchase_orders'] ?? [];
          });
        }
      }
    } catch (e) {
      debugPrint('PO Error: $e');
    }
  }

  Future<void> _fetchSuppliers() async {
    setState(() => _isLoading = true);
    try {
      final response = await ApiService.get('inventory/get_suppliers');
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success']) {
          setState(() {
            _suppliers = data['suppliers'] ?? [];
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

  void _showAddSupplierDialog() {
    final nameController = TextEditingController();
    final contactController = TextEditingController();
    final phoneController = TextEditingController();
    final emailController = TextEditingController();
    final addressController = TextEditingController();
    bool isSaving = false;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: const Color(0xFFFBECEF),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
          title: const Text('Add New Supplier', style: TextStyle(fontWeight: FontWeight.bold)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildField(nameController, 'Company/Supplier Name', Icons.business),
                const SizedBox(height: 12),
                _buildField(contactController, 'Contact Person', Icons.person_outline),
                const SizedBox(height: 12),
                _buildField(phoneController, 'Phone Number', Icons.phone, isNumber: true),
                const SizedBox(height: 12),
                _buildField(emailController, 'Email Address', Icons.email_outlined),
                const SizedBox(height: 12),
                _buildField(addressController, 'Address', Icons.location_on_outlined),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: isSaving ? null : () async {
                if (nameController.text.isEmpty) return;
                setDialogState(() => isSaving = true);
                final success = await _saveSupplier({
                  'name': nameController.text,
                  'contact_person': contactController.text,
                  'phone': phoneController.text,
                  'email': emailController.text,
                  'address': addressController.text,
                });
                if (success && context.mounted) {
                  Navigator.pop(context);
                  _fetchSuppliers();
                } else {
                  setDialogState(() => isSaving = false);
                }
              },
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFD68A96), foregroundColor: Colors.white),
              child: isSaving ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Text('Save Supplier'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildField(TextEditingController controller, String label, IconData icon, {bool isNumber = false}) {
    return TextField(
      controller: controller,
      keyboardType: isNumber ? TextInputType.number : TextInputType.text,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: const Color(0xFFD68A96)),
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
      ),
    );
  }

  Future<bool> _saveSupplier(Map<String, String> data) async {
    try {
      final response = await ApiService.post(
        'inventory/add_supplier',
        data,
      );
      return json.decode(response.body)['success'];
    } catch (e) {
      return false;
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
                    '📦 Inventory & Logistics',
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Color(0xFF1C1B1F), letterSpacing: -0.5),
                  ),
                  Row(
                    children: [
                      ElevatedButton.icon(
                        onPressed: _showCreatePODialog,
                        icon: const Icon(Icons.shopping_cart_checkout),
                        label: const Text('Create PO'),
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.blueGrey, foregroundColor: Colors.white),
                      ),
                      const SizedBox(width: 12),
                      ElevatedButton.icon(
                        onPressed: _showAddSupplierDialog,
                        icon: const Icon(Icons.add),
                        label: const Text('Add Supplier'),
                        style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFD68A96), foregroundColor: Colors.white),
                      ),
                    ],
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
                  Tab(text: 'Suppliers'),
                  Tab(text: 'Purchase Orders'),
                ],
              ),
              const SizedBox(height: 24),
              Expanded(
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator(color: Color(0xFFD68A96)))
                    : TabBarView(
                        controller: _tabController,
                        children: [
                          _buildSupplierList(),
                          _buildPOList(),
                        ],
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSupplierList() {
    if (_suppliers.isEmpty) return const Center(child: Text('No suppliers found.'));
    return ListView.builder(
      itemCount: _suppliers.length,
      itemBuilder: (context, index) {
        final s = _suppliers[index];
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          decoration: cardDecoration(),
          child: Material(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(24),
            child: ListTile(
              leading: const CircleAvatar(backgroundColor: Color(0xFFFBECEF), child: Icon(Icons.business, color: Color(0xFFD68A96))),
              title: Text(s['name'], style: const TextStyle(fontWeight: FontWeight.bold)),
              subtitle: Text('${s['contact_person']} | ${s['phone']}'),
              trailing: IconButton(icon: const Icon(Icons.info_outline), onPressed: () {}),
            ),
          ),
        );
      },
    );
  }

  Widget _buildPOList() {
    if (_purchaseOrders.isEmpty) return const Center(child: Text('No purchase orders found.'));
    return ListView.builder(
      itemCount: _purchaseOrders.length,
      itemBuilder: (context, index) {
        final po = _purchaseOrders[index];
        final bool isReceived = po['status'] == 'Received';
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          decoration: cardDecoration(),
          child: Material(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(24),
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: isReceived ? Colors.green.withValues(alpha: 0.1) : Colors.orange.withValues(alpha: 0.1),
                child: Icon(Icons.shopping_cart, color: isReceived ? Colors.green : Colors.orange),
              ),
              title: Text('PO #${po['id']} - ${po['supplier_name']}', style: const TextStyle(fontWeight: FontWeight.bold)),
              subtitle: Text('Date: ${po['order_date']} | Status: ${po['status']}'),
              trailing: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text('₱${po['total_amount']}', style: const TextStyle(fontWeight: FontWeight.bold)),
                  if (!isReceived)
                    TextButton(
                      onPressed: () => _receivePO(po['id']),
                      child: const Text('Receive', style: TextStyle(fontSize: 10)),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  void _showCreatePODialog() {
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('PO Creation Form coming soon!')));
  }

  Future<void> _receivePO(dynamic poId) async {
    try {
      final response = await ApiService.post(
        'inventory/receive_purchase_order',
        {'po_id': poId},
      );
      final data = json.decode(response.body);
      if (data['success']) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('PO received and stock updated!'), backgroundColor: Colors.green));
        _fetchData();
      }
    } catch (e) {
      debugPrint('Receive Error: $e');
    }
  }
}
