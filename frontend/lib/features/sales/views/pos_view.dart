import 'package:flutter/material.dart';
import 'package:pos/core/services/connectivity_service.dart';
import 'pos_view_mixin.dart';
import 'pos_view_dialogs.dart';
import 'pos_view_widgets.dart';

class PosView extends StatefulWidget {
  final String username;
  final int userId;
  final int terminalId;
  final Map<String, dynamic>? storeSettings;
  const PosView({super.key, required this.username, required this.userId, required this.terminalId, this.storeSettings});

  @override
  State<PosView> createState() => _PosViewState();
}

class _PosViewState extends State<PosView> with PosViewMixin, PosViewDialogs, PosViewWidgets {
  
  @override
  void initState() {
    super.initState();
    isOffline = !ConnectivityService.instance.isConnectedNotifier.value;
    ConnectivityService.instance.isConnectedNotifier.addListener(onConnectivityChanged);
    checkShiftStatus();
    fetchProducts();
    updatePendingSync();
  }

  @override
  void dispose() {
    ConnectivityService.instance.isConnectedNotifier.removeListener(onConnectivityChanged);
    searchController.dispose();
    paymentController.dispose();
    referenceController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        bool isSmallScreen = constraints.maxWidth < 900;

        return Scaffold(
          backgroundColor: Colors.transparent,
          body: Row(
            children: [
              Expanded(
                flex: 3,
                child: Container(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      buildSearchBar(),
                      const SizedBox(height: 16),
                      Expanded(
                        child: isLoading
                          ? buildSkeletonGrid(isSmallScreen ? constraints.maxWidth : constraints.maxWidth - 380)
                          : buildProductGrid(isSmallScreen ? constraints.maxWidth : constraints.maxWidth - 380),
                      ),
                    ],
                  ),
                ),
              ),
              if (!isSmallScreen)
                Container(
                  width: 380,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    border: Border(left: BorderSide(color: Colors.grey.shade200)),
                  ),
                  child: Column(
                    children: [
                      buildCartHeader(),
                      Expanded(child: buildCartList()),
                      buildSummaryArea(),
                    ],
                  ),
                ),
            ],
          ),
          floatingActionButton: isSmallScreen && cart.isNotEmpty
            ? FloatingActionButton.extended(
                onPressed: showCartBottomSheet,
                label: Text('View Order (${cart.length})', style: const TextStyle(fontWeight: FontWeight.bold)),
                icon: const Icon(Icons.shopping_basket),
                backgroundColor: Colors.blue.shade700,
                foregroundColor: Colors.white,
              )
            : null,
        );
      }
    );
  }
}
