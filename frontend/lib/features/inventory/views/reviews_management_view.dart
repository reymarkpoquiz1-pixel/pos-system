import 'package:flutter/material.dart';
import 'package:pos/core/services/api_service.dart';
import 'dart:convert';
import 'package:pos/core/widgets/dashboard_widgets.dart';

class ReviewsManagementView extends StatefulWidget {
  const ReviewsManagementView({super.key});

  @override
  State<ReviewsManagementView> createState() => _ReviewsManagementViewState();
}

class _ReviewsManagementViewState extends State<ReviewsManagementView> {
  List<dynamic> _reviews = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchReviews();
  }

  Future<void> _fetchReviews() async {
    setState(() => _isLoading = true);
    try {
      final response = await ApiService.get('products/get_reviews');
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success']) {
          setState(() {
            _reviews = data['reviews'] ?? [];
          });
        }
      }
    } catch (e) {
      if (mounted) {
        debugPrint('Reviews Fetch Error: $e');
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _updateStatus(int id, String status) async {
    try {
      final response = await ApiService.post('products/update_review_status', {
        'review_id': id,
        'status': status,
      });
      final data = json.decode(response.body);
      if (data['success']) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Review $status!'), backgroundColor: status == 'Approved' ? Colors.green : Colors.red));
        _fetchReviews();
      }
    } catch (e) {
      debugPrint('Update Error: $e');
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
              const Text(
                '⭐ Product Reviews Moderation',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Color(0xFF1C1B1F), letterSpacing: -0.5),
              ),
              const SizedBox(height: 24),
              Expanded(
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator(color: Color(0xFFD68A96)))
                    : _reviews.isEmpty
                        ? const Center(child: Text('No reviews to moderate.'))
                        : ListView.builder(
                            itemCount: _reviews.length,
                            itemBuilder: (context, index) {
                              final r = _reviews[index];
                              final status = r['status'] ?? 'Pending';
                              return Container(
                                margin: const EdgeInsets.only(bottom: 12),
                                decoration: cardDecoration(),
                                child: Material(
                                  color: Colors.transparent,
                                  borderRadius: BorderRadius.circular(24),
                                  child: ListTile(
                                    title: Text('${r['product_name']} - ${r['rating']} Stars', style: const TextStyle(fontWeight: FontWeight.bold)),
                                    subtitle: Text('By: ${r['user_name']}\n"${r['comment']}"'),
                                    isThreeLine: true,
                                    trailing: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        if (status != 'Approved')
                                          IconButton(icon: const Icon(Icons.check, color: Colors.green), onPressed: () => _updateStatus(r['id'], 'Approved')),
                                        if (status != 'Rejected')
                                          IconButton(icon: const Icon(Icons.close, color: Colors.red), onPressed: () => _updateStatus(r['id'], 'Rejected')),
                                      ],
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
