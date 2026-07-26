import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:pos/core/constants/config.dart';
import 'package:pos/features/auth/views/login_screen.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:pos/features/sales/widgets/thermal_receipt_simulator.dart';

// 1. CARD DECORATION HELPER
BoxDecoration cardDecoration() {
  return BoxDecoration(
    color: Colors.white.withValues(alpha: 0.6),
    borderRadius: BorderRadius.circular(24),
    border: Border.all(
      color: const Color(0xFFEFAFB8).withValues(alpha: 0.3),
      width: 1,
    ),
  );
}

// 2. SIDEBAR ITEM WIDGET
Widget buildSidebarItem(
    BuildContext context,
    IconData icon,
    String title,
    String selectedMenu,
    Color activeBg,
    Function(String) onMenuSelect, {
      bool isLogout = false,
    }) {
  bool isSelected = selectedMenu == title;
  return Container(
    margin: const EdgeInsets.symmetric(vertical: 2),
    decoration: BoxDecoration(
      color: isSelected ? activeBg : Colors.transparent,
      borderRadius: BorderRadius.circular(8),
    ),
    child: Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(8),
      child: ListTile(
        dense: true,
        leading: Icon(
          icon,
          color: isSelected ? Colors.white : (isLogout ? Colors.redAccent : const Color(0xFF1C1B1F).withValues(alpha: 0.7)),
        ),
        title: Text(
          title,
          style: TextStyle(
            color: isSelected ? Colors.white : (isLogout ? Colors.redAccent : const Color(0xFF1C1B1F)),
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
            fontSize: 13,
          ),
        ),
        onTap: () {
          if (isLogout) {
            Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const LoginScreen()));
          } else {
            onMenuSelect(title);
          }
        },
      ),
    ),
  );
}

// 3. CATEGORY LABEL
Widget buildCategoryLabel(Color color, String label) {
  return Padding(
    padding: const EdgeInsets.symmetric(vertical: 6.0),
    child: Row(
      children: [
        Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 10),
        Text(label, style: const TextStyle(fontSize: 12, color: Color(0xFF334155), fontWeight: FontWeight.w600)),
      ],
    ),
  );
}

// 4. PROFESSIONAL RECEIPT DIALOG (PERFECT IMAGE COPY)
void showProfessionalReceipt(BuildContext context, Map<String, dynamic> tx, {VoidCallback? onStatusUpdate, Map<String, dynamic>? storeSettings}) {
  bool isThermalView = false;

  showDialog(
    context: context,
    builder: (context) {
      return StatefulBuilder(
        builder: (context, setDialogState) {
          final size = MediaQuery.of(context).size;
          final bool isMobile = size.width < 600;

          return Dialog(
            backgroundColor: Colors.transparent,
            insetPadding: EdgeInsets.symmetric(horizontal: isMobile ? 10 : 40, vertical: 20),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // TOGGLE BUTTON (TOP)
                  Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(30)),
                    child: ToggleButtons(
                      isSelected: [!isThermalView, isThermalView],
                      onPressed: (index) => setDialogState(() => isThermalView = index == 1),
                      borderRadius: BorderRadius.circular(30),
                      constraints: const BoxConstraints(minHeight: 36, minWidth: 120),
                      fillColor: Colors.blue.shade700,
                      selectedColor: Colors.white,
                      children: const [
                        Text('Professional (A4)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                        Text('Thermal (58mm)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),

                  if (isThermalView)
                    ThermalReceiptSimulator(transaction: tx, storeSettings: storeSettings)
                  else
                    _buildProfessionalReceiptContent(context, tx, storeSettings, isMobile, onStatusUpdate),
                ],
              ),
            ),
          );
        },
      );
    },
  );
}

Widget _buildProfessionalReceiptContent(BuildContext context, Map<String, dynamic> tx, Map<String, dynamic>? storeSettings, bool isMobile, VoidCallback? onStatusUpdate) {
  final List<dynamic> items = tx['items'] ?? [];
  final double total = double.tryParse(tx['total_amount'].toString()) ?? 0.0;
  final double tendered = double.tryParse(tx['amount_tendered']?.toString() ?? '0') ?? 0.0;
  final double change = double.tryParse(tx['change']?.toString() ?? '0') ?? 0.0;
  final double vatRate = double.tryParse(storeSettings?['tax_rate']?.toString() ?? '12') ?? 12.0;
  final double subtotal = total / (1 + (vatRate / 100));
  final double vatAmount = total - subtotal;
  final String invoiceNo = "INV-${tx['transaction_id'] ?? tx['id'] ?? 'N/A'}";
  final String currentStatus = tx['order_status'] ?? 'Pending';
  final String orderType = tx['order_type'] ?? (tx['cashier_role'] == 'User' ? 'Online' : 'Walk-in');
  final bool isOnline = orderType == 'Online';

  // Dynamic Store Info
  final String storeName = storeSettings?['store_name'] ?? "JUAN'S STORE";
  final String storeAddress = storeSettings?['address'] ?? '123 Rizal St., Brgy. Poblacion, Angeles City, Pampanga';
  final String storePhone = storeSettings?['phone'] ?? '0912-345-6789';
  final String storeEmail = storeSettings?['email'] ?? 'juansstore@email.com';
  final String? logoUrl = storeSettings?['logo_url'];

  return Container(
    constraints: const BoxConstraints(maxWidth: 550),
    width: double.infinity,
    padding: EdgeInsets.all(isMobile ? 15 : 40),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(2),
    ),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Status Badge at the very top
        Align(
          alignment: Alignment.topRight,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: _getStatusColor(currentStatus).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              currentStatus.toUpperCase(),
              style: TextStyle(color: _getStatusColor(currentStatus), fontWeight: FontWeight.bold, fontSize: 10),
            ),
          ),
        ),
        const SizedBox(height: 10),
        // HEADER SECTION
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              width: isMobile ? 50 : 80,
              height: isMobile ? 50 : 80,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: Colors.black, width: 2),
              ),
              child: logoUrl != null
                  ? ClipOval(child: Image.network(
                      '$baseUrl/$logoUrl',
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) => const Icon(Icons.storefront, color: Colors.black, size: 30),
                    ))
                  : Icon(Icons.shopping_cart, color: Colors.black, size: isMobile ? 30 : 50),
            ),
            const SizedBox(width: 15),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Text(
                      storeName.toUpperCase(),
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          fontSize: isMobile ? 22 : 32,
                          fontWeight: FontWeight.w900,
                          color: Colors.black,
                          letterSpacing: 1.0
                      )
                  ),
                  const SizedBox(height: 2),
                  Text(
                      'Retail and General Merchandise',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.black.withValues(alpha: 0.8))
                  ),
                  Text(
                      storeAddress,
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 10, color: Colors.black.withValues(alpha: 0.7), fontWeight: FontWeight.w500)
                  ),
                  Text(
                      '$storePhone | $storeEmail',
                      style: TextStyle(fontSize: 10, color: Colors.black.withValues(alpha: 0.7), fontWeight: FontWeight.w500)
                  ),
                ],
              ),
            ),
            SizedBox(width: isMobile ? 65 : 80),
          ],
        ),
        const SizedBox(height: 15),
        const Divider(thickness: 1, color: Colors.black12),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Text('RECEIPT / INVOICE', style: TextStyle(fontSize: isMobile ? 18 : 24, fontWeight: FontWeight.bold, letterSpacing: 1)),
        ),
        const SizedBox(height: 20),

        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 12,
              child: Column(
                children: [
                  _receiptMetaRow('Invoice No.', invoiceNo, isMobile: isMobile),
                  _receiptMetaRow('Date', tx['transaction_date']?.toString() ?? tx['date_created']?.toString() ?? 'N/A', isMobile: isMobile),
                  _receiptMetaRow(isOnline ? 'Customer' : 'Cashier', tx['customer_name'] ?? tx['cashier_name'] ?? 'Admin', isMobile: isMobile),
                  if (tx['courier_name'] != null && tx['courier_name'] != '')
                    _receiptMetaRow('Courier', tx['courier_name'], isMobile: isMobile),
                  if (tx['tracking_number'] != null && tx['tracking_number'] != '')
                    _receiptMetaRow('Tracking #', tx['tracking_number'], isMobile: isMobile),
                  _receiptMetaRow(
                      isOnline ? 'Order Type' : 'POS Terminal',
                      isOnline ? 'ONLINE' : 'POS-${(tx['terminal_id'] ?? '1').toString().padLeft(2, '0')}',
                      isMobile: isMobile
                  ),
                ],
              ),
            ),
            const SizedBox(width: 15),
            Expanded(
              flex: 8,
              child: Column(
                children: [
                  _receiptMetaRow('Transaction Type', 'SALE', isMobile: isMobile),
                  _receiptMetaRow('Payment Method', tx['payment_method']?.toString().toUpperCase() ?? 'CASH', isMobile: isMobile),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),

        Container(
          color: Colors.grey.shade200,
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
          child: Row(
            children: [
              const SizedBox(width: 40, child: Text('QTY', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11))),
              const Expanded(child: Text('ITEM', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11))),
              SizedBox(width: isMobile ? 60 : 100, child: Text('PRICE', textAlign: TextAlign.right, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11))),
              SizedBox(width: isMobile ? 70 : 100, child: Text('TOTAL', textAlign: TextAlign.right, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11))),
            ],
          ),
        ),
        const SizedBox(height: 10),

        if (items.isEmpty)
          const Padding(padding: EdgeInsets.all(20), child: Text('No items found.', style: TextStyle(color: Colors.grey)))
        else
          ...items.map((item) {
            final String qty = item['quantity']?.toString() ?? '1';
            final String name = (item['product_name'] ?? item['name'] ?? 'Unknown Item').toString();
            final double price = double.tryParse((item['unit_price'] ?? item['price'] ?? '0').toString()) ?? 0.0;
            final double sub = price * (int.tryParse(qty) ?? 1);
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(width: 40, child: Text(qty, style: const TextStyle(fontSize: 12))),
                  Expanded(child: Text(name, style: const TextStyle(fontSize: 12))),
                  SizedBox(width: isMobile ? 60 : 100, child: Text(price.toStringAsFixed(2), textAlign: TextAlign.right, style: const TextStyle(fontSize: 12))),
                  SizedBox(width: isMobile ? 70 : 100, child: Text(sub.toStringAsFixed(2), textAlign: TextAlign.right, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold))),
                ],
              ),
            );
          }),

        const SizedBox(height: 10),
        const Divider(thickness: 1, color: Colors.black26),

        Align(
          alignment: Alignment.centerRight,
          child: SizedBox(
            width: isMobile ? double.infinity : 320,
            child: Column(
              children: [
                _receiptTotalRow('SUBTOTAL', subtotal.toStringAsFixed(2), isMobile: isMobile),
                _receiptTotalRow('DISCOUNT', '0.00', isMobile: isMobile),
                _receiptTotalRow('TAXABLE AMOUNT', subtotal.toStringAsFixed(2), isMobile: isMobile),
                _receiptTotalRow('VAT ($vatRate%)', vatAmount.toStringAsFixed(2), isMobile: isMobile),
                const Divider(thickness: 1, color: Colors.black26),
                _receiptTotalRow('TOTAL', total.toStringAsFixed(2), isMainTotal: true, isMobile: isMobile),
                const SizedBox(height: 10),
                _receiptTotalRow('AMOUNT TENDERED', tendered.toStringAsFixed(2), isMobile: isMobile),
                _receiptTotalRow('CHANGE', change.toStringAsFixed(2), isMobile: isMobile),
              ],
            ),
          ),
        ),

        const SizedBox(height: 30),
        const Text('Thank you for shopping!', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
        const Text('This serves as your official receipt.', style: TextStyle(fontSize: 12)),
        const SizedBox(height: 5),
        const Text('---------------------------------------------------------------------------------------------------------------',
            maxLines: 1,
            overflow: TextOverflow.clip,
            style: TextStyle(color: Colors.grey, fontSize: 8, letterSpacing: 2)),
        const SizedBox(height: 10),

        FittedBox(
          fit: BoxFit.scaleDown,
          child: Column(
            children: [
              Image.network(
                'https://bwipjs-api.metafloor.com/?bcid=code128&text=$invoiceNo&scale=3&height=10&includetext=false',
                height: 40,
                width: 300,
                fit: BoxFit.fill,
                errorBuilder: (c, e, s) => const Icon(Icons.barcode_reader, size: 50, color: Colors.black),
              ),
              const SizedBox(height: 5),
              Text(invoiceNo, style: const TextStyle(fontSize: 12, letterSpacing: 3, fontWeight: FontWeight.w500)),
            ],
          ),
        ),

        const SizedBox(height: 25),
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text("System: ${storeName.toUpperCase()} POS SYSTEM | www.${storeName.toLowerCase().replaceAll(' ', '')}pos.com",
              style: TextStyle(fontSize: 10, color: Colors.grey.shade600, fontWeight: FontWeight.w500)),
        ),

        const SizedBox(height: 30),

        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close')),
            const SizedBox(width: 15),
            ElevatedButton.icon(
              onPressed: () => printReceipt(tx, storeSettings: storeSettings),
              icon: const Icon(Icons.print, size: 14),
              label: const Text('Print', style: TextStyle(fontSize: 12)),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.deepPurple, foregroundColor: Colors.white),
            ),
          ],
        )
      ],
    ),
  );
}

// 4.1 PRINT RECEIPT LOGIC
Future<void> printReceipt(Map<String, dynamic> tx, {Map<String, dynamic>? storeSettings}) async {
  final doc = pw.Document();

  final String storeName = storeSettings?['store_name'] ?? "JUAN'S STORE";
  final String storeAddress = storeSettings?['address'] ?? '123 Rizal St., Brgy. Poblacion, Angeles City, Pampanga';
  final String storePhone = storeSettings?['phone'] ?? '0912-345-6789';
  final String? logoUrl = storeSettings?['logo_url'];
  final String invoiceNo = "INV-${tx['transaction_id'] ?? tx['id'] ?? 'N/A'}";
  final List<dynamic> items = tx['items'] ?? [];
  final double vatRate = double.tryParse(storeSettings?['tax_rate']?.toString() ?? '12') ?? 12.0;
  final double total = double.tryParse(tx['total_amount'].toString()) ?? 0.0;
  final double subtotal = total / (1 + (vatRate / 100));
  final double vatAmount = total - subtotal;

  pw.MemoryImage? logoImage;
  if (logoUrl != null && logoUrl.isNotEmpty) {
    try {
      final response = await http.get(Uri.parse('$baseUrl/$logoUrl'));
      if (response.statusCode == 200) {
        logoImage = pw.MemoryImage(response.bodyBytes);
      }
    } catch (e) {
      debugPrint('Error loading logo for PDF: $e');
    }
  }

  doc.addPage(
    pw.Page(
      pageFormat: PdfPageFormat(80 * PdfPageFormat.mm, 200 * PdfPageFormat.mm, marginAll: 5 * PdfPageFormat.mm),
      build: (pw.Context context) {
        return pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.center,
          children: [
            if (logoImage != null)
              pw.Container(
                width: 30 * PdfPageFormat.mm,
                height: 30 * PdfPageFormat.mm,
                child: pw.Image(logoImage),
              ),
            pw.SizedBox(height: 2),
            pw.Text(storeName.toUpperCase(), style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 14)),
            pw.Text(storeAddress, style: const pw.TextStyle(fontSize: 8), textAlign: pw.TextAlign.center),
            pw.Text(storePhone, style: const pw.TextStyle(fontSize: 8)),
            pw.Divider(thickness: 0.5),
            pw.SizedBox(height: 5),
            pw.Text('RECEIPT / INVOICE', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10)),
            pw.SizedBox(height: 5),
            pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
              pw.Text('Inv No:', style: const pw.TextStyle(fontSize: 8)),
              pw.Text(invoiceNo, style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold)),
            ]),
            pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
              pw.Text('Date:', style: const pw.TextStyle(fontSize: 8)),
              pw.Text(tx['transaction_date']?.toString() ?? tx['date_created']?.toString() ?? 'N/A', style: const pw.TextStyle(fontSize: 8)),
            ]),
            pw.Divider(thickness: 0.5),
            pw.Row(children: [
              pw.Expanded(flex: 3, child: pw.Text('ITEM', style: pw.TextStyle(fontSize: 7, fontWeight: pw.FontWeight.bold))),
              pw.Expanded(flex: 1, child: pw.Text('QTY', textAlign: pw.TextAlign.center, style: pw.TextStyle(fontSize: 7, fontWeight: pw.FontWeight.bold))),
              pw.Expanded(flex: 2, child: pw.Text('TOTAL', textAlign: pw.TextAlign.right, style: pw.TextStyle(fontSize: 7, fontWeight: pw.FontWeight.bold))),
            ]),
            pw.SizedBox(height: 2),
            ...items.map((item) => pw.Row(children: [
              pw.Expanded(flex: 3, child: pw.Text(item['product_name'] ?? item['name'] ?? '', style: const pw.TextStyle(fontSize: 7))),
              pw.Expanded(flex: 1, child: pw.Text(item['quantity'].toString(), textAlign: pw.TextAlign.center, style: const pw.TextStyle(fontSize: 7))),
              pw.Expanded(flex: 2, child: pw.Text('P${(double.parse(item['unit_price'].toString()) * int.parse(item['quantity'].toString())).toStringAsFixed(2)}', textAlign: pw.TextAlign.right, style: const pw.TextStyle(fontSize: 7))),
            ])),
            pw.Divider(thickness: 0.5),
            pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
              pw.Text('SUBTOTAL', style: const pw.TextStyle(fontSize: 8)),
              pw.Text('P${subtotal.toStringAsFixed(2)}', style: const pw.TextStyle(fontSize: 8)),
            ]),
            pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
              pw.Text('VAT ($vatRate%)', style: const pw.TextStyle(fontSize: 8)),
              pw.Text('P${vatAmount.toStringAsFixed(2)}', style: const pw.TextStyle(fontSize: 8)),
            ]),
            pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
              pw.Text('TOTAL', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
              pw.Text('P${total.toStringAsFixed(2)}', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
            ]),
            pw.SizedBox(height: 10),
            pw.Text('Thank you for shopping!', style: const pw.TextStyle(fontSize: 8)),
          ],
        );
      },
    ),
  );

  await Printing.layoutPdf(onLayout: (PdfPageFormat format) async => doc.save());
}

// 4.2 PRINT Z-REPORT LOGIC
Future<void> printZReport(Map<String, dynamic> summary, {Map<String, dynamic>? storeSettings}) async {
  final doc = pw.Document();
  final String storeName = storeSettings?['store_name'] ?? "JUAN'S STORE";
  final String storeAddress = storeSettings?['address'] ?? '123 Rizal St., Brgy. Poblacion, Angeles City, Pampanga';
  final String? logoUrl = storeSettings?['logo_url'];

  pw.MemoryImage? logoImage;
  if (logoUrl != null && logoUrl.isNotEmpty) {
    try {
      final response = await http.get(Uri.parse('$baseUrl/$logoUrl'));
      if (response.statusCode == 200) {
        logoImage = pw.MemoryImage(response.bodyBytes);
      }
    } catch (e) {
      debugPrint('Error loading logo for Z-Report: $e');
    }
  }

  doc.addPage(
    pw.Page(
      pageFormat: PdfPageFormat(80 * PdfPageFormat.mm, 200 * PdfPageFormat.mm, marginAll: 5 * PdfPageFormat.mm),
      build: (pw.Context context) {
        return pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.center,
          children: [
            if (logoImage != null)
              pw.Container(width: 25 * PdfPageFormat.mm, height: 25 * PdfPageFormat.mm, child: pw.Image(logoImage)),
            pw.Text(storeName.toUpperCase(), style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 12)),
            pw.Text(storeAddress, style: const pw.TextStyle(fontSize: 7), textAlign: pw.TextAlign.center),
            pw.Divider(thickness: 0.5),
            pw.SizedBox(height: 5),
            pw.Text('Z-READING REPORT', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10)),
            pw.SizedBox(height: 10),

            _pwReportRow('Shift ID:', '#${summary['shift_id'] ?? summary['id'] ?? 'N/A'}'),
            _pwReportRow('Printed At:', DateTime.now().toString().substring(0, 16)),
            pw.SizedBox(height: 5),
            pw.Divider(thickness: 0.5, borderStyle: pw.BorderStyle.dashed),
            pw.SizedBox(height: 5),

            _pwReportRow('Starting Cash:', 'P${summary['starting_cash']}'),
            _pwReportRow('Total Sales:', 'P${summary['total_sales']}'),
            _pwReportRow('Expected Cash:', 'P${summary['expected_cash']}'),
            _pwReportRow('Actual Cash:', 'P${summary['actual_cash']}'),
            pw.SizedBox(height: 5),
            pw.Divider(thickness: 0.5),

            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text('DIFFERENCE:', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9)),
                pw.Text(
                  'P${(double.parse(summary['actual_cash'].toString()) - double.parse(summary['expected_cash'].toString())).toStringAsFixed(2)}',
                  style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9),
                ),
              ],
            ),

            pw.SizedBox(height: 20),
            pw.Text('--------------------------', style: const pw.TextStyle(fontSize: 8)),
            pw.Text('Cashier Signature', style: const pw.TextStyle(fontSize: 8)),
            pw.SizedBox(height: 30),
            pw.Text('END OF REPORT', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 8)),
          ],
        );
      },
    ),
  );

  await Printing.layoutPdf(onLayout: (PdfPageFormat format) async => doc.save());
}

pw.Widget _pwReportRow(String label, String value) {
  return pw.Padding(
    padding: const pw.EdgeInsets.symmetric(vertical: 2),
    child: pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Text(label, style: const pw.TextStyle(fontSize: 8)),
        pw.Text(value, style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold)),
      ],
    ),
  );
}

Widget _receiptMetaRow(String label, String value, {bool isMobile = false}) {
  return Padding(
    padding: const EdgeInsets.symmetric(vertical: 2),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
            width: isMobile ? 75 : 100,
            child: Text(
              label,
              style: TextStyle(fontSize: isMobile ? 8.5 : 11, fontWeight: FontWeight.w500),
              maxLines: 2,
            )
        ),
        Text(': ', style: TextStyle(fontSize: isMobile ? 8.5 : 11, fontWeight: FontWeight.bold)),
        Expanded(
            child: Text(
                value,
                style: TextStyle(fontSize: isMobile ? 8.5 : 11, fontWeight: FontWeight.bold)
            )
        ),
      ],
    ),
  );
}

Widget _receiptTotalRow(String label, String value, {bool isMainTotal = false, bool isMobile = false}) {
  return Padding(
    padding: const EdgeInsets.symmetric(vertical: 2),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: TextStyle(fontSize: isMainTotal ? (isMobile ? 18 : 22) : 12, fontWeight: isMainTotal ? FontWeight.w900 : FontWeight.bold)),
        Text(value, style: TextStyle(fontSize: isMainTotal ? (isMobile ? 20 : 24) : 12, fontWeight: isMainTotal ? FontWeight.w900 : FontWeight.bold)),
      ],
    ),
  );
}

Color _getStatusColor(String status) {
  switch (status.toLowerCase()) {
    case 'pending': return Colors.orange;
    case 'preparing': return Colors.blue;
    case 'shipped': return Colors.purple;
    case 'delivered': return Colors.green;
    case 'cancelled': return Colors.red;
    default: return Colors.grey;
  }
}

// 5. THEMED BACKGROUND WRAPPER (SCATTERED SMALL BAGS)
Widget buildThemedBackground({required Widget child}) {
  return Stack(
    children: [
      // Scattered small bags
      Positioned(top: 100, left: 50, child: _smallBagIcon()),
      Positioned(top: 250, right: 80, child: _smallBagIcon()),
      Positioned(bottom: 150, left: 120, child: _smallBagIcon()),
      Positioned(bottom: 300, right: 40, child: _smallBagIcon()),
      Positioned(top: 400, left: 200, child: _smallBagIcon()),
      Positioned(bottom: 50, right: 250, child: _smallBagIcon()),
      Positioned(top: 50, right: 150, child: _smallBagIcon()),
      child,
    ],
  );
}

Widget _smallBagIcon() {
  return Opacity(
    opacity: 0.08,
    child: Icon(
      Icons.shopping_bag_outlined,
      size: 40,
      color: const Color(0xFFD68A96),
    ),
  );
}

// ORIGINAL TABLE HELPERS
TableRow buildTableRowHeader() {
  return const TableRow(
    children: [
      Padding(padding: EdgeInsets.symmetric(vertical: 12.0, horizontal: 8.0), child: Text('Transaction ID', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF475569), fontSize: 12))),
      Padding(padding: EdgeInsets.symmetric(vertical: 12.0, horizontal: 8.0), child: Text('Customer Name', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF475569), fontSize: 12))),
      Padding(padding: EdgeInsets.symmetric(vertical: 12.0, horizontal: 8.0), child: Text('Amount', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF475569), fontSize: 12))),
      Padding(padding: EdgeInsets.symmetric(vertical: 12.0, horizontal: 8.0), child: Text('Status', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF475569), fontSize: 12))),
    ],
  );
}

TableRow buildTableRowData(String id, String name, String amt, String status, Color statusColor) {
  return TableRow(
    children: [
      Padding(padding: const EdgeInsets.symmetric(vertical: 14.0, horizontal: 8.0), child: Text(id, style: const TextStyle(color: Colors.black87, fontSize: 12))),
      Padding(padding: const EdgeInsets.symmetric(vertical: 14.0, horizontal: 8.0), child: Text(name, style: const TextStyle(color: Colors.black87, fontSize: 12))),
      Padding(padding: const EdgeInsets.symmetric(vertical: 14.0, horizontal: 8.0), child: Text(amt, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12))),
      Padding(padding: const EdgeInsets.symmetric(vertical: 10.0, horizontal: 8.0), child: Align(alignment: Alignment.centerLeft, child: Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4), decoration: BoxDecoration(color: statusColor.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(6)), child: Text(status, style: TextStyle(color: statusColor, fontWeight: FontWeight.bold, fontSize: 11))))),
    ],
  );
}

Widget buildProductRow(String name, String soldLabel, String imageUrl) {
  return Padding(
    padding: const EdgeInsets.symmetric(vertical: 8.0),
    child: Row(
      children: [
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 4,
                offset: const Offset(0, 2),
              )
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: imageUrl.isNotEmpty
                ? Image.network(
              imageUrl.startsWith('http') ? imageUrl : '$baseUrl/$imageUrl',
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) => const Icon(Icons.image_not_supported, size: 20, color: Colors.black12),
            )
                : const Icon(Icons.image_outlined, size: 20, color: Colors.black12),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF1C1B1F), letterSpacing: -0.2),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                      soldLabel,
                      style: TextStyle(color: Colors.grey.shade600, fontSize: 11, fontWeight: FontWeight.w500)
                  )
                ]
            )
        ),
      ],
    ),
  );
}

Widget buildScheduleRow(String label, String value, {bool isBold = false}) {
  return Padding(
    padding: const EdgeInsets.symmetric(vertical: 6.0),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: TextStyle(color: isBold ? Colors.black : Colors.grey, fontWeight: isBold ? FontWeight.bold : FontWeight.normal, fontSize: 12)),
        Text(value, style: TextStyle(fontWeight: FontWeight.bold, color: isBold ? Colors.blue : Colors.black, fontSize: 12)),
      ],
    ),
  );
}

class SkeletonLoader extends StatefulWidget {
  final double width;
  final double height;
  final double borderRadius;
  final EdgeInsetsGeometry? margin;

  const SkeletonLoader({
    super.key,
    required this.width,
    required this.height,
    this.borderRadius = 8,
    this.margin,
  });

  @override
  State<SkeletonLoader> createState() => _SkeletonLoaderState();
}

class _SkeletonLoaderState extends State<SkeletonLoader> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 1500))..repeat();
    _animation = Tween<double>(begin: -2, end: 2).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOutSine));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Container(
          width: widget.width,
          height: widget.height,
          margin: widget.margin,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(widget.borderRadius),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              stops: [
                0.1 + _animation.value * 0.1,
                0.5 + _animation.value * 0.1,
                0.9 + _animation.value * 0.1,
              ],
              colors: [
                Colors.grey.shade200,
                Colors.grey.shade100,
                Colors.grey.shade200,
              ],
            ),
          ),
        );
      },
    );
  }
}
