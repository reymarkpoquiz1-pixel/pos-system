import 'package:flutter/material.dart';
import 'package:pos/core/services/api_service.dart';
import 'dart:convert';
import 'package:pos/core/widgets/dashboard_widgets.dart';

class AuditLogsView extends StatefulWidget {
  const AuditLogsView({super.key});

  @override
  State<AuditLogsView> createState() => _AuditLogsViewState();
}

class _AuditLogsViewState extends State<AuditLogsView> {
  List<dynamic> _logs = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchLogs();
  }

  Future<void> _fetchLogs() async {
    setState(() => _isLoading = true);
    try {
      final response = await ApiService.get('settings/get_activity_logs');
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success']) {
          setState(() {
            _logs = data['logs'] ?? [];
          });
        }
      } else if (response.statusCode == 403) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Forbidden: Admin access only.'), backgroundColor: Colors.red));
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
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
                    '📜 Audit Trails / Activity Logs',
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Color(0xFF1C1B1F), letterSpacing: -0.5),
                  ),
                  IconButton(icon: const Icon(Icons.refresh), onPressed: _fetchLogs),
                ],
              ),
              const SizedBox(height: 24),
              Expanded(
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator(color: Color(0xFFD68A96)))
                    : Container(
                        decoration: cardDecoration(),
                        child: ListView.separated(
                          itemCount: _logs.length,
                          separatorBuilder: (context, index) => const Divider(height: 1),
                          itemBuilder: (context, index) {
                            final log = _logs[index];
                            return Material(
                              color: Colors.transparent,
                              borderRadius: BorderRadius.circular(24),
                              child: ListTile(
                                leading: const Icon(Icons.history, color: Colors.grey),
                                title: Text(log['action'], style: const TextStyle(fontWeight: FontWeight.bold)),
                                subtitle: Text('By: ${log['username'] ?? 'System'} | ${log['created_at']}'),
                                trailing: const Icon(Icons.chevron_right, size: 16),
                                onTap: () {
                                  showDialog(
                                    context: context,
                                    builder: (context) => AlertDialog(
                                      title: Text(log['action']),
                                      content: Text('Details: ${log['details']}\n\nTimestamp: ${log['created_at']}'),
                                      actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close'))],
                                    ),
                                  );
                                },
                              ),
                            );
                          },
                        ),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
