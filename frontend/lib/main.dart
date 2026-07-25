import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

import 'core/constants/config.dart';
import 'core/services/api_service.dart';
import 'features/auth/views/register_screen.dart';
import 'features/dashboard/views/admin_dashboard.dart';
import 'features/dashboard/views/staff_dashboard.dart';
import 'features/customer_app/views/user_dashboard.dart';

import 'core/services/connectivity_service.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  ConnectivityService.instance.initialize();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'POS System',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const LoginScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  String _storeName = "A&M Store POS";
  String? _logoUrl;

  @override
  void initState() {
    super.initState();
    _fetchStoreName();
  }

  Future<void> _fetchStoreName() async {
    try {
      final response = await ApiService.get('settings/get_public_settings');
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success']) {
          setState(() {
            _storeName = "${data['settings']['store_name'] ?? 'My Store'} POS";
            _logoUrl = data['settings']['logo_url'];
          });
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
    });

    try {
      final response = await ApiService.post(
        'auth/login',
        {'username': username, 'password': password},
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 201 || response.statusCode == 200) { // NestJS returns 201 for POST
        final userData = data['user'];
        final String role = userData['role'];
        final String token = data['access_token']; // NestJS typically uses access_token
        final String? refreshToken = data['refresh_token'];
        final String storeName = data['store_name'] ?? 'My POS Store';
        final String? logoUrl = data['logo_url'];

        // Save token locally
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('jwt_token', token);
        if (refreshToken != null) {
          await prefs.setString('refresh_token', refreshToken);
        }
        await prefs.setString('store_name', storeName);
        if (logoUrl != null) await prefs.setString('logo_url', logoUrl);
        await prefs.setInt('user_id', int.tryParse(userData['id']?.toString() ?? '0') ?? 0);
        await prefs.setString('user_role', role);

        // Helper para sa capitalization
        String capitalize(String s) => s.isEmpty ? "" : s[0].toUpperCase() + s.substring(1).toLowerCase();

        // Kunin at i-format ang First Name at Last Name
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(data['message'] ?? 'Maling Username o Password!'),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error sa koneksyon: $e')));
    } finally {
      // <-- NAAYOS NA DITO (Mula 'finaly' naging 'finally')
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('')),
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
                _isLoading
                    ? const CircularProgressIndicator()
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
