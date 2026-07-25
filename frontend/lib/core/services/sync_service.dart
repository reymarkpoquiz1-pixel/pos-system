import 'dart:convert';
import 'package:flutter/material.dart';
import 'api_service.dart';
import 'database_helper.dart';

class SyncService {
  static bool _isSyncing = false;

  static Future<void> syncOfflineSales(BuildContext? context) async {
    if (_isSyncing) return;
    _isSyncing = true;

    try {
      final pendingSales = await DatabaseHelper.instance.getPendingSales();
      if (pendingSales.isEmpty) {
        _isSyncing = false;
        return;
      }

      debugPrint("STARTING SYNC: ${pendingSales.length} transactions");
      
      int successCount = 0;

      for (var sale in pendingSales) {
        final response = await ApiService.post('place_order', {
          'items': sale['items'],
          'total_amount': sale['total_amount'],
          'discount': sale['discount'],
          'amount_paid': sale['amount_paid'],
          'change': sale['change'],
          'payment_method': sale['payment_method'],
          'order_status': 'Delivered',
          'order_type': 'Walk-in',
          'customer_id': sale['customer_id'],
        });

        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          if (data['success'] == true) {
            await DatabaseHelper.instance.markAsSynced(sale['id']);
            successCount++;
          }
        }
      }

      if (successCount > 0) {
        await DatabaseHelper.instance.deleteSyncedSales();
        if (context != null && context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('✅ Synced $successCount offline transactions!'),
              backgroundColor: Colors.green,
            ),
          );
        }
      }
    } catch (e) {
      debugPrint("SYNC ERROR: $e");
    } finally {
      _isSyncing = false;
    }
  }

  static Future<int> getPendingCount() async {
    final sales = await DatabaseHelper.instance.getPendingSales();
    return sales.length;
  }
}
