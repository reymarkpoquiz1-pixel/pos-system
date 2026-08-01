import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:intl/intl.dart';
import 'staff_register.dart';
import 'package:pos/core/widgets/dashboard_widgets.dart';
import 'package:pos/core/services/api_service.dart';
import 'package:pos/core/constants/config.dart';

class EmployeesView extends StatefulWidget {
  final List<dynamic> employeesList;
  final List<dynamic> branchesList;
  final bool isMobile;
  final VoidCallback onRefresh;

  const EmployeesView({
    super.key,
    required this.employeesList,
    required this.branchesList,
    required this.isMobile,
    required this.onRefresh,
  });

  @override
  State<EmployeesView> createState() => _EmployeesViewState();
}

class _EmployeesViewState extends State<EmployeesView> {
  final Set<String> _selectedIds = {};
  bool _isSelectionMode = false;

  // I-filter ang listahan para Staff lang ang makita
  List<dynamic> get _staffOnlyList => widget.employeesList
      .where((emp) => emp['role']?.toString().toLowerCase() == 'staff')
      .toList();

  void _toggleSelection(String id) {
    setState(() {
      if (_selectedIds.contains(id)) {
        _selectedIds.remove(id);
      } else {
        _selectedIds.add(id);
      }
    });
  }

  void _toggleSelectionMode() {
    setState(() {
      _isSelectionMode = !_isSelectionMode;
      if (!_isSelectionMode) {
        _selectedIds.clear();
      }
    });
  }

  void _selectAll(bool? select) {
    setState(() {
      if (select == true) {
        for (var emp in _staffOnlyList) {
          final id = emp['user_id']?.toString() ?? emp['username']?.toString() ?? '';
          if (id.isNotEmpty) _selectedIds.add(id);
        }
      } else {
        _selectedIds.clear();
      }
    });
  }

  Future<void> _deleteSelectedEmployees() async {
    if (_selectedIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select at least one employee to delete.')),
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm Delete'),
        content: Text('Are you sure you want to delete ${_selectedIds.length} employee(s)?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      final response = await ApiService.post(
        'employees/delete_employees', 
        {'ids': _selectedIds.toList()},
      );

      final data = jsonDecode(response.body);
      if (data['success'] == true) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Employees deleted successfully'), backgroundColor: Colors.green));
        setState(() {
          _selectedIds.clear();
          _isSelectionMode = false;
        });
        widget.onRefresh();
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(data['message'] ?? 'Delete failed'), backgroundColor: Colors.redAccent));
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.redAccent));
    }
  }

  @override
  Widget build(BuildContext context) {
    final listToShow = _staffOnlyList;

    return Scaffold(
      backgroundColor: const Color(0xFFF7E6E9),
      body: buildThemedBackground(
        child: Padding(
          padding: EdgeInsets.all(widget.isMobile ? 12 : 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '👥 Employee Accounts List',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1C1B1F),
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 20),

              Expanded(
                child: Container(
                  decoration: cardDecoration(),
                  clipBehavior: Clip.antiAlias,
                  child: Column(
                    children: [
                      Container(
                        color: const Color(0xFFD68A96),
                        child: Column(
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Padding(
                                  padding: EdgeInsets.only(left: 16),
                                  child: Opacity(
                                    opacity: 0.25,
                                    child: Icon(Icons.shopping_bag_outlined, size: 22, color: Colors.white),
                                  ),
                                ),
                                _buildHeaderButtons(context),
                              ],
                            ),
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                              child: Row(
                                children: [
                                  if (_isSelectionMode)
                                    SizedBox(
                                      width: 32,
                                      child: Checkbox(
                                        value: listToShow.isNotEmpty && _selectedIds.length == listToShow.length,
                                        onChanged: _selectAll,
                                        side: const BorderSide(color: Colors.white, width: 2),
                                        checkColor: const Color(0xFFD68A96),
                                        activeColor: Colors.white,
                                      ),
                                    ),
                                  _headerCellWithIcon('STATUS', Icons.check_circle_outline, flex: 3),
                                  _headerCell('EMPLOYEE', flex: 5),
                                  _headerCell('ACCOUNT EMAIL', flex: 5),
                                  _headerCell('DETAILS', flex: 8),
                                  _headerCell('ACTIONS', flex: 3, alignment: Alignment.centerRight),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),

                      Expanded(
                        child: listToShow.isEmpty
                            ? const Center(child: Text('Walang staff account na nakarehistro.'))
                            : ListView.separated(
                                padding: EdgeInsets.zero,
                                itemCount: listToShow.length,
                                separatorBuilder: (context, index) => Divider(height: 1, color: Colors.grey.withAlpha(50)),
                                itemBuilder: (context, index) {
                                  final emp = listToShow[index];
                                  return _buildEmployeeRow(emp);
                                },
                              ),
                      ),

                      _buildPagination(),
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

  Widget _headerCell(String label, {int flex = 1, Alignment alignment = Alignment.centerLeft}) {
    return Expanded(
      flex: flex,
      child: Align(
        alignment: alignment,
        child: Text(
          label,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 12,
            letterSpacing: 0.5,
          ),
        ),
      ),
    );
  }

  Widget _headerCellWithIcon(String label, IconData icon, {int flex = 1}) {
    return Expanded(
      flex: flex,
      child: Row(
        children: [
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 12,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(width: 4),
          Icon(icon, size: 14, color: Colors.white.withValues(alpha: 0.8)),
        ],
      ),
    );
  }

  Widget _buildEmployeeRow(dynamic emp) {
    final String firstName = (emp['first_name'] ?? '').toString().trim();
    final String lastName = (emp['last_name'] ?? '').toString().trim();
    final String username = (emp['username'] ?? '').toString().trim();
    final String id = emp['user_id']?.toString() ?? username;

    String fullName = "";
    if (firstName.isNotEmpty || lastName.isNotEmpty) {
      fullName = "$firstName $lastName";
    } else {
      fullName = username.split('@')[0].replaceAll('.', ' ').replaceAll('_', ' ');
    }

    fullName = fullName.split(' ').where((s) => s.isNotEmpty).map((str) {
      return "${str[0].toUpperCase()}${str.substring(1).toLowerCase()}";
    }).join(' ');

    if (fullName.isEmpty) fullName = username;

    final String profileImage = emp['profile_image'] ?? '';
    final String email = emp['email'] ?? (username.contains('@') ? username : 'N/A');

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          if (_isSelectionMode)
            SizedBox(
              width: 32,
              child: Checkbox(
                value: _selectedIds.contains(id),
                onChanged: (val) => _toggleSelection(id),
                activeColor: const Color(0xFFD68A96),
              ),
            ),
          
          Expanded(
            flex: 3,
            child: _statusBadge(emp['status'] ?? 'Verified'),
          ),

          Expanded(
            flex: 5,
            child: Row(
              children: [
                CircleAvatar(
                  radius: 18,
                  backgroundColor: const Color(0xFFFBECEF),
                  backgroundImage: profileImage.isNotEmpty 
                      ? NetworkImage(profileImage.startsWith('http')
                          ? profileImage
                          : (profileImage.startsWith('uploads/') 
                              ? '$baseUrl/$profileImage' 
                              : '$baseUrl/uploads/$profileImage'))
                      : null,
                  onBackgroundImageError: profileImage.isNotEmpty 
                      ? (exception, stackTrace) {
                          debugPrint('Employee profile image error: $exception');
                        }
                      : null,
                  child: profileImage.isEmpty 
                      ? const Icon(Icons.person, size: 20, color: Color(0xFFD68A96))
                      : null,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    fullName,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold, 
                      color: Color(0xFF1C1B1F), 
                      fontSize: 14,
                      letterSpacing: -0.2
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),

          Expanded(
            flex: 5,
            child: Text(
              email,
              style: TextStyle(color: Colors.black.withAlpha(150), fontSize: 13),
              overflow: TextOverflow.ellipsis,
            ),
          ),

          Expanded(
            flex: 8,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                _detailText('Username: $username'),
                _detailText('Role: ${emp['role'] ?? 'Staff'}'),
                _detailText('Terminal: ${emp['terminal_id'] ?? 'N/A'}'),
                if (emp['created_at'] != null)
                  _detailText('Registered: ${DateFormat('MMM dd, yyyy | hh:mm a').format(DateTime.parse(emp['created_at']))}'),
                _detailText('Added by: ${emp['added_by_name'] ?? 'Admin'}'),
              ],
            ),
          ),

          Expanded(
            flex: 3,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                InkWell(
                  onTap: () => AdminUserManagementForm.show(
                    context, 
                    employeeData: emp, 
                    branchesList: widget.branchesList,
                    onAccountCreated: widget.onRefresh
                  ),
                  child: _actionButton(Icons.edit_outlined, Colors.brown[700]!),
                ),
                const SizedBox(width: 8),
                _actionButton(Icons.more_horiz, Colors.black54),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _statusBadge(String status) {
    bool isVerified = status.toLowerCase() == 'verified';
    Color bgColor = isVerified ? const Color(0xFFE6F4EA) : const Color(0xFFFFF7E6);
    Color textColor = isVerified ? const Color(0xFF1E8E3E) : const Color(0xFFB45309);
    IconData icon = isVerified ? Icons.check_circle : Icons.access_time_filled;

    return UnconstrainedBox(
      alignment: Alignment.centerLeft,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: textColor),
            const SizedBox(width: 4),
            Text(
              status,
              style: TextStyle(color: textColor, fontSize: 11, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }

  Widget _detailText(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 1),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 5, right: 8),
            child: Icon(Icons.circle, size: 3, color: Colors.black54),
          ),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(fontSize: 10.5, color: Colors.black87),
            ),
          ),
        ],
      ),
    );
  }

  Widget _actionButton(IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: const Color(0xFFF2D9DE),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(icon, size: 16, color: color),
    );
  }

  Widget _buildHeaderButtons(BuildContext context) {
    return Row(
      children: [
        InkWell(
          onTap: _toggleSelectionMode,
          child: _labelHeaderButton(
            _isSelectionMode ? Icons.close : Icons.checklist_rtl_outlined,
            _isSelectionMode ? 'Cancel' : 'Select',
            color: _isSelectionMode ? Colors.black54 : const Color(0xFF7A5C61)
          ),
        ),
        const SizedBox(width: 12),
        if (_isSelectionMode) ...[
          InkWell(
            onTap: _deleteSelectedEmployees,
            child: _labelHeaderButton(
              Icons.delete_outline,
              'Delete Selected',
              color: _selectedIds.isEmpty ? Colors.grey : const Color(0xFFD68A96)
            ),
          ),
          const SizedBox(width: 12),
        ],
        SizedBox(
          height: 42,
          child: ElevatedButton.icon(
            onPressed: () => AdminUserManagementForm.show(context, branchesList: widget.branchesList, onAccountCreated: widget.onRefresh),
            icon: const Icon(Icons.add_circle_outline_rounded, size: 18),
            label: Text(
              widget.isMobile ? 'Add' : 'Add New Staff',
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFC27A86),
              foregroundColor: Colors.white,
              shape: const RoundedRectangleBorder(
                borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(12),
                ),
              ),
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 20),
            ),
          ),
        ),
      ],
    );
  }

  Widget _labelHeaderButton(IconData icon, String label, {Color? color}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFF2D9DE),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: color ?? const Color(0xFF7A5C61)),
          if (!widget.isMobile) ...[
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: color ?? const Color(0xFF7A5C61),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildPagination() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white.withAlpha(100),
        border: Border(top: BorderSide(color: Colors.grey.withAlpha(30))),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          _pageArrow(Icons.chevron_left),
          _pageNumber('1', active: true),
          _pageNumber('2'),
          _pageNumber('3'),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 4),
            child: Text('...', style: TextStyle(color: Colors.grey)),
          ),
          _pageNumber('5'),
          _pageArrow(Icons.chevron_right),
        ],
      ),
    );
  }

  Widget _pageNumber(String num, {bool active = false}) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 4),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: active ? const Color(0xFFD68A96) : Colors.transparent,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        num,
        style: TextStyle(
          fontSize: 12,
          fontWeight: active ? FontWeight.bold : FontWeight.normal,
          color: active ? Colors.white : Colors.black54,
        ),
      ),
    );
  }

  Widget _pageArrow(IconData icon) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Icon(icon, size: 20, color: Colors.black26),
    );
  }
}
