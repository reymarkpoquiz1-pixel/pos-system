import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:pos/core/services/api_service.dart';
import 'package:pos/core/widgets/dashboard_widgets.dart';

class ExpensesView extends StatefulWidget {
  const ExpensesView({super.key});

  @override
  State<ExpensesView> createState() => _ExpensesViewState();
}

class _ExpensesViewState extends State<ExpensesView> {
  List<dynamic> _expenses = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchExpenses();
  }

  Future<void> _fetchExpenses() async {
    setState(() => _isLoading = true);
    try {
      final response = await ApiService.get('reports/get_expenses');
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success']) {
          setState(() {
            _expenses = data['expenses'] ?? [];
          });
        }
      }
    } catch (e) {
      if (mounted) {
        debugPrint('Expenses Fetch Error: $e');
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showAddExpenseDialog() {
    final titleController = TextEditingController();
    final amountController = TextEditingController();
    String category = 'Utilities';
    final categories = ['Rent', 'Utilities', 'Salary', 'Supplies', 'Marketing', 'Others'];

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: const Color(0xFFFBECEF),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          title: const Text('Record New Expense', style: TextStyle(fontWeight: FontWeight.bold)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: titleController,
                decoration: InputDecoration(labelText: 'Title (e.g. Meralco Bill)', prefixIcon: const Icon(Icons.title), filled: true, fillColor: Colors.white, border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none)),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: amountController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(labelText: 'Amount (₱)', prefixIcon: const Icon(Icons.payments_outlined), filled: true, fillColor: Colors.white, border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none)),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: category,
                decoration: InputDecoration(labelText: 'Category', filled: true, fillColor: Colors.white, border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none)),
                items: categories.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                onChanged: (val) => setDialogState(() => category = val!),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () async {
                if (titleController.text.isEmpty || amountController.text.isEmpty) return;
                final response = await ApiService.post(
                  'reports/add_expense',
                  {
                    'title': titleController.text,
                    'amount': amountController.text,
                    'category': category,
                  },
                );
                if (json.decode(response.body)['success'] && context.mounted) {
                  Navigator.pop(context);
                  _fetchExpenses();
                }
              },
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFD68A96), foregroundColor: Colors.white),
              child: const Text('Save Expense'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    double totalExpenses = _expenses.fold(0.0, (sum, item) => sum + (double.tryParse(item['amount'].toString()) ?? 0.0));

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
                    '💸 Expense Tracking',
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Color(0xFF1C1B1F), letterSpacing: -0.5),
                  ),
                  ElevatedButton.icon(
                    onPressed: _showAddExpenseDialog,
                    icon: const Icon(Icons.add_chart),
                    label: const Text('Record Expense'),
                    style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFD68A96), foregroundColor: Colors.white),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              _buildSummaryCard(totalExpenses),
              const SizedBox(height: 24),
              Expanded(
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator(color: Color(0xFFD68A96)))
                    : ListView.builder(
                        itemCount: _expenses.length,
                        itemBuilder: (context, index) {
                          final e = _expenses[index];
                          return Container(
                            margin: const EdgeInsets.only(bottom: 12),
                            decoration: cardDecoration(),
                            child: Material(
                              color: Colors.transparent,
                              borderRadius: BorderRadius.circular(24),
                              child: ListTile(
                                leading: CircleAvatar(backgroundColor: Colors.red.withValues(alpha: 0.1), child: const Icon(Icons.outbox_rounded, color: Colors.red)),
                                title: Text(e['title'], style: const TextStyle(fontWeight: FontWeight.bold)),
                                subtitle: Text('${e['category']} | ${e['expense_date']}'),
                                trailing: Text('₱${e['amount']}', style: const TextStyle(fontWeight: FontWeight.w900, color: Colors.red, fontSize: 16)),
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

  Widget _buildSummaryCard(double total) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: cardDecoration().copyWith(color: const Color(0xFF1C1B1F)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Total Expenses (All Time)', style: TextStyle(color: Colors.grey, fontSize: 14)),
          const SizedBox(height: 8),
          Text('₱${total.toStringAsFixed(2)}', style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.w900)),
        ],
      ),
    );
  }
}
