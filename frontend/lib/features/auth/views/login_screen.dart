import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

import '../../../core/constants/config.dart';
import '../../../core/services/api_service.dart';
import 'register_screen.dart';
import '../../dashboard/views/admin_dashboard.dart';
import '../../dashboard/views/staff_dashboard.dart';
import '../../customer_app/views/user_dashboard.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  String _statusMessage = "";
  int _retryCount = 0;
  String _storeName = "A&M Store POS";
  String? _logoUrl;

  @override
  void initState() {
    super.initState();
    _loadCachedSettings();
    _fetchStoreName();
  }

  Future<void> _loadCachedSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cachedName = prefs.getString('cached_store_name');
      final cachedLogo = prefs.getString('cached_logo_url');
      if (cachedName != null || cachedLogo != null) {
        setState(() {
          if (cachedName != null) _storeName = "$cachedName POS";
          if (cachedLogo != null) _logoUrl = cachedLogo;
        });
      }
    } catch (e) {
      debugPrint("Cache load error: $e");
    }
  }

  Future<void> _fetchStoreName() async {
    try {
      final response = await ApiService.get('settings/get_public_settings');
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success']) {
          final sName = data['settings']['store_name'] ?? 'My Store';
          final lUrl = data['settings']['logo_url'];
          
          setState(() {
            _storeName = "$sName POS";
            _logoUrl = lUrl;
          });

          // Update cache
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('cached_store_name', sName);
          if (lUrl != null) await prefs.setString('cached_logo_url', lUrl);
        }
      }
    } catch (e) {
      debugPrint("Error fetching store name: $e");
    }
  }

  void _handleLogin() async {
    final username = _usernameController.text.trim();
    final password = _passwordController.text.trim();

    if (username.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Mangyaring punan ang lahat ng field!')),
      );
      return;
    }

    setState(() {
      _isLoading = true;
      _statusMessage = "Nag-lalogin...";
    });

    try {
      final response = await ApiService.post(
        'auth/login',
        {'username': username, 'password': password},
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 201 || response.statusCode == 200) {
        _retryCount = 0;
        final userData = data['user'];
        final String role = userData['role'];
        final String token = data['access_token'];
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
        await prefs.setInt('user_id', int.tryParse(userData['id']?.toString() ?? '0') ?? 0);
        await prefs.setString('user_role', role);

        String capitalize(String s) => s.isEmpty ? "" : s[0].toUpperCase() + s.substring(1).toLowerCase();

        final String firstName = capitalize(userData['first_name']?.toString().trim() ?? '');
        final String lastName = capitalize(userData['last_name']?.toString().trim() ?? '');

        final String fullName = (firstName.isEmpty && lastName.isEmpty) 
            ? userData['username'] 
            : "$firstName $lastName";

        final int userId = int.tryParse(userData['id']?.toString() ?? '0') ?? 0;
        final int terminalId = int.tryParse(userData['terminal_id']?.toString() ?? '0') ?? 0;

        if (!mounted) return;

        Widget targetDashboard;
        if (role == 'Admin') {
          targetDashboard = AdminDashboard(username: fullName, userId: userId, initialStoreName: storeName);
        } else if (role == 'Staff') {
          targetDashboard = StaffDashboard(
            username: fullName, 
            userId: userId, 
            terminalId: terminalId,
            storeName: storeName,
            logoUrl: logoUrl,
          );
        } else {
          targetDashboard = UserDashboard(username: fullName, userId: userId, storeName: storeName, logoUrl: logoUrl);
        }

        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => targetDashboard),
        );
      } else {
        if (!mounted) return;
        String errorMsg = data['message'] ?? 'Maling Username o Password!';
        
        if (errorMsg.contains("SERVER_SLEEPING")) {
          _retryCount++;
          if (_retryCount < 6) {
            for (int i = 5; i > 0; i--) {
              if (!mounted) return;
              setState(() {
                _statusMessage = "Ginigising ang server, susubukan muli sa loob ng $i segundo... (Attempt $_retryCount/5)";
              });
              await Future.delayed(const Duration(seconds: 1));
            }
            _handleLogin(); // Auto-retry
            return;
          } else {
            errorMsg = "Hindi magising ang server. Pakisubukang muli mamaya.";
          }
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMsg.replaceAll("SERVER_SLEEPING: ", "")),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error sa koneksyon: $e')));
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _statusMessage = "";
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Login')),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (_logoUrl != null)
                  Container(
                    margin: const EdgeInsets.only(bottom: 20),
                    width: 120,
                    height: 120,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      image: DecorationImage(
                        image: NetworkImage('$baseUrl/$_logoUrl'),
                        fit: BoxFit.contain,
                      ),
                    ),
                  )
                else
                  const Icon(Icons.store, size: 80, color: Colors.deepPurple),
                const SizedBox(height: 30),
                Text(
                  _storeName,
                  style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.deepPurple),
                ),
                const SizedBox(height: 30),
                TextField(
                  controller: _usernameController,
                  decoration: InputDecoration(
                    labelText: 'Username',
                    prefixIcon: const Icon(Icons.person),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _passwordController,
                  obscureText: true,
                  decoration: InputDecoration(
                    labelText: 'Password',
                    prefixIcon: const Icon(Icons.lock),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                const SizedBox(height: 24),
                if (_statusMessage.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Column(
                      children: [
                        Text(_statusMessage, textAlign: TextAlign.center, style: const TextStyle(color: Colors.deepPurple, fontWeight: FontWeight.bold, fontSize: 13)),
                        const SizedBox(height: 8),
                        LinearProgressIndicator(backgroundColor: Colors.deepPurple.withOpacity(0.1)),
                      ],
                    ),
                  ),
                _isLoading
                    ? (_statusMessage.isEmpty ? const CircularProgressIndicator() : const SizedBox.shrink())
                    : ElevatedButton(
                        onPressed: _handleLogin,
                        style: ElevatedButton.styleFrom(
                          minimumSize: const Size.fromHeight(55),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        child: const Text('Login', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                      ),
                const SizedBox(height: 16),
                TextButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const RegisterScreen(),
                      ),
                    );
                  },
                  child: const Text("Don't have an account? Register here"),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

