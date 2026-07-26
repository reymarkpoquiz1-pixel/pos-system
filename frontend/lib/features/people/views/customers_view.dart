import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:pos/core/services/api_service.dart';
import 'package:pos/core/widgets/dashboard_widgets.dart';

class CustomersView extends StatefulWidget {
  final List<dynamic> customersList;
  final VoidCallback onRefresh;
  const CustomersView({super.key, required this.customersList, required this.onRefresh});

  @override
  State<CustomersView> createState() => _CustomersViewState();
}

class _CustomersViewState extends State<CustomersView> {
  List<dynamic> _customers = [];
  List<dynamic> _filteredCustomers = [];
  bool _isLoading = true;
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _customers = widget.customersList;
    _filteredCustomers = _customers;
    if (_customers.isEmpty) {
      _fetchCustomers();
    } else {
      _isLoading = false;
    }
  }

  @override
  void didUpdateWidget(CustomersView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.customersList != oldWidget.customersList) {
      setState(() {
        _customers = widget.customersList;
        _filterCustomers(_searchQuery);
      });
    }
  }

  Future<void> _fetchCustomers() async {
    setState(() => _isLoading = true);
    try {
      final response = await ApiService.get('costumers/get_customers');
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success']) {
          setState(() {
            _customers = data['customers'];
            _filteredCustomers = _customers;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        debugPrint('Customers Fetch Error: $e');
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _filterCustomers(String query) {
    setState(() {
      _searchQuery = query.toLowerCase();
      _filteredCustomers = _customers.where((c) {
        final name = (c['name'] ?? '').toString().toLowerCase();
        final phone = (c['phone'] ?? '').toString().toLowerCase();
        final email = (c['email'] ?? '').toString().toLowerCase();
        return name.contains(_searchQuery) || phone.contains(_searchQuery) || email.contains(_searchQuery);
      }).toList();
    });
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
                    '👥 Customer Management',
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Color(0xFF1C1B1F), letterSpacing: -0.5),
                  ),
                  SizedBox(
                    height: 44,
                    child: ElevatedButton.icon(
                      onPressed: () => _showAddCustomerDialog(),
                      icon: const Icon(Icons.person_add_alt_1_rounded, size: 18),
                      label: const Text('Add Customer', style: TextStyle(fontWeight: FontWeight.bold)),
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
              _buildSearchBar(),
              const SizedBox(height: 16),
              Expanded(
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator(color: Color(0xFFD68A96)))
                    : _filteredCustomers.isEmpty
                        ? const Center(child: Text('No customers found.', style: TextStyle(color: Colors.grey)))
                        : _buildCustomerList(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showAddCustomerDialog() {
    final nameController = TextEditingController();
    final emailController = TextEditingController();
    final phoneController = TextEditingController();
    final formKey = GlobalKey<FormState>();
    bool isSaving = false;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: const Color(0xFFFBECEF),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
          title: const Row(
            children: [
              Icon(Icons.person_add_outlined, color: Color(0xFFD68A96)),
              SizedBox(width: 12),
              Text('Add New Suki', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFFD68A96))),
            ],
          ),
          content: SingleChildScrollView(
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildDialogField(nameController, 'Full Name', Icons.person, (v) => v!.isEmpty ? 'Required' : null),
                  const SizedBox(height: 16),
                  _buildDialogField(emailController, 'Email Address', Icons.email_outlined, null),
                  const SizedBox(height: 16),
                  _buildDialogField(phoneController, 'Phone Number', Icons.phone_iphone, (v) => v!.isEmpty ? 'Required' : null),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: isSaving ? null : () async {
                if (formKey.currentState!.validate()) {
                  setDialogState(() => isSaving = true);
                  final success = await _saveCustomer(nameController.text, emailController.text, phoneController.text);
                  if (success && context.mounted) {
                    Navigator.pop(context);
                    _fetchCustomers();
                  } else {
                    setDialogState(() => isSaving = false);
                  }
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFD68A96),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: isSaving ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Text('Save Suki'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDialogField(TextEditingController controller, String label, IconData icon, String? Function(String?)? validator) {
    return TextFormField(
      controller: controller,
      validator: validator,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: const Color(0xFFD68A96), size: 20),
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: const BorderSide(color: Color(0xFFEFAFB8))),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: const BorderSide(color: Color(0xFFEFAFB8))),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: const BorderSide(color: Color(0xFFD68A96), width: 1.5)),
      ),
    );
  }

  Future<bool> _saveCustomer(String name, String email, String phone) async {
    try {
      final response = await ApiService.post(
        'costumers/add_customer',
        {'name': name, 'email': email, 'phone': phone},
      );
      final data = json.decode(response.body);
      if (data['success']) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Customer successfully added!'), backgroundColor: Colors.green));
        return true;
      } else {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: ${data['message']}'), backgroundColor: Colors.red));
        return false;
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Connection Error: $e'), backgroundColor: Colors.red));
      return false;
    }
  }

  Widget _buildSearchBar() {
    return Container(
      decoration: cardDecoration(),
      child: TextField(
        controller: _searchController,
        onChanged: _filterCustomers,
        decoration: InputDecoration(
          hintText: 'Search by name, phone, or email...',
          prefixIcon: const Icon(Icons.search, color: Color(0xFFD68A96)),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
          suffixIcon: _searchQuery.isNotEmpty 
            ? IconButton(
                icon: const Icon(Icons.clear), 
                onPressed: () {
                  _searchController.clear();
                  _filterCustomers('');
                }
              ) 
            : null,
        ),
      ),
    );
  }

  Widget _buildCustomerList() {
    return Container(
      decoration: cardDecoration(),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: ListView.separated(
          itemCount: _filteredCustomers.length,
          separatorBuilder: (context, index) => Divider(height: 1, color: Colors.pink.shade50),
          itemBuilder: (context, index) {
            final customer = _filteredCustomers[index];
            return Material(
              color: Colors.transparent,
              borderRadius: BorderRadius.circular(24),
              child: ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                leading: CircleAvatar(
                  backgroundColor: const Color(0xFFFBECEF),
                  child: Text(
                    (customer['name'] ?? 'U')[0].toUpperCase(),
                    style: const TextStyle(color: Color(0xFFD68A96), fontWeight: FontWeight.bold),
                  ),
                ),
                title: Text(
                  customer['name'] ?? 'Unknown',
                  style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF1C1B1F)),
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 4),
                    Row(
                    children: [
                      const Icon(Icons.phone_iphone_rounded, size: 14, color: Colors.grey),
                      const SizedBox(width: 4),
                      Text(customer['phone'] ?? 'No phone', style: const TextStyle(fontSize: 12)),
                      const SizedBox(width: 12),
                      const Icon(Icons.email_outlined, size: 14, color: Colors.grey),
                      const SizedBox(width: 4),
                      Text(customer['email'] ?? 'No email', style: const TextStyle(fontSize: 12)),
                    ],
                  ),
                ],
              ),
              trailing: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '${customer['points'] ?? 0} pts',
                    style: const TextStyle(fontWeight: FontWeight.w900, color: Color(0xFFD68A96), fontSize: 16),
                  ),
                  const Text('Loyalty', style: TextStyle(fontSize: 10, color: Colors.grey)),
                ],
              ),
              onTap: () => _showCustomerDetails(customer),
            ),
          );
          },
        ),
      ),
    );
  }

  void _showCustomerDetails(dynamic customer) async {
    final int customerId = int.parse(customer['id'].toString());
    
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        builder: (_, controller) => Container(
          decoration: const BoxDecoration(
            color: Color(0xFFF7E6E9),
            borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
          ),
          padding: const EdgeInsets.all(24),
          child: FutureBuilder<Map<String, dynamic>>(
            future: _fetchCustomerHistory(customerId),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (!snapshot.hasData || snapshot.data!['success'] == false) {
                return const Center(child: Text('Error loading history.'));
              }

              final data = snapshot.data!;
              final history = data['history'] as List<dynamic>;
              final info = data['customer'];

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(10))),
                  ),
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      CircleAvatar(radius: 30, backgroundColor: const Color(0xFFD68A96), child: Text(info['name'][0].toUpperCase(), style: const TextStyle(fontSize: 24, color: Colors.white, fontWeight: FontWeight.bold))),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(info['name'], style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                            Text(info['email'] ?? 'No email', style: const TextStyle(color: Colors.grey)),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      _infoBox('Total Spend', '₱${info['total_spend'] ?? '0.00'}', Icons.shopping_bag_outlined),
                      const SizedBox(width: 12),
                      _infoBox('Loyalty Points', '${info['points']} pts', Icons.star_outline),
                    ],
                  ),
                  const SizedBox(height: 32),
                  const Text('Points History', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 16),
                  _buildPointsHistory(customerId),
                  const SizedBox(height: 32),
                  const Text('Transaction History', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 16),
                  Expanded(
                    child: history.isEmpty 
                      ? const Center(child: Text('No orders yet.'))
                      : ListView.separated(
                          controller: controller,
                          itemCount: history.length,
                          separatorBuilder: (context, index) => const Divider(),
                          itemBuilder: (context, index) {
                            final tx = history[index];
                            return Material(
                              color: Colors.transparent,
                              child: ListTile(
                                contentPadding: EdgeInsets.zero,
                                title: Row(
                                  children: [
                                    Text('Order ID: ${tx['id']}', style: const TextStyle(fontWeight: FontWeight.bold)),
                                    const SizedBox(width: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(color: Colors.grey.shade200, borderRadius: BorderRadius.circular(4)),
                                      child: Text(tx['payment_method']?.toString().toUpperCase() ?? 'CASH', style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold)),
                                    ),
                                  ],
                                ),
                                subtitle: Text('${tx['transaction_date']} | ${tx['items']?.length ?? 0} items'),
                                trailing: Text('₱${tx['final_amount']}', style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFFD68A96))),
                                onTap: () => showProfessionalReceipt(context, tx),
                              ),
                            );
                          },
                        ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildPointsHistory(int customerId) {
    return FutureBuilder<Map<String, dynamic>>(
      future: _fetchPointsHistory(customerId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) return const SizedBox(height: 50, child: Center(child: CircularProgressIndicator()));
        if (!snapshot.hasData || snapshot.data!['success'] == false) return const Text('No points history.');

        final history = snapshot.data!['history'] as List<dynamic>;
        if (history.isEmpty) return const Text('No points history yet.', style: TextStyle(color: Colors.grey, fontSize: 12));

        return ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: history.length,
          separatorBuilder: (context, index) => const Divider(),
          itemBuilder: (context, index) {
            final h = history[index];
            final earned = int.tryParse(h['points_earned'].toString()) ?? 0;
            final spent = int.tryParse(h['points_spent'].toString()) ?? 0;
            return Material(
              color: Colors.transparent,
              child: ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(h['reason'] ?? 'Purchase'),
                subtitle: Text(h['created_at']),
                trailing: Text(
                  earned > 0 ? '+$earned pts' : '-$spent pts',
                  style: TextStyle(fontWeight: FontWeight.bold, color: earned > 0 ? Colors.green : Colors.red),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<Map<String, dynamic>> _fetchPointsHistory(int id) async {
    try {
      final response = await ApiService.get('costumers/get_points_history?customer_id=$id');
      return json.decode(response.body);
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  Widget _infoBox(String label, String value, IconData icon) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(15)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 18, color: const Color(0xFFD68A96)),
            const SizedBox(height: 8),
            Text(value, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900)),
            Text(label, style: const TextStyle(fontSize: 11, color: Colors.grey)),
          ],
        ),
      ),
    );
  }

  Future<Map<String, dynamic>> _fetchCustomerHistory(int id) async {
    try {
      final response = await ApiService.get('costumers/get_customer_history?customer_id=$id');
      return json.decode(response.body);
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }
}
