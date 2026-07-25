import 'package:flutter/material.dart';
import 'package:pos/core/services/api_service.dart';
import 'dart:convert';
import 'package:pos/core/widgets/dashboard_widgets.dart';

class PaymentsView extends StatefulWidget {
  final List<dynamic> transactions;
  final bool isMobile;
  const PaymentsView({super.key, required this.transactions, required this.isMobile});

  @override
  State<PaymentsView> createState() => _PaymentsViewState();
}

class _PaymentsViewState extends State<PaymentsView> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _publicKeyController = TextEditingController();
  final TextEditingController _secretKeyController = TextEditingController();
  bool _isGcashActive = true;
  bool _isMayaActive = true;
  bool _isStripeActive = false;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _fetchGatewaySettings();
  }

  Future<void> _fetchGatewaySettings() async {
    try {
      final response = await ApiService.get('settings/get_gateways');
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success']) {
          final List gateways = data['gateways'];
          setState(() {
            for (var g in gateways) {
              if (g['gateway_name'] == 'GCash') {
                _isGcashActive = g['is_active'].toString() == '1';
                _publicKeyController.text = g['public_key'] ?? '';
                _secretKeyController.text = g['secret_key'] ?? '';
              } else if (g['gateway_name'] == 'Maya') {
                _isMayaActive = g['is_active'].toString() == '1';
              } else if (g['gateway_name'] == 'Stripe') {
                _isStripeActive = g['is_active'].toString() == '1';
              }
            }
          });
        }
      }
    } catch (e) {
      debugPrint('Fetch Gateway Error: $e');
    }
  }

  Future<void> _saveGatewaySettings() async {
    setState(() => _isSaving = true);
    try {
      final response = await ApiService.post('settings/update_gateway', {
        'gateways': [
          {'name': 'GCash', 'is_active': _isGcashActive, 'public_key': _publicKeyController.text, 'secret_key': _secretKeyController.text},
          {'name': 'Maya', 'is_active': _isMayaActive},
          {'name': 'Stripe', 'is_active': _isStripeActive},
        ]
      });
      final data = json.decode(response.body);
      if (data['success'] && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Gateway settings saved!'), backgroundColor: Colors.green));
      }
    } catch (e) {
      debugPrint('Save Gateway Error: $e');
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    double horizontalPadding = widget.isMobile ? 12 : 24;

    return Scaffold(
      backgroundColor: const Color(0xFFF7E6E9),
      body: buildThemedBackground(
        child: Padding(
          padding: EdgeInsets.all(horizontalPadding),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '💳 Payment Management System',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1C1B1F),
                  letterSpacing: -0.5,
                ),
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 24),
              Expanded(
                child: Container(
                  padding: EdgeInsets.all(horizontalPadding),
                  decoration: cardDecoration(),
                  child: Column(
                    children: [
                      TabBar(
                        controller: _tabController,
                        labelColor: const Color(0xFFD68A96),
                        unselectedLabelColor: Colors.grey,
                        indicatorColor: const Color(0xFFD68A96),
                        isScrollable: true,
                        tabAlignment: TabAlignment.start,
                        tabs: const [
                          Tab(text: 'Transaction History'),
                          Tab(text: 'Refund Requests'),
                          Tab(text: 'Gateway Settings'),
                        ],
                      ),
                      const SizedBox(height: 20),
                      Expanded(
                        child: TabBarView(
                          controller: _tabController,
                          children: [
                            _buildTransactionHistory(),
                            _buildRefundRequests(),
                            _buildGatewaySettings(),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTransactionHistory() {
    final transactions = widget.transactions;

    if (transactions.isEmpty) {
      return const Center(child: Text('Walang nakitang data sa transaksyon.'));
    }

    return ListView.builder(
      itemCount: transactions.length,
      itemBuilder: (context, index) {
        final tx = transactions[index];
        final String status = tx['status']?.toString() ?? 'Paid';
        final String method = tx['payment_method']?.toString() ?? 'Cash';
        final String amount = '₱${tx['total_amount'] ?? '0.00'}';
        final String id = tx['transaction_id']?.toString() ?? 'N/A';
        final String date = tx['date_created']?.toString() ?? 'Today';

        return Material(
          color: Colors.transparent,
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: _getStatusColor(status).withAlpha(26),
              child: Icon(_getIconForMethod(method), color: _getStatusColor(status), size: 18),
            ),
            title: Text('Transaction ID: $id', style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Text('$method | $date'),
            trailing: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(amount, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black)),
                Text(status, style: TextStyle(color: _getStatusColor(status), fontSize: 11, fontWeight: FontWeight.bold)),
              ],
            ),
            onTap: () {
              showProfessionalReceipt(context, tx);
            },
          ),
        );
      },
    );
  }

  Widget _buildRefundRequests() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.assignment_return_outlined, size: 64, color: Colors.grey),
          const SizedBox(height: 16),
          const Text('No active refund requests.', style: TextStyle(color: Colors.grey)),
          const SizedBox(height: 16),
          ElevatedButton(onPressed: () {}, child: const Text('View Refund Logs'))
        ],
      ),
    );
  }

  Widget _buildGatewaySettings() {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Payment Methods Configuration', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 16),
          _buildGatewayToggle('GCash (PayMongo Integration)', _isGcashActive, (val) => setState(() => _isGcashActive = val)),
          _buildGatewayToggle('Maya Business', _isMayaActive, (val) => setState(() => _isMayaActive = val)),
          _buildGatewayToggle('Debit/Credit Card (Stripe)', _isStripeActive, (val) => setState(() => _isStripeActive = val)),
          const SizedBox(height: 24),
          const Text('API Keys & Credentials (GCash/PayMongo)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 16),
          TextField(
            controller: _publicKeyController,
            decoration: const InputDecoration(
              labelText: 'Public Key',
              border: OutlineInputBorder(),
              hintText: 'pk_test_...',
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _secretKeyController,
            obscureText: true,
            decoration: const InputDecoration(
              labelText: 'Secret Key',
              border: OutlineInputBorder(),
              hintText: 'sk_test_...',
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _isSaving ? null : _saveGatewaySettings,
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFD68A96), foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 15)),
              child: _isSaving ? const CircularProgressIndicator(color: Colors.white) : const Text('Save Gateway Configuration', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGatewayToggle(String label, bool isEnabled, Function(bool) onChanged) {
    return Material(
      color: Colors.transparent,
      child: SwitchListTile(
        title: Text(label),
        value: isEnabled,
        onChanged: onChanged,
        activeThumbColor: const Color(0xFFD68A96),
        secondary: const Icon(Icons.account_balance_wallet_outlined),
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'Paid': return Colors.green;
      case 'Pending': return Colors.orange;
      case 'Failed': return Colors.red;
      default: return Colors.grey;
    }
  }

  IconData _getIconForMethod(String method) {
    switch (method) {
      case 'GCash': return Icons.smartphone;
      case 'Maya': return Icons.wallet;
      case 'Card': return Icons.credit_card;
      default: return Icons.payments_outlined;
    }
  }
}
