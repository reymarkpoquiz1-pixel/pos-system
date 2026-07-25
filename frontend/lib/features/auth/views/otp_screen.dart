import 'package:flutter/material.dart';
import 'package:pos/core/services/api_service.dart';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:pos/features/dashboard/views/admin_dashboard.dart';
import 'package:pos/features/dashboard/views/staff_dashboard.dart';
import 'package:pos/features/customer_app/views/user_dashboard.dart';

class OtpScreen extends StatefulWidget {
  final int userId;
  final String email;
  final Map<String, dynamic> loginData; // Pass original login response to complete login
  const OtpScreen({super.key, required this.userId, required this.email, required this.loginData});

  @override
  State<OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends State<OtpScreen> {
  final _otpController = TextEditingController();
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _sendOtp();
  }

  Future<void> _sendOtp() async {
    await ApiService.post('auth/send_otp', {'user_id': widget.userId});
  }

  void _verifyOtp() async {
    if (_otpController.text.length < 6) return;

    setState(() => _isLoading = true);
    try {
      final response = await ApiService.post('auth/verify_otp', {
        'user_id': widget.userId,
        'code': _otpController.text,
      });

      final data = jsonDecode(response.body);
      if (data['success']) {
        // Complete login flow
        _completeLogin();
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(data['message'])));
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _completeLogin() async {
    // Logic from main.dart login
    final data = widget.loginData;
    
    if (data.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Error: Hindi makumpleto ang login (Missing Data)')),
      );
      Navigator.pop(context);
      return;
    }

    final userData = data['user'];
    if (userData == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Error: Hindi mahanap ang user data.')),
      );
      Navigator.pop(context);
      return;
    }

    final String role = userData['role'];
    final String token = data['token'];
    final String? refreshToken = data['refresh_token'];
    final String storeName = data['store_name'] ?? 'My POS Store';
    final String? logoUrl = data['logo_url'];

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('jwt_token', token);
    if (refreshToken != null) {
      await prefs.setString('refresh_token', refreshToken);
    }
    await prefs.setString('store_name', storeName);
    if (logoUrl != null) await prefs.setString('logo_url', logoUrl);
    await prefs.setInt('user_id', widget.userId);
    await prefs.setString('user_role', role);

    String capitalize(String s) => s.isEmpty ? "" : s[0].toUpperCase() + s.substring(1).toLowerCase();
    final String firstName = capitalize(userData['first_name']?.toString().trim() ?? '');
    final String lastName = capitalize(userData['last_name']?.toString().trim() ?? '');
    final String fullName = (firstName.isEmpty && lastName.isEmpty) ? userData['username'] : "$firstName $lastName";
    final int terminalId = int.tryParse(userData['terminal_id']?.toString() ?? '0') ?? 0;

    if (!mounted) return;

    Widget targetDashboard;
    if (role == 'Admin') {
      targetDashboard = AdminDashboard(username: fullName, userId: widget.userId, initialStoreName: storeName);
    } else if (role == 'Staff') {
      targetDashboard = StaffDashboard(username: fullName, userId: widget.userId, terminalId: terminalId, storeName: storeName, logoUrl: logoUrl);
    } else {
      targetDashboard = UserDashboard(username: fullName, userId: widget.userId, storeName: storeName, logoUrl: logoUrl);
    }

    Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => targetDashboard));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7E6E9),
      body: Center(
        child: Container(
          padding: const EdgeInsets.all(32),
          constraints: const BoxConstraints(maxWidth: 400),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24)),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.security, size: 60, color: Color(0xFFD68A96)),
              const SizedBox(height: 24),
              const Text('2-Step Verification', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Text('We sent a code to ${widget.email}', textAlign: TextAlign.center, style: const TextStyle(color: Colors.grey)),
              const SizedBox(height: 32),
              TextField(
                controller: _otpController,
                keyboardType: TextInputType.number,
                textAlign: TextAlign.center,
                maxLength: 6,
                style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, letterSpacing: 8),
                decoration: InputDecoration(
                  counterText: "",
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  hintText: "000000",
                ),
              ),
              const SizedBox(height: 24),
              _isLoading
                  ? const CircularProgressIndicator()
                  : ElevatedButton(
                      onPressed: _verifyOtp,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFD68A96),
                        foregroundColor: Colors.white,
                        minimumSize: const Size.fromHeight(55),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: const Text('Verify Code', style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
              const SizedBox(height: 16),
              TextButton(onPressed: _sendOtp, child: const Text("Resend Code")),
            ],
          ),
        ),
      ),
    );
  }
}
