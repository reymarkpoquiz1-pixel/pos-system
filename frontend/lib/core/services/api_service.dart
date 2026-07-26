import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../constants/config.dart';
import 'database_helper.dart';

class ApiService {
  static Future<Map<String, String>> _getHeaders() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('jwt_token');
    
    return {
      "Content-Type": "application/json",
      if (token != null) "Authorization": "Bearer $token",
    };
  }

  static Future<http.Response> post(String endpoint, Map<String, dynamic> body) async {
    final headers = await _getHeaders();
    try {
      var response = await http.post(
        Uri.parse('$baseUrl/$endpoint'),
        headers: headers,
        body: jsonEncode(body),
      ).timeout(const Duration(seconds: 10)); // Reduced from 30s

      if (response.statusCode == 401) {
        bool refreshed = await _attemptTokenRefresh();
        if (refreshed) {
          final newHeaders = await _getHeaders();
          response = await http.post(
            Uri.parse('$baseUrl/$endpoint'),
            headers: newHeaders,
            body: jsonEncode(body),
          );
        }
      }

      _handleResponse(response);
      return response;
    } catch (e) {
      debugPrint("API POST ERROR ($endpoint): $e");
      String message = "Connection Error: $e";
      if (e.toString().contains('Connection refused') || e.toString().contains('SocketException') || e.toString().contains('TimeoutException')) {
        message = "SERVER_SLEEPING: Ang server ay kasalukuyang natutulog o mabagal. Sinusubukan ulit...";
      }
      return http.Response(jsonEncode({"success": false, "message": message}), 503);
    }
  }

  static Future<http.Response> get(String endpoint) async {
    final headers = await _getHeaders();
    try {
      var response = await http.get(
        Uri.parse('$baseUrl/$endpoint'),
        headers: headers,
      ).timeout(const Duration(seconds: 7)); // Aggressive timeout for reads

      if (response.statusCode == 401) {
        bool refreshed = await _attemptTokenRefresh();
        if (refreshed) {
          final newHeaders = await _getHeaders();
          response = await http.get(
            Uri.parse('$baseUrl/$endpoint'),
            headers: newHeaders,
          );
        }
      }

      _handleResponse(response);

      // Cache products if the request was successful
      if (endpoint.contains('products/get_products') && response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true && data['products'] != null) {
          DatabaseHelper.instance.cacheProducts(data['products']);
        }
      }

      return response;
    } catch (e) {
      debugPrint("API GET ERROR ($endpoint): $e");
      
      String message = "Connection Error: $e";
      if (e.toString().contains('Connection refused') || e.toString().contains('SocketException') || e.toString().contains('TimeoutException')) {
        message = "SERVER_SLEEPING: Ginigising ang server...";
      }

      // If offline and requesting products, try local storage
      if (endpoint.contains('products/get_products')) {
        final localProds = await DatabaseHelper.instance.getLocalProducts();
        if (localProds.isNotEmpty) {
          return http.Response(jsonEncode({"success": true, "products": localProds}), 200);
        }
      }
      return http.Response(jsonEncode({"success": false, "message": message}), 503);
    }
  }

  static Future<bool> _attemptTokenRefresh() async {
    final prefs = await SharedPreferences.getInstance();
    final refreshToken = prefs.getString('refresh_token');

    if (refreshToken == null) return false;

    try {
      final response = await http.post(
        Uri.parse('$baseUrl/auth/refresh_token'),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({"refresh_token": refreshToken}),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          await prefs.setString('jwt_token', data['token']);
          debugPrint("TOKEN REFRESHED SUCCESSFULLY");
          return true;
        }
      }
    } catch (e) {
      debugPrint("REFRESH ERROR: $e");
    }
    return false;
  }

  static Future<http.Response> upload(String endpoint, String filePath, String fieldName) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('jwt_token');

    var request = http.MultipartRequest('POST', Uri.parse('$baseUrl/$endpoint'));
    
    if (token != null) {
      request.headers['Authorization'] = 'Bearer $token';
    }

    request.files.add(await http.MultipartFile.fromPath(fieldName, filePath));

    var streamedResponse = await request.send();
    var response = await http.Response.fromStream(streamedResponse);
    
    _handleResponse(response);
    return response;
  }

  static void _handleResponse(http.Response response) {
    if (response.statusCode == 403) {
      debugPrint("FORBIDDEN ACCESS: User does not have permission.");
    } else if (response.statusCode == 401) {
      debugPrint("UNAUTHORIZED: Session expired or invalid.");
    }
  }
}
