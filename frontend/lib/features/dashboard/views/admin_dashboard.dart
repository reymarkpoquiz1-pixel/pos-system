import 'package:flutter/material.dart';
import 'package:pos/core/services/api_service.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

import 'package:pos/core/constants/config.dart';
import 'package:pos/core/widgets/dashboard_widgets.dart';
import 'dashboard_view.dart';
import 'settings_view.dart';
import 'audit_logs_view.dart';
import 'package:pos/features/inventory/views/inventory_view.dart';
import 'package:pos/features/inventory/views/products_view.dart';
import 'package:pos/features/inventory/views/categories_view.dart';
import 'package:pos/features/inventory/views/suppliers_view.dart';
import 'package:pos/features/inventory/views/reviews_management_view.dart';
import 'package:pos/features/people/views/employees_view.dart';
import 'package:pos/features/people/views/customers_view.dart';
import 'package:pos/features/sales/views/transactions_view.dart';
import 'package:pos/features/sales/views/refunds_view.dart';
import 'package:pos/features/marketing/views/promos_view.dart';
import 'package:pos/features/marketing/views/vouchers_view.dart';
import 'package:pos/features/sales/views/payments_view.dart';
import 'package:pos/features/sales/views/expenses_view.dart';
import 'package:pos/features/dashboard/views/reports_view.dart';
import 'package:pos/features/sales/views/shift_management_view.dart';

class AdminDashboard extends StatefulWidget {
  final String username;
  final int userId;
  final String initialStoreName;
  const AdminDashboard({super.key, required this.username, required this.userId, this.initialStoreName = 'My POS Store'});

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {
  String _selectedMenu = 'Dashboard';
  late String _storeName;
  String? _logoUrl;
  String? _profileImageUrl;
  bool _isLoading = true;
  bool _isSyncing = false;
  bool _isSidebarExpanded = true;

  // Data Lists
  Map<String, dynamic> _dashboardStats = {
    'total_sales_today': '0.00',
    'new_customers_today': '0',
    'total_transactions_today': '0',
    'total_revenue_month': '0.00',
    'low_stock_count': 0,
  };
  Map<String, dynamic> _storeSettings = {};
  Map<String, dynamic> _chartData = {'hourly_sales': [], 'payment_methods': []};
  List<dynamic> _productsList = [];
  List<dynamic> _topSellingProducts = [];
  List<dynamic> _categoriesList = [];
  List<dynamic> _employeesList = [];
  List<dynamic> _customersList = [];
  List<dynamic> _transactionsList = [];
  List<dynamic> _realNotifications = [];
  List<dynamic> _branches = [];
  int _selectedBranchId = 0;

  static const Color sidebarBg = Colors.white;
  static const Color contentBg = Color(0xFFF7E6E9);
  static const Color activeMenuBg = Color(0xFFD68A96);
  static const Color textDark = Color(0xFF1C1B1F);

  @override
  void initState() {
    super.initState();
    _storeName = widget.initialStoreName;
    _loadCachedData().then((_) => _fetchAllData());
  }

  Future<void> _loadCachedData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String? cachedData = prefs.getString('admin_dashboard_cache');
      if (cachedData != null) {
        final data = json.decode(cachedData);
        setState(() {
          _dashboardStats = data['stats'] ?? _dashboardStats;
          _productsList = data['products'] ?? [];
          _categoriesList = data['categories'] ?? [];
          _employeesList = data['employees'] ?? [];
          _customersList = data['customers'] ?? [];
          _transactionsList = data['transactions'] ?? [];
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Cache Error: $e');
    }
  }

  Future<void> _fetchAllData() async {
    bool hasAnyData = _productsList.isNotEmpty || _dashboardStats['total_sales_today'] != '0.00';
    if (!hasAnyData) {
      setState(() => _isLoading = true);
    } else {
      setState(() => _isSyncing = true);
    }
    
    try {
      final response = await ApiService.get('admin/get_initial_data?user_id=${widget.userId}&branch_id=$_selectedBranchId');
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('admin_dashboard_cache', response.body);
          setState(() {
            if (data['store_settings'] != null) {
              _storeSettings = data['store_settings'];
              _storeName = data['store_settings']['store_name'] ?? _storeName;
              _logoUrl = data['store_settings']['logo_url'];
            }
            if (data['current_user'] != null) _profileImageUrl = data['current_user']['profile_image'];
            _dashboardStats = data['stats'] ?? _dashboardStats;
            _chartData = data['charts'] ?? {'hourly_sales': [], 'payment_methods': []};
            _productsList = data['products'] ?? [];
            _topSellingProducts = data['top_selling_products'] ?? [];
            _categoriesList = data['categories'] ?? [];
            _employeesList = data['employees'] ?? [];
            _customersList = data['customers'] ?? [];
            _transactionsList = data['transactions'] ?? [];
            _realNotifications = data['notifications'] ?? [];
            _branches = data['branches'] ?? [];
            _isLoading = false;
            _isSyncing = false;
          });
        }
      }
    } catch (e) {
      debugPrint('Fetch Error: $e');
    } finally {
      if (mounted) setState(() { _isLoading = false; _isSyncing = false; });
    }
  }

  void _handleProductUpdate(dynamic updatedProduct) {
    setState(() {
      List<dynamic> newList = List.from(_productsList);
      
      // Find the item by its real ID or its temporary ID
      int index = newList.indexWhere((p) => p['id'].toString() == updatedProduct['id'].toString());
      
      // If not found by real ID, check if it's a replacement for an optimistic temporary ID
      if (index == -1 && updatedProduct['temp_id'] != null) {
        index = newList.indexWhere((p) => p['id'].toString() == updatedProduct['temp_id'].toString());
      }

      if (updatedProduct['status'] == 'Archived') {
        if (index != -1) newList.removeAt(index);
      } else {
        if (index != -1) {
          // Update existing item with server data
          // Note: local_image_path is intentionally NOT preserved here 
          // to allow the UI to transition from local preview to network image.
          newList[index] = updatedProduct;
        } else {
          // If totally new (not found by ID or temp_id), insert at top
          newList.insert(0, updatedProduct);
        }
      }
      _productsList = newList;
    });
    SharedPreferences.getInstance().then((prefs) {
      final String? cachedData = prefs.getString('admin_dashboard_cache');
      if (cachedData != null) {
        var data = json.decode(cachedData);
        data['products'] = _productsList;
        prefs.setString('admin_dashboard_cache', json.encode(data));
      }
    });
  }

  Widget _buildActiveView(bool isMobile) {
    switch (_selectedMenu) {
      case 'Dashboard':
        return DashboardView(
          key: const PageStorageKey('DashboardView'),
          dashboardStats: _dashboardStats,
          chartData: _chartData,
          productsList: _productsList,
          topSellingProducts: _topSellingProducts,
          transactionsList: _transactionsList,
          isMobile: isMobile,
          onMenuSelect: (menu) => setState(() => _selectedMenu = menu),
          context: context,
          storeSettings: _storeSettings,
          isLoading: _isLoading,
        );
      case 'Products':
        return ProductsView(
          key: const PageStorageKey('ProductsView'),
          productsList: _productsList,
          onRefresh: _fetchAllData,
          onProductUpdated: _handleProductUpdate,
          isMobile: isMobile,
          userId: widget.userId,
          isLoading: _isLoading,
        );
      case 'Categories': return CategoriesView(categoriesList: _categoriesList, onRefresh: _fetchAllData, isMobile: isMobile);
      case 'Inventory': return InventoryView(key: const PageStorageKey('InventoryView'), productsList: _productsList, userId: widget.userId, onRefresh: _fetchAllData);
      case 'Employees': return EmployeesView(employeesList: _employeesList, isMobile: isMobile, onRefresh: _fetchAllData);
      case 'Customers': return CustomersView(customersList: _customersList, onRefresh: _fetchAllData);
      case 'Orders': return TransactionsView(transactionsList: _transactionsList, onRefresh: _fetchAllData, storeSettings: _storeSettings);
      case 'Refunds': return const RefundsView();
      case 'Promos': return const PromosView();
      case 'Vouchers': return const VouchersView();
      case 'Payments': return PaymentsView(transactions: _transactionsList, isMobile: isMobile);
      case 'Suppliers': return const SuppliersView();
      case 'Expenses': return const ExpensesView();
      case 'Reports': return const ReportsView();
      case 'Audit Logs': return const AuditLogsView();
      case 'Shift Management': return ShiftManagementView(userId: widget.userId);
      case 'Review Management': return const ReviewsManagementView();
      case 'Settings': return SettingsView(onUpdate: _fetchAllData, userId: widget.userId);
      default: return const Center(child: Text('Dashboard'));
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final bool isMobile = constraints.maxWidth < 950;
        return Scaffold(
          backgroundColor: contentBg,
          drawer: isMobile ? Drawer(child: _buildSidebar(context)) : null,
          appBar: isMobile
              ? AppBar(
                  backgroundColor: Colors.white,
                  elevation: 0.5,
                  iconTheme: const IconThemeData(color: textDark),
                  actions: _buildAppBarActions(),
                )
              : null,
          body: Row(
            children: [
              if (!isMobile)
                AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  width: _isSidebarExpanded ? 240 : 0,
                  child: ClipRect(
                    child: OverflowBox(
                      minWidth: 240,
                      maxWidth: 240,
                      alignment: Alignment.topLeft,
                      child: _buildSidebar(context),
                    ),
                  ),
                ),
              Expanded(
                child: Column(
                  children: [
                    if (!isMobile) _buildTopNavbar(),
                    Expanded(child: _buildActiveView(isMobile)),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSidebar(BuildContext context) {
    return Container(
      width: 240,
      decoration: const BoxDecoration(
        color: sidebarBg,
        border: Border(right: BorderSide(color: Color(0xFFE2E8F0), width: 1)),
      ),
      child: Column(
        children: [
          _buildSidebarHeader(),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              children: [
                _menuItem(Icons.grid_view_rounded, 'Dashboard'),
                _menuItem(Icons.shopping_bag_outlined, 'Products'),
                _menuItem(Icons.widgets_outlined, 'Categories'),
                _menuItem(Icons.inventory_2_outlined, 'Inventory'),
                _menuItem(Icons.people_outline_rounded, 'Employees'),
                _menuItem(Icons.badge_outlined, 'Customers'),
                _menuItem(Icons.receipt_long_outlined, 'Orders'),
                _menuItem(Icons.assignment_return_outlined, 'Refunds'),
                _menuItem(Icons.percent_rounded, 'Promos'),
                _menuItem(Icons.confirmation_number_outlined, 'Vouchers'),
                _menuItem(Icons.payments_outlined, 'Payments'),
                _menuItem(Icons.local_shipping_outlined, 'Suppliers'),
                _menuItem(Icons.account_balance_wallet_outlined, 'Expenses'),
                _menuItem(Icons.bar_chart_rounded, 'Reports'),
                _menuItem(Icons.history_toggle_off_rounded, 'Audit Logs'),
                _menuItem(Icons.account_balance_wallet_outlined, 'Shift Management'),
                _menuItem(Icons.star_outline, 'Review Management'),
                _menuItem(Icons.settings_outlined, 'Settings'),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: buildSidebarItem(context, Icons.logout_rounded, 'Logout', _selectedMenu, activeMenuBg, (val) {}, isLogout: true),
          ),
        ],
      ),
    );
  }

  Widget _menuItem(IconData icon, String title) {
    return buildSidebarItem(context, icon, title, _selectedMenu, activeMenuBg, (val) => setState(() => _selectedMenu = val));
  }

  Widget _buildSidebarHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_logoUrl != null)
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                image: DecorationImage(
                  image: NetworkImage('$baseUrl/$_logoUrl'),
                  fit: BoxFit.contain,
                  onError: (exception, stackTrace) => debugPrint('Logo error'),
                ),
              ),
            )
          else
            const Icon(Icons.storefront_rounded, color: textDark, size: 26),
          const SizedBox(width: 12),
          Flexible(
            child: Text(
              _storeName,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: textDark, letterSpacing: -0.5),
              overflow: TextOverflow.clip,
              softWrap: false,
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildAppBarActions() {
    int unreadCount = _realNotifications.where((n) => n['is_read'] == '0' || n['is_read'] == 0).length;
    return [
      IconButton(icon: const Icon(Icons.refresh, size: 20, color: textDark), onPressed: _fetchAllData),
      IconButton(
        onPressed: _showNotificationDialog,
        icon: Stack(
          alignment: Alignment.center,
          children: [
            const Icon(Icons.notifications_none_rounded, color: Colors.black87, size: 22),
            if (unreadCount > 0)
              Positioned(
                right: -4,
                top: -4,
                child: Container(
                  padding: const EdgeInsets.all(2),
                  decoration: BoxDecoration(color: Colors.red, borderRadius: BorderRadius.circular(10), border: Border.all(color: Colors.white, width: 1.5)),
                  constraints: const BoxConstraints(minWidth: 14, minHeight: 14),
                  child: Text('$unreadCount', style: const TextStyle(color: Colors.white, fontSize: 7, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
                ),
              ),
          ],
        ),
      ),
      GestureDetector(
        onTap: _uploadProfileImage,
        child: CircleAvatar(
          radius: 14,
          backgroundColor: Colors.grey.shade200,
          backgroundImage: _profileImageUrl != null
              ? NetworkImage(_profileImageUrl!.startsWith('uploads/') 
                  ? '$baseUrl/$_profileImageUrl' 
                  : '$baseUrl/uploads/$_profileImageUrl')
              : const NetworkImage('https://i.pravatar.cc/150?img=47'),
        ),
      ),
      const SizedBox(width: 16),
    ];
  }

  Widget _buildTopNavbar() {
    int unreadCount = _realNotifications.where((n) => n['is_read'] == '0' || n['is_read'] == 0).length;
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Row(
              children: [
                IconButton(
                  icon: Icon(_isSidebarExpanded ? Icons.menu_open_rounded : Icons.menu_rounded, color: textDark),
                  onPressed: () => setState(() => _isSidebarExpanded = !_isSidebarExpanded),
                ),
                const SizedBox(width: 16),
                if (_branches.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(10)),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<int>(
                        value: _selectedBranchId,
                        items: [
                          const DropdownMenuItem(value: 0, child: Text('All Branches (Global)', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold))),
                          ..._branches.map((b) => DropdownMenuItem(
                            value: int.tryParse(b['id'].toString()) ?? 0,
                            child: Text(b['name'], style: const TextStyle(fontSize: 13))
                          )),
                        ],
                        onChanged: (val) {
                          if (val != null) {
                            setState(() => _selectedBranchId = val);
                            _fetchAllData();
                          }
                        },
                      ),
                    ),
                  ),
              ],
            ),
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (_isSyncing)
                const Padding(
                  padding: EdgeInsets.only(right: 8.0),
                  child: SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: activeMenuBg)),
                ),
              IconButton(icon: const Icon(Icons.refresh, color: textDark), onPressed: _fetchAllData),
              const SizedBox(width: 10),
              IconButton(
                onPressed: _showNotificationDialog,
                icon: Stack(
                  alignment: Alignment.center,
                  children: [
                    const Icon(Icons.notifications_none_rounded, color: Colors.black87, size: 24),
                    if (unreadCount > 0)
                      Positioned(
                        right: -2,
                        top: -2,
                        child: Container(
                          padding: const EdgeInsets.all(2),
                          decoration: BoxDecoration(color: Colors.red, borderRadius: BorderRadius.circular(10), border: Border.all(color: Colors.white, width: 1.5)),
                          constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                          child: Text('$unreadCount', style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 14),
              _buildUserProfile(),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildUserProfile() {
    return InkWell(
      onTap: _uploadProfileImage,
      borderRadius: BorderRadius.circular(10),
      child: Row(
        children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: Colors.grey.shade200,
            backgroundImage: _profileImageUrl != null
                ? NetworkImage(_profileImageUrl!.startsWith('uploads/') 
                    ? '$baseUrl/$_profileImageUrl' 
                    : '$baseUrl/uploads/$_profileImageUrl')
                : const NetworkImage('https://i.pravatar.cc/150?img=47'),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(widget.username, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: textDark)),
              const Text('Admin', style: TextStyle(color: Colors.grey, fontSize: 11)),
            ],
          ),
        ],
      ),
    );
  }

  void _showNotificationDialog() {
    ApiService.post('settings/mark_read', {'user_id': widget.userId}).then((_) => _fetchAllData());
    int unreadCount = _realNotifications.where((n) => n['is_read'] == '0' || n['is_read'] == 0).length;
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        alignment: Alignment.topRight,
        insetPadding: const EdgeInsets.only(top: 55, right: 20, left: 20),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned(
              top: -10,
              right: 185,
              child: CustomPaint(
                size: const Size(20, 10),
                painter: _TrianglePainter(color: const Color(0xFFFBECEF)),
              ),
            ),
            Container(
              width: 350,
              decoration: BoxDecoration(
                color: const Color(0xFFFBECEF),
                borderRadius: BorderRadius.circular(28),
                boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 20, offset: const Offset(0, 10))],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Notifications ($unreadCount)', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF1C1B1F), letterSpacing: -0.5)),
                        IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close, color: Color(0xFF1C1B1F)), padding: EdgeInsets.zero, constraints: const BoxConstraints()),
                      ],
                    ),
                  ),
                  Flexible(
                    child: _realNotifications.isEmpty
                        ? const Padding(padding: EdgeInsets.all(50), child: Column(mainAxisSize: MainAxisSize.min, children: [Icon(Icons.notifications_none_rounded, size: 50, color: Colors.black26), SizedBox(height: 12), Text('No new notifications', style: TextStyle(color: Colors.black38, fontWeight: FontWeight.w500))]))
                        : Container(
                            margin: const EdgeInsets.symmetric(horizontal: 16),
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(color: const Color(0xFFFCE1E5), borderRadius: BorderRadius.circular(24)),
                            child: ListView.builder(
                              shrinkWrap: true,
                              padding: EdgeInsets.zero,
                              itemCount: _realNotifications.length,
                              itemBuilder: (context, index) {
                                final notif = _realNotifications[index];
                                final bool isRead = notif['is_read'].toString() == '1';
                                return Container(
                                  margin: EdgeInsets.only(bottom: index == _realNotifications.length - 1 ? 0 : 20),
                                  child: Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: isRead ? Colors.grey.shade300 : const Color(0xFFD68A96).withValues(alpha: 0.2), shape: BoxShape.circle), child: Icon(notif['type'] == 'Inventory' ? Icons.inventory_2_outlined : Icons.notifications_active_outlined, color: isRead ? Colors.grey : const Color(0xFFD68A96), size: 20)),
                                      const SizedBox(width: 16),
                                      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(notif['title'] ?? 'Notification', style: TextStyle(fontWeight: FontWeight.w900, color: const Color(0xFF1C1B1F), fontSize: 14, decoration: isRead ? TextDecoration.lineThrough : null)), const SizedBox(height: 4), Text(notif['message'] ?? '', style: const TextStyle(color: Colors.black87, fontSize: 13)), const SizedBox(height: 4), Text(notif['created_at'] ?? '', style: const TextStyle(fontSize: 10, color: Colors.grey))])),
                                    ],
                                  ),
                                );
                              },
                            ),
                          ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(24),
                    child: SizedBox(width: double.infinity, height: 48, child: ElevatedButton(onPressed: () { Navigator.pop(context); setState(() => _selectedMenu = 'Inventory'); }, style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFD68A96), foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), elevation: 0), child: const Text('Check Inventory', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)))),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _uploadProfileImage() async {
    final picker = ImagePicker();
    final image = await picker.pickImage(source: ImageSource.gallery);
    if (image == null) return;
    try {
      final response = await ApiService.upload('employees/upload_profile_image', image, 'image');
      final data = json.decode(response.body);
      if (data['success']) {
        if (!mounted) return;
        setState(() { _profileImageUrl = data['profile_image']; });
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Profile picture updated!'), backgroundColor: Colors.green));
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Upload failed: ${data['message']}'), backgroundColor: Colors.red));
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
    }
  }
}

class _TrianglePainter extends CustomPainter {
  final Color color;
  _TrianglePainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color;
    final path = Path();
    path.moveTo(0, size.height);
    path.lineTo(size.width / 2, 0);
    path.lineTo(size.width, size.height);
    path.close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
