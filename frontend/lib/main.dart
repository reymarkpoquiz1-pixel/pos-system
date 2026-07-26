import 'package:flutter/material.dart';
import 'core/services/connectivity_service.dart';
import 'features/customer_app/views/storefront_view.dart';

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
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFFD68A96)),
        useMaterial3: true,
        fontFamily: 'Inter', // Assuming Inter or similar sans-serif
      ),
      home: const StoreFrontView(),
      debugShowCheckedModeBanner: false,
    );
  }
}
