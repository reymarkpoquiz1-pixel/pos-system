import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class ThermalReceiptSimulator extends StatelessWidget {
  final Map<String, dynamic> transaction;
  final Map<String, dynamic>? storeSettings;

  const ThermalReceiptSimulator({
    super.key,
    required this.transaction,
    this.storeSettings,
  });

  @override
  Widget build(BuildContext context) {
    final List<dynamic> items = transaction['items'] ?? [];
    final String storeName = storeSettings?['store_name'] ?? "JUAN'S STORE";
    final String address = storeSettings?['address'] ?? "Pampanga, Philippines";
    final String phone = storeSettings?['phone'] ?? "09123456789";
    
    final double total = double.tryParse(transaction['total_amount'].toString()) ?? 0.0;
    final double tendered = double.tryParse(transaction['amount_tendered']?.toString() ?? '0') ?? 0.0;
    final double change = double.tryParse(transaction['change']?.toString() ?? '0') ?? 0.0;

    return Center(
      child: Container(
        width: 280, // Simulated 58mm width in logical pixels
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 10, offset: const Offset(0, 5))
          ],
        ),
        child: Column(
          children: [
            // SHOP HEADER
            Text(storeName.toUpperCase(), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, fontFamily: 'monospace')),
            Text(address, textAlign: TextAlign.center, style: const TextStyle(fontSize: 10, fontFamily: 'monospace')),
            Text("Tel: $phone", style: const TextStyle(fontSize: 10, fontFamily: 'monospace')),
            const SizedBox(height: 10),
            const Text("--------------------------------", style: TextStyle(fontFamily: 'monospace')),
            
            // TRANS INFO
            _row("Date:", transaction['date_created'] ?? DateFormat('MM/dd/yyyy HH:mm').format(DateTime.now())),
            _row("Invoice:", "#${transaction['transaction_id']}"),
            _row("Cashier:", transaction['cashier_name'] ?? "Admin"),
            const Text("--------------------------------", style: TextStyle(fontFamily: 'monospace')),
            
            // ITEMS
            const SizedBox(height: 5),
            ...items.map((item) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(item['name'] ?? 'Product', style: const TextStyle(fontSize: 11, fontFamily: 'monospace')),
                  _row(
                    "${item['quantity']} x ${item['price'] ?? item['unit_price']}", 
                    "₱${((item['quantity'] ?? 1) * (double.tryParse(item['price']?.toString() ?? item['unit_price']?.toString() ?? '0') ?? 0.0)).toStringAsFixed(2)}"
                  ),
                ],
              );
            }),
            
            const SizedBox(height: 10),
            const Text("--------------------------------", style: TextStyle(fontFamily: 'monospace')),
            
            // TOTALS
            _row("TOTAL:", "₱${total.toStringAsFixed(2)}", isBold: true),
            _row("TENDERED:", "₱${tendered.toStringAsFixed(2)}"),
            _row("CHANGE:", "₱${change.toStringAsFixed(2)}", isBold: true),
            
            const SizedBox(height: 20),
            const Text("THANK YOU! PLEASE COME AGAIN", style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, fontFamily: 'monospace')),
            const SizedBox(height: 5),
            const Icon(Icons.qr_code_2, size: 40),
            const SizedBox(height: 10),
            const Text("***** END OF RECEIPT *****", style: TextStyle(fontSize: 8, color: Colors.grey, fontFamily: 'monospace')),
            
            // Jagged edge effect
            const SizedBox(height: 20),
            _buildJaggedEdge(),
          ],
        ),
      ),
    );
  }

  Widget _row(String label, String value, {bool isBold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontSize: 11, fontWeight: isBold ? FontWeight.bold : FontWeight.normal, fontFamily: 'monospace')),
          Text(value, style: TextStyle(fontSize: 11, fontWeight: isBold ? FontWeight.bold : FontWeight.normal, fontFamily: 'monospace')),
        ],
      ),
    );
  }

  Widget _buildJaggedEdge() {
    return Row(
      children: List.generate(14, (index) => Expanded(
        child: Container(
          height: 10,
          decoration: BoxDecoration(
            color: Colors.grey.shade100,
            borderRadius: BorderRadius.circular(10),
          ),
          margin: const EdgeInsets.symmetric(horizontal: 2),
        ),
      )),
    );
  }
}
