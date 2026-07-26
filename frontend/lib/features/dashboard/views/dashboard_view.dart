import 'package:flutter/material.dart';
import 'package:pos/core/constants/config.dart';
import 'package:pos/core/widgets/dashboard_widgets.dart';
import '../widgets/dashboard_painters.dart';

class DashboardView extends StatelessWidget {
  final Map<String, dynamic> dashboardStats;
  final Map<String, dynamic> chartData;
  final List<dynamic> productsList;
  final List<dynamic> topSellingProducts;
  final List<dynamic> transactionsList;
  final bool isMobile;
  final Function(String) onMenuSelect;
  final BuildContext context;
  final Map<String, dynamic>? storeSettings;
  final bool isLoading;

  const DashboardView({
    super.key,
    required this.dashboardStats,
    required this.chartData,
    required this.productsList,
    required this.topSellingProducts,
    required this.transactionsList,
    required this.isMobile,
    required this.onMenuSelect,
    required this.context,
    this.storeSettings,
    this.isLoading = false,
  });

  static const Color textDark = Color(0xFF1E293B);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7E6E9),
      body: buildThemedBackground(
        child: SingleChildScrollView(
          padding: EdgeInsets.all(isMobile ? 16.0 : 24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildQuickActions(),
              const SizedBox(height: 24),
              Flex(
                direction: isMobile ? Axis.vertical : Axis.horizontal,
                crossAxisAlignment: isMobile ? CrossAxisAlignment.stretch : CrossAxisAlignment.start,
                children: [
                  // LEFT SIDE PANELS
                  Expanded(
                    flex: isMobile ? 0 : 2,
                    child: Column(
                      children: [
                        _buildSalesCards(),
                        const SizedBox(height: 24),
                        _buildChartsRow(),
                        const SizedBox(height: 24),
                        _buildRecentTransactionsTable(),
                      ],
                    ),
                  ),

                  if (!isMobile) const SizedBox(width: 20),
                  if (isMobile) const SizedBox(height: 24),

                  // RIGHT SIDE PANELS
                  Expanded(
                    flex: isMobile ? 0 : 1,
                    child: Column(
                      children: [
                        _buildTopSellingProducts(),
                        const SizedBox(height: 24),
                        _buildLowStockAlert(),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildQuickActions() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: cardDecoration(),
      child: LayoutBuilder(
        builder: (context, constraints) {
          return FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minWidth: constraints.maxWidth,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.bolt, color: Colors.amber, size: 20),
                      const SizedBox(width: 8),
                      const Text(
                        'Quick Actions:', 
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: textDark)
                      ),
                    ],
                  ),
                  const SizedBox(width: 16),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _actionButton(Icons.add_shopping_cart, 'Product', Colors.purple, () => onMenuSelect('Products')),
                      const SizedBox(width: 8),
                      _actionButton(Icons.percent_rounded, 'Promo', Colors.blue, () => onMenuSelect('Promos')),
                      const SizedBox(width: 8),
                      _actionButton(Icons.file_download_outlined, 'Report', Colors.green, () => onMenuSelect('Reports')),
                    ],
                  ),
                ],
              ),
            ),
          );
        }
      ),
    );
  }

  Widget _actionButton(IconData icon, String label, Color color, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: isMobile ? 8 : 12, vertical: 6),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 4),
            Text(
              label, 
              style: TextStyle(
                color: color, 
                fontWeight: FontWeight.bold, 
                fontSize: isMobile ? 11 : 12
              )
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSalesCards() {
    Widget totalSalesCard = Container(
      height: 175,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: const Color(0xFFE2F0D9),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFC5E1A5).withValues(alpha: 0.5)),
      ),
      child: Stack(
        children: [
          Positioned(
            right: isMobile ? -10 : -15,
            bottom: isMobile ? -60 : -35,
            child: Image.asset(
              'assets/images/larawan.png',
              width: isMobile ? 250 : 170,
              height: isMobile ? 250 : 170,
              fit: BoxFit.contain,
              errorBuilder: (context, error, stackTrace) => const Icon(
                Icons.analytics_outlined,
                size: 90,
                color: Colors.black12,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Row(
                  children: [
                    const Text(
                      'Total Sales (Today)',
                      style: TextStyle(
                        color: Color(0xFF388E3C),
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(color: Colors.green.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(4)),
                      child: const Text('▲ 12%', style: TextStyle(color: Colors.green, fontSize: 10, fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                isLoading && dashboardStats['total_sales_today'] == '0.00'
                  ? const SkeletonLoader(width: 140, height: 32, margin: EdgeInsets.only(top: 4))
                  : Text(
                      '₱${dashboardStats['total_sales_today']}',
                      style: const TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w900,
                        color: textDark,
                        letterSpacing: -0.5,
                      ),
                    ),
                const SizedBox(height: 10),
                Container(width: 100, height: 1, color: Colors.black12),
                const SizedBox(height: 10),
                const Text(
                  'New Customers',
                  style: TextStyle(color: Colors.black54, fontSize: 12),
                ),
                isLoading && dashboardStats['new_customers_today'] == '0'
                  ? const SkeletonLoader(width: 40, height: 22, margin: EdgeInsets.only(top: 4))
                  : Text(
                      '${dashboardStats['new_customers_today']}',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: textDark,
                      ),
                    ),
              ],
            ),
          ),
        ],
      ),
    );

    Widget transactionsCard = Container(
      height: 175,
      padding: const EdgeInsets.all(16),
      decoration: cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Monthly Revenue',
                style: TextStyle(color: Colors.grey, fontSize: 12, fontWeight: FontWeight.w600),
              ),
              const Icon(Icons.payments_outlined, color: Colors.blue, size: 14),
            ],
          ),
          isLoading && dashboardStats['total_revenue_month'] == '0.00'
            ? const SkeletonLoader(width: 120, height: 24, margin: EdgeInsets.only(top: 4))
            : Text(
                '₱${dashboardStats['total_revenue_month']}',
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: textDark),
              ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Gross Profit (Est.)',
                style: TextStyle(color: Colors.grey, fontSize: 12, fontWeight: FontWeight.w600),
              ),
              const Icon(Icons.trending_up, color: Colors.green, size: 14),
            ],
          ),
          isLoading && (dashboardStats['total_profit_month'] == null || dashboardStats['total_profit_month'] == '0.00')
            ? const SkeletonLoader(width: 120, height: 24, margin: EdgeInsets.only(top: 4))
            : Text(
                '₱${dashboardStats['total_profit_month'] ?? '0.00'}',
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: Colors.green),
              ),
        ],
      ),
    );

    return Flex(
      direction: isMobile ? Axis.vertical : Axis.horizontal,
      crossAxisAlignment: isMobile ? CrossAxisAlignment.stretch : CrossAxisAlignment.start,
      children: [
        isMobile ? totalSalesCard : Expanded(flex: 1, child: totalSalesCard),
        if (isMobile) const SizedBox(height: 16) else const SizedBox(width: 20),
        isMobile ? transactionsCard : Expanded(flex: 1, child: transactionsCard),
      ],
    );
  }

  Widget _buildRecentTransactionsTable() {
    final physicalTrans = transactionsList.where((tx) => tx['order_type'] != 'Online').take(4).toList();
    final onlineTrans = transactionsList.where((tx) => tx['order_type'] == 'Online').take(4).toList();

    return Column(
      children: [
        // PHYSICAL STORE SALES TABLE
        Container(
          padding: const EdgeInsets.all(20),
          decoration: cardDecoration(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.storefront, color: Color(0xFFD68A96), size: 20),
                      SizedBox(width: 8),
                      Text(
                        'Recent Physical Store Sales',
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: textDark),
                      ),
                    ],
                  ),
                  TextButton(
                    onPressed: () => onMenuSelect('Transactions'),
                    child: const Text('View All', style: TextStyle(color: Colors.blue, fontSize: 12)),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              if (isLoading && physicalTrans.isEmpty)
                Column(
                  children: List.generate(3, (index) => const Padding(
                    padding: EdgeInsets.symmetric(vertical: 8.0),
                    child: SkeletonLoader(width: double.infinity, height: 40),
                  )),
                )
              else if (physicalTrans.isEmpty)
                const Center(child: Padding(
                  padding: EdgeInsets.all(20.0),
                  child: Text('No physical sales found.', style: TextStyle(color: Colors.grey)),
                ))
              else
                _buildTransactionList(physicalTrans, isOnline: false),
            ],
          ),
        ),
        
        const SizedBox(height: 24),

        // ONLINE ORDERS TABLE
        Container(
          padding: const EdgeInsets.all(20),
          decoration: cardDecoration(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.shopping_bag_outlined, color: Colors.blue, size: 20),
                      SizedBox(width: 8),
                      Text(
                        'Recent Online Orders',
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: textDark),
                      ),
                    ],
                  ),
                  TextButton(
                    onPressed: () => onMenuSelect('Orders'),
                    child: const Text('View All', style: TextStyle(color: Colors.blue, fontSize: 12)),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              if (isLoading && onlineTrans.isEmpty)
                Column(
                  children: List.generate(3, (index) => const Padding(
                    padding: EdgeInsets.symmetric(vertical: 8.0),
                    child: SkeletonLoader(width: double.infinity, height: 40),
                  )),
                )
              else if (onlineTrans.isEmpty)
                const Center(child: Padding(
                  padding: EdgeInsets.all(20.0),
                  child: Text('No online orders found.', style: TextStyle(color: Colors.grey)),
                ))
              else
                _buildTransactionList(onlineTrans, isOnline: true),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTransactionList(List<dynamic> list, {required bool isOnline}) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: SizedBox(
        width: 550,
        child: Column(
          children: [
            Container(
              decoration: BoxDecoration(
                color: const Color(0xFFEEF2F6),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Table(
                columnWidths: const {
                  0: FlexColumnWidth(2),
                  1: FlexColumnWidth(3),
                  2: FlexColumnWidth(2),
                  3: FlexColumnWidth(2),
                },
                children: [buildTableRowHeader()],
              ),
            ),
            Table(
              border: TableBorder(horizontalInside: BorderSide(color: Colors.grey.shade100, width: 1)),
              columnWidths: const {
                0: FlexColumnWidth(2),
                1: FlexColumnWidth(3),
                2: FlexColumnWidth(2),
                3: FlexColumnWidth(2),
              },
              defaultVerticalAlignment: TableCellVerticalAlignment.middle,
              children: List<TableRow>.from(
                list.map((tx) {
                  final String rawStatus = tx['order_status'] ?? 'Pending';
                  final String displayStatus = (!isOnline && rawStatus.toLowerCase() == 'delivered') 
                      ? 'PAID' 
                      : rawStatus.toUpperCase();

                  return TableRow(
                    children: [
                      InkWell(
                        onTap: () => showProfessionalReceipt(context, tx, storeSettings: storeSettings),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 14.0, horizontal: 8.0),
                          child: Text(tx['transaction_id']?.toString() ?? 'N/A', style: const TextStyle(color: Colors.blue, fontWeight: FontWeight.bold, fontSize: 12)),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 14.0, horizontal: 8.0), 
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                tx['customer_name']?.toString() ?? (isOnline ? 'Online Customer' : 'Walk-in Customer'), 
                                style: const TextStyle(color: Colors.black87, fontSize: 12),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (isOnline)
                              Container(
                                margin: const EdgeInsets.only(left: 4),
                                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                                decoration: BoxDecoration(
                                  color: Colors.blue.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: const Text('ONLINE', style: TextStyle(color: Colors.blue, fontSize: 8, fontWeight: FontWeight.bold)),
                              ),
                          ],
                        )
                      ),
                      Padding(padding: const EdgeInsets.symmetric(vertical: 14.0, horizontal: 8.0), child: Text('₱${tx['total_amount']}', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12))),
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 10.0, horizontal: 8.0),
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                            decoration: BoxDecoration(
                              color: _getStatusColor(rawStatus).withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              displayStatus,
                              style: TextStyle(color: _getStatusColor(rawStatus), fontWeight: FontWeight.bold, fontSize: 11),
                            ),
                          ),
                        ),
                      ),
                    ],
                  );
                }),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopSellingProducts() {
    final displayProducts = topSellingProducts;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Top Selling Products',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: textDark),
              ),
              TextButton(
                onPressed: () => onMenuSelect('Reports'),
                child: const Text('View All', style: TextStyle(color: Colors.grey, fontSize: 12, fontWeight: FontWeight.w600)),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (isLoading && displayProducts.isEmpty)
            Column(
              children: List.generate(3, (index) => Padding(
                padding: const EdgeInsets.only(bottom: 12.0),
                child: Row(
                  children: [
                    const SkeletonLoader(width: 48, height: 48, borderRadius: 10),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SkeletonLoader(width: 120, height: 16),
                          const SizedBox(height: 6),
                          const SkeletonLoader(width: 60, height: 12),
                        ],
                      ),
                    ),
                  ],
                ),
              )),
            )
          else if (displayProducts.isEmpty)
            const Text('Walang data ng benta.', style: TextStyle(fontSize: 12, color: Colors.grey))
          else
            ...displayProducts.map((prod) {
              String name = prod['name'] ?? 'Unknown Item';
              String soldCount = "${prod['total_sold'] ?? 0} sold";
              
              String imgUrl = prod['image_url'] ?? '';
              if (imgUrl.isNotEmpty && !imgUrl.startsWith('http')) {
                imgUrl = '$baseUrl/$imgUrl';
              }

              return Padding(
                padding: const EdgeInsets.only(bottom: 12.0),
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
                        child: imgUrl.isNotEmpty
                            ? Image.network(
                                imgUrl,
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
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: textDark, letterSpacing: -0.2),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            soldCount,
                            style: TextStyle(fontSize: 11, color: Colors.grey.shade600, fontWeight: FontWeight.w500),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }

  Widget _buildLowStockAlert() {
    int lowStockCount = int.tryParse(dashboardStats['low_stock_count'].toString()) ?? 0;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Low Stock Alert',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: textDark),
          ),
          const SizedBox(height: 16),
          Material(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(24),
            child: ListTile(
              contentPadding: EdgeInsets.zero,
              leading: CircleAvatar(
                backgroundColor: lowStockCount > 0 ? Colors.red.withValues(alpha: 0.1) : Colors.green.withValues(alpha: 0.1),
                child: Icon(Icons.notifications_active, color: lowStockCount > 0 ? Colors.red : Colors.green, size: 18),
              ),
              title: Text(
                lowStockCount > 0 ? '$lowStockCount na Produkto ang Paubos' : 'Ligtas ang Lahat ng Stocks',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: textDark),
              ),
              subtitle: Text(
                lowStockCount > 0 ? 'Kailangan nang mag-reorder sa supplier.' : 'Sapat ang bilangan ng iyong imbentaryo.',
                style: const TextStyle(fontSize: 11, color: Colors.grey),
              ),
            ),
          ),
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
      case 'refunded': return Colors.red;
      default: return Colors.grey;
    }
  }

  Widget _buildChartsRow() {
    return Flex(
      direction: isMobile ? Axis.vertical : Axis.horizontal,
      crossAxisAlignment: isMobile ? CrossAxisAlignment.stretch : CrossAxisAlignment.start,
      children: [
        Expanded(
          flex: isMobile ? 0 : 4,
          child: Container(
            padding: const EdgeInsets.all(20),
            height: 310,
            decoration: cardDecoration(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Hourly Sales Trend', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: textDark)),
                const SizedBox(height: 15),
                Expanded(child: CustomPaint(size: Size.infinite, painter: AdvancedBarChartPainter(data: chartData['hourly_sales'] ?? []))),
              ],
            ),
          ),
        ),
        if (isMobile) const SizedBox(height: 16) else const SizedBox(width: 20),
        Expanded(
          flex: isMobile ? 0 : 3,
          child: Container(
            padding: const EdgeInsets.all(20),
            height: 310,
            decoration: cardDecoration(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Payment Methods', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: textDark)),
                    const Icon(Icons.pie_chart_outline, size: 16, color: Colors.blue),
                  ],
                ),
                const Spacer(),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    SizedBox(width: 110, height: 110, child: CustomPaint(painter: ThickDonutChartPainter(data: chartData['payment_methods'] ?? []))),
                    const SizedBox(width: 15),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          buildCategoryLabel(const Color(0xFF4DB6AC), 'GCash'),
                          buildCategoryLabel(const Color(0xFF81C784), 'Cash'),
                          buildCategoryLabel(const Color(0xFFFFB74D), 'Maya'),
                          buildCategoryLabel(const Color(0xFF64B5F6), 'Card'),
                        ],
                      ),
                    ),
                  ],
                ),
                const Spacer(),
                const Divider(),
                const Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Auto-Confirmed', style: TextStyle(fontSize: 11, color: Colors.grey)),
                    Text('98%', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.green)),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
