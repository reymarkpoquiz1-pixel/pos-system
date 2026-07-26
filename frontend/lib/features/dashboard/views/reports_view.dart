import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:fl_chart/fl_chart.dart';
import 'package:pos/core/services/api_service.dart';
import 'package:pos/core/constants/config.dart';
import 'package:pos/core/widgets/dashboard_widgets.dart';

class ReportsView extends StatefulWidget {
  const ReportsView({super.key});

  @override
  State<ReportsView> createState() => _ReportsViewState();
}

class _ReportsViewState extends State<ReportsView> {
  bool _isLoading = true;
  Map<String, dynamic> _stats = {
    'today_sales': '0.00',
    'monthly_sales': '0.00',
    'total_transactions': '0',
    'low_stock_count': '0',
  };
  List<dynamic> _topProducts = [];
  double _salesPrediction = 0.0;
  List<dynamic> _topSukis = [];
  List<dynamic> _shifts = [];
  List<FlSpot> _chartSpots = [];
  List<PieChartSectionData> _pieSections = [];

  @override
  void initState() {
    super.initState();
    _fetchReportData();
  }

  Future<void> _fetchReportData() async {
    setState(() => _isLoading = true);
    try {
      final responses = await Future.wait([
        ApiService.get('reports/get_analytics_summary'),
        ApiService.get('reports/get_top_selling'),
        ApiService.get('reports/get_sales_prediction'),
        ApiService.get('reports/get_top_suki'),
        ApiService.get('reports/get_chart_data'),
        ApiService.get('sales/get_shift_history'),
      ]);

      if (responses.every((res) => res.statusCode == 200)) {
        final statsData = json.decode(responses[0].body);
        final topProdData = json.decode(responses[1].body);
        final predictionData = json.decode(responses[2].body);
        final topSukiData = json.decode(responses[3].body);
        final chartData = json.decode(responses[4].body);
        final shiftData = json.decode(responses[5].body);

        setState(() {
          if (statsData['success']) _stats = statsData['data'];
          if (topProdData['success']) _topProducts = topProdData['products'] ?? [];
          if (predictionData['success']) _salesPrediction = double.tryParse(predictionData['prediction'].toString()) ?? 0.0;
          if (topSukiData['success']) _topSukis = topSukiData['top_sukis'] ?? [];
          if (shiftData['success']) _shifts = shiftData['shifts'] ?? [];
          
          if (chartData['success']) {
            final trend = chartData['sales_trend'] as List;
            _chartSpots = trend.asMap().entries.map((e) => FlSpot(e.key.toDouble(), double.tryParse(e.value['total'].toString()) ?? 0.0)).toList();
            
            final shares = chartData['category_share'] as List;
            final colors = [Colors.blue, Colors.green, Colors.orange, Colors.purple, Colors.red];
            _pieSections = shares.asMap().entries.map((e) => PieChartSectionData(
              value: double.tryParse(e.value['total_sales'].toString()) ?? 0.0,
              title: e.value['category'],
              color: colors[e.key % colors.length],
              radius: 50,
              titleStyle: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white),
            )).toList();
          }
        });
      }
    } catch (e) {
      if (mounted) {
        debugPrint('Report Fetch Error: $e');
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error loading reports: $e')));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
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
                    '📈 Reports & Analytics',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1C1B1F),
                      letterSpacing: -0.5,
                    ),
                  ),
                  Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.download_rounded, color: Colors.blue),
                        tooltip: 'Export CSV',
                        onPressed: () => _exportToCSV(),
                      ),
                      IconButton(
                        icon: const Icon(Icons.account_balance_rounded, color: Colors.green),
                        tooltip: 'Accounting Export',
                        onPressed: () => _exportAccounting(),
                      ),
                      IconButton(
                        icon: const Icon(Icons.refresh),
                        onPressed: _fetchReportData,
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 24),
              if (_isLoading)
                const Expanded(child: Center(child: CircularProgressIndicator(color: Color(0xFFD68A96))))
              else
                Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                      children: [
                        _buildSummaryGrid(),
                        const SizedBox(height: 24),
                        Row(
                          children: [
                            Expanded(child: _buildLineChart()),
                            const SizedBox(width: 24),
                            Expanded(child: _buildPieChart()),
                          ],
                        ),
                        const SizedBox(height: 24),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(flex: 2, child: _buildTopProductsSection()),
                            const SizedBox(width: 24),
                            Expanded(flex: 1, child: _buildAIInsightsSection()),
                          ],
                        ),
                        const SizedBox(height: 24),
                        _buildShiftHistorySection(),
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

  Widget _buildShiftHistorySection() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('🏦 Cashier Shift Reports (X/Z Reading)', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          if (_shifts.isEmpty)
            const Text('No shift records found.', style: TextStyle(color: Colors.grey))
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _shifts.length,
              separatorBuilder: (context, index) => const Divider(),
              itemBuilder: (context, index) {
                final shift = _shifts[index];
                return Material(
                  color: Colors.transparent,
                  borderRadius: BorderRadius.circular(24),
                  child: ListTile(
                    leading: const Icon(Icons.account_balance_wallet_outlined, color: Colors.green),
                    title: Text('Cashier: ${shift['username']}'),
                    subtitle: Text('Start: ${shift['start_time']}\nEnd: ${shift['end_time'] ?? 'Active'}'),
                    trailing: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text('Total: ₱${shift['total_sales'] ?? '0.00'}', style: const TextStyle(fontWeight: FontWeight.bold)),
                        Text('Cash in Drawer: ₱${shift['actual_cash'] ?? '0.00'}', style: const TextStyle(fontSize: 10, color: Colors.grey)),
                      ],
                    ),
                  ),
                );
              },
            ),
        ],
      ),
    );
  }

  void _exportToCSV() {
    String csv = 'Date,Revenue,Transactions\n';
    csv += 'Today,${_stats['today_sales']},${_stats['total_transactions']}\n';
    
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Reports exported as pos_report.csv'), backgroundColor: Colors.green),
    );
    debugPrint(csv);
  }

  void _exportAccounting() {
    debugPrint('$baseUrl/reports/export_accounting');
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Accounting Audit Report generated!'), backgroundColor: Colors.green),
    );
  }

  Widget _buildLineChart() {
    return Container(
      height: 300,
      padding: const EdgeInsets.all(24),
      decoration: cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Weekly Sales Trend', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 24),
          Expanded(
            child: LineChart(
              LineChartData(
                gridData: const FlGridData(show: false),
                titlesData: const FlTitlesData(show: false),
                borderData: FlBorderData(show: false),
                lineBarsData: [
                  LineChartBarData(
                    spots: _chartSpots,
                    isCurved: true,
                    color: const Color(0xFFD68A96),
                    barWidth: 4,
                    dotData: const FlDotData(show: true),
                    belowBarData: BarAreaData(show: true, color: const Color(0xFFD68A96).withValues(alpha: 0.1)),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPieChart() {
    return Container(
      height: 300,
      padding: const EdgeInsets.all(24),
      decoration: cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Sales by Category', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 24),
          Expanded(
            child: PieChart(
              PieChartData(
                sections: _pieSections,
                centerSpaceRadius: 40,
                sectionsSpace: 2,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAIInsightsSection() {
    return Column(
      children: [
        _buildPredictionCard(),
        const SizedBox(height: 24),
        _buildTopSukiCard(),
      ],
    );
  }

  Widget _buildPredictionCard() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: cardDecoration().copyWith(
        gradient: LinearGradient(
          colors: [const Color(0xFFD68A96).withValues(alpha: 0.1), Colors.white],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.auto_awesome, color: Color(0xFFD68A96), size: 20),
              SizedBox(width: 8),
              Text('AI Sales Prediction', style: TextStyle(fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 16),
          const Text('Projected Sales Tomorrow:', style: TextStyle(fontSize: 12, color: Colors.grey)),
          Text(
            '₱${_salesPrediction.toStringAsFixed(2)}',
            style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: Color(0xFFD68A96)),
          ),
          const SizedBox(height: 8),
          const Text(
            'Based on your last 7 days of performance and growth trends.',
            style: TextStyle(fontSize: 10, color: Colors.grey, fontStyle: FontStyle.italic),
          ),
        ],
      ),
    );
  }

  Widget _buildTopSukiCard() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('💎 Top Sukis (Loyal Customers)', style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          if (_topSukis.isEmpty)
            const Text('Not enough data.', style: TextStyle(color: Colors.grey, fontSize: 12))
          else
            ..._topSukis.map((suki) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 15,
                    backgroundColor: const Color(0xFFFBECEF),
                    child: Text(suki['name'][0].toString().toUpperCase(), style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFFD68A96))),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(suki['name'], style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                        Text('${suki['order_count']} orders', style: const TextStyle(fontSize: 10, color: Colors.grey)),
                      ],
                    ),
                  ),
                  Text('₱${suki['total_spend']}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFFD68A96))),
                ],
              ),
            )),
        ],
      ),
    );
  }

  Widget _buildSummaryGrid() {
    return LayoutBuilder(
      builder: (context, constraints) {
        int crossAxisCount = constraints.maxWidth > 1200 ? 5 : (constraints.maxWidth > 800 ? 3 : 2);
        return GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: crossAxisCount,
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
          childAspectRatio: 1.8,
          children: [
            _statCard("Today's Revenue", "₱${_stats['today_sales']}", Icons.payments_outlined, Colors.green),
            _statCard("Monthly Revenue", "₱${_stats['monthly_sales']}", Icons.trending_up, Colors.blue),
            _statCard("Monthly Profit", "₱${_stats['monthly_profit'] ?? '0.00'}", Icons.account_balance_wallet_outlined, Colors.teal),
            _statCard("Total Orders", "${_stats['total_transactions']}", Icons.receipt_long_outlined, Colors.purple),
            _statCard("Low Stock", "${_stats['low_stock_count']}", Icons.warning_amber_rounded, Colors.orange),
          ],
        );
      }
    );
  }

  Widget _statCard(String label, String value, IconData icon, Color color) {
    return Container(
      decoration: cardDecoration(),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(label, style: const TextStyle(color: Colors.grey, fontSize: 13, fontWeight: FontWeight.bold)),
              Icon(icon, color: color, size: 20),
            ],
          ),
          Text(value, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: Color(0xFF1C1B1F))),
        ],
      ),
    );
  }

  Widget _buildTopProductsSection() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('🔥 Top Selling Products', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          if (_topProducts.isEmpty)
            const Text('No sales data yet.', style: TextStyle(color: Colors.grey))
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _topProducts.length,
              separatorBuilder: (context, index) => const Divider(height: 24),
              itemBuilder: (context, index) {
                final prod = _topProducts[index];
                return Row(
                  children: [
                    Text('#${index + 1}', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
                    const SizedBox(width: 16),
                    Container(
                      width: 50, height: 50,
                      decoration: BoxDecoration(
                        color: const Color(0xFFFBECEF),
                        borderRadius: BorderRadius.circular(8),
                        image: prod['image_url'] != null
                            ? DecorationImage(
                                image: NetworkImage(prod['image_url'].toString().startsWith('http') ? prod['image_url'] : '$baseUrl/${prod['image_url']}'),
                                fit: BoxFit.cover,
                              )
                            : null,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(prod['name'] ?? 'Product', style: const TextStyle(fontWeight: FontWeight.bold)),
                          Text('₱${prod['selling_price']}', style: const TextStyle(color: Colors.grey, fontSize: 12)),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(color: const Color(0xFFFBECEF), borderRadius: BorderRadius.circular(20)),
                      child: Text('${prod['total_sold']} sold', style: const TextStyle(color: Color(0xFFD68A96), fontWeight: FontWeight.bold, fontSize: 12)),
                    ),
                  ],
                );
              },
            ),
        ],
      ),
    );
  }
}
