import 'package:flutter/material.dart';
import 'package:pos/core/services/api_service.dart';
import 'dart:convert';
import 'package:pos/core/constants/config.dart';
import 'package:pos/core/widgets/dashboard_widgets.dart';
import 'package:pos/features/sales/views/pos_view.dart';
import 'package:pos/features/sales/views/staff_shift_view.dart';

class StaffDashboard extends StatefulWidget {
  final String username;
  final int userId;
  final int terminalId;
  final String storeName;
  final String? logoUrl;
  const StaffDashboard({super.key, required this.username, required this.userId, required this.terminalId, this.storeName = 'My POS Store', this.logoUrl});

  @override
  State<StaffDashboard> createState() => _StaffDashboardState();
}

class _StaffDashboardState extends State<StaffDashboard> {
  String _selectedMenu = 'POS System';
  bool _isSidebarExpanded = true;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  Map<String, dynamic> _storeSettings = {};
  bool _isLoadingSettings = true;

  @override
  void initState() {
    super.initState();
    _fetchSettings();
  }

  Future<void> _fetchSettings() async {
    try {
      final response = await ApiService.get('settings/get_store_settings?user_id=${widget.userId}');
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success']) {
          setState(() {
            _storeSettings = data['settings'] ?? {};
            _isLoadingSettings = false;
          });
        }
      }
    } catch (e) {
      debugPrint('Error fetching settings: $e');
      setState(() => _isLoadingSettings = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        bool isMobile = constraints.maxWidth < 1100;

        return Scaffold(
          key: _scaffoldKey,
          backgroundColor: const Color(0xFFEFF2F7),
          drawer: isMobile ? Drawer(child: _buildSidebar()) : null,
          body: SafeArea(
            child: Row(
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
                        child: _buildSidebar(),
                      ),
                    ),
                  ),
                Expanded(
                  child: Column(
                    children: [
                      _buildTopNavbar(isMobile),
                      Expanded(
                        child: _buildMainContent(),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildSidebar() {
    return Container(
      width: 240,
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(right: BorderSide(color: Colors.grey.shade200, width: 1)),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 30),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (widget.logoUrl != null)
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      image: DecorationImage(
                        image: NetworkImage('$baseUrl/${widget.logoUrl}'),
                        fit: BoxFit.contain,
                      ),
                    ),
                  )
                else
                  const Icon(Icons.storefront_rounded, color: Color(0xFF1E293B), size: 26),
                const SizedBox(width: 12),
                Flexible(
                  child: Text(
                    widget.storeName, 
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Color(0xFF1E293B)),
                    softWrap: false,
                    overflow: TextOverflow.clip,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              children: [
                _menuItem(Icons.shopping_cart_outlined, 'POS System'),
                _menuItem(Icons.lock_clock_outlined, 'Shift Management'),
                _menuItem(Icons.history_rounded, 'My Sales'),
                _menuItem(Icons.person_outline, 'My Profile'),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: buildSidebarItem(
              context, 
              Icons.logout_rounded, 
              'Logout', 
              '', 
              Colors.redAccent, 
              (val) {}, 
              isLogout: true
            ),
          ),
        ],
      ),
    );
  }

  Widget _menuItem(IconData icon, String title) {
    return buildSidebarItem(
      context, 
      icon, 
      title, 
      _selectedMenu, 
      const Color(0xFF334155), 
      (val) {
        setState(() => _selectedMenu = val);
        if (Scaffold.of(context).isDrawerOpen) {
          Navigator.pop(context);
        }
      }
    );
  }

  Widget _buildTopNavbar(bool isMobile) {
    return Container(
      color: Colors.white,
      padding: EdgeInsets.symmetric(horizontal: 24, vertical: isMobile ? 8 : 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Row(
              children: [
                if (isMobile) 
                  IconButton(
                    icon: const Icon(Icons.menu, color: Color(0xFF1E293B)),
                    onPressed: () => _scaffoldKey.currentState?.openDrawer(),
                  )
                else
                  IconButton(
                    icon: Icon(_isSidebarExpanded ? Icons.menu_open_rounded : Icons.menu_rounded, color: const Color(0xFF1E293B)),
                    onPressed: () => setState(() => _isSidebarExpanded = !_isSidebarExpanded),
                  ),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    _selectedMenu, 
                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.notifications_none_rounded, color: Colors.black87, size: 22),
              const SizedBox(width: 20),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const CircleAvatar(radius: 18, backgroundImage: NetworkImage('https://i.pravatar.cc/150?img=12')),
                  const SizedBox(width: 8),
                  if (!isMobile)
                  Flexible(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.username, 
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                          overflow: TextOverflow.ellipsis,
                        ),
                        const Text('Staff / Cashier', style: TextStyle(color: Colors.grey, fontSize: 11)),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMainContent() {
    switch (_selectedMenu) {
      case 'POS System':
        return PosView(
          username: widget.username, 
          userId: widget.userId, 
          terminalId: widget.terminalId,
          storeSettings: _storeSettings,
        );
      case 'Shift Management':
        return StaffShiftView(
          userId: widget.userId, 
          username: widget.username,
          onShiftStatusChanged: _fetchSettings, 
          storeSettings: _storeSettings,
        );
      case 'My Sales':
        return _buildMySalesHistory();
      case 'My Profile':
        return _buildMyProfile();
      default:
        return const Center(child: Text('Feature coming soon.'));
    }
  }

  Widget _buildMySalesHistory() {
    return FutureBuilder(
      future: ApiService.get('sales/get_user_orders?user_id=${widget.userId}'),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
        final data = json.decode((snapshot.data as dynamic).body);
        final sales = data['orders'] as List;

        return Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('My Transaction History', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
              const SizedBox(height: 20),
              Expanded(
                child: sales.isEmpty 
                  ? const Center(child: Text('No sales recorded today.'))
                  : ListView.builder(
                      itemCount: sales.length,
                      itemBuilder: (context, index) {
                        final s = sales[index];
                        return Card(
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                          child: ListTile(
                            leading: const CircleAvatar(backgroundColor: Color(0xFFEFF2F7), child: Icon(Icons.receipt_long, color: Color(0xFF334155))),
                            title: Text('Order ID: ${s['id']}', style: const TextStyle(fontWeight: FontWeight.bold)),
                            subtitle: Text('${s['transaction_date']} | ${s['payment_method']}'),
                            trailing: Text('₱${s['final_amount']}', style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFFD68A96))),
                            onTap: () => showProfessionalReceipt(context, s, storeSettings: _storeSettings),
                          ),
                        );
                      },
                    ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildMyProfile() {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        children: [
          const CircleAvatar(radius: 60, backgroundImage: NetworkImage('https://i.pravatar.cc/150?img=12')),
          const SizedBox(height: 20),
          Text(widget.username, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
          const Text('Staff / Cashier', style: TextStyle(color: Colors.grey)),
          const SizedBox(height: 30),
          const ListTile(leading: Icon(Icons.email), title: Text('Email'), subtitle: Text('juan@email.com')),
          const ListTile(leading: Icon(Icons.phone), title: Text('Phone'), subtitle: Text('0912-345-6789')),
          ListTile(leading: const Icon(Icons.terminal), title: const Text('Terminal ID'), subtitle: Text('POS-${widget.terminalId}')),
        ],
      ),
    );
  }
}
