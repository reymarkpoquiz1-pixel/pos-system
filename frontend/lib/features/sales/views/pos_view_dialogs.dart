import 'package:flutter/material.dart';
import 'package:pos/core/services/api_service.dart';
import 'dart:convert';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:http/http.dart' as http;
import 'pos_view_mixin.dart';

mixin PosViewDialogs on PosViewMixin {
  @override
  void showShiftAlert() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Shift Required', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
        content: const Text('You must open a shift before you can process any sales. Please go to Shift Management.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  @override
  void showVariantSelectionDialog(Map<String, dynamic> product, List<dynamic> variants) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Select Variant for ${product['name']}'),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.separated(
            shrinkWrap: true,
            itemCount: variants.length,
            separatorBuilder: (context, index) => const Divider(),
            itemBuilder: (context, index) {
              final v = variants[index];
              final String colorName = v['color_name'] ?? '';
              final String size = v['size'] ?? '';
              final int stock = int.tryParse(v['stock']?.toString() ?? '0') ?? 0;
              final colorHex = v['color_hex'] ?? 'ffffffff';

              return ListTile(
                leading: Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    color: Color(int.parse(colorHex, radix: 16)),
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                ),
                title: Text('$colorName ${size.isNotEmpty ? "($size)" : ""}'),
                subtitle: Text('Stock: $stock', style: TextStyle(color: stock <= 0 ? Colors.red : Colors.green)),
                trailing: const Icon(Icons.add_shopping_cart, size: 20, color: Colors.blue),
                enabled: stock > 0,
                onTap: () {
                  Navigator.pop(context);
                  performAddToCart(product, v);
                },
              );
            },
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        ],
      ),
    );
  }

  void showPaymentDialog() {
    if (cart.isEmpty) return;
    paymentController.clear();
    referenceController.clear();
    String selectedMethod = 'Cash';

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          final media = MediaQuery.of(context);
          final bool isLandscape = media.orientation == Orientation.landscape;
          final bool isKeyboardOpen = media.viewInsets.bottom > 0;

          double tendered = double.tryParse(paymentController.text) ?? 0.0;
          double change = tendered > totalAmount ? tendered - totalAmount : 0.0;

          return Dialog(
            insetPadding: EdgeInsets.symmetric(
              horizontal: isLandscape ? 40 : 20,
              vertical: isKeyboardOpen ? 10 : 24
            ),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: isLandscape ? 700 : 400),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.payments_outlined, color: Colors.blue, size: 24),
                          const SizedBox(width: 10),
                          const Text('Process Payment', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                          const Spacer(),
                          IconButton(
                            onPressed: () => Navigator.pop(context),
                            icon: const Icon(Icons.close, size: 20, color: Colors.grey),
                          ),
                        ],
                      ),
                      const Divider(height: 24),

                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: ['Cash', 'GCash', 'Maya', 'Card'].map((m) => ChoiceChip(
                          label: Text(m),
                          selected: selectedMethod == m,
                          onSelected: (val) => setDialogState(() => selectedMethod = m),
                        )).toList(),
                      ),
                      const SizedBox(height: 20),

                      if (isLandscape)
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(child: buildPaymentSummary(change)),
                            const SizedBox(width: 24),
                            Expanded(child: Column(
                              children: [
                                buildPaymentInput(setDialogState),
                                if (selectedMethod != 'Cash') ...[
                                  const SizedBox(height: 12),
                                  TextField(
                                    controller: referenceController,
                                    decoration: const InputDecoration(labelText: 'Reference Number', border: OutlineInputBorder()),
                                  ),
                                ]
                              ],
                            )),
                          ],
                        )
                      else ...[
                        buildPaymentSummary(change),
                        const SizedBox(height: 20),
                        buildPaymentInput(setDialogState),
                        if (selectedMethod != 'Cash') ...[
                          const SizedBox(height: 12),
                          TextField(
                            controller: referenceController,
                            decoration: const InputDecoration(labelText: 'Reference Number', border: OutlineInputBorder()),
                          ),
                        ]
                      ],

                      const SizedBox(height: 24),

                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
                          const SizedBox(width: 12),
                          ElevatedButton(
                            onPressed: (selectedMethod == 'Cash' && tendered < totalAmount) ? null : () => finalizeTransaction(tendered, change, selectedMethod),
                            style: ElevatedButton.styleFrom(backgroundColor: Colors.blue, foregroundColor: Colors.white),
                            child: const Text('FINALIZE & PRINT'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        }
      ),
    );
  }

  Widget buildPaymentSummary(double change) {
    final bool isLandscape = MediaQuery.of(context).orientation == Orientation.landscape;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Total Amount to Pay:', style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text('₱${totalAmount.toStringAsFixed(2)}',
              style: TextStyle(fontSize: isLandscape ? 24 : 32, fontWeight: FontWeight.w900, color: Colors.blue)),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.green.shade50,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Change:', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.green)),
              Text('₱${change.toStringAsFixed(2)}',
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.green)),
            ],
          ),
        ),
      ],
    );
  }

  Widget buildPaymentInput(StateSetter setDialogState) {
    return TextField(
      controller: paymentController,
      autofocus: true,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      decoration: const InputDecoration(
        labelText: 'Amount Received',
        hintText: '0.00',
        prefixText: '₱ ',
        border: OutlineInputBorder(),
        filled: true,
        fillColor: Color(0xFFF8FAFC),
      ),
      onChanged: (val) => setDialogState(() {}),
    );
  }

  void showScannerDialog() {
    setState(() => isScannerOpen = true);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Scan Product Barcode'),
        content: SizedBox(
          width: 400,
          height: 400,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: MobileScanner(
              onDetect: (capture) {
                final List<Barcode> barcodes = capture.barcodes;
                for (final barcode in barcodes) {
                  final String? code = barcode.rawValue;
                  if (code != null) {
                    debugPrint('Barcode found! $code');
                    handleBarcodeScanned(code);
                    Navigator.pop(context);
                    break;
                  }
                }
              },
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close')),
        ],
      ),
    ).then((_) => setState(() => isScannerOpen = false));
  }

  void showCustomerSelectionDialog() async {
    showDialog(
      context: context,
      builder: (context) => FutureBuilder<http.Response>(
        future: ApiService.get('costumers/get_customers'),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
          final data = json.decode(snapshot.data!.body);
          final List customers = data['customers'] ?? [];

          return AlertDialog(
            title: const Text('Select Customer / Suki'),
            content: SizedBox(
              width: 400,
              height: 400,
              child: Column(
                children: [
                  ListTile(
                    leading: const CircleAvatar(child: Icon(Icons.people_outline)),
                    title: const Text('Walk-in Customer (Default)'),
                    onTap: () {
                      setState(() => selectedCustomer = null);
                      Navigator.pop(context);
                    },
                  ),
                  const Divider(),
                  Expanded(
                    child: ListView.builder(
                      itemCount: customers.length,
                      itemBuilder: (context, index) {
                        final c = customers[index];
                        return ListTile(
                          leading: CircleAvatar(child: Text(c['name'][0])),
                          title: Text(c['name']),
                          subtitle: Text(c['phone'] ?? ''),
                          trailing: Text('${c['points']} pts', style: const TextStyle(color: Colors.blue, fontWeight: FontWeight.bold)),
                          onTap: () {
                            setState(() => selectedCustomer = c);
                            Navigator.pop(context);
                          },
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  void showCartBottomSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setBottomSheetState) {
          final media = MediaQuery.of(context);
          final bool isLandscape = media.orientation == Orientation.landscape;

          return Align(
            alignment: Alignment.bottomCenter,
            child: Container(
              width: isLandscape ? 500 : double.infinity,
              height: media.size.height * (isLandscape ? 0.9 : 0.8),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 10, spreadRadius: 1)],
              ),
              child: Column(
                children: [
                  Container(
                    margin: const EdgeInsets.only(top: 12, bottom: 8),
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)),
                  ),
                  buildCartHeader(),
                    Expanded(
                    child: ListView.builder(
                      itemCount: cart.length,
                      itemBuilder: (context, index) {
                        final item = cart[index];
                        final String variantInfo = [item['variant_name'], item['variant_size']]
                            .where((s) => s != null && s.isNotEmpty)
                            .join(', ');

                        return ListTile(
                          title: Text(item['name'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (variantInfo.isNotEmpty)
                                Text(variantInfo, style: const TextStyle(fontSize: 11, color: Colors.blue, fontWeight: FontWeight.w600)),
                              Text('₱${item['price']} x ${item['quantity']}'),
                            ],
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text('₱${(item['price'] * item['quantity']).toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold)),
                              IconButton(
                                onPressed: () {
                                  removeFromCart(index);
                                  setBottomSheetState(() {});
                                  setState(() {});
                                  if (cart.isEmpty) Navigator.pop(context);
                                },
                                icon: const Icon(Icons.remove_circle_outline, color: Colors.red, size: 20)
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                  buildSummaryArea(),
                ],
              ),
            ),
          );
        }
      ),
    );
  }

  // Abstract UI methods to be provided by PosViewWidgets
  Widget buildCartHeader();
  Widget buildSummaryArea();
}
